require File.expand_path('../../../../../test/test_helper', __FILE__)

class TpcFilterableTest < ActiveSupport::TestCase
  # Minimal includer: the concern only needs #params, so the tests exercise it
  # without booting a controller or touching the request cycle.
  class FilterStub
    include RedminePurchaseRequests::TpcFilterable
    attr_reader :params

    # @project mirrors the before_action every including controller runs; the
    # concern reads it to bound sibling expansion to the visible scope.
    def initialize(params, project = nil)
      @params = params
      @project = project if project
    end
  end

  def stub(params, project = nil)
    FilterStub.new(params, project)
  end

  # --- param normalisation -------------------------------------------------

  test 'accepts a scalar param so pre-multi-select bookmarks still work' do
    assert_equal ['5'], stub(tpc_code_id: '5').selected_tpc_code_ids
  end

  test 'accepts an array param' do
    assert_equal %w[5 7], stub(tpc_code_id: %w[5 7]).selected_tpc_code_ids
  end

  test 'strips blank and nil entries' do
    assert_equal ['5'], stub(tpc_code_id: ['5', '', nil]).selected_tpc_code_ids
  end

  test 'returns an empty array when the param is absent' do
    assert_equal [], stub({}).selected_tpc_code_ids
  end

  test 'coerces integer ids to strings for comparison' do
    assert_equal %w[5 7], stub(tpc_code_id: [5, 7]).selected_tpc_code_ids
  end

  # --- active? -------------------------------------------------------------
  # An empty array is truthy in Ruby, so callers must never test the id list
  # for truthiness directly. These pin that down.

  test 'an all-blank selection is not an active filter' do
    assert_not stub(tpc_code_id: ['', nil]).tpc_filter_active?
  end

  test 'a populated selection is an active filter' do
    assert stub(tpc_code_id: ['5']).tpc_filter_active?
  end

  test 'a missing param is not an active filter' do
    assert_not stub({}).tpc_filter_active?
  end

  # --- membership ----------------------------------------------------------

  test 'everything is selected when no filter is set' do
    assert stub({}).tpc_selected?(99)
  end

  test 'reports membership for a selected id' do
    assert stub(tpc_code_id: %w[5 7]).tpc_selected?(7)
  end

  test 'reports non-membership for an unselected id' do
    assert_not stub(tpc_code_id: %w[5 7]).tpc_selected?(9)
  end

  # --- scope building ------------------------------------------------------

  test 'leaves the scope untouched when no filter is set' do
    sql = stub({}).apply_tpc_filter(PurchaseRequest.all).to_sql
    assert_not_includes sql, 'tpc_code_id'
  end

  test 'builds an IN clause for multiple ids' do
    sql = stub(tpc_code_id: %w[5 7]).apply_tpc_filter(PurchaseRequest.all).to_sql
    assert_match(/tpc_code_id/, sql)
    assert_match(/IN /, sql)
  end

  test 'filters TpcCode listings on id rather than the association' do
    sql = stub(tpc_code_id: %w[5 7]).apply_tpc_filter(TpcCode.all, column: :id).to_sql
    assert_match(/tpc_codes/, sql)
    assert_no_match(/tpc_code_id/, sql)
  end

  # --- sibling expansion ---------------------------------------------------
  #
  # A TPC number can exist twice, once globally and once scoped to a project.
  # The filter shows that pair as one entry and submits only the leading id,
  # so the concern has to widen the selection back out to both -- otherwise
  # every record hanging off the other row drops out of the results.

  class SiblingExpansionTest < ActiveSupport::TestCase
    NUMBER = 'TPCEXPAND1'.freeze

    def setup
      @project = Project.create!(name: 'TPC Expand Test', identifier: 'tpc-expand-test')
      @other   = Project.create!(name: 'TPC Other Test', identifier: 'tpc-other-test')
      @global  = create_tpc(project: nil)
      @scoped  = create_tpc(project: @project)
    end

    def teardown
      TpcCode.where('LOWER(tpc_number) LIKE ?', 'tpcexpand%').delete_all
      @project.destroy
      @other.destroy
    end

    def create_tpc(attrs = {})
      TpcCode.create!({
        tpc_number: NUMBER,
        tpc_owner_name: 'Test Owner',
        tpc_email: 'owner@example.com',
        is_active: true
      }.merge(attrs))
    end

    def stub(params, project = nil)
      TpcFilterableTest::FilterStub.new(params, project)
    end

    test 'selecting one id of a pair expands to both' do
      ids = stub(tpc_code_id: [@scoped.id.to_s]).expanded_tpc_code_ids

      assert_equal [@global.id, @scoped.id].sort, ids.map(&:to_i).sort
    end

    test 'expansion works from either side of the pair' do
      ids = stub(tpc_code_id: [@global.id.to_s]).expanded_tpc_code_ids

      assert_equal [@global.id, @scoped.id].sort, ids.map(&:to_i).sort
    end

    test 'the expanded ids reach the generated SQL' do
      sql = stub(tpc_code_id: [@scoped.id.to_s]).apply_tpc_filter(PurchaseRequest.all).to_sql

      assert_includes sql, @scoped.id.to_s
      assert_includes sql, @global.id.to_s
    end

    test 'a record linked to the sibling row counts as selected' do
      assert stub(tpc_code_id: [@scoped.id.to_s]).tpc_selected?(@global.id)
    end

    test 'an unrelated code is still not selected' do
      unrelated = create_tpc(tpc_number: 'TPCEXPAND2', project: nil)

      assert_not stub(tpc_code_id: [@scoped.id.to_s]).tpc_selected?(unrelated.id)
    end

    test 'case and padding differences still count as the same code' do
      padded = create_tpc(tpc_number: " #{NUMBER.downcase} ", project: @other)

      ids = stub(tpc_code_id: [@scoped.id.to_s]).expanded_tpc_code_ids

      assert_includes ids, padded.id.to_s
    end

    # Without the bound, filtering inside one project would pull in another
    # project's same-numbered code and surface rows the user cannot see.
    test 'expansion stays inside the visible scope when a project is set' do
      foreign = create_tpc(project: @other)

      ids = stub({ tpc_code_id: [@scoped.id.to_s] }, @project).expanded_tpc_code_ids

      assert_includes ids, @global.id.to_s
      assert_not_includes ids, foreign.id.to_s
    end

    # An id matching nothing must keep filtering to nothing. Dropping it would
    # turn a filter that should be empty into an unfiltered list.
    test 'an id matching no row is passed through rather than dropped' do
      missing = (TpcCode.maximum(:id) || 0) + 1000

      assert_equal [missing.to_s], stub(tpc_code_id: [missing.to_s]).expanded_tpc_code_ids
    end

    test 'no filter means no expansion' do
      assert_equal [], stub({}).expanded_tpc_code_ids
    end
  end

end

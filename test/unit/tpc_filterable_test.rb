require File.expand_path('../../../../../test/test_helper', __FILE__)

class TpcFilterableTest < ActiveSupport::TestCase
  # Minimal includer: the concern only needs #params, so the tests exercise it
  # without booting a controller or touching the request cycle.
  class FilterStub
    include RedminePurchaseRequests::TpcFilterable
    attr_reader :params

    def initialize(params)
      @params = params
    end
  end

  def stub(params)
    FilterStub.new(params)
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
end

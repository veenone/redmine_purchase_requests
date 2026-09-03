require File.expand_path('../../../../../test/test_helper', __FILE__)

# sort_update takes a whitelist, and anything outside it is silently ignored by
# sort_clause -- so a typo'd column name produces a header that looks clickable
# and does nothing, with no error anywhere. These tests pin each whitelist to
# the columns that actually exist.
class SortableColumnsTest < ActiveSupport::TestCase
  SORTABLE = {
    PurchaseRequest => %w[id title status_id user_id estimated_price tpc_code_id created_at updated_at],
    Capex           => %w[year tpc_code_id description total_amount],
    Opex            => %w[year opex_code description total_amount category_id tpc_code_id],
    TpcCode         => %w[tpc_number tpc_name tpc_owner_name department tpc_email description project_id is_active],
    Vendor          => %w[name vendor_id country email phone contact_person website project_id is_active]
  }.freeze

  SORTABLE.each do |model, columns|
    test "every sortable column on #{model.name} exists in the database" do
      missing = columns - model.column_names
      assert_empty missing,
                   "#{model.name} sorts on #{missing.join(', ')}, which the table does not have; " \
                   'those headers would render as dead links'
    end
  end

  test 'sort_clause honours the whitelist' do
    allowed = %w[title created_at]
    assert_equal ['title ASC'], Redmine::SortCriteria.new('title:asc').sort_clause(allowed)
    assert_equal ['title DESC'], Redmine::SortCriteria.new('title:desc').sort_clause(allowed)
  end

  test 'sort_clause ignores a column outside the whitelist' do
    assert_nil Redmine::SortCriteria.new('estimated_price:asc').sort_clause(%w[title])
  end

  test 'sort_clause ignores injection attempts' do
    assert_nil Redmine::SortCriteria.new("title'; DROP TABLE purchase_requests;--:asc").sort_clause(%w[title])
  end

  # reorder, not order: these scopes carry a default ordering, and order would
  # append to it, leaving the original sort in charge.
  test 'reorder replaces an existing default ordering' do
    sql = PurchaseRequest.order(created_at: :desc).reorder('title ASC').to_sql
    assert_match(/ORDER BY title ASC/, sql)
    assert_no_match(/created_at.*DESC/, sql[/ORDER BY.*/])
  end
end

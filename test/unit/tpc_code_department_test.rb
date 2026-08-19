require File.expand_path('../../../../../test/test_helper', __FILE__)

# Covers what migration 039 owns: the foreign key exists and every TPC code
# carrying a department string has been linked to a Department. Also covers
# the belongs_to :department association added alongside it (Task 3) and the
# search scope that joins through it.
class TpcCodeDepartmentTest < ActiveSupport::TestCase
  def setup
    @dept = Department.create!(name: 'Research')
  end

  def teardown
    TpcCode.where(tpc_number: 'TPCTEST1').delete_all
    Department.where(name: 'Research').delete_all
  end

  def build_tpc(attrs = {})
    TpcCode.new({
      tpc_number: 'TPCTEST1',
      tpc_owner_name: 'Test Owner',
      tpc_email: 'owner@example.com'
    }.merge(attrs))
  end

  test 'the foreign key column exists' do
    assert_includes TpcCode.column_names, 'department_id'
  end

  # tpc_codes.department is still present on purpose: 039 is additive, and 040
  # drops it immediately before the restart that activates the new code.
  # Dropping it earlier would break the running app, which keeps naming the
  # column in its writes.
  test 'the string column survives until migration 040' do
    assert_includes TpcCode.column_names, 'department'
  end

  test 'every TPC code carrying a department string has been linked' do
    # Raw SQL on purpose. With belongs_to :department in place, the hash form
    # where(department: ...) is rewritten against department_id, which makes
    # this assertion a tautology that can never fail.
    unlinked = TpcCode.where(
      "tpc_codes.department IS NOT NULL AND tpc_codes.department != '' AND tpc_codes.department_id IS NULL"
    ).count
    assert_equal 0, unlinked,
                 'the backfill must leave no departmented TPC code without a department_id'
  end

  test 'the backfill collapsed name variants into a single department' do
    names = Department.pluck(:name).map { |n| n.to_s.strip.downcase }
    assert_equal names.uniq.size, names.size,
                 'case and whitespace variants must not have produced duplicate departments'
  end

  test 'a TPC code links to a department' do
    tpc = build_tpc(department: @dept)
    assert tpc.valid?
    assert_equal 'Research', tpc.department.name
  end

  test 'a TPC code may have no department' do
    assert build_tpc.valid?
  end

  test 'deleting a department nullifies the link rather than the TPC code' do
    tpc = build_tpc(department: @dept)
    tpc.save!
    assert_not_nil tpc.department_id, 'the association must have set the foreign key'
    @dept.destroy
    assert TpcCode.exists?(tpc.id), 'the TPC code must survive'
    assert_nil tpc.reload.department_id
  end

  test 'search matches on department name' do
    tpc = build_tpc(department: @dept)
    tpc.save!
    assert_includes TpcCode.search('research').pluck(:id), tpc.id
  end

  test 'search matches on department code' do
    @dept.update!(code: 'RND')
    tpc = build_tpc(department: @dept)
    tpc.save!
    assert_includes TpcCode.search('rnd').pluck(:id), tpc.id
  end

  test 'search still returns TPC codes that have no department' do
    tpc = build_tpc(tpc_owner_name: 'Findable Person')
    tpc.save!
    assert_includes TpcCode.search('findable').pluck(:id), tpc.id
  end
end

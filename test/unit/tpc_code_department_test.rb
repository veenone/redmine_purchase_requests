require File.expand_path('../../../../../test/test_helper', __FILE__)

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

  # tpc_codes.department is deliberately still present at this point: migration
  # 039 is additive, and 040 drops it immediately before the restart that
  # activates the new code. Dropping it earlier would break the running app,
  # which keeps naming the column in its writes. The assertion that it is gone
  # belongs with 040, not here.
  test 'every TPC code carrying a department string has been linked' do
    unlinked = TpcCode.where.not(department: [nil, '']).where(department_id: nil).count
    assert_equal 0, unlinked,
                 'the backfill must leave no departmented TPC code without a department_id'
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
    @dept.destroy
    assert TpcCode.exists?(tpc.id), 'the TPC code must survive'
    assert_nil tpc.reload.department_id
  end
end

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

  test 'the string column is gone' do
    assert_not_includes TpcCode.column_names, 'department'
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

require File.expand_path('../../../../../test/test_helper', __FILE__)

# Covers what migration 039 owns: the foreign key exists and every TPC code
# carrying a department string has been linked to a Department.
#
# Association behaviour is deliberately NOT tested here. TpcCode has no
# belongs_to :department yet, so a test assigning a Department to it would
# write the object's to_s into the surviving string column: one such test
# fails outright, and a dependent: :nullify test passes vacuously because
# department_id was never set. Those tests ship with the association itself.
class TpcCodeDepartmentTest < ActiveSupport::TestCase
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
    unlinked = TpcCode.where.not(department: [nil, '']).where(department_id: nil).count
    assert_equal 0, unlinked,
                 'the backfill must leave no departmented TPC code without a department_id'
  end

  test 'the backfill collapsed name variants into a single department' do
    names = Department.pluck(:name).map { |n| n.to_s.strip.downcase }
    assert_equal names.uniq.size, names.size,
                 'case and whitespace variants must not have produced duplicate departments'
  end
end

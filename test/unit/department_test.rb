require File.expand_path('../../../../../test/test_helper', __FILE__)

class DepartmentTest < ActiveSupport::TestCase
  def teardown
    Department.delete_all
  end

  test 'requires a name' do
    assert_not Department.new(name: nil).valid?
  end

  test 'rejects a duplicate name regardless of case' do
    Department.create!(name: 'R&D')
    dup = Department.new(name: 'r&d')
    assert_not dup.valid?
    assert_includes dup.errors.attribute_names, :name
  end

  test 'allows a blank code because the migration cannot invent one' do
    assert Department.new(name: 'Finance').valid?
  end

  test 'allows several departments to have blank codes at once' do
    Department.create!(name: 'Finance')
    assert Department.new(name: 'Legal').valid?
  end

  test 'rejects a duplicate code when one is present' do
    Department.create!(name: 'Finance', code: 'FIN')
    assert_not Department.new(name: 'Legal', code: 'FIN').valid?
  end

  test 'display_name shows code and name when a code is set' do
    assert_equal 'FIN - Finance', Department.new(code: 'FIN', name: 'Finance').display_name
  end

  test 'display_name falls back to the name while the code is blank' do
    assert_equal 'Finance', Department.new(name: 'Finance').display_name
  end

  test 'ordered sorts coded departments before uncoded ones' do
    b = Department.create!(name: 'Beta')
    a = Department.create!(name: 'Alpha', code: 'AAA')
    assert_equal [a.id, b.id], Department.ordered.pluck(:id)
  end
end

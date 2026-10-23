require File.expand_path('../../../../../test/test_helper', __FILE__)

# A TPC number can exist twice -- once globally, once scoped to a project --
# because TpcCode's uniqueness validation is scoped to project_id. The filter
# used to render that pair as two identical-looking entries which each matched
# only their own records. These cover the grouping that collapses them.
class TpcCodeMergeTest < ActiveSupport::TestCase
  NUMBER = 'TPCMERGE1'.freeze

  def setup
    @project = Project.create!(name: 'TPC Merge Test', identifier: 'tpc-merge-test')
    @dept    = Department.create!(name: 'Merge Test Dept')
  end

  def teardown
    TpcCode.where('LOWER(tpc_number) LIKE ?', 'tpcmerge%').delete_all
    Department.where(name: 'Merge Test Dept').delete_all
    @project.destroy
  end

  def create_tpc(attrs = {})
    TpcCode.create!({
      tpc_number: NUMBER,
      tpc_owner_name: 'Test Owner',
      tpc_email: 'owner@example.com',
      is_active: true
    }.merge(attrs))
  end

  # --- normalisation -------------------------------------------------------

  test 'numbers differing only by case or padding are the same code' do
    assert_equal TpcCode.normalize_number(' TPC1969 '), TpcCode.normalize_number('tpc1969')
  end

  # --- grouping ------------------------------------------------------------

  test 'a global code and its project namesake collapse into one entry' do
    create_tpc(project: nil)
    create_tpc(project: @project)

    entries = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER))

    assert_equal 1, entries.size
    assert entries.first.merged?
  end

  test 'the merged entry carries every underlying id' do
    global  = create_tpc(project: nil)
    scoped  = create_tpc(project: @project)

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal [global.id, scoped.id].sort, entry.group_ids.sort
  end

  test 'a code with no namesake is left alone' do
    solo = create_tpc(tpc_number: 'TPCMERGE2', project: nil)

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: 'TPCMERGE2')).first

    assert_not entry.merged?
    assert_equal [solo.id], entry.group_ids
  end

  test 'a plain row reports itself as its own group' do
    solo = create_tpc(tpc_number: 'TPCMERGE2', project: nil)

    assert_equal [solo.id], solo.group_ids
  end

  test 'codes that merely start alike are not grouped together' do
    create_tpc(tpc_number: 'TPCMERGE2', project: nil)
    create_tpc(tpc_number: 'TPCMERGE23', project: nil)

    entries = TpcCode.merged_for_filter(TpcCode.where('tpc_number LIKE ?', 'TPCMERGE2%'))

    assert_equal 2, entries.size
  end

  # --- which row's details win --------------------------------------------

  test 'the project row leads, so its own wording wins' do
    create_tpc(project: nil, tpc_name: 'Global Name')
    create_tpc(project: @project, tpc_name: 'Project Name')

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal 'Project Name', entry.tpc_name
  end

  # The live data has exactly this shape: an imported project row with no
  # tpc_name beside a global row carrying the real one. Without the fallback
  # the entry renders as a bare owner name.
  test 'a blank field on the project row falls back to the global row' do
    create_tpc(project: nil, tpc_name: 'Global Name', department: @dept)
    create_tpc(project: @project, tpc_name: nil, department: nil)

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal 'Global Name', entry.tpc_name
    assert_equal @dept, entry.department
    assert_equal "#{NUMBER} - Global Name", entry.display_name
  end

  test 'surrounding whitespace is stripped out of the displayed owner' do
    create_tpc(project: @project, tpc_name: nil, tpc_owner_name: '  Gilbert ASUNCION  ')

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal "#{NUMBER} - Gilbert ASUNCION", entry.display_name
  end

  test 'the entry takes the project row id, so the checkbox value is unchanged' do
    create_tpc(project: nil)
    scoped = create_tpc(project: @project)

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal scoped.id, entry.id
  end

  test 'a merged entry names every scope it covers' do
    create_tpc(project: nil)
    create_tpc(project: @project)

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal 'TPC Merge Test + Global', entry.scope_display
  end

  # --- delegation ----------------------------------------------------------

  test 'untouched attributes still delegate to the leading row' do
    create_tpc(project: nil)
    scoped = create_tpc(project: @project, tpc_email: 'scoped@example.com')

    entry = TpcCode.merged_for_filter(TpcCode.where(tpc_number: NUMBER)).first

    assert_equal 'scoped@example.com', entry.tpc_email
    assert_equal scoped.tpc_number, entry.tpc_number
  end

  test 'entries come back ordered by number' do
    create_tpc(tpc_number: 'TPCMERGE3', project: nil)
    create_tpc(tpc_number: 'TPCMERGE2', project: nil)

    numbers = TpcCode.merged_for_filter(
      TpcCode.where(tpc_number: %w[TPCMERGE2 TPCMERGE3])
    ).map(&:tpc_number)

    assert_equal %w[TPCMERGE2 TPCMERGE3], numbers
  end
end

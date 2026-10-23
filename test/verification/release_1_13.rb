# Verifies the 1.13.0 changes end to end through real requests.
#   bundle exec rails runner -e production plugins/redmine_purchase_requests/test/verification/release_1_13.rb [project-identifier]
# Every write happens inside a transaction that is rolled back; files copied
# to disk for the DMSF check are removed afterwards.

FAILURES = []
def check(label)
  ok = yield
  puts format('  %-66s %s', label, ok ? 'PASS' : '*** FAIL ***')
  FAILURES << label unless ok
rescue StandardError => e
  puts format('  %-66s *** ERROR *** %s', label, "#{e.class}: #{e.message.lines.first.to_s.strip[0, 80]}")
  FAILURES << label
end

project = Project.find(ARGV[0] || Project.joins(:enabled_modules).where(enabled_modules: { name: 'purchase_requests' }).first.identifier)
admin = User.active.where(admin: true).first
# Runner-process only: act as an admin without a password.
ApplicationController.class_eval { define_method(:find_current_user) { admin } }

app = ActionDispatch::Integration::Session.new(Rails.application)
app.host! 'localhost'
get = lambda do |path|
  app.get(path)
  [app.response.status, app.response.body]
end
base = "/projects/#{project.identifier}"

puts "Project: #{project.identifier}"

check('3: PR dashboard renders (was PreparedStatementInvalid)') { get.("#{base}/purchase_requests/dashboard")[0] == 200 }
check('3: PR dashboard with explicit year renders') { get.("#{base}/purchase_requests/dashboard?year=#{Date.current.year}")[0] == 200 }
check('3: TPC dashboard with year filter renders') { get.("#{base}/tpc_codes/dashboard?year=#{Date.current.year}")[0] == 200 }

pages = {
  'PR list' => "#{base}/purchase_requests?lifecycle=all",
  'CAPEX list' => "#{base}/capex",
  'CAPEX dashboard' => "#{base}/capex/dashboard",
  'OPEX list' => "#{base}/opex",
  'OPEX dashboard' => "#{base}/opex/dashboard",
  'TPC codes' => "#{base}/tpc_codes",
  'Departments' => "#{base}/departments",
  'Global TPC codes' => '/tpc_codes'
}
pages.each do |name, path|
  check("2: #{name} renders, with the pager when it has rows") do
    status, body = get.(path)
    status == 200 && (body.include?('class="pages"') || body.include?('pr-empty') || body.include?('nodata'))
  end
end

check('2: PR list shows at most 10 rows by default') do
  _, body = get.("#{base}/purchase_requests?lifecycle=all")
  body.scan('class="pr-cell-id"').size <= 10
end
check('2: per_page=25 is honoured and offered') do
  _, body = get.("#{base}/purchase_requests?lifecycle=all&per_page=25")
  total = project.purchase_requests.count
  body.scan('class="pr-cell-id"').size == [total, 25].min
end
check('2: core per_page session is untouched') do
  app.get('/projects')
  app.session[:per_page].nil? || Setting.per_page_options_array.include?(app.session[:per_page])
end

tpc_dashboard = get.("#{base}/tpc_codes/dashboard")[1]
check('6: Top-10 request counts link to the filtered request list') do
  tpc_dashboard.match?(%r{href="#{Regexp.escape(base)}/purchase_requests\?tpc_code_id=\d+"})
end
check('6: linked list count matches the dashboard count') do
  link = tpc_dashboard[%r{<a title="[^"]*" href="(#{Regexp.escape(base)}/purchase_requests\?tpc_code_id=\d+)">(\d+)</a>}, 1]
  count = tpc_dashboard[%r{href="#{Regexp.escape(link.to_s)}">(\d+)</a>}, 1].to_i
  _, list = get.(link.to_s)
  list[%r{<span class="count">\((\d+)\)</span>}, 1].to_i == count
end
check('5: cost bars are formatted with the currency') do
  tpc_dashboard.include?("tpcCostCurrency + ' ' + Number(tpc.total_cost).toLocaleString")
end

ActiveRecord::Base.transaction do
  vendor = Vendor.first || Vendor.create!(name: 'Verify Vendor 1.13')
  vendor.update!(description: 'Trades as VerifyCo')
  check('1: vendor description renders on the vendor page') { get.("/vendors/#{vendor.id}")[1].include?('Trades as VerifyCo') }
  check('1: vendor description renders in the global vendor list') { get.('/vendors')[1].include?('Trades as VerifyCo') }
  check('1: vendor description is in the CSV export') { get.('/vendors/export.csv')[1].include?('Trades as VerifyCo') }

  pr = project.purchase_requests.first
  attachment = Attachment.create!(container: pr, file: StringIO.new('verify 1.13'), filename: 'verify-1-13.pdf',
                                  author: admin, content_type: 'application/pdf')
  check('4: PR attachment listed on the project Files tab') do
    body = get.("#{base}/files")[1]
    body.include?('verify-1-13.pdf') && body.include?("purchase_requests/#{pr.id}")
  end

  if RedminePurchaseRequests::DmsfMirror.enabled_for?(project)
    RedminePurchaseRequests::DmsfMirror.sync(pr.reload)
    dmsf_file = DmsfFile.visible.find_by(project_id: project.id, name: 'verify-1-13.pdf')
    check('4: attachment copied into DMSF') { dmsf_file&.last_revision && File.exist?(dmsf_file.last_revision.disk_file) }
    check('4: copy is inside Purchase Requests / PR-<id> ...') do
      dmsf_file.dmsf_folder.title.start_with?("PR-#{pr.id} ") && dmsf_file.dmsf_folder.dmsf_folder.title == 'Purchase Requests'
    end
    RedminePurchaseRequests::DmsfMirror.sync(pr.reload)
    check('4: re-sync does not duplicate') { DmsfFile.visible.where(project_id: project.id, name: 'verify-1-13.pdf').count == 1 }
    FileUtils.rm_f(dmsf_file.last_revision.disk_file) if dmsf_file&.last_revision
  else
    puts '  (DMSF not enabled on this project, skipped DMSF checks)'
  end
  FileUtils.rm_f(attachment.diskfile)
  raise ActiveRecord::Rollback
end

puts FAILURES.empty? ? 'ALL PASS' : "#{FAILURES.size} FAILED"

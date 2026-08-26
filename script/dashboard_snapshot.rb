# Renders the CAPEX and OPEX dashboards with each controller's real computed
# assigns and writes the HTML to disk, so a refactor can be proved output-
# identical. Run via:
#   RAILS_ENV=production bundle exec rails runner \
#     plugins/redmine_purchase_requests/script/dashboard_snapshot.rb capture before
require 'fileutils'

MODE   = ARGV[0]
TAG_A  = ARGV[1]
TAG_B  = ARGV[2]
ROOT   = Rails.root.join('tmp', 'dashboard_snapshots')

# Fixtures: [name, controller, project_identifier, params]
def fixtures
  proj = Project.joins(:enabled_modules)
                .where(enabled_modules: { name: 'purchase_requests' })
                .first
  raise 'no project with purchase_requests enabled' unless proj
  years = (Capex.pluck(:year) + Opex.pluck(:year)).compact.uniq.sort
  y_data    = years.last || Date.current.year
  y_empty   = (years.max || Date.current.year) + 5
  [
    ['capex_data',  CapexController, proj, { year: y_data.to_s }],
    ['capex_empty', CapexController, proj, { year: y_empty.to_s }],
    ['opex_data',   OpexController,  proj, { year: y_data.to_s }],
    ['opex_empty',  OpexController,  proj, { year: y_empty.to_s }]
  ]
end

def render_one(controller_class, project, params)
  c = controller_class.new
  request = ActionDispatch::TestRequest.create
  request.path_parameters[:controller] = controller_class.controller_path
  request.path_parameters[:action] = 'dashboard'
  params.each { |k, v| request.path_parameters[k] = v }
  c.set_request!(request)
  c.set_response!(controller_class.make_response!(request))
  c.instance_variable_set(:@project, project)
  User.current = User.active.where(admin: true).first
  c.send(:dashboard)
  dir = controller_class.name.sub('Controller', '').underscore
  view = c.view_context
  view.lookup_context.prefixes = [dir]
  html = view.render(template: "#{dir}/dashboard", layout: false)
  normalize(html)
rescue => e
  "RENDER-ERROR #{e.class}: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
end

# Redmine's ApplicationHelper#form_tag_html stamps every <form> with a
# name="<id-or-form>-<8 hex chars>" attribute via SecureRandom.hex(4) (a
# workaround for https://bugzilla.mozilla.org/show_bug.cgi?id=1279253). That
# makes the attribute change on every single render regardless of any code
# change, which would otherwise show up as a permanent, meaningless DIFF.
# Normalize it away so the harness only reports diffs that reflect real
# output changes.
def normalize(html)
  html.gsub(/name="([a-zA-Z0-9_]*-)?[0-9a-f]{8}"/) { |m| m.sub(/[0-9a-f]{8}"\z/, 'RANDOMIZED"') }
end

case MODE
when 'capture'
  dir = ROOT.join(TAG_A)
  FileUtils.mkdir_p(dir)
  fixtures.each do |name, klass, proj, params|
    html = render_one(klass, proj, params)
    File.write(dir.join("#{name}.html"), html)
    puts "  captured #{name} (#{html.bytesize} bytes)#{' *** RENDER-ERROR ***' if html.start_with?('RENDER-ERROR')}"
  end
  puts "wrote #{dir}"
when 'compare'
  a = ROOT.join(TAG_A); b = ROOT.join(TAG_B)
  differing = []
  Dir[a.join('*.html')].sort.each do |fa|
    name = File.basename(fa)
    fb = b.join(name)
    unless File.exist?(fb)
      puts "MISSING in #{TAG_B}: #{name}"; differing << name; next
    end
    if File.read(fa) == File.read(fb)
      puts "  same  #{name}"
    else
      puts "  DIFF  #{name}"
      differing << name
      puts `diff -u #{fa} #{fb} | head -80`
    end
  end
  puts differing.empty? ? "\nALL IDENTICAL" : "\nDIFFERING: #{differing.join(', ')}"
  exit(differing.empty? ? 0 : 1)
else
  abort "usage: dashboard_snapshot.rb capture <tag> | compare <tagA> <tagB>"
end

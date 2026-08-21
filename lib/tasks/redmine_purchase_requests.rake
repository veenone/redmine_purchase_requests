namespace :redmine_purchase_requests do
  desc 'Compile every app/views/**/*.erb template in this plugin through ' \
       "Rails' own ERB handler, failing on any template that does not compile. " \
       'ERB.new(...).src alone never raises on a broken template -- it only ' \
       'generates Ruby source; this task actually compiles that source with ' \
       'RubyVM::InstructionSequence, which is what catches things like an ' \
       'unterminated string literal.'
  task check_templates: :environment do
    plugin_root = File.expand_path('../..', __dir__)
    views_glob  = File.join(plugin_root, 'app', 'views', '**', '*.erb')
    templates   = Dir.glob(views_glob).sort

    failures = []

    templates.each do |path|
      begin
        src = ActionView::Template::Handlers::ERB::Erubi.new(File.read(path)).src
        RubyVM::InstructionSequence.compile(src, path)
      rescue StandardError, SyntaxError => e
        failures << [path, e]
      end
    end

    puts "Checked #{templates.size} template(s) under #{views_glob}"

    if failures.any?
      puts
      puts "#{failures.size} template(s) failed to compile:"
      failures.each do |path, error|
        puts "  #{path}"
        puts "    #{error.class}: #{error.message.lines.first&.strip}"
      end
      abort('redmine_purchase_requests:check_templates FAILED')
    else
      puts 'All templates compiled cleanly.'
    end
  end

  # ------------------------------------------------------------------
  # Frontend debt ratchet
  # ------------------------------------------------------------------
  #
  # Every number the 1.11.0 frontend audit reported got there one commit at
  # a time. Nothing stopped it, so nothing stops it coming back. This task
  # fails only when a count goes UP -- a ratchet, not a cliff. Existing debt
  # does not have to be paid off for it to start earning its keep.
  #
  # Lower a ceiling whenever a mitigation lands. Never raise one to make a
  # build pass: that is the failure mode this exists to prevent.
  RATCHET_CEILINGS = {
    'inline style= attributes'    => 363,
    'raw font-size in ERB'        => 44,
    'raw font-size in CSS'        => 15,
    'raw hex outside <script>'    => 0,
    'raw hex inside <script>'     => 45,
    'th without scope='           => 0,
    'templates with <style>'      => 14
  }.freeze

  def self.ratchet_measure(plugin_root)
    erbs = Dir.glob(File.join(plugin_root, 'app', 'views', '**', '*.erb')).sort
              .map { |p| File.read(p) }
    css_path = File.join(plugin_root, 'assets', 'stylesheets', 'purchase_requests.css')
    css = File.exist?(css_path) ? File.read(css_path) : ''
    # :root holds the token definitions -- literal values there are the point.
    css_body = css.sub(/:root\s*\{.*?\}/m, '')

    scripts = erbs.map { |s| s.scan(/<script[^>]*>.*?<\/script>/m).join }
# A var() fallback is a defensive default, not debt: it never paints
# while its token is defined. Blank the hex inside one before counting.
fallback = /var\(\s*--pr-[a-z0-9-]+\s*,\s*#[0-9a-fA-F]{3,6}\s*\)/
outside = erbs.map do |s|
  s.gsub(/<script[^>]*>.*?<\/script>/m, '')
   .gsub(fallback) { |m| m.gsub(/#[0-9a-fA-F]{3,6}/, 'FALLBACK') }
end
    size_re = /font-size:\s*[0-9.]+(?:px|em|rem)/
    hex_re  = /#[0-9a-fA-F]{6}\b/

    {
      'inline style= attributes' => erbs.sum { |s| s.scan(/style\s*=\s*["']/).size },
      'raw font-size in ERB'     => erbs.sum { |s| s.scan(size_re).size },
      'raw font-size in CSS'     => css_body.scan(size_re).size,
      'raw hex outside <script>' => outside.sum { |s| s.scan(hex_re).size },
      'raw hex inside <script>'  => scripts.sum { |s| s.scan(hex_re).size },
      'th without scope='        => outside.sum { |s| s.scan(/<th\b(?![^>]*scope=)/).size },
      'templates with <style>'   => erbs.count { |s| s.include?('<style') }
    }
  end

  desc 'Fail if any frontend debt metric has grown past its ceiling. A ' \
       'ratchet, not a cliff: it only complains when a count goes up, so ' \
       'existing debt does not block a build. Lower a ceiling in this file ' \
       'whenever a mitigation lands; never raise one to go green.'
  task ratchet: :environment do
    plugin_root = File.expand_path('../..', __dir__)
    counts = ratchet_measure(plugin_root)

    grown = {}
    slack = {}

    counts.each do |name, n|
      ceiling = RATCHET_CEILINGS.fetch(name)
      if n > ceiling
        grown[name] = [n, ceiling]
      elsif n < ceiling
        slack[name] = [n, ceiling]
      end
      status = if n > ceiling then "GREW +#{n - ceiling}"
               elsif n < ceiling then "ok  (-#{ceiling - n})"
               else 'ok'
               end
      puts format('  %-28s %4d / %-4d %s', name, n, ceiling, status)
    end

    puts

    if grown.any?
      puts "#{grown.size} metric(s) grew:"
      grown.each do |name, (n, ceiling)|
        puts "  #{name}: #{n}, ceiling is #{ceiling}"
      end
      puts
      puts 'Use a token or a class instead of a literal. If you genuinely'
      puts 'removed some and the count still grew elsewhere, fix that first.'
      abort('redmine_purchase_requests:ratchet FAILED')
    end

    if slack.any?
      puts "nothing grew. #{slack.size} ceiling(s) can be lowered:"
      slack.each { |name, (n, ceiling)| puts "  #{name}: #{ceiling} -> #{n}" }
    else
      puts 'nothing grew, and every ceiling is tight.'
    end
  end

end

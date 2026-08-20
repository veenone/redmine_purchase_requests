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
end

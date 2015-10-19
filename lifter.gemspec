lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "lifter/version"

Gem::Specification.new do |gem|
  gem.authors       = ["Michael Amundson"]
  gem.email         = ["sumofparts@uh-oh.co"]

  gem.description   = <<-DESCRIPTION.strip.gsub(/\s+/, " ")
    A Ruby daemon for managing concurrent large file uploads independent of a web application.
  DESCRIPTION

  gem.summary       = "Painless file uploads"
  gem.homepage      = "https://github.com/sumofparts/lifter"
  gem.licenses      = ["MIT"]

  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "lifter"
  gem.require_paths = ["lib"]
  gem.version       = Lifter::VERSION

  gem.add_runtime_dependency "http_parser.rb", "~> 0.6.0"
  gem.add_runtime_dependency "http", "~> 0.9.8"
  gem.add_runtime_dependency "eventmachine", "~> 1.0.8"

  gem.add_development_dependency "bundler", "~> 1.0"
end

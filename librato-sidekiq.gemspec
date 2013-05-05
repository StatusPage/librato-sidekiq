require './lib/librato-sidekiq/version'

Gem::Specification.new do |s|
  s.name = %q{librato-sidekiq}
  s.version = Librato::Sidekiq::VERSION
  s.license = "MIT"

  s.authors = ["Scott Klein"]
  s.description = %q{Sidekiq hooks to push stats into Librato}
  s.email = %q{scott@statuspage.io}
  s.files = Dir.glob("lib/**/*") + [
     "LICENSE",
     "README.md",
     "History.md",
     "Gemfile",
     "librato-sidekiq.gemspec",
  ]
  s.homepage = %q{http://github.com/StatusPage/librato-sidekiq}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %q{Sidekiq hooks to push stats into Librato}
  s.test_files = Dir.glob("test/**/*")
  s.add_dependency(%q<sidekiq>, [">= 0"])
  s.add_dependency(%q<librato-rails>, [">= 0"])
  s.add_development_dependency(%q<mini_shoulda>, [">= 0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
end

require './lib/cacher/version'

Gem::Specification.new do |s|
  s.name = "cacher"
  s.version = Cacher.version
  s.authors = ["Jay Adkisson"]
  s.email = ["jay@goodguide.com"]
  s.summary = "All your cache are belong to us"
  s.description = "A nifty configurable frontend to any cache"
  s.homepage = "http://github.com/jayferd/cacher"
  s.rubyforge_project = "cacher"
  s.files = Dir['Gemfile', 'cacher.gemspec', 'lib/**/*.rb']

  # no dependencies
end

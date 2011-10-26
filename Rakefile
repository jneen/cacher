require 'rake/clean'

task :spec do
  spec_files = FileList.new('./spec/**/*_spec.rb')
  sh "ruby -I./lib -r ./spec/spec_helper #{spec_files.join(' ')}"
end

CLEAN.include('*.gem')
task :build => [:clean, :spec] do
  puts
  sh "gem build cacher.gemspec"
end

task :default => :spec

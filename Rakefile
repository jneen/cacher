task :spec do
  spec_files = FileList.new('./spec/**/*_spec.rb')
  sh "ruby -I./lib -r ./spec/spec_helper #{spec_files.join(' ')}"
end

task :default => :spec

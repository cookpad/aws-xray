require "bundler/gem_tasks"
task :default => :spec

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
end

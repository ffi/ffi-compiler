require 'rubygems'
require 'rubygems/tasks'
require 'rspec/core/rake_task'

Gem::Tasks.new do |t|
  t.scm.tag.format = '%s'
end

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

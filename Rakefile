require 'rubygems'
require 'rubygems/package_task'

def gem_spec
  @gem_spec ||= Gem::Specification.load('ffi-compiler.gemspec')
end

Gem::PackageTask.new(gem_spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
  pkg.package_dir = 'pkg'
end
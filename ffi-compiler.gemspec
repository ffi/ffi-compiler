Gem::Specification.new do |s|
  s.name = 'ffi-compiler'
  s.version = '1.0.0'
  s.author = 'Wayne Meissner'
  s.email = 'wmeissner@gmail.com'
  s.homepage = 'http://wiki.github.com/ffi/ffi'
  s.summary = 'Ruby FFI Rakefile generator'
  s.description = 'Ruby FFI library'
  s.files = %w(ffi-compiler.gemspec Gemfile Rakefile README.md LICENSE) + Dir.glob("{lib,spec}/**/*")
  s.has_rdoc = false
  s.license = 'Apache 2.0'
  s.required_ruby_version = '>= 1.9'
  s.add_dependency 'rake'
  s.add_dependency 'ffi', '>= 1.0.0'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubygems-tasks'
end

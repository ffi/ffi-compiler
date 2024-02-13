Gem::Specification.new do |s|
  s.name = 'ffi-compiler2'
  s.version = '2.3.0'
  s.author = 'Dāvis'
  s.email = 'davispuh@gmail.com'
  s.homepage = 'https://gitlab.com/davispuh/ffi-compiler'
  s.summary = 'Ruby FFI Rakefile generator'
  s.description = 'Ruby FFI library'
  s.files = %w(ffi-compiler.gemspec Gemfile Rakefile README.md LICENSE) + Dir.glob("{lib,spec}/**/*")
  s.license = 'Apache-2.0'
  s.required_ruby_version = '>= 1.9'
  s.add_dependency 'rake'
  s.add_dependency 'ffi', '>= 1.0.0'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubygems-tasks'
end


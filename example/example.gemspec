Gem::Specification.new do |s|
  s.name = 'example'
  s.version = '0.0.1'
  s.author = 'E. Xample'
  s.email = 'ffi-example@example.com'
  s.homepage = 'http://wiki.github.com/ffi/ffi'
  s.summary = 'Ruby FFI example'
  s.description = 'Ruby FFI example'
  s.files = %w(Rakefile example.gemspec) + Dir.glob("{lib,spec,ext}/**/*")
  s.has_rdoc = false
  s.license = 'unknown'
  s.required_ruby_version = '>= 1.9.3'
  s.extensions << 'ext/Rakefile'
  s.add_dependency 'rake'
  s.add_dependency 'ffi-compiler', '>= 0.0.2'
  s.add_development_dependency 'rspec'
end

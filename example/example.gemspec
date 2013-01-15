Gem::Specification.new do |s|
  s.name = 'example'
  s.version = '0.0.1'
  s.author = 'Wayne Meissner'
  s.email = 'wmeissner@gmail.com'
  s.homepage = 'http://wiki.github.com/ffi/ffi'
  s.summary = 'Ruby FFI example'
  s.description = 'Ruby FFI example'
  s.files = %w(example.gemspec) + Dir.glob("{lib,spec}/**/*") + Dir.glob("ext/**/*.{c,cpp}")
  s.has_rdoc = false
  s.license = 'LGPL-3'
  s.required_ruby_version = '>= 1.9.3'
  s.extensions << 'ext/mkrf_conf.rb'
  s.add_dependency 'rake'
  s.add_dependency 'ffi-compiler'
  s.add_development_dependency 'rspec'
end

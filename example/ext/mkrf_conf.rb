require 'ffi-compiler/mkrf'

FFI::Compiler.new('example') do |c|
  c.have_header?('stdio.h', '/usr/local/include')
  c.have_func?('puts')
  c.have_library?('z')
end

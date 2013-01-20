require 'ffi'
require 'ffi-compiler/loader'

module Example
  extend FFI::Library
  ffi_lib FFI::Compiler::Loader.find('example')
  
  class Foo < FFI::Struct
    layout :a, :int, :b, :int
  end
  
  class Bar < FFI::Struct
    layout :foo, Foo, :foo_ptr, Foo.by_ref
  end
  
  attach_function :example, [], :long
  attach_function :foo, [ Foo ], :int
  attach_function :bar, [ Bar.by_value, Foo ], :int
end



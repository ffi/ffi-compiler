require 'ffi'

module Example
  extend FFI::Library
  ffi_lib File.join(File.dirname(__FILE__), '..', '..', 'ext', FFI.map_library_name('example'))
  attach_function :example, [], :long
end



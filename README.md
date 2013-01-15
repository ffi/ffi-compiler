
[ffi-compiler](https://github.com/ffi/ffi-compiler) is a ruby library for automating compilation of native libraries for use with [ffi](https://github.com/ffi/ffi)

To use, define your own ruby->native API using ffi, implement it in C, then use ffi-compiler to compile it.

Example
------
	
###### Directory layout
	lib
	  |- example
	      |- example.rb
	      
	ext
      |- example.c
      |- mkrf_conf.rb
      
    example.gemspec

###### lib/example/example.rb
	require 'ffi'
	
	module Example
	  extend FFI::Library
	  
	  # Project layout is with ruby files in lib/example/, C impl in ext/
	  # Load the library by full path
	  ffi_lib File.join('../../ext', FFI.map_library_name('example'))
	  
	  # example function which takes no parameters and returns long
	  attach_function :example, [], :long
	end

###### ext/example.c
	long
	example(void)
	{
	  return 0xdeadbeef;
	}

###### ext/mkrf_conf.rb
	require 'ffi-compiler/mkrf'
	
	FFI::Compiler.new('example') do |c|
	  c.have_header?('stdio.h', '/usr/local/include')
	  c.have_func?('puts')
	  c.have_library?('z')
	end
    
###### Build gem and install it
	gem build example.gemspec && gem install example-0.0.1.gem
	Successfully built RubyGem
	  Name: example
	  Version: 0.0.1
	  File: example-0.0.1.gem
	Building native extensions.  This could take a while...
	Successfully installed example-0.0.1

###### Test it
	$ irb
	2.0.0dev :001 > require 'example/example'
	 => true 
	2.0.0dev :002 > puts "Example.example=#{Example.example.to_s(16)}"
	Example.example=deadbeef
	 => nil 

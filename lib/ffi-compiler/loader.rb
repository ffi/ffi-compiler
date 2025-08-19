require 'pathname'
require 'ffi'
require_relative 'platform'

module FFI
  module Compiler
    module Loader
      # Finds the native extension for the given library name.
      # Tries RubyGems extension_dir using the library name as the gem name (best effort),
      # then always falls back to the legacy recursive search for compatibility.
      def self.find(name, start_path = nil)
        library = Platform.system.map_library_name(name)

        # Try RubyGems extension_dir using name as gem name (best effort)
        if defined?(Gem::Specification)
          begin
            spec = Gem::Specification.find_by_name(name)
            if spec && spec.respond_to?(:extension_dir)
              ext_dir = spec.extension_dir
              ext_path = File.join(ext_dir, library)
              return ext_path if File.exist?(ext_path)
            end
          rescue Gem::MissingSpecError
            # Ignore and fall back to legacy search
          end
        end

        # Legacy search
        root = false
        Pathname.new(start_path || caller_path(caller[0])).ascend do |path|
          Dir.glob("#{path}/**/#{FFI::Platform::ARCH}-#{FFI::Platform::OS}/#{library}") do |f|
            return f
          end
          Dir.glob("#{path}/**/#{library}") do |f|
            return f
          end
          break if root
          root = File.basename(path) == 'lib'
        end
        raise LoadError, "cannot find '#{name}' library"
      end

      def self.caller_path(line = caller[0])
        if FFI::Platform::OS == 'windows'
          drive = line[0..1]
          path =  line[2..-1].split(/:/)[0]
          full_path = drive + path
        else
          full_path = line.split(/:/)[0]
        end
        File.dirname full_path
      end
    end
  end
end
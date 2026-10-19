require 'pathname'
require 'ffi'
require_relative 'platform'

module FFI
  module Compiler
    module Loader
      def self.find(name, start_path = nil)
        library = Platform.system.map_library_name(name)
        start_path ||= caller_path(caller[0])

        # Load from modern extension fast-path when called from an active gem spec
        if (spec = active_spec_containing(start_path)) && spec.respond_to?(:extension_dir)
          ext_path = File.join(spec.extension_dir, library)
          return ext_path if File.exist?(ext_path)
        end

        # Try to find the library in the legacy lib path, passed start_path or local folder
        root = false
        Pathname.new(start_path).ascend do |path|
          Dir.glob("#{path}/**/#{FFI::Platform::ARCH}-#{FFI::Platform::OS}/#{library}") do |f|
            return f
          end

          Dir.glob("#{path}/**/#{library}") do |f|
            return f
          end

          break if root

          # Next iteration will be the root of the gem if this is the lib/ dir - stop after that
          root = File.basename(path) == 'lib'
        end
        raise LoadError.new("cannot find '#{name}' library")
      end

      def self.active_spec_containing(path)
        return unless defined?(Gem) && Gem.respond_to?(:loaded_specs)

        path = path.to_s
        Gem.loaded_specs.each_value.find do |spec|
          gem_dir = spec.gem_dir
          path == gem_dir || path.start_with?(gem_dir + File::SEPARATOR)
        end
      end
      private_class_method :active_spec_containing

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

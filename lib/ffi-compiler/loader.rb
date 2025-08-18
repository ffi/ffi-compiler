require 'pathname'
require 'ffi'
require_relative 'platform'

module FFI
  module Compiler
    module Loader
      def self.find(name, start_path = nil)
        library = Platform.system.map_library_name(name)

        if defined?(Gem::Specification)
          begin
            spec = Gem::Specification.find_by_name(name)
            if spec && spec.respond_to?(:extension_dir)
              ext_dir = spec.extension_dir
              ext_path = File.join(ext_dir, library)
              return ext_path if File.exist?(ext_path)
            end
          rescue Gem::MissingSpecError => e
            # Provide a clearer, actionable error for users/gem authors if the gem is not installed
            # or named incorrectly, rather than letting a RubyGems error bubble up.
            raise LoadError, "Could not find gem specification for '#{name}'. Ensure the gem is installed and named correctly. (#{e.message})"
          end
        end

        # Only fallback in explicit dev/test mode
        if ENV['FFI_COMPILER_DEV_MODE'] == '1'
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
        end

        raise LoadError, "Could not find extension for '#{name}'. Ensure the gem is installed and named correctly."
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
require 'rake'
require 'rake/tasklib'
require 'rake/clean'

module FFI
  module Compiler
    class ExportTask < Rake::TaskLib

      def initialize(rb_dir, out_dir)
        @rb_dir = rb_dir
        @out_dir = out_dir
        @exports = []
        yield self if block_given?

        @exports.each do |e|
          file e[:header] => [ e[:rb_file] ] do |t|
            ruby "-I#{File.join(File.dirname(__FILE__), 'fake_ffi')} #{File.join(File.dirname(__FILE__), 'exporter.rb')} #{t.prerequisites[0]} #{t.name}"
          end
          CLEAN.include(e[:header])

          desc "Export API headers"
          task :api_headers => [ e[:header] ]
        end

        task :package => [ :api_headers ]
      end


      def export(rb_file)
        @exports << { :rb_file => File.join(@rb_dir, rb_file), :header => File.join(@out_dir, File.basename(rb_file).sub(/\.rb$/, '.h')) }
      end
    end
  end
end

require 'rake/tasklib'
require 'rake/clean'
require 'ffi'
require 'tmpdir'
require 'rbconfig'

module FFI
  class Compiler
    DEFAULT_CFLAGS = %w(-fexceptions -O -fno-omit-frame-pointer -fno-strict-aliasing)
    DEFAULT_LDFLAGS = %w(-fexceptions)
    
    class Task < Rake::TaskLib
      attr_reader :cflags, :cxxflags, :ldflags, :libs
      
      def initialize(name)
        @name = File.basename(name)
        @defines = []
        @include_paths = []
        @library_paths = []
        @libraries = []
        @headers = []
        @functions = []
        @cflags = DEFAULT_CFLAGS.dup
        @cxxflags = DEFAULT_CFLAGS.dup
        @ldflags = DEFAULT_LDFLAGS.dup
        @libs = []

        yield self if block_given?
        define_task!
      end

      def have_func?(func)
        main = <<-C_FILE
        extern void #{func}();
        int main(int argc, char **argv) { #{func}(); return 0; }
        C_FILE

        if try_compile(main)
          @functions << func
          return true
        end
        false
      end

      def have_header?(header, *paths)
        try_header(header, @include_paths) || try_header(header, paths)
      end

      def have_library?(libname, *paths)
        try_library(libname, @library_paths) || try_library(libname, paths)
      end

      private
      def define_task!
        pic_flags = %w(-fPIC)
        so_flags = []
        
        if FFI::Platform.mac?
          pic_flags = []
          so_flags << '-dynamiclib'

        elsif FFI::Platform.name =~ /linux/
          so_flags << "-shared -Wl,-soname,#{lib_name}"
        
        else
          so_flags << '-shared'
        end
        so_flags = so_flags.join(' ')

        lib_name = FFI.map_library_name(@name)

        iflags = @include_paths.uniq.map { |p| "-I#{p}" }
        defines = @functions.uniq.map { |f| "-DHAVE_#{f.upcase}=1" }
        defines << @headers.uniq.map { |h| "-DHAVE_#{h.upcase.sub(/\./, '_')}=1" }

        cflags = (@cflags + pic_flags + iflags + defines).join(' ')
        cxxflags = (@cxxflags + @cflags + pic_flags + iflags + defines).join(' ')
        ld_flags = (@library_paths.map { |path| "-L#{path}" } + @ldflags).join(' ')
        libs = (@libraries.map { |l| "-l#{l}" } + @libs).join(' ')

        src_files = FileList['*.{c,cpp}']
        obj_files = src_files.ext '.o'
        ld = src_files.detect { |f| f =~ /\.cpp$/ } ? cxx : cc

        CLEAN.include(obj_files)

        rule '.o' => '.c' do |t|
          sh "#{cc} #{cflags} -o #{t.name} -c #{t.source}"
        end

        rule '.o' => '.cpp' do |t|
          sh "#{cxx} #{cxxflags} -o #{t.name} -c #{t.source}"
        end

        desc "Build dynamic library"
        file lib_name => obj_files do |t|
          sh "#{ld} #{so_flags} -o #{t.name} #{t.prerequisites.join(' ')} #{ld_flags} #{libs}"
        end
        CLEAN.include(lib_name)

        task :default => [ lib_name ]
      end

      def try_header(header, paths)
        main = <<-C_FILE
          #include <#{header}>
          int main(int argc, char **argv) { return 0; }
        C_FILE

        if paths.empty? && try_compile(main)
          @headers << header
          return true
        end

        paths.each do |path|
          if try_compile(main, "-I#{path}")
            @include_paths << path
            @headers << header
            return true
          end
        end
        false
      end


      def try_library(libname, paths)
        main = <<-C_FILE
        int main(int argc, char **argv) { return 0; }
        C_FILE

        if paths.empty? && try_compile(main)
          @libraries << libname
          return true
        end

        paths.each do |path|
          if try_compile(main, "-L#{path}", "-l#{libname}")
            @library_paths << path
            @libraries << libname
          end
        end
      end

      def try_compile(src, *opts)
        Dir.mktmpdir do |dir|
          path = File.join(dir, 'ffi-test.c')
          File.open(path, 'w') do |f|
            f << src
          end
          begin
            return system "#{cc} #{opts.join(' ')} -o #{File.join(dir, 'ffi-test')} #{path} >& /dev/null"
          rescue
            return false
          end
        end
      end

      def cc
        @cc ||= (ENV['CC'] || RbConfig::CONFIG['CC'] || 'cc')
      end

      def cxx
        @cxx ||= (ENV['CXX'] || RbConfig::CONFIG['CXX'] || 'c++')
      end
    end
  end
end

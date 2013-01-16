require 'rake/tasklib'
require 'rake/clean'
require 'ffi'
require 'tmpdir'

module FFI
  class Compiler
    class Task < Rake::TaskLib
      def initialize(name)
        @name = name
        @defines = []
        @include_paths = []
        @library_paths = []
        @libraries = []
        @headers = []
        @functions = []

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

      def create_rakefile!
        create_rakefile(@name)
      end

      private
      def define_task!
        lib_name = FFI.map_library_name(@name)
        pic_flags = '-fPIC'
        so_flags = ''
        ld_flags = ''
        cc = 'cc'
        cxx = 'c++'
        iflags = @include_paths.uniq.map { |p| "-I#{p}" }.join(' ')
        defines = @functions.uniq.map { |f| "-DHAVE_#{f.upcase}=1" }.join(' ')
        defines << " " + @headers.uniq.map { |h| "-DHAVE_#{h.upcase.sub(/\./, '_')}=1" }.join(' ')

        if FFI::Platform.mac?
          pic_flags = ''
          ld_flags += ' -dynamiclib '

        elsif FFI::Platform.name =~ /linux/
          so_flags += " -shared -Wl,-soname,#{lib_name} "
        end

        cflags = "#{pic_flags} #{iflags} #{defines}".strip
        ld_flags += so_flags
        ld_flags += @library_paths.map { |path| "-L#{path}" }.join(' ')
        ld_flags.strip!
        ld = FileList['*.cpp'].empty? ? cc : cxx
        cxxflags = cflags
        libs = @libraries.map { |l| "-l#{l}" }.join(" ")

        obj_files = FileList['*.c', '*.cpp'].map { |f| f.gsub(/\.(c|cpp)$/, '.o') }

        CLEAN.include(obj_files)

        desc "Compile C file to object file"
        rule '.o' => ['.c'] do |t|
          sh "#{cc} #{cflags} -o #{t.name} -c #{t.source}"
        end

        desc "Compile C++ file to object file"
        rule '.o' => ['.cpp'] do |t|
          sh "#{cxx} #{cxxflags} -o #{t.name} -c #{t.source}"
        end

        desc "Compile to dynamic library"
        file lib_name => obj_files do |t|
          sh "#{ld} #{ld_flags} -o #{t.name} #{t.prerequisites.join(' ')} #{libs}"
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
          File.open(path, "w") do |f|
            f << src
          end
          begin
            return system "cc #{opts.join(' ')} -o #{File.join(dir, 'ffi-test')} #{path} >& /dev/null"
          rescue
            return false
          end
        end
      end
    end
  end
end
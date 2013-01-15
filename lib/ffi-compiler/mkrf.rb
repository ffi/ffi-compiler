require 'ffi'
require 'tmpdir'

module FFI
  class Compiler 
    def initialize(name, &block)
      @name = name
      @defines = []
      @include_paths = []
      @library_paths = []
      @libraries = []
      @headers = []
      @functions = []

      if block_given?
        yield self 
        create_rakefile!
      end
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

    def create_rakefile(name)
      lib_name = FFI.map_library_name(name)
      pic_flags = '-fPIC'
      so_flags = ''
      ld_flags = ''
      cc = 'cc'
      cxx = 'c++'
      iflags = @include_paths.uniq.map{ |p| "-I#{p}" }.join(' ')
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
      
      File.open('Rakefile', 'w') do |f|
        f.puts <<-RAKEFILE

require 'rake/clean'

CC = '#{cc}'
CXX = '#{cxx}'
LD = FileList['*.cpp'].empty? ? CC : CXX
CFLAGS = '#{cflags}'
CXXFLAGS = '#{cflags}'
LDFLAGS = '#{ld_flags}'
LIBS = '#{@libraries.map {|l| "-l#{l}" }.join(" ")}' 

OBJ_FILES = FileList['*.c', '*.cpp'].map { |f| f.gsub(/\.(c|cpp)$/, '.o') }

CLEAN.include(OBJ_FILES)

desc "Compile C file to object file"
rule '.o' => [ '.c' ] do |t|
  sh "\#{CC} \#{CFLAGS} -o \#{t.name} -c \#{t.source}"
end

desc "Compile C++ file to object file"
rule '.o' => [ '.cpp' ] do |t|
  sh "\#{CXX} \#{CXXFLAGS} -o \#{t.name} -c \#{t.source} "
end

desc "Compile to dynamic library"
task :compile => "#{lib_name}"

file "#{lib_name}" => OBJ_FILES do |t|
  sh "\#{LD} \#{LDFLAGS} -o \#{t.name} \#{t.prerequisites.join(' ')} \#{LIBS}"
end

task :default => :compile

    RAKEFILE
      end
    end

  end
end


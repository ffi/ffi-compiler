require 'fileutils'
require 'tmpdir'
require 'ffi-compiler/compile_task'

RSpec.describe FFI::Compiler::CompileTask do
  let(:vendor_dir) { File.join(Dir.pwd, 'vendor') }

  around do |example|
    Dir.mktmpdir('ffi-compiler-compile-task') do |dir|
      Dir.chdir(dir) do
        Rake.with_application do
          verbose, Rake::FileUtilsExt.verbose_flag = Rake::FileUtilsExt.verbose_flag, false
          clean, clobber = CLEAN.dup, CLOBBER.dup
          example.run
        ensure
          Rake::FileUtilsExt.verbose_flag = verbose
          CLEAN.replace(clean)
          CLOBBER.replace(clobber)
        end
      end
    end
  end

  it 'defines a valid HAVE_ macro for a header in a subdirectory' do
    FileUtils.mkdir_p('include/foo')
    File.write('include/foo/bar-baz.h', "#define BAR_BAZ 1\n")
    FileUtils.mkdir_p('ext')
    File.write('ext/foo.c', <<~C)
      #ifndef HAVE_FOO_BAR_BAZ_H
      #error "HAVE_FOO_BAR_BAZ_H is not defined"
      #endif
      int foo(void) { return 1; }
    C

    found = nil
    described_class.new('ext/foo') { |t| found = t.have_header?('foo/bar-baz.h', File.join(Dir.pwd, 'include')) }

    expect(found).to be(true)
    expect { Rake::Task[:default].invoke }.not_to raise_error
  end

  describe '#have_func?' do
    it 'finds a function the linker resolves and defines its HAVE_ macro' do
      write_extension(<<~C)
        #ifndef HAVE_PUTS
        #error "HAVE_PUTS is not defined"
        #endif
        int foo(void) { return 1; }
      C

      expect(configure { |t| t.have_func?('puts') }).to be(true)
      expect { Rake::Task[:default].invoke }.not_to raise_error
    end

    it 'finds a function when the task compiles with -Werror=strict-prototypes' do
      expect(configure { |t| t.cflags << '-Werror=strict-prototypes'; t.have_func?('puts') }).to be(true)
    end

    it 'finds a function from a library and a split search path given in the ldflags' do
      build_static_library('bar', 'int bar(void) { return 42; }')

      expect(configure { |t| t.ldflags << "-L #{vendor_dir} -lbar"; t.have_func?('bar') }).to be(true)
    end

    it 'finds a builtin function when the task compiles with -Werror' do
      expect(configure { |t| t.cflags << '-Werror'; t.have_func?('strlen') }).to be(true)
    end

    it 'finds a function when the task compiles with -pedantic-errors' do
      expect(configure { |t| t.cflags << '-pedantic-errors'; t.have_func?('puts') }).to be(true)
    end

    it 'does not find a function no library provides' do
      expect(configure { |t| t.have_func?('ffi_compiler_missing_function') }).to be(false)
    end

    it 'does not find a missing function when the ldflags allow undefined symbols' do
      undefined = RUBY_PLATFORM =~ /darwin/ ? '-Wl,-undefined,dynamic_lookup' : '-Wl,--unresolved-symbols=ignore-all'

      expect(configure { |t| t.ldflags << undefined; t.have_func?('ffi_compiler_missing_function') }).to be(false)
    end

    it 'does not find a missing function when split -Wl, ldflags allow undefined symbols' do
      undefined = RUBY_PLATFORM =~ /darwin/ ? '-Wl,-undefined -Wl,dynamic_lookup' : '-Wl,--unresolved-symbols -Wl,ignore-all'

      expect(configure { |t| t.ldflags << undefined; t.have_func?('ffi_compiler_missing_function') }).to be(false)
    end

    it 'does not find a missing function when -Xlinker ldflags allow undefined symbols' do
      undefined = RUBY_PLATFORM =~ /darwin/ ? '-Xlinker -undefined -Xlinker dynamic_lookup' : '-Xlinker --unresolved-symbols=ignore-all'

      expect(configure { |t| t.ldflags << undefined; t.have_func?('ffi_compiler_missing_function') }).to be(false)
    end

    it 'finds a function when the ldflags restrict the exported symbols' do
      skip 'Apple ld option' unless RUBY_PLATFORM =~ /darwin/
      File.write('exported.txt', "_foo\n")
      exported = "-Wl,-exported_symbols_list,#{File.join(Dir.pwd, 'exported.txt')}"

      expect(configure { |t| t.ldflags << exported; t.have_func?('puts') }).to be(true)
    end

    it 'keeps -Werror=<warning> in its probes' do
      probe_flags = []
      configure do |t|
        allow(t).to receive(:try_link) { |_source, *flags| probe_flags.concat(flags) }
        t.cflags << '-Werror'
        t.cflags << '-Werror=implicit-function-declaration'
        t.have_func?('puts')
      end

      expect(probe_flags).to include('-Werror=implicit-function-declaration')
      expect(probe_flags).not_to include('-Werror')
    end
  end

  describe '#have_library?' do
    it 'finds a library the linker resolves' do
      expect(configure { |t| t.have_library?('m') }).to be(true)
    end

    it 'does not find a missing library' do
      expect(configure { |t| t.have_library?('ffi_compiler_missing_library', Dir.pwd) }).to be(false)
    end
  end

  describe '#have_library' do
    it 'finds a function declared by several headers' do
      expect(configure { |t| t.have_library('m', 'cos', ['stdio.h', 'math.h']) }).to be(true)
    end

    it 'includes every header, not only the first' do
      expect(configure { |t| t.have_library('m', 'cos', ['math.h', 'ffi_compiler_missing.h']) }).to be(false)
    end

    it 'does not find a library whose header is missing' do
      expect(configure { |t| t.have_library('m', nil, 'ffi_compiler_missing.h') }).to be(false)
    end

    it 'compiles its probe with the task cflags' do
      FileUtils.mkdir_p('include')
      File.write('include/probe.h', "#ifndef PROBE_ENABLED\n#error \"PROBE_ENABLED is not defined\"\n#endif\n")

      found = configure do |t|
        t.add_include_path(File.join(Dir.pwd, 'include'))
        t.cflags << '-DPROBE_ENABLED'
        t.have_library('m', 'cos', ['math.h', 'probe.h'])
      end

      expect(found).to be(true)
    end

    it 'compiles its probe with the task defines' do
      FileUtils.mkdir_p('include')
      File.write('include/probe.h', "#ifndef PROBE_ENABLED\n#error \"PROBE_ENABLED is not defined\"\n#endif\n")

      found = configure do |t|
        t.add_include_path(File.join(Dir.pwd, 'include'))
        t.add_define('PROBE_ENABLED')
        t.have_library('m', 'cos', ['math.h', 'probe.h'])
      end

      expect(found).to be(true)
    end

    it 'declares the function itself when given no headers' do
      expect(configure { |t| t.have_library('m', 'cos', []) }).to be(true)
    end

    it 'declares the function itself when its headers do not' do
      expect(configure { |t| t.have_library('m', 'cos', ['stdio.h']) }).to be(true)
    end

    it 'does not find a function missing from the library' do
      expect(configure { |t| t.have_library('m', 'ffi_compiler_missing_function') }).to be(false)
    end
  end

  describe '#find_library' do
    it 'finds a library in an extra path and links the extension against it' do
      build_static_library('bar', 'int bar(void) { return 42; }')
      write_extension("extern int bar(void);\nint foo(void) { return bar(); }\n")

      expect(configure { |t| t.find_library('bar', 'bar', vendor_dir) }).to be(true)
      expect { Rake::Task[:default].invoke }.not_to raise_error
    end

    it 'finds a static library that depends on one found earlier' do
      build_static_library('base', 'int base(void) { return 42; }')
      build_static_library('top', 'extern int base(void); int top(void) { return base(); }')
      write_extension("extern int top(void);\nint foo(void) { return top(); }\n")

      found = configure { |t| [t.find_library('base', 'base', vendor_dir), t.find_library('top', 'top', vendor_dir)] }

      expect(found).to eq([true, true])
      expect { Rake::Task[:default].invoke }.not_to raise_error
    end

    it 'does not find a library missing from the extra paths' do
      expect(configure { |t| t.find_library('ffi_compiler_missing_library', 'bar', Dir.pwd) }).to be(false)
    end
  end

  def configure
    result = nil
    described_class.new('ext/foo') { |t| result = yield t }
    result
  end

  def write_extension(source)
    FileUtils.mkdir_p('ext')
    File.write('ext/foo.c', source)
  end

  def build_static_library(name, source)
    cc = ENV['CC'] || RbConfig::CONFIG['CC'] || 'cc'
    FileUtils.mkdir_p(vendor_dir)
    File.write("#{vendor_dir}/#{name}.c", "#{source}\n")
    system("#{cc} -fPIC -c #{vendor_dir}/#{name}.c -o #{vendor_dir}/#{name}.o", exception: true)
    system("ar rcs #{vendor_dir}/lib#{name}.a #{vendor_dir}/#{name}.o", exception: true)
  end
end

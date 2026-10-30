require 'fileutils'
require 'tmpdir'
require 'ffi-compiler/compile_task'

RSpec.describe FFI::Compiler::CompileTask do
  around do |example|
    Dir.mktmpdir('ffi-compiler-compile-task') do |dir|
      Dir.chdir(dir) do
        rake, Rake.application = Rake.application, Rake::Application.new
        verbose, Rake::FileUtilsExt.verbose_flag = Rake::FileUtilsExt.verbose_flag, false
        clean, clobber = CLEAN.dup, CLOBBER.dup
        example.run
      ensure
        Rake.application = rake
        Rake::FileUtilsExt.verbose_flag = verbose
        CLEAN.replace(clean)
        CLOBBER.replace(clobber)
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
end

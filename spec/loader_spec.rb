require 'fileutils'
require 'tmpdir'
require 'ffi-compiler/loader'

RSpec.describe FFI::Compiler::Loader do
  let(:library) { FFI::Compiler::Platform.system.map_library_name('foo') }
  let(:arch_dir) { "#{FFI::Platform::ARCH}-#{FFI::Platform::OS}" }

  around do |example|
    Dir.mktmpdir('ffi-compiler-loader') do |dir|
      @root = File.realpath(dir)
      example.run
    end
  end

  def touch(*parts)
    path = File.join(@root, *parts)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)
    path
  end

  describe '.find' do
    context 'when searching the legacy lib path' do
      it 'finds a library below start_path' do
        expected = touch('mygem', 'lib', 'mygem', library)

        expect(described_class.find('foo', File.join(@root, 'mygem', 'lib'))).to eq(expected)
      end

      it 'prefers a library in the platform directory over a generic one' do
        touch('mygem', 'ext', library)
        expected = touch('mygem', 'ext', arch_dir, library)

        expect(described_class.find('foo', File.join(@root, 'mygem', 'lib'))).to eq(expected)
      end

      it 'ascends from start_path to the gem root' do
        expected = touch('mygem', 'ext', library)

        expect(described_class.find('foo', File.join(@root, 'mygem', 'lib', 'mygem'))).to eq(expected)
      end

      it 'does not search above the gem root' do
        touch(library)
        FileUtils.mkdir_p(File.join(@root, 'mygem', 'lib'))

        expect { described_class.find('foo', File.join(@root, 'mygem', 'lib')) }
          .to raise_error(LoadError, "cannot find 'foo' library")
      end

      it 'raises LoadError when the library does not exist' do
        FileUtils.mkdir_p(File.join(@root, 'mygem', 'lib'))

        expect { described_class.find('foo', File.join(@root, 'mygem', 'lib')) }
          .to raise_error(LoadError, "cannot find 'foo' library")
      end

      it "defaults start_path to the caller's directory" do
        expected = touch('mygem', 'ext', library)
        caller_file = touch('mygem', 'lib', 'mygem.rb')

        # Evaluate the call as if it were made from lib/mygem.rb
        expect(eval("FFI::Compiler::Loader.find('foo')", binding, caller_file)).to eq(expected)
      end
    end
  end
end

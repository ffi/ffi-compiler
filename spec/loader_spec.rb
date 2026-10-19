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

      it 'accepts start_path as a Pathname' do
        expected = touch('mygem', 'ext', library)

        expect(described_class.find('foo', Pathname.new(File.join(@root, 'mygem', 'lib')))).to eq(expected)
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

    context 'when called from an activated gem' do
      let(:gem_home) { GemHome.new(@root) }

      # Runs Loader.find in a child process with +activate+ gems activated.
      # Returns the path found, or :load_error.
      def find_in_gem_home(start_path, activate:)
        result = gem_home.run(<<~RUBY, activate: activate)
          require 'ffi-compiler/loader'
          begin
            print FFI::Compiler::Loader.find('foo', #{start_path.inspect})
          rescue LoadError
            print 'LoadError'
          end
        RUBY
        result == 'LoadError' ? :load_error : result
      end

      it "finds the library in the gem's extension_dir" do
        gem_dir = gem_home.install('mygem', ext_files: [library])

        expect(find_in_gem_home(File.join(gem_dir, 'lib'), activate: ['mygem']))
          .to eq(File.join(gem_home.extension_dir('mygem-1.0'), library))
      end

      it "prefers the gem's extension_dir over a copy in the gem directory" do
        gem_dir = gem_home.install('mygem', ext_files: [library], gem_files: ["ext/#{arch_dir}/#{library}"])

        expect(find_in_gem_home(File.join(gem_dir, 'lib'), activate: ['mygem']))
          .to eq(File.join(gem_home.extension_dir('mygem-1.0'), library))
      end

      it "falls back to the gem directory when the extension_dir lacks the library" do
        gem_dir = gem_home.install('mygem', ext_files: ['other.so'], gem_files: ["ext/#{arch_dir}/#{library}"])

        expect(find_in_gem_home(File.join(gem_dir, 'lib'), activate: ['mygem']))
          .to eq(File.join(gem_dir, 'ext', arch_dir, library))
      end

      it "does not return a library from another gem's extension_dir" do
        gem_home.install('other', ext_files: [library])
        gem_dir = gem_home.install('mygem', gem_files: ["ext/#{library}"])

        expect(find_in_gem_home(File.join(gem_dir, 'lib'), activate: %w[other mygem]))
          .to eq(File.join(gem_dir, 'ext', library))
      end

      it "raises LoadError when only another gem's extension_dir has the library" do
        gem_home.install('other', ext_files: [library])
        gem_dir = gem_home.install('mygem')

        expect(find_in_gem_home(File.join(gem_dir, 'lib'), activate: %w[other mygem])).to eq(:load_error)
      end
    end
  end
end

require 'fileutils'
require 'open3'
require 'rbconfig'

# Builds a throwaway GEM_HOME with installed gems and runs Ruby code against it
# in a child process, so specs can activate real gems without touching the
# bundle the spec run itself is using.
class GemHome
  attr_reader :root

  def initialize(root)
    @root = root
  end

  # Installs a gem named +name+. Each of +ext_files+ is placed in the gem's
  # extension_dir, as RubyGems does for a compiled extension, and each of
  # +gem_files+ is placed in the gem directory. Returns the gem directory.
  def install(name, version: '1.0', ext_files: [], gem_files: [])
    full_name = "#{name}-#{version}"
    gem_dir = File.join(root, 'gems', full_name)

    write(File.join(gem_dir, 'lib', "#{name}.rb"))
    gem_files.each { |f| write(File.join(gem_dir, f)) }

    unless ext_files.empty?
      write(File.join(gem_dir, 'ext', 'extconf.rb'))
      ext_dir = extension_dir(full_name)
      ext_files.each { |f| write(File.join(ext_dir, f)) }
      write(File.join(ext_dir, 'gem.build_complete'))
    end

    write(File.join(root, 'specifications', "#{full_name}.gemspec"), <<~RUBY)
      Gem::Specification.new do |s|
        s.name = #{name.inspect}
        s.version = #{version.inspect}
        s.summary = 'fake'
        s.authors = ['fake']
        s.files = ['lib/#{name}.rb']
        s.extensions = #{ext_files.empty? ? [] : ['ext/extconf.rb']}
      end
    RUBY

    gem_dir
  end

  def extension_dir(full_name)
    File.join(root, 'extensions', Gem::Platform.local.to_s, Gem.extension_api_version, full_name)
  end

  # Activates +gems+ and then runs +code+ in a child process using this
  # GEM_HOME. Returns the child's stdout; raises if it fails.
  def run(code, activate: [])
    script = activate.map { |g| "gem #{g.inspect}\n" }.join + code
    stdout, stderr, status = Open3.capture3(child_env, RbConfig.ruby, *load_path_args, '-e', script)
    raise "child process failed:\n#{stderr}" unless status.success?

    stdout
  end

  private

  def write(path, content = '')
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def child_env
    env = { 'GEM_HOME' => root, 'GEM_PATH' => root, 'RUBYOPT' => nil, 'RUBYLIB' => nil }
    ENV.each_key { |k| env[k] = nil if k.start_with?('BUNDLE_', 'BUNDLER_') }
    env
  end

  # ffi-compiler and ffi are not installed in this GEM_HOME; put them on the
  # load path directly.
  def load_path_args
    paths = [File.expand_path('../../lib', __dir__)] + Gem.loaded_specs.fetch('ffi').full_require_paths
    paths.flat_map { |p| ['-I', p] }
  end
end

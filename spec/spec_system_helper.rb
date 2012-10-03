require 'fileutils'
require 'tmpdir'

class GemDirLayout
  def initialize(install_dir)
    @d = File.join install_dir, "gems"
    FileUtils.mkdir_p @d
  end

  def install_dir; @d                   end
  def bin;         File.join(@d, 'bin') end
  def lib;         File.join(@d, 'lib') end
end

class SystemContext
  class GemBuildFailed < Exception; end
  class GemFileMissing < Exception; end
  class InstallFailed  < Exception; end

  attr_reader :dir

  def initialize
    @dir = Dir.mktmpdir
    @gem = GemDirLayout.new(@dir)
  end

  def done!
    FileUtils.rm_rf(@dir)
  end

  def deploy_gem
    build_output = `gem build ceedling.gemspec`
    raise GemBuildFailed.new if build_output.match(/Successfully/).nil?

    gem_file = build_output.match(/File: (?<file>ceedling-.+\.gem)/)[:file]
    raise GemFileMissing.new if gem_file.nil?
    gem_name = gem_file.match(/(.+)\.gem/)[1]

    cmd = "gem install --no-rdoc --no-ri -i #{@gem.install_dir} #{gem_file}"
    install_output = `#{cmd}`
    raise InstallFailed.new if install_output.match(/Successfully installed #{gem_name}/).nil?
  end
end

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
  class VerificationFailed < Exception; end

  attr_reader :dir, :gem

  def initialize
    @dir = Dir.mktmpdir
    @gem = GemDirLayout.new(@dir)
  end

  def done!
    FileUtils.rm_rf(@dir)
  end

  def deploy_gem
    git_repo = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    bundler_gem_file_data = [ %Q{source "http://rubygems.org/"} ,
                              %Q{gem "ceedling", :path => "#{git_repo}"}
                            ].join("\n")

    File.open(File.join(@dir, "Gemfile"), "w+") do |f|
      f.write(bundler_gem_file_data)
    end

    Dir.chdir @dir do
      with_constrained_env do
        puts `cat Gemfile`
        puts @gem.install_dir
        puts `bundle install --path #{@gem.install_dir}`

        checks = ["bundle exec ruby -S ceedling"]
        raise VerificationFailed unless checks.map {|c| system(c)}.all?
      end
    end
  end

  # Does a few things:
  #   - Configures the environment.
  #   - Runs the command from the temporary context directory.
  #   - Restores everything to where it was when finished.
  def context_exec(cmd, *args)
    with_context do
      `#{args.unshift(cmd).join(" ")}`
    end
  end

  def with_context
    Dir.chdir @dir do |current_dir|
      with_constrained_env do
        ENV['RUBYLIB'] = @gem.lib
        ENV['RUBYPATH'] = @gem.bin

        yield
      end
    end
  end

  def backup_env
    # Force a deep clone. Hacktacular, but works.
    @_env = YAML.load(ENV.to_hash.to_yaml)
  end

  def destroy_env(keep_keys=[])
    ENV.keys.each {|k| ENV.delete(k) unless keep_keys.include?(k)}
  end

  def constrain_env
    keep_keys = %w{PATH rvm_bin_path GEM_HOME TMPDIR}
    destroy_env(keep_keys)
  end

  def restore_env
    @_env.each_pair {|k,v| ENV[k] = v}
  end

  def with_constrained_env
    begin
      backup_env
      constrain_env
      yield
    ensure
      restore_env
    end
  end
end

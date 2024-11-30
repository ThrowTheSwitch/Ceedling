# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================
  
require 'ceedling/plugin'
require 'ceedling/exceptions'

class Ccache < Plugin
  # Set the environment variable directly from the configuration file
  def set_raw(env_name, value)
    return unless @ccache_config.key?(value)
    ENV['CCACHE_' + env_name.upcase] = @ccache_config[value]
  end

  # Set the environment variable from the configuration file, using the boolean semantics
  # defined by ccache:  https://ccache.dev/manual/4.10.2.html#_boolean_values
  def set_boolean(env_name, value)
    return unless @ccache_config.key?(value)
    if @ccache_config[value]
      ENV['CCACHE_' + env_name.upcase] = ''
      ENV.delete('CCACHE_NO' + env_name.upcase)
    else
      ENV['CCACHE_NO' + env_name.upcase] = ''
      ENV.delete('CCACHE_' + env_name.upcase)
    end
  end

  # Set the environment variable from the configuration file, but ensure that the path is absolute
  def set_absolute_path(env_name, value)
    return unless @ccache_config.key?(value)
    ENV['CCACHE_' + env_name.upcase] = if File.absolute_path?(@ccache_config[value])
                                     @ccache_config[value]
                                   else
                                     File.absolute_path(@ccache_config[value])
                                   end
  end

  # Set the environment variable from the configuration file.
  # If the path is relative, it is made relative to the build root directory.
  def set_path_realtive_to_build(env_name, value)
    return unless @ccache_config.key?(value)
    ENV['CCACHE_' + env_name.upcase] = if File.absolute_path?(@ccache_config[value])
                                     @ccache_config[value]
                                   else
                                     File.join(@ceedling[:configurator].project_config_hash[:project_build_root], @ccache_config[:cache_dir])
                                   end
  end

  # `Plugin` setup()
  def setup
    @ccache_config = @ceedling[:setupinator].config_hash[:ccache]

    # The following options are translated from the yaml configuration to the environment variables
    # The options are taken from the ccache manual: https://ccache.dev/manual/4.10.2.html#_configuration_options
    set_path_realtive_to_build('DIR', :cache_dir)
    set_absolute_path('BASEDIR', :base_dir)
    set_raw('COMPILERCHECK', :compiler_check)
    set_boolean('COMPRESS', :compression)
    set_raw('COMPRESSIONLEVEL', :compression_level)
    set_raw('EXTENSION', :cpp_extension)
    set_boolean('DEBUG', :debug)
    set_path_realtive_to_build('DEBUGDIR', :debug_dir)
    set_boolean('DEPEND', :depend_mode)
    set_boolean('DIRECT', :direct_mode)
    set_boolean('DISABLE', :disable)
    set_raw('EXTRAFILES', :extra_files_to_hash)
    set_boolean('FILECLONE', :file_clone)
    set_boolean('HARDLINK', :hard_link)
    set_boolean('HASHDIR', :hash_dir)
    set_raw('IGNOREHEADERS', :ignore_headers_in_manifest)
    set_raw('IGNOREOPTIONS', :ignore_options)
    set_boolean('INODECACHE', :inode_cache)
    set_boolean('COMMENTS', :keep_comments_cpp)
    set_raw('LIMIT_MULTIPLE', :limit_multiple)
    set_raw('LOGFILE', :log_file)
    set_raw('MAXFILES', :max_files)
    set_raw('MAXSIZE', :max_size)
    set_raw('PATH', :path)
    set_boolean('PCH_EXTSUM', :pch_external_checksum)
    set_raw('PREFIX', :prefix_command)
    set_raw('PREFIX_CPP', :prefix_command_cpp)
    set_boolean('READONLY', :read_only)
    set_boolean('READONLY_DIRECT', :read_only_direct)
    set_boolean('RECACHE', :recache)
    set_boolean('CPP2', :run_second_cpp)
    set_raw('SLOPPINESS', :sloppiness)
    set_boolean('STATS', :stats)
    set_raw('TEMPDIR', :temporary_dir)
    set_raw('UMASK', :umask)

    # Prepends ccache to the compiler executable
    # This will ensure that ccache is used for all compilations, 
    # while still allowing the user to override the compiler.
    @ceedling[:configurator].project_config_hash[:tools_test_compiler][:executable].prepend('ccache ')
  end
end

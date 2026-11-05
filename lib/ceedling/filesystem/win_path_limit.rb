# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'
require 'ceedling/constants'
require 'ceedling/filesystem/win_long_paths'

# What :project ↳ :win_path_limit means once the long path probe has answered: which
# Windows limit applies, and the one message that says why. Also how each limit reads
# in a path length message.
module WinPathLimit

  # What a probe result means for a `:win_path_limit` mode: whether long paths are in
  # effect, and the one message to log about it, as arguments to `Loginator#log`.
  #  - `:long_paths` keeps the long limit when files work, warning if listings don't.
  #  - `:auto` takes the long limit only with full support, noting why when it doesn't.
  #  - Without file support, either mode keeps the classic limit and names the cause.
  def self.decision(result, mode)
    case result[:support]
    when :full
      return { long_paths: true, log: ["Windows long paths: full support (Ruby #{RUBY_VERSION})", Verbosity::DEBUG] }
    when :files_only
      return files_only_decision( mode )
    else
      return no_support_decision( result, mode )
    end
  end

  # How a Windows path limit reads in a message
  def self.limit_name(limit)
    return "Windows' #{WinLongPaths::LIMITS[:classic_directory]}-character limit for directories" if limit == WinLongPaths::LIMITS[:classic_directory]
    return "Windows' #{limit.to_s.reverse.scan( /\d{1,3}/ ).join( ',' ).reverse}-character long path limit" if limit == WinLongPaths::LIMITS[:long_paths]

    return "Windows' #{limit}-character limit"
  end

  def self.files_only_decision(mode)
    listing = "Ruby #{RUBY_VERSION} cannot list directories past #{WinLongPaths::LIMITS[:classic]} characters"

    if mode == :long_paths
      message = ":project ↳ :win_path_limit is :long_paths, but #{listing}. Builds can write long paths, but Ceedling's " \
                'directory scans, `clean`, and `clobber` can fail or leave files behind in them. Ruby 4.0 or later lists them.'
      return { long_paths: true, log: [message, Verbosity::COMPLAIN] }
    end

    message = "Windows long paths are enabled, but #{listing}. Ceedling keeps reporting paths against the " \
              "#{WinLongPaths::LIMITS[:classic]}-character limit. Ruby 4.0 or later lists them."
    return { long_paths: false, log: [message, Verbosity::NORMAL, LogLabels::NOTICE] }
  end

  def self.no_support_decision(result, mode)
    cause, remedy = cause_text( result )
    limit         = "the #{WinLongPaths::LIMITS[:classic]}-character limit"

    if mode == :long_paths
      message = ":project ↳ :win_path_limit is :long_paths, but #{cause}. Ceedling reports paths against #{limit}.#{remedy}"
      return { long_paths: false, log: [message, Verbosity::COMPLAIN] }
    end

    message = "Windows long paths are unavailable: #{cause}. Ceedling keeps reporting paths against #{limit}.#{remedy}"
    return { long_paths: false, log: [message, Verbosity::NORMAL, LogLabels::NOTICE] }
  end

  def self.cause_text(result)
    case result[:cause]
    when :registry_disabled
      return ["long paths are not enabled on this host (#{WinLongPaths::REGISTRY_KEY} ↳ #{WinLongPaths::REGISTRY_VALUE} is not 1)",
              ' Enable "Win32 long paths" and run Ceedling again.']
    when :process_not_aware
      return ["long paths are enabled on this host, but this Ruby (#{RbConfig.ruby}) could not use them in the build " \
              "directory. Either it is not long-path-aware, or that directory's drive does not support long paths", '']
    else
      return ["the Windows registry could not be read to check for long path support (#{result[:error]})", '']
    end
  end

  private_class_method :files_only_decision, :no_support_decision, :cause_text

end

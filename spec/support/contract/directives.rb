# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'contract/contract'

module Contract

  # One `#include` in a row's file, as the row wrote it.
  #
  # `key` names the directive in reports: the includer, then the spelling in its quotes
  # or angle brackets, or the Partials macro and its arguments as written.
  Directive = Struct.new( :includer, :spelling, :angle, :macro, :args, keyword_init: true ) do
    def partial?
      return !macro.nil?
    end

    # Unity, CMock, CException and Ceedling's own headers, which every build supplies
    def framework?
      return !partial? && Directives::FRAMEWORK.include?( File.basename( spelling ) )
    end

    # The Partial's module directory as written, nil for a macro without one
    def partial_dir
      return macro.end_with?( '_AT' ) ? args[0] : nil
    end

    def partial_module
      return macro.end_with?( '_AT' ) ? args[1] : args[0]
    end

    def key
      return "#{includer} #{macro}(#{args.join( ', ' )})" if partial?
      return "#{includer} <#{spelling}>" if angle

      return "#{includer} \"#{spelling}\""
    end
  end

  # Finds the `#include` directives in a row's C files by their text
  module Directives

    FRAMEWORK = %w[unity.h unity_internals.h cmock.h CException.h ceedling.h].freeze

    C_FILE  = /\.(c|h|hpp|hh|hxx|cpp|cc)\z/.freeze
    INCLUDE = /\A\s*#\s*include\s*(?:"([^"]+)"|<([^>]+)>|((?:TEST|MOCK)_PARTIAL_\w+)\s*\(([^)]*)\))/.freeze

    # Every directive in `tree`, a Hash of path to text, in file and line order, without
    # the framework headers
    def self.scan(tree)
      found = tree.keys.sort.flat_map { |path| C_FILE.match?( path ) ? in_file( path, tree[path] ) : [] }
      return found.reject( &:framework? )
    end

    def self.in_file(path, text)
      return text.each_line.filter_map do |line|
        match = INCLUDE.match( line )
        next if match.nil?

        if match[3]
          args = match[4].split( ',' ).map( &:strip )
          Directive.new( includer: path, macro: match[3], args: args )
        else
          Directive.new( includer: path, spelling: match[1] || match[2], angle: !match[2].nil? )
        end
      end
    end

  end

end

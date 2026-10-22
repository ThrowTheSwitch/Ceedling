# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# One module a `module:create`, `module:destroy`, or `module:stub` call names, read
# from the arguments a user types between the task's brackets.
#
# An argument is a module name, optionally preceded by colon-separated path hints
# (`lab:secret:lair`). The hints join into one path for the path matcher, and a
# Windows drive letter's own colon stays part of that path. A slash in the name
# instead names a subdirectory to create.
#
# The first argument is always a module. A later argument that spells a pattern sets
# the pattern for every module in the call. A name carrying the configured test file
# prefix asks for its test file alone.
class ModuleGeneratorRequest < Struct.new( :name, :path_hint, :pattern, keyword_init: true )

  PATTERNS = %w[src test dh dih mch mvp].freeze

  # A drive letter's colon, which is part of a path rather than a hint separator
  DRIVE = /\A[A-Za-z]:(?=[\\\/])/

  def self.parse(args, test_prefix:, patterns: true)
    args = args.compact.map( &:strip )
    raise CeedlingException.new( 'The module task names no module.' ) if args.first.to_s.empty?

    names, pattern = patterns ? split_pattern( args ) : [args, nil]

    return names.map do |arg|
      request = from_argument( arg, pattern )
      patterns ? request.test_only( test_prefix, arg ) : request
    end
  end

  # The module arguments and the one pattern among the arguments after the first
  def self.split_pattern(args)
    found, names = args.drop( 1 ).partition { |arg| PATTERNS.include?( arg.downcase ) }
    raise CeedlingException.new( "The module task takes one pattern, not #{found.join( ', ' )}." ) if found.size > 1

    return [args.take( 1 ) + names, found.first&.downcase]
  end

  def self.from_argument(arg, pattern)
    hint, name = split_hint( arg )
    raise CeedlingException.new( "The module argument `#{arg}` names no module." ) if name.empty?

    return new( name: name, path_hint: hint, pattern: pattern ).freeze
  end

  # The joined hint, or nil, and the name. A drive letter belongs to the hint when hints
  # follow it, and to the name otherwise.
  def self.split_hint(arg)
    drive = arg[DRIVE].to_s
    hints = arg.delete_prefix( drive ).split( ':', -1 )
    name  = hints.pop
    return [nil, drive + name] if hints.empty?

    hint = drive + hints.reject( &:empty? ).join( '/' )
    return [hint.empty? ? nil : hint, name]
  end

  private_class_method :split_pattern, :from_argument, :split_hint

  # This request as a test-only module when its name carries the test file prefix. A
  # prefix ending in a letter or digit (`Test`) needs a word boundary after it, so
  # `TestWidget` is a test file while `Testimony` is a module.
  def test_only(test_prefix, arg)
    return self unless name.start_with?( test_prefix )

    module_name = name.delete_prefix( test_prefix )
    return self if test_prefix.match?( /[[:alnum:]]\z/ ) and module_name.match?( /\A[[:lower:][:digit:]]/ )

    raise CeedlingException.new( "The module argument `#{arg}` names no module." ) if module_name.empty?

    return self.class.new( name: module_name, path_hint: path_hint, pattern: 'test' ).freeze
  end

end

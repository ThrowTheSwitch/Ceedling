# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/toolchain_output'

# Explains compiler errors where one translation unit declares a name twice or two ways.
#
# A mock or Partial substitutes a header only through the #include directives a test
# names and the order of its search paths. A header's real content can still reach a
# compilation another way, and its declarations then collide with the substitute's (see
# HEADER_COLLISIONS.md). Headers that share a directory can collide the same way with no
# substitute involved, since a quoted #include finds its neighbor before any search path.
#
# Compilers word the collision differently. GCC reports "conflicting types for" and
# "previous definition of". Clang reports "redefinition of" and "previous definition is
# here". Each is a real wording for the same error.
class HeaderCollisionSpecialist

  COLLISION_SYMPTOMS = /redeclaration of|redefinition of|conflicting types|previous definition/i

  # A header path in a GCC or Clang diagnostic location, `path.h:line:column`
  HEADER_LOCATION = /([^\s"]+\.h):\d+:\d+/

  # The education and options that follow a shared-directory prescription's lead
  SHARED_DIRECTORY_GUIDANCE = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • One translation unit may define a type, a tag, or an enum value only once, and every declaration of a name must agree.
    • An include guard keeps a header out the second time only when both arrivals are the same file. Two copies of a header, or two headers that declare one name, pass every guard.
    • A quoted #include looks in the including file's own directory before any search path. A header there reaches its neighbor directly, whatever order the search paths set.
    • Ceedling isolates a header's neighbors only when the header is mocked or Partialized. No header in this directory is, so no isolation applies here.
    • Isolation reaches only one level: a neighbor that #includes a substituted header directly. A chain that passes through further headers or directories is beyond it.

    OPTIONS:
    1. Trace the #include chains into this directory to the declaration that arrives twice, or to the two declarations that disagree.
    2. Mock or Partialize the header whose content should be substituted, so Ceedling isolates its neighbors.
    3. Change the #include or the search path that brings in the second copy.
    4. Add or fix the include guard of a header that arrives twice.
  GUIDANCE

  constructor :test_substitutions, :gcc_dependency_parser, :file_wrapper

  def diagnoses()
    return [
      diagnosis( :substituted_header_collision, method( :examine_substituted_header ) ),
      diagnosis( :shared_directory_collision, method( :examine_shared_directory ) )
    ]
  end

  ### Private ###

  private

  def diagnosis(name, examination)
    return BuildStepDoctor::Diagnosis.new( name: name, steps: [:compile], symptoms: COLLISION_SYMPTOMS, examination: examination )
  end

  # A header the output names that is also one the test substitutes means the real
  # header's content reached the compilation beside its substitute
  def examine_substituted_header(kase)
    mentioned = kase.output.scan( HEADER_LOCATION ).flatten.uniq

    culprit = @test_substitutions.real_headers( kase.inputs[:testable] ).find do |basename, real_path|
      mentioned.any? { |m| File.basename( m ) == basename && File.expand_path( m ) == File.expand_path( real_path ) }
    end
    return nil if culprit.nil?

    return substituted_header_prescription( *culprit )
  end

  # A named header beside other headers, none of them substituted, may have reached its
  # neighbor through a quoted #include. Isolation acts only around a substituted header,
  # so its directory and Ceedling's own are left out. The headers the first attempt's .d
  # file lists are what this test reaches. A toolchain that writes no .d file leaves
  # only the directory's listing, which may overstate the risk.
  def examine_shared_directory(kase)
    reached  = reached_headers( kase.inputs[:dependencies] )
    excluded = excluded_dirs( kase.inputs[:testable] )

    return named_by_directory( kase.output ).filter_map do |dir, headers|
      next if within?( dir, excluded ) || !neighbors?( dir, headers, reached )

      shared_directory_prescription( headers, reached: !reached.nil? )
    end
  end

  # The headers the output names, grouped by their expanded directory
  def named_by_directory(output)
    return ToolchainOutput.headers( output ).group_by { |header| File.dirname( File.expand_path( header ) ) }
  end

  def within?(dir, roots)
    return roots.any? { |root| dir == root || dir.start_with?( root + '/' ) }
  end

  # Every header the .d file lists, expanded, or nil without a .d file
  def reached_headers(dependencies)
    return nil if dependencies.nil? || !@file_wrapper.exist?( dependencies )

    files = @gcc_dependency_parser.parse( @file_wrapper.read( dependencies ) ).values.flatten
    return files.select { |file| header?( file ) }.map { |file| File.expand_path( file ) }.uniq
  end

  def excluded_dirs(testable)
    substituted = @test_substitutions.real_headers( testable ).values.map { |real_path| File.dirname( File.expand_path( real_path ) ) }
    return substituted + @test_substitutions.generated_dirs( testable ).map { |dir| File.expand_path( dir ) }
  end

  def neighbors?(dir, headers, reached)
    beside = reached ? reached.select { |header| File.dirname( header ) == dir } : listed_headers( dir )
    return (beside | headers.map { |header| File.expand_path( header ) }).size > 1
  end

  def listed_headers(dir)
    return [] unless @file_wrapper.directory?( dir )

    return @file_wrapper.directory_entries( dir ).select { |name| header?( name ) }.map { |name| File.join( dir, name ) }
  end

  def header?(filepath)
    return ToolchainOutput::HEADER_EXTENSIONS.include?( File.extname( filepath ).delete_prefix( '.' ).downcase )
  end

  def substituted_header_prescription(basename, real_path)
    notice  = "This looks like '#{basename}' is mocked or Partialized for this test, but its " \
              "real content ('#{real_path}') is also reaching compilation through a second " \
              "unmocked #include chain.\n"
    notice += "> The cause is most likely a transitive #include chain through an unrelated " \
              "header brought about by C convention quirks in search paths and #include guards.\n"
    notice += "> Consider investigating the #include chain and modifying your source or " \
              "Partializing/mocking the problematic header (without necessarily using it) to " \
              "break the transitive #include chain.\n"

    return notice
  end

  # The directory is spelled as the output spelled it
  def shared_directory_prescription(headers, reached:)
    dir      = File.dirname( headers.first )
    names    = headers.map { |header| "'#{File.basename( header )}'" }
    listing  = names.size == 1 ? names.first : "#{names[0..-2].join( ', ' )} and #{names.last}"
    subject  = names.size == 1 ? 'This header shares' : 'Each of these headers shares'
    company  = reached ? "other headers this test's compilation reaches" : 'other headers'

    return "The compiler output appears to report a redeclaration or conflicting types involving #{listing}. " \
           "If so, the cause may lie in how headers reach this compilation. #{subject} the directory '#{dir}' with #{company}.\n" \
           "\n" + SHARED_DIRECTORY_GUIDANCE
  end
end

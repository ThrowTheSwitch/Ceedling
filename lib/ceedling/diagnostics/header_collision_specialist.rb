# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/toolchain_output'
require 'ceedling/diagnostics/header_collision_guidance'

# Explains compiler errors where one translation unit declares a name twice or two ways.
#
# A mock or Partial substitutes a header only through the #include directives a test
# names and the order of its search paths. A header's real content can still reach a
# compilation another way, and its declarations then collide with the substitute's (see
# HEADER_COLLISIONS.md). Headers that share a directory can collide the same way with no
# substitute involved, since a quoted #include finds its neighbor before any search path.
#
# Compilers word the collision differently, and no list of wordings is complete. The
# symptoms below cover the families DOCTOR.md lists and end in a generic net, since a
# missed collision costs more than guidance that turns out not to apply.
class HeaderCollisionSpecialist

  COLLISION_SYMPTOMS = [
    # GCC
    /redefinition of|redeclaration of|conflicting types|previous (?:definition|declaration)|redeclared as different kind/i,
    # Clang, armclang, and Microchip XC8 v2 and later
    /typedef redefinition|previous definition is here/i,
    # EDG front ends: IAR (Pe101), Arm armcc (#101), TI and Green Hills (error #101)
    /has already been (?:declared|defined)|invalid redeclaration|declaration is incompatible|(?:\bPe|#)0*(?:101|147|256)\b/i,
    # MSVC
    /\bC(?:2011|2084|2370|2371)\b|redefinition; different/,
    # TASKING, SDCC, and other compilers
    /redefin|redeclar|already (?:been )?(?:declared|defined)|duplicate (?:definition|declaration)/i
  ].freeze

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
    mentioned = ToolchainOutput.headers( kase.output )

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
    return "The compiler output appears to report a redeclaration or conflicting types in '#{basename}'. " \
           "If so, this test's substitute for '#{basename}' may be colliding with its real content ('#{real_path}'), " \
           "which can reach this compilation through a second, unmocked #include chain.\n" \
           "\n" + HeaderCollisionGuidance::SUBSTITUTED_HEADER
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
           "\n" + HeaderCollisionGuidance::SHARED_DIRECTORY
  end
end

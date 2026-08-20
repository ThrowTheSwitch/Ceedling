# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/file_path_utils'
require 'ceedling/test_invoker/test_build_validations'

# Owns everything about the TEST_SOURCE_FILE() build directive's own path
# content: collecting a test's raw directive strings, telling additive
# entries apart from subtractive ones, resolving each to a real project
# file, and validating that every entry names something real. Callers care
# about what a test's directive entries resolve to and whether they're
# valid; they don't need to know the +:/-: convention or how a raw string
# becomes a real filepath.
class TestSourceFileDirectiveResolver

  include TestBuildValidations

  constructor :test_context_extractor, :file_finder, :configurator, :loginator

  # Splits a test's TEST_SOURCE_FILE() entries into files to add and files to
  # remove, using the same +:/-: convention :paths list entries use, then
  # resolves each side to a real project file exactly as a bare entry always
  # has. The removal side is returned as resolved path => original directive
  # text, so a caller can both act on the resolved path and name the entry
  # that caused it.
  def resolve(test_filepath, context)
    raw = @test_context_extractor.lookup_build_directive_sources_list( test_filepath )
    additive, subtractive = raw.partition { |source| FilePathUtils.add_path?( source ) }

    find = -> (source) {
      @file_finder.find_build_input_file(
        filepath: FilePathUtils.no_aggregation_decorators( source ),
        complain: :ignore,
        context:  context
      )
    }

    additive_sources = additive.map(&find).compact

    subtractive_sources = subtractive.each_with_object({}) do |source, hash|
      resolved = find.call( source )
      hash[resolved] = source unless resolved.nil?
    end

    return [additive_sources, subtractive_sources]
  end

  # Applies this test's TEST_SOURCE_FILE("-:...") entries against the fully
  # assembled source list, regardless of how each removed file originally got
  # there -- the implicit header/source convention, a positive directive, or
  # a Partial. Each removal that actually changes the list is logged by name
  # so the resulting build is never quietly different from what the source
  # list would otherwise suggest.
  def remove_subtracted(sources, subtractive:, test_filepath:)
    subtractive.each do |removed_path, raw|
      next unless sources.include?( removed_path )
      msg = "TEST_SOURCE_FILE(\"#{raw}\") removed '#{removed_path}' from " \
            "#{test_filepath}'s compile/link list."
      @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end

    return sources - subtractive.keys
  end

end

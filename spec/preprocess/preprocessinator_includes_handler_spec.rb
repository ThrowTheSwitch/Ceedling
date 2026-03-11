# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator_includes_handler'

describe PreprocessinatorIncludesHandler do
  before :each do
    @configurator           = double('configurator')
    @preprocessinator_line_marker_includes_extractor = double('preprocessinator_line_marker_includes_extractor')
    @include_factory        = double('include_factory')
    @tool_executor          = double('tool_executor')
    @file_wrapper           = double('file_wrapper')
    @yaml_wrapper           = double('yaml_wrapper')
    @parsing_parcels        = double('parsing_parcels')
    @loginator              = double('loginator')
    @reportinator           = double('reportinator')
  end

  subject do
    PreprocessinatorIncludesHandler.new(
      :configurator           => @configurator,
      :include_factory        => @include_factory,
      :preprocessinator_line_marker_includes_extractor => @preprocessinator_line_marker_includes_extractor,
      :tool_executor          => @tool_executor,
      :file_wrapper           => @file_wrapper,
      :yaml_wrapper           => @yaml_wrapper,
      :parsing_parcels        => @parsing_parcels,
      :loginator              => @loginator,
      :reportinator           => @reportinator
    )
  end

  # TODO: Test coverage

end

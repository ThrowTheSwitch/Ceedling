require 'spec_helper'
require 'rspec/mocks/standalone'

describe PreprocessinatorIncludesHandler do
  describe "#form_shallow_dependencies_rule" do
    it "should allow #includes with whitespace after the # symbol" do
      objects = {
          :configurator => Object.new, :tool_executor => BasicObject.new,
          :task_invoker => mock(), :file_path_utils => Object.new,
          :yaml_wrapper => nil, :file_wrapper => Object.new
      }

      input = <<-EOS.strip_indentation
        #include "nospace.h"
        # include "single-space.h"
        #\tinclude "tab.h"
        #        include "multiple-spaces.h"
      EOS

      expected_output = <<-EOS.strip_indentation
        #include "nospace.h"
        #include "@@@@nospace.h"
        #include "single-space.h"
        #include "@@@@single-space.h"
        #include "tab.h"
        #include "@@@@tab.h"
        #include "multiple-spaces.h"
        #include "@@@@multiple-spaces.h"
      EOS

      objects[:file_path_utils].stub(:form_temp_path)
      objects[:file_wrapper].stub(:read).and_return(input)
      objects[:configurator].stub(:tools_test_includes_preprocessor)
      objects[:tool_executor].stub(:build_command_line).and_return(:line => nil, :options => nil)
      objects[:tool_executor].stub(:exec).and_return(:output => 'done')

      objects[:file_wrapper].should_receive(:write).with(nil, expected_output)
      PreprocessinatorIncludesHandler.new(objects).form_shallow_dependencies_rule(nil)
    end
  end
end

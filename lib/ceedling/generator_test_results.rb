# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for .ext()
require 'ceedling/constants'
require 'ceedling/exceptions'


##
## Sample Unity Test Executable Output
## ===================================
##
## - Output is line-oriented. Anything outside the recognized lines is assumed to be from `printf()`
##   or equivalent calls and collected for presentation as a collection of $stdout lines.
## - Multiline output (i.e. failure messages) can be achieved by "encoding" newlines as literal 
##   "\n"s (slash-n). `extract_line_elements()` handles converting newline markers into real newlines.
## - :PASS has no trailing message unless Unity's test case execution duration feature is enabled.
##   If enabled, a numeric value with 'ms' as a units signifier trails, ":PASS 1.2 ms".
## - :IGNORE optionally can include a trailing message.
## - :FAIL has a trailing message that relays an assertion failure or crash condition.
## - The statistics line always has the same format with only the count values varying.
## - If there are no failed test cases, the final line is 'OK'. Otherwise, it is 'FAIL'.
##
## $stdout:
## -----------------------------------------------------------------------------------------------------
## TestUsartModel.c:24:testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting:PASS
## TestUsartModel.c:34:testIgnore:IGNORE
## TestUsartModel.c:39:testFail:FAIL: Expected 2 Was 3
## TestUsartModel.c:49:testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately:PASS
## TestUsartModel.c:55:testShouldReturnErrorMessageUponInvalidTemperatureValue:PASS
## TestUsartModel.c:61:testShouldReturnWakeupMessage:PASS
##
## -----------------------
## 6 Tests 1 Failures 1 Ignored
## FAIL

##
## Sample Test Results Output File (YAML)
## ======================================
## The following corresponds to the test executable output above.
##
## TestUsartModel.fail:
## ---
## :source:
##   :file: test/TestUsartModel.c
##   :dirname: test
##   :basename: TestUsartModel.c
## :successes:
## - :test: testGetBaudRateRegisterSettingShouldReturnAppropriateBaudRateRegisterSetting
##   :line: 24
##   :message: ''
##   :unity_test_time: 0
## - :test: testGetFormattedTemperatureFormatsTemperatureFromCalculatorAppropriately
##   :line: 49
##   :message: ''
##   :unity_test_time: 0
## - :test: testShouldReturnErrorMessageUponInvalidTemperatureValue
##   :line: 55
##   :message: ''
##   :unity_test_time: 0
## - :test: testShouldReturnWakeupMessage
##   :line: 61
##   :message: ''
##   :unity_test_time: 0
## :failures:
## - :test: testFail
##   :line: 39
##   :message: Expected 2 Was 3
##   :unity_test_time: 0
## :ignores:
## - :test: testIgnore
##   :line: 34
##   :message: ''
##   :unity_test_time: 0
## :counts:
##   :total: 6
##   :passed: 4
##   :failed: 1
##   :ignored: 1
## :stdout: []
## :time: 0.006512000225484371

class GeneratorTestResults

  constructor :configurator, :generator_test_results_sanity_checker, :yaml_wrapper

  def setup()
    # Aliases
    @sanity_checker = @generator_test_results_sanity_checker
  end

  def process_and_write_results(executable, unity_shell_result, results_file, test_file)
    output_file = results_file

    results = get_results_structure

    results[:source][:dirname] = File.dirname(test_file)
    results[:source][:basename] = File.basename(test_file)
    results[:source][:file] = test_file
    results[:time] = unity_shell_result[:time] unless unity_shell_result[:time].nil?

    # Process test statistics
    if (unity_shell_result[:output] =~ TEST_STDOUT_STATISTICS_PATTERN)
      results[:counts][:total] =   $1.to_i
      results[:counts][:failed] =  $2.to_i
      results[:counts][:ignored] = $3.to_i
      results[:counts][:passed] = (results[:counts][:total] - results[:counts][:failed] - results[:counts][:ignored])
    else
      raise CeedlingException.new( "Could not parse output for `#{executable}`: \"#{unity_shell_result[:output]}\"" ) 
    end

    # Remove test statistics lines
    output_string = unity_shell_result[:output].sub( TEST_STDOUT_STATISTICS_PATTERN, '' )

    # Process test executable results line-by-line
    output_string.lines do |line|
      # Process Unity test executable output
      case line.chomp
      when /(:IGNORE)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:ignores] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)

      when /(:PASS$)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)

      when /(:PASS \(.* ms\)$)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)

      when /(:FAIL)/
        elements = extract_line_elements( executable, line, results[:source][:file] )
        results[:failures] << elements[0]
        results[:stdout] << elements[1] if (!elements[1].nil?)

      # Collect up all other output
      else
        results[:stdout] << line.chomp # Ignores blank lines
      end
    end

    @sanity_checker.verify( results, unity_shell_result[:exit_code] )

    output_file = results_file.ext( @configurator.extension_testfail ) if (results[:counts][:failed] > 0)

    @yaml_wrapper.dump(output_file, results)

    return { :result_file => output_file, :result => results }
  end

  # Filter list of test cases:
  #  --test_case
  #  --exclude_test_case
  #
  # @return Array - list of the test_case hashses {:test, :line_number}
  def filter_test_cases(test_cases)
    _test_cases = test_cases.clone 

    # Filter tests which contain test_case_name passed by `--test_case` argument
    if !@configurator.include_test_case.empty?
      _test_cases.delete_if { |i| !(i[:test] =~ /#{@configurator.include_test_case}/) }
    end

    # Filter tests which contain test_case_name passed by `--exclude_test_case` argument
    if !@configurator.exclude_test_case.empty?
      _test_cases.delete_if { |i| i[:test] =~ /#{@configurator.exclude_test_case}/ }
    end

    return _test_cases
  end

  def create_crash_failure(source, shell_result, test_cases)
    count = test_cases.size()

    output = []
    test_cases.each do |test_case|
      output << "#{source}:#{test_case[:line_number]}:#{test_case[:test]}:FAIL: Test executable crashed"
    end

    shell_result[:output] = 
      regenerate_test_executable_stdout(
        total:   count,
        failed:  count,
        ignored: 0,
        output:  output
      )

    shell_result[:exit_code] = count

    return shell_result
  end

  # Fill out a template to mimic Unity's test executable output
  def regenerate_test_executable_stdout(total:, failed:, ignored:, output:[])
    values = {
      :total => total,
      :failed => failed,
      :ignored => ignored,
      :output => output.map {|line| line.strip()}.join("\n"),
      :result => (failed > 0) ? 'FAIL' : 'OK'
    }

    return UNITY_TEST_RESULTS_TEMPLATE % values
  end

  ### Private ### 
  
  private

  def get_results_structure
    return {
      :source    => {:file => '', :dirname => '', :basename => '' },
      :successes => [],
      :failures  => [],
      :ignores   => [],
      :counts    => {:total => 0, :passed => 0, :failed => 0, :ignored  => 0},
      :stdout    => [],
      :time      => 0.0
      }
  end

  def extract_line_elements(executable, line, filename)
    # Handle anything preceding filename in line as extra output to be collected
    stdout = nil
    stdout_regex = /(.+)#{Regexp.escape(filename)}:[0-9]+:(PASS|IGNORE|FAIL).+/i
    unity_test_time = 0 

    if (line =~ stdout_regex)
      stdout = $1.clone
      line.sub!(/#{Regexp.escape(stdout)}/, '')
    end

    # Collect up test results minus any extra output
    elements = (line.strip.split(':'))[1..-1]

    # Find timestamp if available
    if (elements[-1] =~ / \((\d*(?:\.\d*)?) ms\)/)
      unity_test_time = $1.to_f / 1000
      elements[-1].sub!(/ \((\d*(?:\.\d*)?) ms\)/, '')
    end

    if elements[3..-1]
      message = (elements[3..-1].join(':')).strip
    else
      message = nil
    end

    components = {
      :test => elements[1],
      :line => elements[0].to_i,
      # Decode any multline strings
      :message => message.nil? ? nil : message.gsub( NEWLINE_TOKEN, "\n" ),
      :unity_test_time => unity_test_time
    }

    return components, stdout if elements.size >= 3
    
    # Fall through failure case
    raise CeedlingException.new( "Could not parse results output line \"line\" for `#{executable}`" )
  end

end

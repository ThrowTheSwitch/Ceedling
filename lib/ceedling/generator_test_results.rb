require 'rubygems'
require 'rake' # for .ext()
require 'ceedling/constants'

class GeneratorTestResults

  constructor :configurator, :generator_test_results_sanity_checker, :yaml_wrapper, :debugger_utils

  def process_and_write_results(unity_shell_result, results_file, test_file)
    output_file = results_file

    results = get_results_structure

    results[:source][:dirname] = File.dirname(test_file)
    results[:source][:basename] = File.basename(test_file)
    results[:source][:file] = test_file
    results[:time] = unity_shell_result[:time] unless unity_shell_result[:time].nil?

    # process test statistics
    if (unity_shell_result[:output] =~ TEST_STDOUT_STATISTICS_PATTERN)
      results[:counts][:total] = $1.to_i
      results[:counts][:failed] = $2.to_i
      results[:counts][:ignored] = $3.to_i
      results[:counts][:passed] = (results[:counts][:total] - results[:counts][:failed] - results[:counts][:ignored])
    else
      if @configurator.project_config_hash[:project_use_backtrace]
        # Accessing this code block we expect failure during test execution
        # which should be connected with SIGSEGV
        results[:counts][:total] = 1   # Set to one as the amount of test is unknown in segfault, and one of the test is failing
        results[:counts][:failed] = 1  # Set to one as the one of tests is failing with segfault
        results[:counts][:ignored] = 0
        results[:counts][:passed] = 0

        #Collect function name which cause issue and line number
        if unity_shell_result[:output] =~ /\s"(.*)",\sline_num=(\d*)/
          results[:failures] << { :test => $1, :line =>$2, :message => unity_shell_result[:output], :unity_test_time => unity_shell_result[:time]}
        else
          #In case if regex fail write default values
          results[:failures] << { :test => '??', :line =>-1, :message => unity_shell_result[:output], :unity_test_time => unity_shell_result[:time]}
        end
      end
    end

    # remove test statistics lines
    output_string = unity_shell_result[:output].sub(TEST_STDOUT_STATISTICS_PATTERN, '')
    output_string.lines do |line|
      # process unity output
      case line.chomp
      when /(:IGNORE)/
        elements = extract_line_elements(line, results[:source][:file])
        results[:ignores] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:PASS$)/
        elements = extract_line_elements(line, results[:source][:file])
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:PASS \(.* ms\)$)/
        elements = extract_line_elements(line, results[:source][:file])
        results[:successes] << elements[0] 
        results[:stdout] << elements[1] if (!elements[1].nil?)
      when /(:FAIL)/
        elements = extract_line_elements(line, results[:source][:file])
        elements[0][:test] = @debugger_utils.restore_new_line_character_in_flatten_log(elements[0][:test])
        results[:failures] << elements[0]
        results[:stdout] << elements[1] if (!elements[1].nil?)
      else # collect up all other
        if !@configurator.project_config_hash[:project_use_backtrace]
          results[:stdout] << line.chomp
        end
      end
    end

    @generator_test_results_sanity_checker.verify(results, unity_shell_result[:exit_code])

    output_file = results_file.ext(@configurator.extension_testfail) if (results[:counts][:failed] > 0)

    results[:failures].each do |failure|
      failure[:message] = @debugger_utils.unflat_debugger_log(failure[:message])
    end
    @yaml_wrapper.dump(output_file, results)

    return { :result_file => output_file, :result => results }
  end

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

  def extract_line_elements(line, filename)
    # handle anything preceding filename in line as extra output to be collected
    stdout = nil
    stdout_regex = /(.+)#{Regexp.escape(filename)}.+/i
    unity_test_time = 0 

    if (line =~ stdout_regex)
      stdout = $1.clone
      unless @configurator.project_config_hash[:project_use_backtrace]
        line.sub!(/#{Regexp.escape(stdout)}/, '')
      end
    end

    # collect up test results minus and extra output
    elements = (line.strip.split(':'))[1..-1]

    # find timestamp if available
    if (elements[-1] =~ / \((\d*(?:\.\d*)?) ms\)/)
      unity_test_time = $1.to_f / 1000
      elements[-1].sub!(/ \((\d*(?:\.\d*)?) ms\)/, '')
    end
    if elements[3..-1]
      message = (elements[3..-1].join(':')).strip
      message = @debugger_utils.unflat_debugger_log(message)
    else
      message = nil
    end

    return {:test => elements[1], :line => elements[0].to_i, :message => message, :unity_test_time => unity_test_time}, stdout if elements.size >= 3
    return {:test => '???', :line => -1, :message => nil, :unity_test_time => unity_test_time} #fallback safe option. TODO better handling
  end

end

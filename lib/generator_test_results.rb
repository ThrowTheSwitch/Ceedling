require 'rubygems'
require 'rake' # for .ext()
require 'constants' # for Verbosity constants class


 
class GeneratorTestResults

  constructor :configurator, :yaml_wrapper, :streaminator

  
  def process_and_write_results(raw_unity_output, results_file, test_file)
    output_file = results_file
    
    results = get_results_structure
    
    results[:source][:path] = File.dirname(test_file)
    results[:source][:file] = File.basename(test_file)
    
    raw_unity_lines = raw_unity_output.split(/\n|\r\n/)
    raw_unity_lines.delete_at(-1) # final 'FAIL' or 'OK'
    raw_unity_lines.delete_at(-2) # '-----------------' line before final stats
    
    raw_unity_lines.each do |line|
      # process unity output
      case line
      when /(:IGNORE)/
        results[:ignores]   << extract_line_elements(line)
      when /(:PASS$)/
        results[:successes] << extract_line_elements(line)
      when /(:FAIL)/
        results[:failures]  << extract_line_elements(line)
      # process test statistics
      when /^(\d+)\s+Tests\s+(\d+)\s+Failures\s+(\d+)\s+Ignored/i
        results[:counts][:total]   = $1.to_i
        results[:counts][:failed]  = $2.to_i
        results[:counts][:ignored] = $3.to_i
        results[:counts][:passed]  = (results[:counts][:total] - results[:counts][:failed] - results[:counts][:ignored])
      else
        results[:stdout] << line.chomp
      end
    end
    
    output_file = results_file.ext(@configurator.extension_testfail) if (results[:counts][:failed] > 0)
    
    @yaml_wrapper.dump(output_file, results)
  end

  private

  def get_results_structure
    return {
      :source    => {:path => '', :file => ''},
      :successes => [],
      :failures  => [],
      :ignores   => [],
      :counts    => {:total => 0, :passed => 0, :failed => 0, :ignored  => 0},
      :stdout    => [],
      }
  end
  
  def extract_line_elements(line)
    elements = (line.strip.split(':'))[1..-1]
    return {:test => elements[1], :line => elements[0].to_i, :message => (elements[3..-1].join(':')).strip}
  end

end

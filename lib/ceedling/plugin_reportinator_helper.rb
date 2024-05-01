# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'erb'
require 'rubygems'
require 'rake' # for ext()
require 'ceedling/constants'
require 'ceedling/exceptions'

class PluginReportinatorHelper
  
  attr_writer :ceedling
  
  constructor :configurator, :loginator, :yaml_wrapper, :file_wrapper
  
  def fetch_results(results_path, options)
    # Create the results filepaths
    pass_path = results_path.ext( @configurator.extension_testpass )
    fail_path = results_path.ext( @configurator.extension_testfail )

    # Collect whether the results file(s) exists
    pass_exists = ( @file_wrapper.exist?( pass_path ) ? true : false )
    fail_exists = ( @file_wrapper.exist?( fail_path ) ? true : false )

    # Handle if neither file exists
    if !fail_exists and !pass_exists

      if options[:boom]
        # Complain loudly
        error = "Could find no test results for '#{File.basename(results_path).ext(@configurator.extension_source)}'"
        raise CeedlingException.new(error)

      else
        # Otherwise simply return empty results
        return {}
      end
    end

    # Handle if both files exists and return the newer results
    if pass_exists and fail_exists
      if @file_wrapper.newer?( pass_path, fail_path )
        return @yaml_wrapper.load( pass_path )
      else
        return @yaml_wrapper.load( fail_path )
      end
    end

    # Return success results
    return @yaml_wrapper.load(pass_path) if pass_exists

    # Return fail results
    return @yaml_wrapper.load(fail_path) if fail_exists
    
    # Safety fall-through (flow control should never get here)
    return {}
  end

  def process_results(aggregate, results)
    return if (results.empty?)
    aggregate[:times][(results[:source][:file])] = results[:time]
    aggregate[:successes]        << { :source => results[:source].clone, :collection => results[:successes].clone } if (results[:successes].size > 0)
    aggregate[:failures]         << { :source => results[:source].clone, :collection => results[:failures].clone  } if (results[:failures].size > 0)
    aggregate[:ignores]          << { :source => results[:source].clone, :collection => results[:ignores].clone   } if (results[:ignores].size > 0)
    aggregate[:stdout]           << { :source => results[:source].clone, :collection => results[:stdout].clone    } if (results[:stdout].size > 0)
    aggregate[:counts][:total]   += results[:counts][:total]
    aggregate[:counts][:passed]  += results[:counts][:passed]
    aggregate[:counts][:failed]  += results[:counts][:failed]
    aggregate[:counts][:ignored] += results[:counts][:ignored]
    aggregate[:counts][:stdout]  += results[:stdout].size
    aggregate[:total_time]       += results[:time]
  end

  def run_report(template, hash, verbosity)
    output = ERB.new( template, trim_mode: "%<>" )

    # Run the report template and log result with no log level heading
    @loginator.log( output.result(binding()), verbosity, LogLabels::NONE )
  end
  
end

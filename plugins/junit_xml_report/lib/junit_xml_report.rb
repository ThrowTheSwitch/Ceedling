# This is a simple plugin to generate junit-like XML output
# Hacked together to produce output in a format Jenkins CI can digest
# Based on the xml_tests_report plugin
#
# Author:: Cormac Cannon (mailto:cormac.cannon@neuromoddevices.com)
# License:: Distributed under the same license as Ceedling

require 'ceedling/plugin'
require 'ceedling/constants'

class JunitXmlReport < Plugin

  OUTPUT_FILE_NAME='report_junit.xml'

  TAGS = { :testrun => 'testsuites', :testgroup => 'testsuite', :testcase => 'testcase', :testfailure => 'failure'}

  def setup
    @results_list = {}
    @test_counter = 0
  end

  def post_test_fixture_execute(arg_hash)
    context = arg_hash[:context]

    @results_list[context] = [] if (@results_list[context].nil?)

    @results_list[context] << arg_hash[:result_file]
  end

  def post_build
    @results_list.each_key do |context|
      results = @ceedling[:plugin_reportinator].assemble_test_results(@results_list[context])

      file_path = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s, OUTPUT_FILE_NAME )

      @ceedling[:file_wrapper].open( file_path, 'w' ) do |f|
        @test_counter = 1
        write_results( results, f )
      end
    end
  end

  private

  def write_results( results, stream )
    write_header( results[:counts], stream ) #includes statistics
    write_tests( results[:successes], stream)
    write_failures( results[:failures], stream )
    write_footer( stream )
  end

  def write_header( counts, stream )
    stream.puts "<?xml version='1.0' encoding='utf-8' ?>"
    stream.puts "<#{TAGS[:testrun]}>"
    stream.puts "\t<#{TAGS[:testgroup]} name='Ceedling' tests='#{counts[:total]}' time='0' failures='#{counts[:failed]}' errors='0' skipped='#{counts[:ignored]}'>"
  end

  def write_tests( results, stream )

    results.each do |result|
        result[:collection].each do |item|
          stream.puts "\t\t<#{TAGS[:testcase]} classname='#{File.join( result[:source][:path], result[:source][:file] )}' name='#{item[:test]}'/>"
          @test_counter += 1
        end
    end

  end

  def write_failures( results, stream )

    results.each do |result|
        result[:collection].each do |item|
          filename = File.join( result[:source][:path], result[:source][:file] )
          stream.puts "\t\t<#{TAGS[:testcase]} classname='#{File.join( result[:source][:path], result[:source][:file] )}' name='#{item[:test]}'>"
          stream.puts "\t\t\t<#{TAGS[:testfailure]} type='failure' message='#{item[:message]}'>#{filename}:#{item[:line]}</#{TAGS[:testfailure]}>"
          stream.puts "\t\t</#{TAGS[:testcase]}>"
          @test_counter += 1
        end
    end

  end

  def write_footer( stream )
    stream.puts "\t</#{TAGS[:testgroup]}>"
    stream.puts "</#{TAGS[:testrun]}>"
  end

end

require 'ceedling/plugin'
require 'ceedling/constants'

class HtmlTestsReport < Plugin
  def setup
    @results_list = {}
    @test_counter = 0
  end

  def post_test_fixture_execute(arg_hash)
    context = arg_hash[:context]

    @results_list[context] = [] if @results_list[context].nil?

    @results_list[context] << arg_hash[:result_file]
  end

  def post_build
    @results_list.each_key do |context|
      results = @ceedling[:plugin_reportinator].assemble_test_results(@results_list[context])

      artifact_filename = @ceedling[:configurator].project_config_hash[:html_tests_report_artifact_filename] || 'report.html'
      artifact_fullpath = @ceedling[:configurator].project_config_hash[:html_tests_report_path] || File.join(PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s)
      file_path = File.join(artifact_fullpath, artifact_filename)

      @ceedling[:file_wrapper].open(file_path, 'w') do |f|
        @test_counter = 1
        write_results(results, f)
      end
    end
  end

  private

  def write_results(results, stream)
    write_header(stream)
    write_statistics(results[:counts], stream)
    write_failures(results[:failures], stream)
    write_tests(results[:ignores], stream, "Ignored Tests", "ignored")
    write_tests(results[:successes], stream, "Success Tests", "success")
    write_footer(stream)
  end

  def write_header(stream)
    stream.puts "<!DOCTYPE html>"
    stream.puts '<html lang="en">'
    stream.puts '<head>'
    stream.puts '<meta charset="UTF-8">'
    stream.puts '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
    stream.puts '<meta http-equiv="X-UA-Compatible" content="ie=edge">'
    stream.puts '<title>Test Overview</title>'
    stream.puts '<style>'
    stream.puts '* { font-family: sans-serif;}'
    stream.puts 'table {'
    stream.puts 'border-collapse: collapse;'
    stream.puts 'table-layout: fixed;'
    stream.puts 'width: 99%;'
    stream.puts 'margin: 0 0px 25px 7px;'
    stream.puts 'padding-right: 7px;'
    stream.puts 'font-size: 0.9em;'
    stream.puts 'min-width: 400px;'
    stream.puts 'border-radius: 5px 5px 0 0;'
    stream.puts 'overflow: hidden;'
    stream.puts 'box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);'
    stream.puts '}'
    stream.puts 'details summary { cursor: pointer; }'
    stream.puts 'h1 {'
    stream.puts 'margin: 0 0 7px 14px;'
    stream.puts 'font-size: 1.5em;'
    stream.puts 'font-weight: bold;'
    stream.puts 'text-align: left;'
    stream.puts '}'
    stream.puts 'thead tr {'
    stream.puts 'background-color: #009879;'
    stream.puts 'color: #ffffff;'
    stream.puts 'text-align: left;'
    stream.puts 'font-weight: bold;'
    stream.puts '}'
    stream.puts '.failed thead tr { background-color: #983500; }'
    stream.puts '.ignored thead tr { background-color: #849800; }'
    stream.puts '.success thead tr { background-color: #00981e; }'
    stream.puts 'table th, td { padding: 12px 15px; word-break: break-all; }'
    stream.puts 'table tbody tr { border-bottom: 1px solid #dddddd; }'
    stream.puts 'table tbody tr:nth-of-type(even) { background-color: #f3f3f3; }'
    stream.puts 'table tbody tr:last-of-type { border-bottom: 2px solid #009879; }'
    stream.puts '.failed tbody tr:last-of-type { border-bottom: 2px solid #983500; }'
    stream.puts '.ignored tbody tr:last-of-type { border-bottom: 2px solid #849800; }'
    stream.puts '.success tbody tr:last-of-type { border-bottom: 2px solid #00981e; }'
    stream.puts 'table tbody tr:hover { color: #009879; }'
    stream.puts '.failed tbody tr:hover { color: #983500; }'
    stream.puts '.ignored tbody tr:hover { color: #849800; }'
    stream.puts '.success tbody tr:hover { color: #00981e; }'
    stream.puts '</style>'
    stream.puts '</head>'
    stream.puts '<body>'
  end

  def write_statistics(counts, stream)
    stream.puts '<h1>Summary</h1>'
    stream.puts '<table>'
    stream.puts '<thead><tr><th>Total</th><th>Passed</th><th>Ignored</th><th>Failed</th></tr></thead>'
    stream.puts '<tbody>'
    stream.puts "<tr>"
    stream.puts "<td>#{counts[:total]}</td>"
    stream.puts "<td>#{counts[:total] - counts[:ignored] - counts[:failed]}</td>"
    stream.puts "<td>#{counts[:ignored]}</td>"
    stream.puts "<td>#{counts[:failed]}</td>"
    stream.puts "</tr>"
    stream.puts "</tbody>"
    stream.puts "</table>"
  end

  def write_failures(results, stream)
    if results.size.zero?
      return
    end

    stream.puts '<h1>Failed Test</h1>'
    stream.puts '<table class="failed">'
    stream.puts '<thead><tr><th>File</th><th>Location</th><th>Message</th></tr></thead>'
    stream.puts '<tbody>'

    results.each do |result|
      filename = result[:source][:path] + result[:source][:file]
      @first_row = true

      result[:collection].each do |item|

        stream.puts "<tr>"

        if @first_row
          stream.puts "<td rowspan=\"#{result[:collection].size}\">#{filename}</td>"
          @first_row = false
        end

        stream.puts "<td>#{item[:test]}::#{item[:line]}</td>"
        if item[:message].empty?
          stream.puts "<td>—</td>"
        else
          if item[:message].size > 150
            stream.puts "<td><details><summary>Message hidden due to long length.</summary>#{item[:message]}</details></td>"
          else
            stream.puts "<td>#{item[:message]}</td>"
          end
        end
        stream.puts "</tr>"
      end
    end

    stream.puts "</tbody>"
    stream.puts "</table>"
  end

  def write_tests(results, stream, title, style)
    if results.size.zero?
      return
    end

    stream.puts "<h1>#{title}</h1>"
    stream.puts "<table class='#{style}'>"
    stream.puts '<thead><tr><th>File</th><th>Name</th><th>Message</th></tr></thead>'
    stream.puts '<tbody>'

    results.each do |result|
      filename = result[:source][:path] + result[:source][:file]
      @first_row = true

      result[:collection].each do |item|
        stream.puts "<tr>"

        if @first_row
          stream.puts "<td rowspan=\"#{result[:collection].size}\">#{filename}</td>"
          @first_row = false
        end

        stream.puts "<td>#{item[:test]}</td>"
        if item[:message].empty?
          stream.puts "<td>—</td>"
        else
          if item[:message].size > 150
            stream.puts "<td><details><summary>Message hidden due to long length.</summary>#{item[:message]}</details></td>"
          else
            stream.puts "<td>#{item[:message]}</td>"
          end
        end
        stream.puts "</tr>"
      end
    end

    stream.puts "</tbody>"
    stream.puts "</table>"
  end

  def write_footer(stream)
    stream.puts '</body>'
    stream.puts '</html>'
  end
end

require 'verbosinator'


class ReporterTestResultsHelper
  
  constructor :reportinator, :streaminator
  
  def print_results(report_data)
    report = ''
    
    if (report_data[:ignored_count] > 0)
      report += @reportinator.generate_banner('IGNORED UNIT TEST SUMMARY')
      report_data[:ignores_list].each{ |item| report += "#{item}\n" }
    end
    
    if (report_data[:failed_count] > 0)
      report += @reportinator.generate_banner('FAILED UNIT TEST SUMMARY')
      report_data[:failures_list].each{ |item| report += "#{item}\n" }
    end

    total_string = report_data[:tested_count].to_s
    format_string = "%#{total_string.length}i"

    report += @reportinator.generate_banner('OVERALL UNIT TEST SUMMARY')
    report += "TOTAL TESTED:  #{total_string}\n"
    report += "TOTAL FAILED:  #{sprintf(format_string, report_data[:failed_count])}\n"
    report += "TOTAL IGNORED: #{sprintf(format_string, report_data[:ignored_count])}\n"
    report += "\n"
    
    @streaminator.stdout_puts(report, Verbosity::NORMAL)
  end
  
end
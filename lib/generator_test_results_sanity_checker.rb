 
class GeneratorTestResultsSanityChecker

  constructor :streaminator
  
  def verify(results)

    if (results[:ignores].size != results[:counts][:ignored])
      sanity_check_warning(results[:source][:file], 'final ignore count does not match summation of ignored test cases.')
    end
    
    if (results[:failures].size != results[:counts][:failed])
      sanity_check_warning(results[:source][:file], 'final fail count does not match summation of failed test cases.')
    end

    if ((results[:ignores].size + results[:failures].size + results[:successes].size) != results[:counts][:total])
      sanity_check_warning(results[:source][:file], 'final test count does not match summation of all test cases.')
    end
    
  end

  private
  
  def sanity_check_warning(file, message)
    @streaminator.stdout_puts("WARNING: Internal framework sanity check for test fixture '#{file}' reveals that #{message}")
  end

end

 
class GeneratorTestResultsSanityChecker

  constructor :streaminator
  
  def verify(results)

    if (results[:ignores].size != results[:counts][:ignored])
      sanity_check_warning(results[:source][:file], 'the final ignore count does not match summation of ignored test cases.')
    end
    
    if (results[:failures].size != results[:counts][:failed])
      sanity_check_warning(results[:source][:file], 'the final fail count does not match summation of failed test cases.')
    end

    if ((results[:ignores].size + results[:failures].size + results[:successes].size) != results[:counts][:total])
      sanity_check_warning(results[:source][:file], 'the final test count does not match summation of all test cases.')
    end
    
  end

  private
  
  def sanity_check_warning(file, message)
    @streaminator.stderr_puts("ERROR: Internal sanity check for test fixture '#{file}' finds that #{message}")
    raise
  end

end

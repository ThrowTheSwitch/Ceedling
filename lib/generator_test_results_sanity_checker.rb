 
class GeneratorTestResultsSanityChecker

  constructor :streaminator
  
  def verify(results, unity_exit_code)
    ceedling_ignores_count   = results[:ignores].size
    ceedling_failures_count  = results[:failures].size
    ceedling_tests_summation = (ceedling_ignores_count + ceedling_failures_count + results[:successes].size)

    # many platforms limit exit codes to a maximum of 255
    if ((ceedling_failures_count != unity_exit_code) and (unity_exit_code < 255))
      sanity_check_warning(results[:source][:file], "Unity's exit code (#{unity_exit_code}) does not match Ceedling's summation of failed test cases (#{ceedling_failures_count}).")
    end

    if ((ceedling_failures_count < 255) and (unity_exit_code == 255))
      sanity_check_warning(results[:source][:file], "Ceedling's summation of failed test cases (#{ceedling_failures_count}) is less than Unity's exit code (255 or more).")
    end
    
    if (ceedling_ignores_count != results[:counts][:ignored])
      sanity_check_warning(results[:source][:file], "Unity's final ignore count (#{results[:counts][:ignored]}) does not match Ceedling's summation of ignored test cases (#{ceedling_ignores_count}).")
    end
    
    if (ceedling_failures_count != results[:counts][:failed])
      sanity_check_warning(results[:source][:file], "Unity's final fail count (#{results[:counts][:failed]}) does not match Ceedling's summation of failed test cases (#{ceedling_failures_count}).")
    end

    if (ceedling_tests_summation != results[:counts][:total])
      sanity_check_warning(results[:source][:file], "Unity's final test count ((#{results[:counts][:total]})) does not match Ceedling's summation of all test cases (#{ceedling_tests_summation}).")
    end
    
  end

  private
  
  def sanity_check_warning(file, message)
    @streaminator.stderr_puts("\nERROR: Internal sanity check for test fixture '#{file}' finds that #{message}")
    raise
  end

end

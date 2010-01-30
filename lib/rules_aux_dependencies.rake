

rule(/#{PROJECT_TEST_DEPENDENCIES_PATH}\/#{'.+\\'+EXTENSION_DEPENDENCIES}$/ => [
    proc do |task_name|
      return @objects[:file_finder].find_test_or_source_file(task_name)
    end  
  ]) do |dep|
  @objects[:generator].generate_dependencies_file(dep.source, dep.name)
end


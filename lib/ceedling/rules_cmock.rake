

rule(/#{CMOCK_MOCK_PREFIX}[^\/\\]+#{'\\'+EXTENSION_SOURCE}$/ => [
    proc do |task_name|
      @ceedling[:file_finder].find_header_input_for_mock_file(task_name)
    end  
  ]) do |mock,orig|

  @ceedling[:generator].generate_mock(TEST_SYM, [mock,orig])
end

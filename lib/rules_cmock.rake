

rule(/#{CMOCK_MOCK_PREFIX}.+#{'\\'+EXTENSION_SOURCE}$/ => [
    proc do |task_name|
      return @ceedling[:file_finder].find_mockable_header(task_name)
    end  
  ]) do |mock|
  @ceedling[:generator].generate_mock(mock.source)
end

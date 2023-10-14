require 'ceedling/constants'

class CeedlingException < RuntimeError
  # Nothing at the moment
end

class ShellExecutionException < CeedlingException
  attr_reader :shell_result
  def initialize(shell_result:, message:)
    @shell_result = shell_result
    super(message)
  end
end

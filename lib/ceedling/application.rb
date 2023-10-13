
# As Rake is removed, more and more functionality and code entrypoints will migrate here

class Application

  constructor :system_wrapper

  def setup
    @failures = false
  end

  def register_build_failure
    @failures = true
  end

  def build_succeeded?
    return (!@failures) && @system_wrapper.ruby_success?
  end

end

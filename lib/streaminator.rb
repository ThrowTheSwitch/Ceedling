
class Streaminator

  constructor :verbosinator, :stream_wrapper

  # for those objects for whom the configurator has already been instantiated,
  # Streaminator is a convenience object for handling verbosity and writing to the std streams

  def stdout_puts(string, verbosity)
    @stream_wrapper.stdout_puts(string) if (@verbosinator.should_output?(verbosity))
    @stream_wrapper.stdout_flush
  end

  def stderr_puts(string, verbosity)
    @stream_wrapper.stderr_puts(string) if (@verbosinator.should_output?(verbosity))
    @stream_wrapper.stderr_flush
  end

end

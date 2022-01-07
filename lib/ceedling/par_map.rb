
def par_map(n, things, &block)
  if (things.length <= 1)
    yield things.pop() if not things.empty?
    return
  end

  queue = Queue.new
  things.each { |thing| queue << thing }

  num_threads = [n, things.length].min()
  threads = (1..num_threads).collect do
    Thread.new do
      begin
        while true
          yield queue.pop(true)
        end
      rescue ThreadError

      end
    end
  end
  threads.each { |t| t.join }
end


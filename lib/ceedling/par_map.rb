

def par_map(n, things, &block)
  queue = Queue.new
  things.each { |thing| queue << thing }
  
  threads = (1..n).collect do
    thread = Thread.new do
      begin
        while true
          yield queue.pop(true)
        end
      rescue ThreadError
        # ...
      end
    end
    thread.abort_on_exception = true
    thread # Hand thread to collect Enumerable routine
  end

  threads.each do |thread|
    thread.join
  end
end


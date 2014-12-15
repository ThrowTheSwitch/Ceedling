require 'ceedling/par_map'

def short_task_should(n)
  done_count = 0
  par_map(n, [0.01] * (n - 1) + [0] * 10) do |seconds|
    sleep(seconds)
    if seconds == 1 then
      done_count.should >= 10
    else
      done_count += 1
    end
  end
end

describe "par_map" do
  it "should run shorter tasks while larger tasks are blocking (with 2 threads)" do
    short_task_should(2)
  end

  it "should run shorter tasks while larger tasks are blocking (with 3 threads)" do
    short_task_should(3)
  end

  it "should run shorter tasks while larger tasks are blocking (with 4 threads)" do
    short_task_should(4)
  end

  #the following two tests are still slightly nondeterministic and may occasionally
  #  show false positives (though we think we've gotten it pretty stable)
  it "should collide if multiple threads are used" do
    is_running = false
    # we are trying to maximize the potential for collision by varying the sleep
    #  delay between threads
    collision = false
    par_map(4, (1..5).to_a) do |x|
      if is_running then
        collision = true
      end
      is_running = true
      sleep(0.01 * x)
      is_running = false
    end
    expect(collision).to eq true
  end

  it "should be serial if only one thread is used" do
    is_running = false
    par_map(1, (1..5).to_a) do |x|
      expect(is_running).to eq false
      is_running = true
      sleep(0.01 * x)
      is_running = false
    end
  end


end

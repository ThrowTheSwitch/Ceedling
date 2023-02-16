module TargetLoader
  class NoTargets    < RuntimeError; end
  class NoDirectory  < RuntimeError; end
  class NoDefault    < RuntimeError; end
  class NoSuchTarget < RuntimeError; end

  class RequestReload < RuntimeError; end

  def self.inspect(config, target_name=nil)
    unless config[:targets]
      raise NoTargets
    end

    targets = config[:targets]
    unless targets[:targets_directory]
      raise NoDirectory.new("No targets directory specified.")
    end
    unless targets[:default_target]
      raise NoDefault.new("No default target specified.")
    end

    target_path = lambda {|name| File.join(targets[:targets_directory], name + ".yml")}

    target = if target_name
               target_path.call(target_name)
             else
               target_path.call(targets[:default_target])
             end

    unless File.exist? target
      raise NoSuchTarget.new("No such target: #{target}")
    end

    ENV['CEEDLING_MAIN_PROJECT_FILE'] = target

    raise RequestReload
  end
end

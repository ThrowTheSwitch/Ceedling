module TargetLoader
  class NoTargets   < Exception; end
  class NoDirectory < Exception; end
  class NoDefault   < Exception; end

  class RequestReload < Exception; end

  def self.inspect(config, target_name)
    unless config[:targets]
      raise NoTargets
    end

    targets = config[:targets]
    unless targets[:targets_directory]
      raise NoDirectory
    end
    unless targets[:default_target]
      raise NoDefault
    end

    target_path = lambda {|name| File.join(targets[:targets_directory], name + ".yml")}

    target = if ENV['TARGET']
               target_path.call(ENV['TARGET'])
             else
               target_path.call(targets[:default_target])
             end

    ENV['CEEDLING_MAIN_PROJECT_FILE'] = target

    raise RequestReload
  end
end

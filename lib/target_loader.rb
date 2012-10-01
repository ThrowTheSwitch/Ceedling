class TargetLoader
  class NoTargets < Exception; end
  class NoDefault < Exception; end

  def initialize(config)
    p config
    raise "nope"
  end
end

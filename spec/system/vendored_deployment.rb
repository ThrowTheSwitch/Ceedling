require 'spec_system_helper'

describe "Ceedling deployed in a project's `vendor` directory." do
  before do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after do
    @c.done!
  end

  xit "can create projects" do
  end

  xit "can test projects" do
  end

  xit "can use the module plugin" do
  end
end

require 'spec_system_helper'

describe "Ceedling deployed in a project's `vendor` directory." do
  before do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after do
    @c.done!
  end

  it "can create projects" do
    @c.with_context do
      proj_name = "fake_project"
      output = `bundle exec ruby -S ceedling new fake_project`
      Dir.chdir proj_name do
        1.should == 2
      end
    end
  end

  xit "can test projects" do
  end

  xit "can use the module plugin" do
  end
end

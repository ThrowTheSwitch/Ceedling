require 'spec_system_helper'

describe "Ceedling" do
  include CeedlingTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "deployed in a project's `vendor` directory." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { contains_documentation }
    it { can_test_projects }
    it { can_use_the_module_plugin }
  end

  describe "deployed in a project's `vendor` directory without docs." do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --nodocs #{@proj_name} 2>&1`
      end
    end

    it { does_not_contain_documentation }
  end

  describe "deployed as a gem" do
    before do
      @proj_name = "fake_project"
      @c.with_context do
        `bundle exec ruby -S ceedling new --as-gem #{@proj_name} 2>&1`
      end
    end

    after { @c.with_context { FileUtils.rm_rf @proj_name } }

    it { can_create_projects }
    it { does_not_contain_a_vendor_directory }
    it { can_test_projects }
    it { can_use_the_module_plugin }
  end
end

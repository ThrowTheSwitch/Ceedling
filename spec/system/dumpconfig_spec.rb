# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'yaml'

##
## `ceedling dumpconfig` coverage
## ==============================
##
## Two concerns, both otherwise untested at this tier (mixin_ordering_spec.rb and
## ruby_replacement_spec.rb each exercise `dumpconfig` only incidentally, for their
## own unrelated concerns):
##
## 1. A default (--app enabled) dumpconfig run's `:extension` config entries are
##    FilenameExtension objects (lib/ceedling/filename_extension.rb) -- without a
##    custom YAML serialization hook, these dump as tagged `!ruby/object:...`
##    values instead of clean, safe YAML any tool can read back.
##
## 2. `--stdout` writes the same YAML directly to standard output instead of a
##    file, for a consuming tool that wants Ceedling's resolved configuration
##    without a temp file -- every console banner/notice dumpconfig would
##    otherwise print must be suppressed so the stream stays pure YAML.
##
ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dumpconfig") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    it "dumps clean YAML to a file, with :extension entries as plain arrays, not tagged Ruby objects" do
      dump_file = nil
      @c.with_context do
        Dir.chdir @proj_name do
          dump_file = File.expand_path('dump_config.yml')
          @c.ceedling_appcmd_exec("dumpconfig #{dump_file}")
        end
      end

      raw = File.read(dump_file)
      expect(raw).not_to include('!ruby/object')

      config = YAML.safe_load(raw, permitted_classes: [Symbol])
      expect(config.dig(:extension, :source)).to be_a(Array)
      expect(config.dig(:extension, :source)).not_to be_empty
    end

    it "writes the same clean YAML to standard output instead of a file with --stdout" do
      output = nil
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_appcmd_exec("dumpconfig --stdout")
        end
      end

      # A leaked banner/notice would either break the parse outright or show up
      # as extraneous top-level content -- a clean parse is the direct proof
      # nothing but YAML reached the stream.
      config = YAML.safe_load(output.to_s, permitted_classes: [Symbol])
      expect(config.dig(:extension, :source)).to be_a(Array)
      expect(output).not_to include('!ruby/object')
      expect(output).not_to include('Dumped project configuration')
    end

    it "extracts just the requested section to stdout, positional arguments treated as SECTIONS" do
      output = nil
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_appcmd_exec("dumpconfig --stdout tools test_compiler")
        end
      end

      config = YAML.safe_load(output.to_s, permitted_classes: [Symbol])
      expect(config.keys).to eq([:test_compiler])
    end

    it "fails with a clear error and non-zero exit status when FILEPATH is omitted without --stdout" do
      @c.with_context do
        Dir.chdir @proj_name do
          @c.ceedling_appcmd_exec("dumpconfig")
        end
      end

      expect(@c.last_exit_status).not_to eq(0)
      expect(@c.raw_output).to match(/FILEPATH is a required parameter/)
    end
  end
end

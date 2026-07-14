# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# 'C' (aka POSIX) is the stress pick: it's the one locale guaranteed present on every
# POSIX system (no locale-gen required), and it's the locale under which Ruby's
# Encoding.default_external resolves to US-ASCII on Linux rather than UTF-8. That gap
# between "source files are UTF-8" and "platform default encoding is 7-bit ASCII" is
# the condition this spec exists to stress: any code path that reads or scans file
# content without accounting for the platform default encoding is exposed here in a way
# it would not be under this repo's normal UTF-8 test locale (en_US.UTF-8, forced by
# SystemContext#with_context for every other system spec).
ENCODING_STRESS_LOCALE = (ENV.fetch('LC_ALL', nil) || ENV.fetch('LANG', nil) || 'C').freeze

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before :all do
    skip "Default-encoding stress testing is only supported on Linux" unless RUBY_PLATFORM.include?('linux')
  end

  # with_context forces LC_ALL/LANG/LANGUAGE to en_US.UTF-8; override to the stress
  # locale immediately before each Ceedling invocation so Ceedling's own Ruby process
  # runs under a non-UTF-8 default external encoding, not just any spawned subprocess.
  def stress_encoding!
    ENV['LC_ALL']   = ENCODING_STRESS_LOCALE
    ENV['LANG']     = ENCODING_STRESS_LOCALE
    ENV['LANGUAGE'] = ENCODING_STRESS_LOCALE
  end

  # Canary: proves this job is actually exercising a non-UTF-8 default encoding before
  # trusting any "pass" from the example-project cases below. Without this, a future
  # Ruby release or Linux runner image that changes how default_external is resolved
  # from LC_ALL/LANG could silently turn this whole file into a no-op that always passes
  # against an effectively UTF-8 environment -- a false positive for encoding coverage.
  describe "Sanity check: the default-encoding stress condition is real" do
    it "confirms Ruby's default external encoding is non-UTF-8, and that naive reads of planted non-ASCII content fail without an encoding-safety guard" do
      # Encoding.default_external is resolved once at Ruby process startup from the
      # ambient LC_ALL/LANG at that time (the CI job sets LC_ALL=C/LANG=C before `rake`
      # runs) and does not change if ENV is mutated afterward -- so this reflects the
      # actual condition every other case in this file runs under.
      expect(Encoding.default_external.name).to eq('US-ASCII'),
        "Expected the '#{ENCODING_STRESS_LOCALE}' locale to resolve Ruby's default " \
        "external encoding to US-ASCII on this platform, but got " \
        "#{Encoding.default_external.name.inspect}. If Ruby or this runner image " \
        "changed how default_external is derived from LC_ALL, the rest of this file's " \
        "passes may be false positives."

      # Confirm the planted non-ASCII comment (examples/temp_sensor/test/TestMain.c)
      # actually breaks *naive*, unguarded string processing under this default --
      # proving the stress condition has teeth, not just that the encoding name matches.
      # This is the same failure mode (`invalid byte sequence`) that encoding-safety
      # guards elsewhere in Ceedling's source-scanning code exist to prevent.
      non_ascii_fixture = File.expand_path('../../../examples/temp_sensor/test/TestMain.c', __FILE__)
      expect {
        File.read(non_ascii_fixture).match(/test/)
      }.to raise_error(ArgumentError, /invalid byte sequence/)
    end
  end

  describe "Command: `ceedling example temp_sensor` under '#{ENCODING_STRESS_LOCALE}' default encoding" do
    before do
      @c.with_context { @c.ceedling_appcmd_exec("example temp_sensor") }
    end

    it "tests with preprocessing enabled" do
      @c.with_context do
        stress_encoding!
        Dir.chdir "temp_sensor" do
          @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :all } })
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+86/)
          expect(output).to match(/PASSED:\s+86/)
        end
      end
    end

    it "tests with preprocessing disabled" do
      @c.with_context do
        stress_encoding!
        Dir.chdir "temp_sensor" do
          @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :none } })
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          # One fewer test than the preprocessing-enabled case: without preprocessing,
          # raw-source test-case discovery doesn't expand a conditional-compilation-gated
          # test that the preprocessed path does.
          expect(output).to match(/TESTED:\s+85/)
          expect(output).to match(/PASSED:\s+85/)
        end
      end
    end
  end

  describe "Command: `ceedling example wondrous_forest` under '#{ENCODING_STRESS_LOCALE}' default encoding" do
    before do
      @c.with_context { @c.ceedling_appcmd_exec("example wondrous_forest") }
    end

    it "tests with standard preprocessing" do
      @c.with_context do
        stress_encoding!
        Dir.chdir "wondrous_forest" do
          @c.merge_project_yml_for_test({ :test_build => { :preprocess_force_fallback => false } })
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+65/)
          expect(output).to match(/PASSED:\s+65/)
        end
      end
    end

    it "tests with fallback preprocessing" do
      @c.with_context do
        stress_encoding!
        Dir.chdir "wondrous_forest" do
          @c.merge_project_yml_for_test({ :test_build => { :preprocess_force_fallback => true } })
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+65/)
          expect(output).to match(/PASSED:\s+65/)
        end
      end
    end
  end
end

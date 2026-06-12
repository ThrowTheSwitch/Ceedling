# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# Capture the active locale at spec load time.
# When run via `rake ci` normally, this is the system default (en_US.UTF-8 or similar).
# When run by the CI locale job, LC_ALL=ja_JP.UTF-8 is set before RSpec starts,
# so LOCALE_SPEC_ACTIVE_LOCALE captures the Japanese locale and informs both the
# describe block label and the in-test locale override.
LOCALE_SPEC_ACTIVE_LOCALE = (ENV.fetch('LC_ALL', nil) || ENV.fetch('LANG', nil) || 'en_US.UTF-8').freeze

# Returns true if the named locale is installed and available on this system.
# Uses `locale -a` which is a standard POSIX utility available on Linux.
# Returns false on non-Linux platforms (Windows does not use POSIX locale names)
# and on any command execution error.
# Note: `locale -a` may report 'ja_JP.utf8' for a locale installed as 'ja_JP.UTF-8';
# comparison normalizes case and strips hyphens so both forms match.
def locale_spec_locale_installed?(locale)
  return false unless RUBY_PLATFORM.include?('linux')
  normalize = ->(l) { l.downcase.delete('-') }
  `locale -a 2>/dev/null`.split.any? { |l| normalize.call(l) == normalize.call(locale) }
rescue
  false
end

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("locale") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    describe "Test builds under '#{LOCALE_SPEC_ACTIVE_LOCALE}' locale" do
      before :all do
        skip "Locale testing is only supported on Linux" unless RUBY_PLATFORM.include?('linux')
        skip "Locale '#{LOCALE_SPEC_ACTIVE_LOCALE}' is not installed on this system" \
          unless locale_spec_locale_installed?(LOCALE_SPEC_ACTIVE_LOCALE)
      end

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.c"), 'src/'
          end
        end
      end

      it "tests standard preprocessing under '#{LOCALE_SPEC_ACTIVE_LOCALE}' locale" do
        @c.with_context do
          # with_context sets LC_ALL=en_US.UTF-8 before yielding; override to the active
          # locale so GCC runs under that locale and produces locale-specific preprocessor
          # output (e.g. <組み込み> for <built-in> under ja_JP), exercising encoding-safe
          # binary-mode reads and line marker extraction in the preprocessinator.
          ENV['LC_ALL']   = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANG']     = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANGUAGE'] = LOCALE_SPEC_ACTIVE_LOCALE
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :mocks } })
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            expect(output).not_to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests fallback preprocessing under '#{LOCALE_SPEC_ACTIVE_LOCALE}' locale" do
        @c.with_context do
          ENV['LC_ALL']   = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANG']     = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANGUAGE'] = LOCALE_SPEC_ACTIVE_LOCALE
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            settings = {
              :project    => { :use_test_preprocessor => :mocks },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with standard preprocessing under '#{LOCALE_SPEC_ACTIVE_LOCALE}' locale" do
        @c.with_context do
          ENV['LC_ALL']   = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANG']     = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANGUAGE'] = LOCALE_SPEC_ACTIVE_LOCALE
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            # :use_partials automatically enables mocking and preprocessing — no explicit
            # :use_test_preprocessor needed.
            @c.merge_project_yml_for_test({ :project => { :use_partials => true } })
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            expect(output).not_to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with fallback preprocessing under '#{LOCALE_SPEC_ACTIVE_LOCALE}' locale" do
        @c.with_context do
          ENV['LC_ALL']   = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANG']     = LOCALE_SPEC_ACTIVE_LOCALE
          ENV['LANGUAGE'] = LOCALE_SPEC_ACTIVE_LOCALE
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end
    end
  end
end

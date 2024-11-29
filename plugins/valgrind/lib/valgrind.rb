require 'ceedling/plugin'
require 'ceedling/constants'
require 'valgrind_constants'

class Valgrind < Plugin
    attr_reader :config

    def setup
      @result_list = []

      @config = {
        :project_test_build_output_path => VALGRIND_BUILD_OUTPUT_PATH
      }

      @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    end
end

# end blocks always executed following rake run
END {
    # cache our input configurations to use in comparison upon next execution
    @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash) if @ceedling[:task_invoker].invoked?(/^#{VALGRIND_TASK_ROOT}/)
}

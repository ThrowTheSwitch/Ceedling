require 'require_all'
require 'constructor'

RSpec.configure do |configuration|
  configuration.mock_with :rr
end

here = File.dirname(__FILE__)

$: << File.join(here, '../lib')
$: << File.join(here, '../vendor/deep_merge/lib')
$: << File.join(here, '../vendor/cmock/lib')

support_files = File.join(File.dirname(__FILE__), "support/**/*.rb")
require_all Dir.glob(support_files)
support_dir = File.join(File.dirname(__FILE__), 'support')

# Eventually, we should use this.
#
# # ceedling_files = File.join(File.dirname(__FILE__), '../lib/**/*.rb')
# # require_all Dir.glob(ceedling_files)

require 'preprocessinator_extractor'
require 'configurator_builder'
require 'configurator'

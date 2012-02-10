require 'require_all'
require 'constructor'

here = File.dirname(__FILE__)

$: << File.join(here, '../lib')
$: << File.join(here, '../vendor/deep_merge/lib')

support_files = File.join(File.dirname(__FILE__), "support/**/*.rb")
require_all Dir.glob(support_files)
support_dir = File.join(File.dirname(__FILE__), 'support')

RSpec.configure do |configuration|
  configuration.mock_with :rr
end

require 'preprocessinator_extractor'
require 'configurator_builder'
require 'configurator'

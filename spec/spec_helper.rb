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

class String
  def left_margin(indentation_level = 0)
    indent = " " * indentation_level

    data_start_at_col = self.lines.map do |l|
      white_space = l.match(/(^\s*)\S/)

      if white_space
        white_space[1].length
      end
    end.compact.min

    self.lines.map do |l|
      rel = l[data_start_at_col..-1]
      if rel
        indent + rel
      end
    end.compact.join
  end
end

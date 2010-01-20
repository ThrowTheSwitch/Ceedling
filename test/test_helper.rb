
#gem install test-unit -v 1.2.3
ruby_version = RUBY_VERSION.split('.')
if (ruby_version[1].to_i == 9) and (ruby_version[2].to_i > 1)
  require 'gems'
  gem 'test-unit'
end
require 'test/unit'

require 'behaviors'


class String
  def left_margin(margin=0)
    non_whitespace_column = 0
    new_lines = []
    
    # find first line with non-whitespace and count left columns of whitespace
    self.each_line do |line|
      if (line =~ /^\s*\S/)
        non_whitespace_column = $&.length - 1
        break
      end
    end
    
    # iterate through each line, chopping off leftmost whitespace columns and add back the desired whitespace margin
    self.each_line do |line|
      columns = []
      margin.times{columns << ' '}
      # handle special case of line being narrower than width to be lopped off
      if (non_whitespace_column < line.length)
        new_lines << "#{columns.join}#{line[non_whitespace_column..-1]}"
      else
        new_lines << "\n"
      end
    end
    
    return new_lines.join
  end
end


TESTS_ROOT    = File.expand_path(File.dirname(__FILE__))
SYSTEST_ROOT  = TESTS_ROOT + '/system'

LIB_ROOT      = File.expand_path(File.dirname(__FILE__) + '/../lib')

CEEDLING_ROOT = 'test_ceedling_root'
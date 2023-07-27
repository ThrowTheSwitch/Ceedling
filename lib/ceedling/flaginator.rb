require 'rubygems'
require 'rake' # for ext()
require 'fileutils'
require 'ceedling/constants'


# :flags:
#   :release:
#     :compile:
#       :'test_.+'
#         - -pedantic   # add '-pedantic' to every test file
#       :*:          # add '-foo' to compilation of all files not main.c
#         - -foo
#       :main:       # add '-Wall' to compilation of main.c
#         - -Wall
#   :test:
#     :link:
#       :test_main:  # add '--bar --baz' to linking of test_main.exe
#         - --bar
#         - --baz

def partition(hash, &predicate)
  hash.partition(&predicate).map(&:to_h)
end

class Flaginator

  constructor :configurator, :streaminator

  def flags_defined?(context, operation)
    # create configurator accessor method
    accessor = ('flags_' + context.to_s).to_sym

    # check for context in flags configuration
    return false if not @configurator.respond_to?( accessor )

    # get flags sub hash associated with this context
    flags = @configurator.send( accessor )

    # check if operation represented in flags hash
    return false if not flags.include?( operation )    

    return true
  end

  def get_flag(hash, file_name)
    file_key = file_name.to_sym
   
    # 1. try literals
    literals, magic = partition(hash) { |k, v| k.to_s =~ /^\w+$/ }  
    return literals[file_key] if literals.include?(file_key)
    
    any, regex = partition(magic) { |k, v| (k == :'*') || (k == :'.*')  } # glob or regex wild card
    
    # 2. try regexes
    find_res = regex.find { |k, v| file_name =~ /^#{k}$/ }
    return find_res[1] if find_res
    
    # 3. try anything
    find_res = any.find { |k, v| file_name =~ /.*/ }
    return find_res[1] if find_res
      
    # 4. well, we've tried
    return []
  end
  
  def flag_down(operation, context, file)
    # create configurator accessor method
    accessor = ('flags_' + context.to_s).to_sym

    # create simple filename key from whatever filename provided
    file_name = File.basename( file ).ext('')
    file_key = File.basename( file ).ext('').to_sym

    # if no entry in configuration for flags for this context, bail out
    return [] if not @configurator.respond_to?( accessor )

    # get flags sub hash associated with this context
    flags = @configurator.send( accessor )

    # if operation not represented in flags hash, bail out
    return [] if not flags.include?( operation )

    # redefine flags to sub hash associated with the operation
    flags = flags[operation]

    if flags == nil
      error = "ERROR: No entries for '[#{operation}][#{context}]' flags in project configuration."
      @streaminator.stderr_puts(error, Verbosity::ERRORS)
      raise
    end

    # look for missing flag values
    flags.each do |k, v|
      if v == nil
        error = "ERROR: Missing value for '[#{operation}][#{context}][#{k}]' flags in project configuration."
        @streaminator.stderr_puts(error, Verbosity::ERRORS)
        raise
      end
    end

    return get_flag(flags, file_name)
  end

end

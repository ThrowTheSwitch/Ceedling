require 'hardmock/utils'

module Hardmock
  class Expectation
    include Utils
    attr_reader :block_value

    def initialize(options) #:nodoc:
      @options = options
    end

    def apply_method_call(mock,mname,args,block) #:nodoc:
      unless @options[:mock].equal?(mock)
        raise anger("Wrong object", mock,mname,args)
      end
      unless @options[:method] == mname
        raise anger("Wrong method",mock,mname,args)
      end

      # Tester-defined block to invoke at method-call-time:
      expectation_block = @options[:block]

      expected_args = @options[:arguments]
      # if we have a block, we can skip the argument check if none were specified
      unless (expected_args.nil? || expected_args.empty?) && expectation_block && !@options[:suppress_arguments_to_block]
        unless expected_args == args
          raise anger("Wrong arguments",mock,mname,args)
        end
      end

      relayed_args = args.dup
      if block
        if expectation_block.nil?
          # Can't handle a runtime block without an expectation block
          raise ExpectationError.new("Unexpected block provided to #{to_s}")
        else
          # Runtime blocks are passed as final argument to the expectation block
          unless @options[:suppress_arguments_to_block]
            relayed_args << block
          else
            # Arguments suppressed; send only the block
            relayed_args = [block]
          end
        end
      end

      # Run the expectation block:
      @block_value = expectation_block.call(*relayed_args) if expectation_block

      raise @options[:raises] unless @options[:raises].nil?
			
			return_value = @options[:returns]
			if return_value.nil?
				return @block_value
			else
				return return_value
			end
    end

    # Set the return value for an expected method call.
    # Eg,
    #   @cash_machine.expects.withdraw(20,:dollars).returns(20.00)
    def returns(val)
      @options[:returns] = val
      self
    end
    alias_method :and_return, :returns
    
    # Set the arguments for an expected method call.
    # Eg,
    #   @cash_machine.expects.deposit.with(20, "dollars").returns(:balance => "20")
    def with(*args)
      @options[:arguments] = args
      self      
    end
    
    # Rig an expected method to raise an exception when the mock is invoked.
    #
    # Eg,
    #   @cash_machine.expects.withdraw(20,:dollars).raises "Insufficient funds"
    #
    # The argument can be:
    # * an Exception -- will be used directly
    # * a String -- will be used as the message for a RuntimeError
    # * nothing -- RuntimeError.new("An Error") will be raised
    def raises(err=nil)
      case err
      when Exception
        @options[:raises] = err
      when String
        @options[:raises] = RuntimeError.new(err)
      else
        @options[:raises] = RuntimeError.new("An Error")
      end
      self
    end

    # Convenience method: assumes +block_value+ is set, and is set to a Proc
    # (or anything that responds to 'call')
    #
    #   light_event = @traffic_light.trap.subscribe(:light_changes)
    #
    #   # This code will meet the expectation:
    #   @traffic_light.subscribe :light_changes do |color|
    #     puts color
    #   end
    #
    # The color-handling block is now stored in <tt>light_event.block_value</tt>
    #
    # The block can be invoked like this:
    #
    #   light_event.trigger :red
    # 
    # See Mock#trap and Mock#expects for information on using expectation objects 
    # after they are set.
    #
    def trigger(*block_arguments)
      unless block_value
        raise ExpectationError.new("No block value is currently set for expectation #{to_s}")
      end
      unless block_value.respond_to?(:call)
        raise ExpectationError.new("Can't apply trigger to #{block_value} for expectation #{to_s}")
      end
      block_value.call *block_arguments
    end

    # Used when an expected method accepts a block at runtime.  
    # When the expected method is invoked, the block passed to
    # that method will be invoked as well.
    #
    # NOTE: ExpectationError will be thrown upon running the expected method
    # if the arguments you set up in +yields+ do not properly match up with
    # the actual block that ends up getting passed.
    # 
    # == Examples
    # <b>Single invocation</b>: The block passed to +lock_down+ gets invoked
    # once with no arguments:
    #
    #   @safe_zone.expects.lock_down.yields
    #
    #   # (works on code that looks like:)
    #   @safe_zone.lock_down do 
    #     # ... this block invoked once
    #   end
    # 
    # <b>Multi-parameter blocks:</b> The block passed to +each_item+ gets
    # invoked twice, with <tt>:item1</tt> the first time, and with
    # <tt>:item2</tt> the second time:
    # 
    #   @fruit_basket.expects.each_with_index.yields [:apple,1], [:orange,2]
    #
    #   # (works on code that looks like:)
    #   @fruit_basket.each_with_index do |fruit,index|
    #     # ... this block invoked with fruit=:apple, index=1, 
    #     # ... and then with fruit=:orange, index=2
    #   end
    #
    # <b>Arrays can be passed as arguments too</b>... if the block 
    # takes a single argument and you want to pass a series of arrays into it,
    # that will work as well:
    #
    #   @list_provider.expects.each_list.yields [1,2,3], [4,5,6]
    #
    #   # (works on code that looks like:)
    #   @list_provider.each_list do |list|
    #     # ... list is [1,2,3] the first time
    #     # ... list is [4,5,6] the second time
    #   end
    #
    # <b>Return value</b>: You can set the return value for the method that
    # accepts the block like so: 
    #
    #   @cruncher.expects.do_things.yields(:bean1,:bean2).returns("The Results")
    #
    # <b>Raising errors</b>: You can set the raised exception for the method that
    # accepts the block. NOTE: the error will be raised _after_ the block has
    # been invoked.
    #
    #   # :bean1 and :bean2 will be passed to the block, then an error is raised:
    #   @cruncher.expects.do_things.yields(:bean1,:bean2).raises("Too crunchy")
    #
    def yields(*items)
      @options[:suppress_arguments_to_block] = true
      if items.empty?
        # Yield once
        @options[:block] = lambda do |block|
          if block.arity != 0 and block.arity != -1
            raise ExpectationError.new("The given block was expected to have no parameter count; instead, got #{block.arity} to <#{to_s}>")
          end
          block.call
        end
      else
        # Yield one or more specific items
        @options[:block] = lambda do |block|
          items.each do |item|
            if item.kind_of?(Array) 
              if block.arity == item.size
                # Unfold the array into the block's arguments:
                block.call *item
              elsif block.arity == 1
                # Just pass the array in
                block.call item
              else
                # Size mismatch
                raise ExpectationError.new("Can't pass #{item.inspect} to block with arity #{block.arity} to <#{to_s}>")
              end
            else
              if block.arity != 1
                # Size mismatch
                raise ExpectationError.new("Can't pass #{item.inspect} to block with arity #{block.arity} to <#{to_s}>")
              end
              block.call item
            end
          end
        end
      end
      self
    end

    def to_s # :nodoc:
      format_method_call_string(@options[:mock],@options[:method],@options[:arguments])
    end

    private 
    def anger(msg, mock,mname,args)
      ExpectationError.new("#{msg}: expected call <#{to_s}> but was <#{format_method_call_string(mock,mname,args)}>")
    end
  end
end


module Hardmock
  # Mock is used to set expectations in your test.  Most of the time you'll use
  # <tt>#expects</tt> to create expectations.
  #
  # Aside from the scant few control methods (like +expects+, +trap+ and +_verify+) 
  # all calls made on a Mock instance will be immediately applied to the internal
  # expectation mechanism.
  #
  # * If the method call was expected and all the parameters match properly, execution continues
  # * If the expectation was configured with an expectation block, the block is invoked
  # * If the expectation was set up to raise an error, the error is raised now
  # * If the expectation was set up to return a value, it is returned
  # * If the method call was _not_ expected, or the parameter values are wrong, an ExpectationError is raised.
  class Mock
    include Hardmock::MethodCleanout

    # Create a new Mock instance with a name and a MockControl to support it.
    # If not given, a MockControl is made implicitly for this Mock alone; this means
    # expectations for this mock are not tied to other expectations in your test.
    #
    # It's not recommended to use a Mock directly; see Hardmock and
    # Hardmock#create_mocks for the more wholistic approach.
    def initialize(name, mock_control=nil)
      @name = name
      @control = mock_control || MockControl.new
      @expectation_builder = ExpectationBuilder.new
    end

    def inspect
      "<Mock #{@name}>"
    end

    # Begin declaring an expectation for this Mock.
    #
    # == Simple Examples
    # Expect the +customer+ to be queried for +account+, and return <tt>"The
    # Account"</tt>: 
    #   @customer.expects.account.returns "The Account"
    #
    # Expect the +withdraw+ method to be called, and raise an exception when it
    # is (see Expectation#raises for more info):
    #   @cash_machine.expects.withdraw(20,:dollars).raises("not enough money")
    #
    # Expect +customer+ to have its +user_name+ set
    #   @customer.expects.user_name = 'Big Boss'
    #   
    # Expect +customer+ to have its +user_name+ set, and raise a RuntimeException when
    # that happens:
    #   @customer.expects('user_name=', "Big Boss").raises "lost connection"
    #
    # Expect +evaluate+ to be passed a block, and when that happens, pass a value
    # to the block (see Expectation#yields for more info):
    #   @cruncher.expects.evaluate.yields("some data").returns("some results")
    #
    #
    # == Expectation Blocks
    # To do special handling of expected method calls when they occur, you
    # may pass a block to your expectation, like:
    #   @page_scraper.expects.handle_content do |address,request,status|
    #     assert_not_nil address, "Can't abide nil addresses"
    #     assert_equal "http-get", request.method, "Can only handle GET"
    #     assert status > 200 and status < 300, status, "Failed status"
    #     "Simulated results #{request.content.downcase}"
    #   end
    # In this example, when <tt>page_scraper.handle_content</tt> is called, its
    # three arguments are passed to the <i>expectation block</i> and evaluated
    # using the above assertions.  The last value in the block will be used 
    # as the return value for +handle_content+
    #
    # You may specify arguments to the expected method call, just like any normal
    # expectation, and those arguments will be pre-validated before being passed
    # to the expectation block.  This is useful when you know all of the
    # expected values but still need to do something programmatic.
    #
    # If the method being invoked on the mock accepts a block, that block will be
    # passed to your expectation block as the last (or only) argument.  Eg, the 
    # convenience method +yields+ can be replaced with the more explicit:
    #   @cruncher.expects.evaluate do |block|
    #     block.call "some data"
    #     "some results"
    #   end
    #
    # The result value of the expectation block becomes the return value for the
    # expected method call. This can be overidden by using the +returns+ method:
    #   @cruncher.expects.evaluate do |block|
    #     block.call "some data"
    #     "some results"
    #   end.returns("the actual value")
    # 
    # <b>Additionally</b>, the resulting value of the expectation block is stored
    # in the +block_value+ field on the expectation.  If you've saved a reference 
    # to your expectation, you may retrieve the block value once the expectation
    # has been met.
    #
    #   evaluation_event = @cruncher.expects.evaluate do |block|
    #     block.call "some data"
    #     "some results"
    #   end.returns("the actual value")
    #
    #   result = @cruncher.evaluate do |input|
    #     puts input  # => 'some data'
    #   end
    #   # result is 'the actual value'
    #   
    #   evaluation_event.block_value # => 'some results'
    #
    def expects(*args, &block)
      expector = Expector.new(self,@control,@expectation_builder)
      # If there are no args, we return the Expector
      return expector if args.empty?
      # If there ARE args, we set up the expectation right here and return it
      expector.send(args.shift.to_sym, *args, &block)
    end
    alias_method :expect, :expects
    alias_method :should_receive, :expects

    # Special-case convenience: #trap sets up an expectation for a method
    # that will take a block.  That block, when sent to the expected method, will
    # be trapped and stored in the expectation's +block_value+ field.
    # The Expectation#trigger method may then be used to invoke that block.
    #
    # Like +expects+, the +trap+ mechanism can be followed by +raises+ or +returns+.
    #
    # _Unlike_ +expects+, you may not use an expectation block with +trap+.  If 
    # the expected method takes arguments in addition to the block, they must
    # be specified in the arguments to the +trap+ call itself.
    #
    # == Example
    # 
    #   create_mocks :address_book, :editor_form
    #
    #   # Expect a subscription on the :person_added event for @address_book:
    #   person_event = @address_book.trap.subscribe(:person_added)
    #
    #   # The runtime code would look like:
    #   @address_book.subscribe :person_added do |person_name|
    #     @editor_form.name = person_name
    #   end
    #
    #   # At this point, the expectation for 'subscribe' is met and the 
    #   # block has been captured.  But we're not done:
    #   @editor_form.expects.name = "David"
    #
    #   # Now invoke the block we trapped earlier:
    #    person_event.trigger "David"
    #
    #   verify_mocks
    def trap(*args)
      Trapper.new(self,@control,ExpectationBuilder.new)
    end

    def method_missing(mname,*args) #:nodoc:
      block = nil
      block = Proc.new if block_given?
      @control.apply_method_call(self,mname,args,block)
    end


    def _control #:nodoc:
      @control
    end

    def _name #:nodoc:
      @name
    end

    # Verify that all expectations are fulfilled.  NOTE: this method triggers
    # validation on the _control_ for this mock, so all Mocks that share the
    # MockControl with this instance will be included in the verification.
    #
    # <b>Only use this method if you are managing your own Mocks and their controls.</b>
    #
    # Normal usage of Hardmock doesn't require you to call this; let
    # Hardmock#verify_mocks do it for you.
    def _verify
      @control.verify
    end
  end
end



# Stubbing support
#
# Stubs methods on classes and instances
#

# Why's "metaid.rb" stuff crunched down:
class Object #:nodoc:#
	def hm_metaclass #:nodoc:#
    class << self
      self
    end
  end
	
	def hm_meta_eval(&blk) #:nodoc:#
    hm_metaclass.instance_eval(&blk)
  end

	def hm_meta_def(name, &blk) #:nodoc:#
		hm_meta_eval { define_method name, &blk }
	end
end



module Hardmock

  # == Hardmock: Stubbing and Mocking Concrete Methods
  #
  # Hardmock lets you stub and/or mock methods on concrete classes or objects.
  #
  # * To "stub" a concrete method is to rig it to return the same thing always, disregarding any arguments.
  # * To "mock" a concrete method is to surplant its funcionality by delegating to a mock object who will cover this behavior.
  #
  # Mocked methods have their expectations considered along with all other mock object expectations.
  #
  # If you use stubbing or concrete mocking in the absence (or before creation) of other mocks, you need to invoke <tt>prepare_hardmock_control</tt>.
  # Once <tt>verify_mocks</tt> or <tt>clear_expectaions</tt> is called, the overriden behavior in the target objects is restored.
  #
  # == Examples
  #
  #   River.stubs!(:sounds_like).returns("gurgle")
  #
  #   River.expects!(:jump).returns("splash")
  #
  #   rogue.stubs!(:sounds_like).returns("pshshsh")
  #
  #   rogue.expects!(:rawhide_tanning_solvents).returns("giant snapping turtles")
  #
  module Stubbing
    # Exists only for documentation 
  end

  class ReplacedMethod #:nodoc:#
    attr_reader :target, :method_name

    def initialize(target, method_name)
      @target = target
      @method_name = method_name

      Hardmock.track_replaced_method self
    end
  end

  class StubbedMethod < ReplacedMethod #:nodoc:#
    def invoke(args)
      raise @raises if @raises
      @return_value
    end

    def returns(stubbed_return)
      @return_value = stubbed_return
    end

    def raises(err)
      err = RuntimeError.new(err) unless err.kind_of?(Exception)
      @raises = err
    end
  end

  class ::Object
    def stubs!(method_name)
      method_name = method_name.to_s
      already_stubbed = Hardmock.has_replaced_method?(self, method_name)

      stubbed_method = Hardmock::StubbedMethod.new(self, method_name)


      unless _is_mock? or already_stubbed
        if methods.include?(method_name.to_s)
          hm_meta_eval do 
            alias_method "_hardmock_original_#{method_name}".to_sym, method_name.to_sym
          end
        end
      end

      hm_meta_def method_name do |*args|
        stubbed_method.invoke(args)
      end

      stubbed_method
    end

    def expects!(method_name, *args, &block)
      if self._is_mock?
        raise Hardmock::StubbingError, "Cannot use 'expects!(:#{method_name})' on a Mock object; try 'expects' instead"
      end

      method_name = method_name.to_s

      @_my_mock = Mock.new(_my_name, $main_mock_control) if @_my_mock.nil?

      unless Hardmock.has_replaced_method?(self, method_name)
        # Track the method as replaced
        Hardmock::ReplacedMethod.new(self, method_name)

        # Preserver original implementation of the method by aliasing it away
        if methods.include?(method_name)
          hm_meta_eval do 
            alias_method "_hardmock_original_#{method_name}".to_sym, method_name.to_sym
          end
        end

        # Re-define the method to utilize our patron mock instance.
        # (This global-temp-var thing is hokey but I was having difficulty generating 
        # code for the meta class.)
        begin
          $method_text_temp = %{
            def #{method_name}(*args,&block)
              @_my_mock.__send__(:#{method_name}, *args, &block)
            end
          }
          class << self
            eval $method_text_temp
          end
        ensure
          $method_text_temp = nil
        end
      end

      return @_my_mock.expects(method_name, *args, &block)
    end
      
    def _is_mock?
      self.kind_of?(Mock)
    end

    def _my_name
      self.kind_of?(Class) ? self.name : self.class.name
    end

    def _clear_mock
      @_my_mock = nil
    end

  end

  class ::NilClass
    # Use this only if you really mean it
    alias_method :intentionally_stubs!, :stubs!
    
    # Use this only if you really mean it
    alias_method :intentionally_expects!, :expects!

    # Overridden to protect against accidental nil reference self delusion 
    def stubs!(mname)
      raise StubbingError, "Cannot stub #{mname} method on nil.  (If you really mean to, try 'intentionally_stubs!')"
    end

    # Overridden to protect against accidental nil reference self delusion 
    def expects!(mname, *args)
      raise StubbingError, "Cannot mock #{mname} method on nil.  (If you really mean to, try 'intentionally_expects!')"
    end
  end

  class << self
    def track_replaced_method(replaced_method)
      all_replaced_methods << replaced_method
    end

    def all_replaced_methods
      $all_replaced_methods ||= []
    end

    def has_replaced_method?(obj, method_name)
      hits = all_replaced_methods.select do |replaced|
        (replaced.target.object_id == obj.object_id) and (replaced.method_name.to_s == method_name.to_s)
      end
      return !hits.empty?
    end

    def restore_all_replaced_methods
      all_replaced_methods.each do |replaced|
        unless replaced.target._is_mock?
          backed_up = "_hardmock_original_#{replaced.method_name}"
          if replaced.target.methods.include?(backed_up)
            replaced.target.hm_meta_eval do
              alias_method replaced.method_name.to_sym, backed_up.to_sym 
            end
          end
          replaced.target._clear_mock
        end
      end
      all_replaced_methods.clear
    end
  end

end


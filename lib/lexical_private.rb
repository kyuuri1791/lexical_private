# frozen_string_literal: true

require_relative "lexical_private/version"

# Provides lexical-scope visibility control for module methods.
# When a module extends LexicalPrivate and calls +lexical_private+,
# all subsequently defined methods become lexically private: they can
# only be called from other methods defined in the same module.
module LexicalPrivate
  class Error < StandardError; end

  def lexical_private
    mod = self
    lp_key = :"_lexical_private_#{object_id}"

    # Step 1: Wrap already-defined methods as "trusted" so they can call LP methods.
    # Must run before setting up the hook to avoid triggering it.
    instance_methods(false).each do |method_name|
      mod.__send__(:_lp_wrap_as_trusted, method_name, lp_key)
    end

    # Step 2: Hook method_added so all subsequent method definitions become LP.
    singleton_class.prepend(
      Module.new do
        define_method(:method_added) do |method_name|
          return if @_lp_wrapping

          @_lp_wrapping = true
          begin
            super(method_name)
            mod.__send__(:_lp_wrap_as_private, method_name, lp_key)
          ensure
            @_lp_wrapping = false
          end
        end
      end
    )
  end

  private

  def _lp_wrap_as_trusted(method_name, lp_key)
    original = instance_method(method_name)
    define_method(method_name) do |*args, &block|
      prev = Fiber[lp_key] || 0
      Fiber[lp_key] = prev + 1
      begin
        original.bind_call(self, *args, &block)
      ensure
        Fiber[lp_key] = prev
      end
    end
  end

  def _lp_wrap_as_private(method_name, lp_key)
    original = instance_method(method_name)
    define_method(method_name) do |*args, &block|
      unless (Fiber[lp_key] || 0).positive?
        raise NoMethodError,
              "private method '#{method_name}' called for an instance of #{self.class}"
      end

      prev = Fiber[lp_key]
      Fiber[lp_key] = prev + 1
      begin
        original.bind_call(self, *args, &block)
      ensure
        Fiber[lp_key] = prev
      end
    end
  end
end

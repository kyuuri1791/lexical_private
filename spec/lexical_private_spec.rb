# frozen_string_literal: true

RSpec.describe LexicalPrivate do
  it "has a version number" do
    expect(LexicalPrivate::VERSION).not_to be nil
  end

  describe "lexical_private" do
    before do
      stub_const("M", Module.new do
        extend LexicalPrivate

        def public_method
          private_method
        end

        lexical_private

        def private_method
          "secret"
        end
      end)

      stub_const("C", Class.new { include M })
    end

    it "allows calling the LP method from within the module's public method" do
      expect(C.new.public_method).to eq("secret")
    end

    it "raises NoMethodError when the LP method is called directly from outside" do
      expect { C.new.private_method }.to raise_error(NoMethodError, /private method 'private_method'/)
    end

    it "raises NoMethodError when the LP method is called from a method defined in the including class" do
      c_class = Class.new do
        include M

        def external_call
          private_method
        end
      end
      expect { c_class.new.external_call }.to raise_error(NoMethodError, /private method 'private_method'/)
    end
  end

  describe "LP method calling another LP method" do
    before do
      stub_const("M2", Module.new do
        extend LexicalPrivate

        def public_method
          first_private
        end

        lexical_private

        def first_private
          second_private
        end

        def second_private
          "deep secret"
        end
      end)

      stub_const("C2", Class.new { include M2 })
    end

    it "allows an LP method to call another LP method" do
      expect(C2.new.public_method).to eq("deep secret")
    end

    it "raises NoMethodError when the second LP method is called directly" do
      expect { C2.new.second_private }.to raise_error(NoMethodError)
    end
  end

  describe "independent modules do not interfere with each other" do
    before do
      stub_const("MA", Module.new do
        extend LexicalPrivate

        def public_a
          private_a
        end

        lexical_private

        def private_a
          "a"
        end
      end)

      stub_const("MB", Module.new do
        extend LexicalPrivate

        def public_b
          private_b
        end

        lexical_private

        def private_b
          "b"
        end
      end)

      stub_const("CA", Class.new { include MA })
      stub_const("CB", Class.new { include MB })
    end

    it "does not allow MA's trusted context to access MB's LP methods" do
      mixed = Class.new do
        include MA
        include MB

        def cross_call
          public_a   # enters MA context
          private_b  # MB's LP method — should NOT be accessible
        end
      end
      expect { mixed.new.cross_call }.to raise_error(NoMethodError, /private method 'private_b'/)
    end

    it "allows each module's own public methods to call their LP methods independently" do
      expect(CA.new.public_a).to eq("a")
      expect(CB.new.public_b).to eq("b")
    end
  end
end

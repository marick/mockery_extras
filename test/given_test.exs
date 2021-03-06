defmodule GivenTest do
  use ExUnit.Case
  import Mockery.Macro
  use MockeryExtras.Given
  alias MockeryExtras.Stubbery
  import FlowAssertions.AssertionA, only: [assertion_fails: 2]

  def function_under_test_uses_date(count) do
    {:ok, mockable(Date).add(~D[2001-02-03], count)}
  end

  describe "matching" do
    test "matching constants" do
      # Manifest constants
      given Date.add(~D[2001-02-03], 3), return: "return for 3"
      
      # Calculations and variables
      date = ~D[2001-02-03]
      given(Date.add(date, 1+3), return: "return for 4")
      
      assert function_under_test_uses_date(3) == {:ok, "return for 3"}
      assert function_under_test_uses_date(4) == {:ok, "return for 4"}
    end

    test "an exact argument match replaces the previous value" do
      given Date.add(~D[2001-02-03], 3), return: "replaced"
      given Date.add(~D[2001-02-03], 3), return: "used"
      
      assert function_under_test_uses_date(3) == {:ok, "used"}
    end

    test "a completely missed function falls through" do
      # because no mock is set up
      assert {:ok, ~D[2001-02-08]} = function_under_test_uses_date(5)
    end

    test "a call without a matching arglist produces an error" do
      given Date.add(~D[2001-02-03], 3), return: "not used"

      assertion_fails("You did not set up a stub for Date.add(~D[2001-02-03], 5)",
        fn -> 
          function_under_test_uses_date(5)
        end)
    end
    
    test "matching with don't cares" do
      given Date.add(~D[2001-02-03], @any), return: "return value"
      
      assert function_under_test_uses_date(3) == {:ok, "return value"}
    end

    test "earliest match is selected" do
      given Date.add(~D[2001-02-03], @any), return: "return value"
      given Date.add(~D[2001-02-03], :specific), return: "impossible"

      assert function_under_test_uses_date(:specific) == {:ok, "return value"}
    end
    
    test "... so an @any can be used as a fallback" do
      given Date.add(~D[2001-02-03], :specific), return: "specific"
      given Date.add(~D[2001-02-03], @any), return: "return value"

      assert function_under_test_uses_date(:specific) == {:ok, "specific"}
      assert function_under_test_uses_date(:other) == {:ok, "return value"}
    end

    def calls_with_default(map, key, default),
      do: mockable(Map).get(map, key, default)
    def calls_without_default(map, key), 
      do: mockable(Map).get(map, key)

    test "the `given` arglist determines the arity" do
      given Map.get(%{}, :key, :default), return: 3
      given Map.get(%{}, :key, @any),     return: "3 default"
      given Map.get(%{}, :key),           return: 2

      assert calls_with_default(%{}, :key, :default) == 3
      assert calls_with_default(%{}, :key, :other) == "3 default"

      assert calls_without_default(%{}, :key) == 2
    end
  end

  def streamer(map, key), do: mockable(Map).get(map, key)

  test "streaming" do 
    given Map.get(@any, @any), stream: [3, 4]
      
    assert streamer(%{}, :key) == 3
    assert streamer(%{}, :key) == 4

    assertion_fails("There are no more stubbed values for Map.get(%{}, :key)",
      fn -> 
        streamer(%{}, :key)          
      end)
  end

  test "user errors" do
    # These have to be tested manually, because they happen at compile time.

    # There must be a single keyword, either `return:` or `stream:`
    # given Map.get(@any, @any), return: 5, stream: 6

    # There must be a single keyword, either `return:` or `stream:`
    # given Map.get(@any, @any), retur: 5

    # It doesn't make sense to use a module-less function call.
    # given streamer(%{}, 5), return: 333333333
  end
    
  describe "varieties of module descriptions" do 

    def function_under_test_uses_string_dot_chars(arg) do
      {:ok, mockable(String.Chars).to_string(arg)}
    end
    
    alias String.Chars
    def function_under_test_uses_chars(arg) do
      {:ok, mockable(Chars).to_string(arg)}
    end
    
    test "given with a compound non-aliased module" do
      given String.Chars.to_string(3), return: "return for 3 S.C"
      
      assert function_under_test_uses_string_dot_chars(3) == {:ok, "return for 3 S.C"}
    end
    
    test "given with an aliased module" do
      given Chars.to_string(3), return: "return for 3 C"
      
      assert function_under_test_uses_string_dot_chars(3) == {:ok, "return for 3 C"}
    end
    
    test "aliased and unaliased versions resolve to the same module" do
      given String.Chars.to_string(3), return: "return for 3 S.C"
      assert function_under_test_uses_chars(3) == {:ok, "return for 3 S.C"}
      assert function_under_test_uses_string_dot_chars(3) == {:ok, "return for 3 S.C"}
    end
    
  end

  describe "util" do 
    test "matchers" do
      assert Stubbery.make_matcher([1, 2]).([1, 2   ])
      refute Stubbery.make_matcher([1, 2]).([1, 2222])
      assert Stubbery.make_matcher([1, 1+1]).([1, 2])
      assert Stubbery.make_matcher([1, @any]).([1, 3333])
    end

    @key Stubbery.process_dictionary_key(Module, [fun: 3])
    @fun [fun: 3]

    test "a `:return` stub always returns the same value" do
      Stubbery.add_stub(@key, @fun, :return, "retval")
      assert Stubbery.stubbed_value!(@key, @fun) == "retval"
      assert Stubbery.stubbed_value!(@key, @fun) == "retval"
    end

    test "a `:stream` stub returns the head and side-effecs the tail " do
      Stubbery.add_stub(@key, @fun, :stream, [1, 2])
      assert Stubbery.stubbed_value!(@key, @fun) == 1
      assert [{@fun, :stream, [2], _}] = Process.get(@key)
      assert Stubbery.stubbed_value!(@key, @fun) == 2
    end
    
  end    
end

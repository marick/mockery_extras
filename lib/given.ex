defmodule MockeryExtras.Given do
  import Mockery
  alias MockeryExtras.MacroX
  alias MockeryExtras.Stubbery

  @moduledoc """
  This module provides a pretty notation for a common case that's not
  gracefully handled by [Mockery](https://hexdocs.pm/mockery/readme.html). 
  Here is how you instruct Mockery to return the value `"5"` when
  `Map.get/3` is called with `%{}` and `:key`:

      use MockeryExtras.Given
      given Map.get(%{}, :key), return: "5"

  Note that the first argument to `given` looks like an ordinary function call.

  It is also common to have a "don't care" argument, like this:

      given Map.get(@any, :key), return: "5"

  See `given/2` for more.
  """
  
  @doc """
  Takes what looks like a function call, plus a return value, and arranges that
  such a function call will return the given value whenever it's made at a
  ["seam"](https://www.informit.com/articles/article.aspx?p=359417&seqNum=2)
  marked with [`Mockery.mockable`](https://hexdocs.pm/mockery/Mockery.Macro.html#mockable/2). 

      # Code:
      ... mockable(Schema).changeset(struct, params) ...

      # Test: 
      given Schema.changeset(%Schema{}, %{age: "3"}), return: %Changeset{...}

  The function's arguments and return value can be constants, as shown
  above, or they can be calculations or variables. That can be helpful
  when the `given` appears in a test helper:

      def helper(params, cast_value, something_else) do 
        ...
        given Schema.changeset(%Schema{}, params), return: cast_value
        ...
        assert ...
      end

  A function argument can be the special value `@any` (defined when
  the module is `used`). That's useful when the argument is irrelevant
  and you don't want to have to type it out:

        given Schema.changeset(@any, params), return: cast_value

  `@any` expands to a function whose value is always `true`. More generally,
  any function used as an argument is not matched with equality. Instead, the
  call-time value is passed to the function, which should return a truthy value
  to indicate a match. So you can do this:

        given Module.f(5, &even/1), return: 8

  Notes:
  * You can provide return values for many arglist values. 
    
        given Module.f(5, &even/1), return: 8
        given Module.f(6, @any),    return: 9

  * If there's more than one match, the first is used.

  * If the same arglist is given twice, the second replaces the first.
    That lets you use ExUnit `setup` to establish defaults:

        def setup do  
          given RunningExample.params(:a_runnable), return: %{}
          ...

        test "..."
          given RunningExample.params(:a_runnable), return: %{"a" => "1"}
          assert Steps.runnable(:a_runnable) == %{a: 1}
        end

  * If a function has a `given` value for one or more arglists, but none
    matched, an error is raised.
  """
  
  defmacro given(funcall, return: value) do
    given_(funcall, value)
  end

  defmacro given(funcall, do: value) do
    IO.puts "Prefer `given ..., return: ...` to `given ..., do: ...`"
    given_(funcall, value)
  end

  defp given_(funcall, value) do
    {_, the_alias, name_and_arity, arglist_spec} = 
      MacroX.decompose_call_alt(funcall)

    expand(the_alias, name_and_arity, arglist_spec, value)
  end
    

  @doc """
  The guts of `given/2` for use in your own macros.

  This function is convenient when you want to create a number of stubs at
  once. For example, suppose the `RunningExample` module has several single-argument
  getters. A `stub` macro can be more compact than several `givens`:

      stub(
        original_params: input,
        format:          :phoenix,
        neighborhood:    %{een(b: Module) => %{id: 383}})
      
  `stub` can be written like this:

      defmacro stub(kws) do
        for {key, val} <- kws do
          Given.expand(RunningExample, [{key, 1}], [:running], val)
        end
      end

  When calling `expand(module_alias, name_and_arity, arglist_spec,
  return_value)`, know that:

  * `module_alias` can be a simple atom, like `RunningExample`,
    which is an alias for `EctoTestDSL.Run.RunningExample`. More generally, it
    can be the `:__aliases__` value from `Macro.decompose_call/1`. 

  * `name_and_arity` is a function name and arity pair of the form `[get: 3]`.

  * `arglist_spec` is a list of values like `[5, @any]`.
  * `return_value` is any value.
  """
  def expand(module_alias, name_and_arity, arglist_spec, return_value) do
    quote do
      module = MockeryExtras.MacroX.alias_to_module(unquote(module_alias), __ENV__)
      process_key = Stubbery.process_dictionary_key(module, unquote(name_and_arity))
      Stubbery.add_stub(process_key, unquote(arglist_spec), unquote(return_value))
      
      return_calculator = Stubbery.make__return_calculator(process_key, unquote(name_and_arity))
      mock(module, unquote(name_and_arity), return_calculator)
    end
  end

  @doc """
  This shows (as with `IO.inspect`) all the existing stubs.

  The format is not pretty.

      [
        {{Given, Date, [add: 2]},
         [
           {[~D[2001-02-03], 3], "return for 3",
            #Function<9.8563522/1 in MockeryExtras.Stubbery.make_matcher/1>}
         ]}
      ]

  """
  def inspect do
    Process.get
    |> Enum.filter(&Stubbery.given?/1)
    |> IO.inspect
  end

  defmacro __using__(_) do
    quote do
      import MockeryExtras.Given, only: [given: 2]

      @any &Stubbery.any/1
    end
  end
end

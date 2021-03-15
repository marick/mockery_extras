defmodule MockeryExtras.Getters do
  alias MockeryExtras.Defx
  
  @moduledoc """
  Utilities for defining `mockable` functions that get map/struct/keyword values up to
  three levels of nesting. 


  Even though complex nested structures aren't necessarily the best
  thing for your code, they sometimes exist: 

      all = %{
        top1: 1,
        top2: 1.2,
        down: %{
          lower: 2,
          down: %{
            lowest: 3
          }
        }
      }

  You're stuck with them, at least for now. You'd often prefer not to
  spread knowledge of the exact structure through the code, because that would
  make a lot of code fragile in the face of change. 

  So you can hide the structure behind "getters" that (alone) know how
  to reach into the structure and retrieve a value. They present a
  "flattened" API.

  ## Defining getters

  Those functions are simple to write, so you might
  as well use a macro to do that for you:

      getters([:top1, :top2])
      # defines top1/1, top2/1, so that:
      # top1(all) => 1
      # top2(all) => 2

      # Three levels of nesting are allowed.
      getters(:down, :down, [:lowest])
      # lowest(all) => 3

  See `getters/1` for details such as how to specify default values
  (akin to those of `Map.get/3` or `Keyword.get/3`).

  ## Mocking/stubbing support

  If you go to the trouble of creating a flattened API to protect client code
  from structure, you probably want to do the same thing for tests. That is,
  you don't want tests to create an actual nested structure. Instead you want to
  stub out the getter functions.

  To explain, I'll use this (simplified) version of a structure of mine:

      defmodule EctoTestDSL.Run.RunningExample do
        @enforce_keys [:example, :history]
        defstruct [:example, :history, ...]
    
        getters :example, [
          :name, :schema_module, :usually_ignore
          checks: %{}
          neighborhood: %{}
          ...
        ]
        ...

  Those getters are already set up for stubbing, so
  `MockeryExtras.Given.given/2` can be used in tests:

      test "expected values" do 
        given RunningExample.checks(:running), return: %{name: "Bossie"}
                                    ^^^^^^^^
        actual = Steps.check_new_fields(:running, :changeset_from_params)
                                        ^^^^^^^^                            
        ...


  Notice that I use the atom `:running` instead of a composite
  structure.


  ## Conveniences for you to copy and tweak

  The `given` notation is still more cumbersome than I like, so I'll
  typically create some structure-specific stubs that do more of the
  work. My tests for functions that work with `RunningExamples` use a macro
  called `stub`:

      setup do
        stub(name: :example, neighborhood: %{}, usually_ignore: [])
        :ok
      end

      test "..." do 
        stub(checks: %{name: "Bossie"}, ...)
        ...
      end

   You can find the definition of `stub` in
   [examples/running_stubs.ex](../examples/running_stubs.ex).

   A problem with wrapping a nested structure in an API with getters
   is that you lose Elixir's concise `.` notation. You'll have to type
   something like `RunningExample.checks(running)` instead of
   `running.checks`.

   For that reason, I'll typically use a shorthand notation in
   the beginning of functions like `Steps.check_new_fields`:

       def check_new_fields(running, which_step) do
         from(running, use: [:neighborhood, :name, :field_checks,
                             :fields_from, :usually_ignore])
   
   That is the same as:

       def check_new_fields(running, which_step) do
         neighborhood = RunningExample.neighborhood(:running)
         name = RunningExample.name(:running)
         field_checks = RunningExample.field_checks(:running)

  See [examples/from.ex](../examples/from.ex) for the definition of
  `from` and the related `from_history` (not explained here).
  """

  # ---------GETTERS----------------------------------------------------------
  @doc """
  When defined like the above, a `KeyError` will be raised if any key
  is missing.

  Default values can be given:
    
      getters(:down, [lower: "some default"])
      # lower(%{down: %{}}) => "some default"


  Only the last step in the path may be missing. Applying `lower` to `%{}`
  would result in a key error.

  A variant, `private_getters`, will define the getters with `defp` instead
  of `def`.
  The generated functions will work with any combination of maps, structures, or
  keywords. So, for example, the following works:

      getters :history, [:params, :changeset]
    
      # changeset(%{history: [changeset: "..."]}) => "..."

  """

  defmacro getters(names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [name])
  end

  defmacro getters(top_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [top_level, name])
  end

  defmacro getters(top_level, next_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [top_level, next_level, name])
  end

  # ---------RENAMING GETTERS----------------------------------------------------

  defmacro getter(name, opts) do
    Defx.defx(:def, name, create_path(opts))
  end

  defp create_path(opts) do
    default? = Keyword.has_key?(opts, :default)
    default = Keyword.get(opts, :default)
    case Keyword.get(opts, :for) do
      list when is_list(list) ->
        defx_path(list, default?, default)
      atom when is_atom(atom) ->
        defx_path([atom], default?, default)
    end
  end

  defp defx_path(path_components, false, _) do
    path_components
  end

  defp defx_path(path_components, true, default) do
    {front, [last]} = Enum.split(path_components, -1)
    front ++ [{last, default}]
  end

  # ---------PRIVATE_GETTERS----------------------------------------------------------
  
  defmacro private_getters(names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [name])
  end

  defmacro private_getters(top_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [top_level, name])
  end

  defmacro private_getters(top_level, next_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [top_level, next_level, name])
  end

  # ----------------------------------------------------------------------------

  defmacro publicize(new_name, renames: old_name) do
    quote do
      def unquote(new_name)(maplike), do: unquote(old_name)(maplike)
    end
  end
end

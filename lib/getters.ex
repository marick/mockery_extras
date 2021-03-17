defmodule MockeryExtras.Getters do
  alias MockeryExtras.Defx
  
  @moduledoc """

  Utilities for defining functions that get map/struct/keyword values
  up to three levels of nesting. 

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
  "flattened" API to client code.

  Those functions are simple to write manually, but you might
  as well use a macro to do it for you:

      getters([:top1, :top2])
      # defines top1/1, top2/1, so that:
      # top1(all) => 1
      # top2(all) => 2

      # Three levels of nesting are allowed.
      getters(:down, :down, [:lowest])
      # lowest(all) => 3

  See `getters/1` for details, such as how to specify default values
  (akin to those of `Map.get/3` or `Keyword.get/3`).

  See [Stubbing Complex
  Structures](https://github.com/marick/mockery_extras/blob/main/stubbing_complex_structures.md)
  to see how a little bit of custom (copy and tweak) work can improve
  the testing of code that works against a flattened API, plus an
  alternative to verbose code like `MyStructure.getter(structure)`.
  """

  # ---------GETTERS----------------------------------------------------------
  @doc """
  Define N getters, possibly with defaults.

  The argument must be a list. For each atom in the list, a function effectively
  like the following is defined:

      def atom(structure), do: structure[atom]

  Note that the getter's argument can be either a `Map` or a `Keyword`. 

  Default values can be given:
    
      getters([:x, y: "some default"])
      # y(%{}) => "some default"

  If there's no default, a missing value will produce a `KeyError`.
  """

  defmacro getters(names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [name])
  end

  @doc """
  Define N getters for the second level of a nested structure.

  The first argument is an atom that's expected to index
  a `Map` or `Keyword`. The value of that index is again expected to be 
  a `Map` or `Keyword`.

  The second argument is a list with the same form as in
  `getters/1`. It provides the names for the generated functions. (The
  first argument plays no role.)

      getters(:top, [:x, y: "some default"])
      # x(%{top: [x: 1]}) => 1
      # y(%{top: [    ]}) => "some default"

  Note that the default only applies at the bottom level. The
  following will raise a `RuntimeError`:


  """
  defmacro getters(top_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [top_level, name])
  end

  @doc """
  Define N getters for the third level of a nested structure.
  """ 
  defmacro getters(top_level, next_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:def, name, [top_level, next_level, name])
  end

  # ---------RENAMING GETTERS----------------------------------------------------

  @doc """
  Define a single getter with a different name than the field it accesses.

  For example, this:

      getter :meio, for: [:root, :middle]
      # meio(root: %{middle: 3}) => 3

  A default can also be provided:

      getter :meio, for: [:root, :middle], default: "default"
      # meio(root: %{}) => "default"

  If the getter is for the top level, the `for:` value needn't be a list:

      getter :raiz, for: :root
  """ 
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

  @doc """
  The same as `getters/1` except the functions are generated using `defp`.

  Most often this is used in a module that defines a structure, its getters,
  and also more complicated functions that work on the structure. 
  """

  defmacro private_getters(names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [name])
  end

  @doc """
  The same as `getters/2` except the functions are generated using `defp`.
  """
  defmacro private_getters(top_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [top_level, name])
  end

  @doc """
  The same as `getters/3` except the functions are generated using `defp`.
  """
  defmacro private_getters(top_level, next_level, names) when is_list(names) do
    for name <- names, do: Defx.defx(:defp, name, [top_level, next_level, name])
  end
end

defmodule MockeryExtras.Getters do
  alias MockeryExtras.Defx
  
  @moduledoc """
  Utilities for defining functions that get map/struct/keyword values up to
  three levels of nesting. They're handy when you want to hide a complex
  structure behind an interface.

  Examples: 
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

      getters([:top1, :top2])
      # defines top1/1, top2/1, so that
      # 
      # top1(all) => 1
      # top2(all) => 2

      # Three levels of nesting are allowed.

      getters(:down, :down, [:lowest])
      # lowest(all) => 3

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

  # ---------GETTERS----------------------------------------------------------

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

  def defx_path(path_components, false, _) do
    path_components
  end

  def defx_path(path_components, true, default) do
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

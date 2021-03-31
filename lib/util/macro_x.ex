defmodule MockeryExtras.MacroX do

  @doc """
  A function that takes two forms of function call and returns their
  constitutent parts. The forms are syntax trees (typically given to a
  macro that uses the results of this function.)

  1. The first form is like `Module.function(1, 2, 3)`. In this case, the
     following structure is returned:

          {:in_named_module, Module, [function: 3], [1, 2, 3]}

     The module part of the function call may be multi-part, like
     `Module.Submodule`. That's what will appear in the second tuple
     position. The module may be the use of an alias, like `alias
     Module.Submodule, as: S`. In that case, the alias (`S`) will appear
     in the second position.

  2. The second form has no module component, like `function(1, 2, 3)`, which
     returns:

          {:in_calling_module, :use__MODULE__, [function: 3], [1, 2, 3]}

     This value signals that the caller must supply the module. If the caller
     is a macro, it will probably use `__MODULE__`.

  Any other form will raise `RuntimeError`.
  """

  def decompose_call_alt(funcall) do
    case Macro.decompose_call(funcall) do
      {{:__aliases__, _, aliases},  fun_atom, args} -> 
        composed_alias =
          Enum.reduce(aliases, :Elixir, fn alias, acc ->
            Module.safe_concat(acc, alias)
          end)
        function_description = [{fun_atom, length(args)}]
        
        {:in_named_module, composed_alias, function_description, args}
        
      {fun_atom, args} ->
        function_description = [{fun_atom, length(args)}]
        {:in_calling_module, :use__MODULE__, function_description, args}
        
      _ ->
        raise """
        #{Macro.to_string(funcall)} does not look like a call to a function
        attached to a module.
        """
    end
  end

  def alias_to_module(the_alias, env) do 
    Keyword.get(env.aliases, the_alias, the_alias)
  end
end

## This code is in the public domain.

defmodule Example.From do
  alias Example.RunningExample, as: ModuleWithGetters 
  ##    ^^^^^^^^^^^^^^^^^^^^^^  Change this

  ## You can probably copy this function as is.
  defmacro from(running, use: keys) do
    assert_existence(keys, 1)
    varlist = Enum.map(keys, &one_var/1)    
    calls = Enum.map(keys, &(field_access(&1, running)))
    emit(varlist, calls)
  end

  # This is for getters that take an extra argument. The first
  # argument is used to navigate along a path defined at compile time.
  # The second argument, not known at compile time, selects a field
  # within what was found at the end of the path.
  #
  #  You will have to change the getter `two_arg_access` uses (in this case,
  #  `ModuleWithGetters.step_value/2`) and doubtless the name `from_history`.
  defmacro from_history(running, kws) do
    varlist = Enum.map(kws, &one_var/1)
    calls = Enum.map(kws, &(two_arg_access &1, running))
    emit(varlist, calls)
  end

  # ----------------------------------------------------------------------------
  defp one_var({var_name, _step_name}), do: Macro.var(var_name, nil)
  defp one_var( var_name),              do: Macro.var(var_name, nil)

  defp assert_existence(names, of_arity) do
    relevant = 
      ModuleWithGetters.__info__(:functions)
      |> Enum.filter(fn {_, arity} -> arity == of_arity end)
      |> Enum.map(fn {name, _} -> name end)
      |> MapSet.new

    extras = MapSet.difference(MapSet.new(names), relevant)
    unless Enum.empty?(extras) do
      raise "Unknown getters: #{inspect Enum.into(extras, [])}"
    end
  end
  
  defp field_access(key, running) do
    quote do: mockable(ModuleWithGetters).unquote(key)(unquote(running))
  end

  defp two_arg_access({_var_name, step_name}, running),
    do: two_arg_access(step_name, running)

  defp two_arg_access(step_name, running) do
    quote do 
      mockable(ModuleWithGetters).step_value!(unquote(running), unquote(step_name))
    end
  end

  defp emit(varlist, calls) do
    quote do: {unquote_splicing(varlist)} = {unquote_splicing(calls)}
  end

  defmacro __using__(_) do
    quote do
      import Example.From
      import Mockery.Macro
    end
  end
end

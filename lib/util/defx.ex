defmodule MockeryExtras.Defx do
  @moduledoc false
  
  def module_for(%{}), do: Map
  def module_for([_car|_cdr]), do: Keyword

  def get_leaf(so_far, rest) when not is_map(so_far) and not is_list(so_far) do
    raise """
    Trying to get #{inspect rest} from inside #{inspect so_far}.
    Did you forget to make a stub?
    """
  end

  def get_leaf(so_far, [namelike]) do
    case namelike do
      {name, default} ->
        module_for(so_far).get(so_far, name, default)
      name ->
        module_for(so_far).fetch!(so_far, name)
    end
  end

  def get_leaf(so_far, [name | rest]) do
    module_for(so_far).fetch!(so_far, name) |> get_leaf(rest)
  end

  def defx(def_kind, namelike, path) do
    true_name =
      case namelike do
        {name, _} -> name
        name -> name
      end
    
    quote do
      unquote(def_kind)(unquote(true_name)(maplike),
        do: MockeryExtras.Defx.get_leaf(maplike, unquote(path)))
    end
  end
end

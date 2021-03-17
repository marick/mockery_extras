defmodule Example.Params do
  alias ExUnit.Assertions

  defmodule Phoenix do
    def format(struct) when is_struct(struct),
      do: Map.from_struct(struct) |> format
    
    def format(map) do 
      map
      |> Map.delete(:__meta__)
      |> Enum.map(fn {k,v} -> {value_to_string(k), value_to_string(v)} end)
      |> Map.new
    end
    
    defp value_to_string(value) do
      cond do
        is_list(value) ->
          Enum.map(value, &value_to_string/1)
        String.Chars.impl_for(value) ->
          to_string(value)
        is_map(value) -> 
          format(value)
        true ->
          value
      end
    end
  end
  

  def format(params, how) do
    formatters = %{
      raw: &(&1),
      phoenix: &Phoenix.format/1
    }

    case Map.get(formatters, how) do
      nil -> 
        Assertions.flunk """
        `#{inspect how}` is not a valid format for test data params.
        Try one of these: `#{inspect Map.keys(formatters)}`
        """
      formatter ->
        formatter.(params)
    end
  end
end

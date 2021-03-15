defmodule MockeryExtras do
  @moduledoc """
  
  `MockeryExtras.Given` provides a simple way to stub function calls.

      use Given
      given Map.get(%{}, :key), return: "5"
      given Map.get(@any, :key), return: "5"

  There is also support for writing your own macros.
  """

end

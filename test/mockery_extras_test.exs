defmodule MockeryExtrasTest do
  use ExUnit.Case
  doctest MockeryExtras

  test "greets the world" do
    assert MockeryExtras.hello() == :world
  end
end

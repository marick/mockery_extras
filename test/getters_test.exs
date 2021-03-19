defmodule MockeryExtrasTest do
  use ExUnit.Case
  import MockeryExtras.Getters

  defmodule Levels do
    defstruct [:top, :t1, :t2]
    
    getters [:t1, :t2]
    getters :top, [:lower]
    getters :top, :middle, [:bottom]
  end
  
  test "one-level getters" do
    assert Levels.t1(%Levels{t1: 5}) == 5
    assert Levels.t2(%Levels{t2: 50}) == 50
    assert_raise(KeyError, fn -> Levels.t1(%{}) end)
  end
  
  test "two-level getters" do
    assert Levels.lower(%Levels{top: %{lower: 5}}) == 5
  end
  
  test "three-level getters" do
    assert Levels.bottom(%Levels{top: %{middle: %{bottom: 5}}}) == 5
  end

  # ----------------------------------------------------------------------------

  defmodule Defaults do
    defstruct [:top, :t1, :t2]
    
    getters([:t1,                   t2: :default])
    getters :top,          [     lower: :default]
    getters :top, :middle, [:m, bottom: :default]
  end
    
  test "top default" do
    assert Defaults.t1(%{t1: 383}) == 383
    assert_raise(KeyError, fn -> Defaults.t1(%{}) end)
    
    assert Defaults.t2(%{t2: 383}) == 383
    assert Defaults.t2(%{}) == :default
  end
  
  test "two-level defaults" do
    assert Defaults.lower(%Defaults{top: %{lowerx: 5}}) == :default
  end
  
  test "three-level defaults" do
    assert Defaults.bottom(%Defaults{top: %{middle: %{m: 5}}}) == :default
  end

  defmodule Private do
    use ExUnit.Case
    
    defstruct [:top, :t1, :t2]
    
    private_getters [:t1, t2: 33]
    
    test "created" do
      assert t1(%{t1: 5}) == 5
      assert t2(%{t1: 5}) == 33
      assert_raise(KeyError, fn -> t1(%{}) end)
    end
  end

  test "the functions really are private" do
    refute Kernel.function_exported?(Private, :t1, 1)
  end

  # ----------------------------------------------------------------------------

  getters [:plain_map]
  test "you don't actually need a struct definition" do
    assert plain_map(%{plain_map: 5}) == 5
  end
    
  # ----------------------------------------------------------------------------

  defmodule Rename do
    defstruct [:root]
    
    getter :raiz,    for: :root
    getter :do_raiz, for: :root, default: :default

    getter :meio,    for: [:root, :middle]
    getter :do_meio, for: [:root, :middle], default: "default"

    getter :fundo,    for: [:root, :middle, :bottom]
    getter :do_fundo, for: [:root, :middle, :bottom], default: "another default"
  end


  test "renaming" do
    assert Rename.raiz(%{root: 1}) == 1
    assert Rename.do_raiz(%{}) == :default
    assert Rename.do_raiz(%{root: [middle: 3]}) == [middle: 3]

    assert Rename.do_meio(%{root: [middle: 3]}) == 3
    assert Rename.do_meio(%{root: [mid:    3]}) == "default"
    
    assert Rename.do_fundo(%{root: [middle: %{bottom: 3}]}) == 3
    assert Rename.do_fundo(%{root: [middle: %{}]}) == "another default"

    # Toss in a couple of error cases
    
    assert_raise KeyError, fn -> Rename.do_fundo(%{root: [mid:    3]}) end
    %{message: msg} =
      assert_raise RuntimeError, fn -> Rename.do_fundo(%{root: [middle: 1]}) end
    assert msg =~ "Did you forget to make a stub"
  end

  # These are compile-time checks, so not usually turned on

  # getter :original_params, from: [:example, :params]
  # (RuntimeError) `getter` requires a `:for` keyword

  # getter :original_params, for: [:example, :params], defalt: 3
  # (RuntimeError) Invalid key(s) for `getter`: [:defalt]

  # ----------------------------------------------------------------------------

  defmodule Mixer do
    defstruct [:example, :history, :params]

    getters :example, :history, [:params, changeset: %{}]
  end

  test "mixtures of keyword lists and maps" do
    assert Mixer.params(%{example:  [m: 3, history: [params: 5]]}) == 5
    assert Mixer.changeset(%{example:  [m: 3, history: [params: 5]]}) == %{}
    assert Mixer.changeset(%{example: %{m: 3, history: [changeset: "..."]}}) == "..."
  end

end

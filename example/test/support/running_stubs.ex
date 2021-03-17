defmodule Example.RunningStubs do
  alias MockeryExtras.Given
  alias Example.RunningExample, as: ModuleWithGetters 
  ##    ^^^^^^^^^^^^^^^^^^^^^^  Change this

  @stubbed_structure :running
  ## The tests should pass the value of `@stubbed_structure` in place
  ## of an actual complex structure.

  @two_arg_getter :step_value!
  ## This is the name of a getter that takes two arguments: a
  ## structure to descend into, and a second argument used to further
  ## process or navigate into the value found there.
  ##
  ## In this case, `:step_value!` extracts the `:history` substructure
  ## from a `RunningExample`, then does a `Keyword.get(the_history, some)key)`.
  ##
  ## So `stub_history(inserted_value: 5)` expands into: 
  ##    given step_value!(:running, :inserted_value), return: 5

  # You should be able to use this code unchanged.
  defmacro stub(kws) do
    for {key, val} <- kws do
      Given.expand(ModuleWithGetters,
        [{key, 1}],
        [@stubbed_structure],
        val)
    end
  end

  # You will want to change the name `stub_history`, but probably nothing else.
  defmacro stub_history(kws) do
    for {key, val} <- kws do
      Given.expand(ModuleWithGetters,
        [{@two_arg_getter, 2}],
        [@stubbed_structure, key],
        val)
    end
  end
end

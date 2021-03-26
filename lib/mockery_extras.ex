defmodule MockeryExtras do
  @moduledoc """
  
  `MockeryExtras.Given` provides a simple way to stub function calls.

      use Given
      given Map.get(%{}, :key), return: "5"
      given Map.get(@any, :key), return: "5"
      given Map.get(@any, :key), stream: [1, 2, 3]

  There is also support for writing your own stubbing
  macros.

  --------------

  `MockeryExtras.Getters` provides shorthand for defining
  getters for nodes in complex structures. With a small amount of
  copying and pasting, you can isolate both client code and tests from
  details about structure.  See [Stubbing Complex
  Structures](https://github.com/marick/mockery_extras/blob/main/stubbing_complex_structures.md)
  for an example.

      defmodule EctoTestDSL.Run.RunningExample do
        defstruct [:example, :history,
                   script: :none_just_testing,
                   tracer: :none]
      
        getters :example, [                    # <<<<<<<<<<
          eens: [],
          validation_changeset_checks: [],
          constraint_changeset_checks: [],
          field_checks: %{},
          fields_from: :nothing,
        ]
  """

end

defmodule MockeryExtras do
  @moduledoc """
  
  `MockeryExtras.Given` provides a simple way to stub function calls.

      use Given
      given Map.get(%{}, :key), return: "5"
      given Map.get(@any, :key), return: "5"

  There is also support for writing your own macros.

  --------------

  `MockeryExtras.Getters` makes it easy to hide complex structures
  from client code and tests. It provides a shorthand notation to
  define getters, plus supports lightweight use of those getters in
  product code and tests.

      #### Complex structure and getters

      defmodule EctoTestDSL.Run.RunningExample do
        @enforce_keys [:example, :history]
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

      #### Use in client code. The verbose way: 

      def check_new_fields(running, which_step) do
        neighborhood = RunningExample.neighborhood(:running)
        ...

      # ... or the terse way:

      def check_new_fields(running, which_step) do
        from(running, use: [:neighborhood, :name, :field_checks,
                            :fields_from, :usually_ignore])

      #### Use in test code

      setup do
        stub(name: :example, neighborhood: %{}, usually_ignore: [])
        :ok
      end

      test "..." do 
        stub(checks: %{name: "Bossie"}, ...)
        ...
        actual = Steps.check_new_fields(:running, :changeset_from_params)
      end
  """

end

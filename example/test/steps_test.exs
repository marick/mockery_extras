defmodule Example.StepsTest do
  use ExUnit.Case
  import FlowAssertions.AssertionA
  alias Example.Steps
  import Example.RunningStubs

  setup do
    stub [name: :example, workflow_name: :success]
    :ok
  end

  test "a valid assertion produces a result that's not recorded" do
    changeset = changeset(valid?: true)
    stub_history(changeset_producing_step: changeset)

    actual = Steps.assert_valid_changeset(:running, :changeset_producing_step)
    assert actual == :uninteresting_result
  end

  test "an invalid assertion produces a useful error message" do
    changeset = changeset(valid?: false)
    stub_history(changeset_producing_step: changeset)

    assertion_fails(~r/Example `:example`:/,
      [message: ~r/workflow `:success` expects a valid changeset/,
       left: changeset],
      fn ->
        Steps.assert_valid_changeset(:running, :changeset_producing_step)
      end)
  end

  defp changeset(opts), do: struct(Ecto.Changeset, opts)

end

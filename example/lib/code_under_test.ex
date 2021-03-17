defmodule Example.Steps do
  use Example.From
  import ExUnit.Assertions
  import FlowAssertions.Define.BodyParts

  Module.register_attribute __MODULE__, :step, accumulate: true, persist: true

  @step :assert_valid_changeset
  def assert_valid_changeset(running, which_changeset) do 
    from(running, use: [:name, :workflow_name])
    from_history(running, changeset: which_changeset)

    # The package this is extracted from supports testing. So "product code"
    # uses ExUnit
    adjust_assertion_message(
      fn ->
        elaborate_assert(changeset.valid?,
          "workflow `#{inspect workflow_name}` expects a valid changeset",
          left: changeset)
      end,
      fn message ->
        "Example `#{inspect name}`: #{message}"
      end)

    :uninteresting_result
  end
end

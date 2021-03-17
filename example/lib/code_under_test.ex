defmodule Example.Steps do
  use Example.From
  import FlowAssertions.Define.BodyParts
  # The package this is extracted from supports testing. So "product code"
  # uses some assertion-building code I've also written. See `flow_assertions`
  # in Hex. (The majority of that package is useful assertions built with
  # `FlowAssertions.Define`.)

  def assert_valid_changeset(running, which_changeset) do 
    from(running, use: [:name, :workflow_name])         # <<< bind variables
    from_history(running, changeset: which_changeset)   # <<<

    # The rest of this is just code.
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

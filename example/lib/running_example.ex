defmodule Example.RunningExample do
  import MockeryExtras.Getters
  
  @enforce_keys [:example, :history]
  defstruct [:example, :history]

  getters :example, [eens: [], field_checks: %{}]
  getters :example, :metadata, [:name, :workflow_name, :repo, :module_under_test]

  getter :original_params, for: :params

  private_getters :example, [:format]

  def step_value!(%{history: history}, step_name),
    do: Keyword.fetch!(history, step_name)

  # Conveniences for history values we know will always have the same name.
  # Possibly a bad idea.
  def neighborhood(running), do: step_value!(running, :repo_setup)
  def expanded_params(running), do: step_value!(running, :params)

  def formatted_params(running) do
    expanded_params(running)
    |> Example.Params.format(format(running))
  end
end

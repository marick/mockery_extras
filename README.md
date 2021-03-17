# MockeryExtras

Additions to [`mockery`](https://github.com/appunite/mockery) that may
make your programming life a bit more pleasant.

Provides:

* A [simple way](https://hexdocs.pm/mockery_extras/MockeryExtras.Given.html#content) to stub function calls:

  ```elixir
  use Given
  given Map.get(%{}, :key), return: "5"
  given Map.get(@any, :key), return: "5"
  ```

* [Easy definition of getters](https://hexdocs.pm/mockery_extras/MockeryExtras.Getters.html#content) for complex structures, plus support code
  for insulating client code and tests from details of that structure. 
  See [Stubbing Complex Structures](stubbing_complex_structures.md).

## Installation

Add `mockery_extras` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:mockery_extras, "~> 0.2.0"}
  ]
end
```

Documentation is at
[https://hexdocs.pm/mockery_extras](https://hexdocs.pm/mockery_extras).


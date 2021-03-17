# Stubbing complex structures

Sometimes, despite what you might want, you end up with a complex
structure -- sometimes called a "God object" -- that's used in many
places in your code. If that client code contains text like
`user.privileges[:author].read`, you have two problems:

1. Any attempt to change the "shape" of the complex structure becomes
   hard because there are so many places to change. That
   locks you into complexity because it's too painful to undo it
   by, for example, breaking the single structure into several.
   
2. Tests have to construct sample data. In a dynamically typed
   language, they don't have to create a complete God object; they need
   only supply the fields the code under test actually uses. But, once again,
   changes to the structure can require a lot of changes to tests.
   
Here, I'll show how to avoid such coupling, using the code in
`MockeryExtras.Getters` and `MockeryExtras.Given`. The emphasis is
on both simplifying change and avoiding busywork.

## TL;DR

## Necessary Background

I'll use a simplified version of code from
[`ecto_test_dsl`](https://github.com/marick/ecto_test_dsl) as an
example. That code works on *examples* of how particular Ecto schemas
are manipulated by client code. Examples are a terse notation for
creating tests of Ecto validation, insertion, constraint checking, and
so on.

People tend to use Ecto in a stylized way - that is, a lot of their
code looks pretty much the same. But different people's style can be
different. Some people use what I think of as "Phoenix Classic" style
(where, for example, changesets are checked after a `Repo.insert`, not
before). I myself prefer a "view model" style, which involves two Ecto
schemas and separate checks for validation failures and constraint
errors.

The point is that the example structure has to support customization
to fit different styles. As such, it's a plain map with some required
fields rather than a predefined `defstruct`.

When an example is put into action, the processing goes through a
series of steps, such as recursively loading the repo with other
examples, finalizing parameters (by, for example, inserting foreign
key values), creating a changeset, inserting a changeset, checking
insertion results, and so on. The results of one step are usually used
in one or more later steps.

Again, these steps and what they do depend on the style, so the
structure supporting them has to be open-ended. Specifically, the
*history* is a keywod list. Each result is pushed onto it as a
`{step_name, step_value}` pair.

## `RunningExample`

*Note: this is the least interesting of the next three parts. Feel
free to skim. The detail will be most useful if you want to copy this
approach for your own structures.*

Since the history and example always exist at the same time, it makes
sense to put them into a structure:

```elixir
defmodule Example.RunningExample do
  @enforce_keys [:example, :history]
  defstruct [:example, :history]
```

(There are more fields in the real structure, but they add nothing here.)

(You can find all the example code, including tests, in [`example`](example).)

It would be easy enough to create "getter" functions for fields, like this:

```elixir
defmodule Example.RunningExample do
  ...
  def eens(running),         do: Map.get(running.example, :eens,          [])
  def field_checks(running), do: Map.get(running.example, :field_checks, %{})
```

... and so on. However, that's the kind of work a computer --
specifically, a macro -- should do:

```elixir
  import MockeryExtras.Getters
  getters :example, [eens: [], field_checks: %{}]
```

It's actually more common for code and tests to work with data stored
another level below `:examples`, under `:metadata`. Those getters are
created like this:

```elixir
  getters :example, :metadata, [:name, :repo, :module_under_test]
```

Note: `:metadata` as a name made some sense, once upon a time, but
it's a crummy name now. Because access to its data is via
`RunningExamples.name/1`, `RunningExample.repo/1`, and so on, it would
be easy to change, but I haven't gotten around to it.

While we're talking about bad names, one of the first mandatory keys
under `:example` was `:params`. It originally meant parameters written
as atom/value pairs: `%{name: "Bossie", age: 1, tags: ["docile"]}` 

Since then, it's become useful to add on two other kinds:

* *expanded* parameters have had foreign keys or other
  association values substituted in.
  
* *formatted* parameters are ones formatted the same way EEx does, and thus
  how they're actually presented to Phoenix controllers. For example:
  
      %{"name" => "Bossie", "age" => "1", "tags" => ["docile"]}

For clarity, the original `:params` should be replaced with a better
name. For the moment, I've just given the getter a different name:

```elixir
  getter :original_params, from: :params
```

### Getters with arguments

The history has to be handled a bit differently. Recall that it's a
keyword list without hardcoded keys. So its getter must take an argument:

```elixir
  def step_value!(%{history: history}, step_name),
    do: Keyword.fetch!(history, step_name)
```

Well, it's *almost* without hardcoded keys. 

* The `repo_setup` key has the result of the very first step. That step
  inserts all examples that the current example depends on. It is the
  source of all association data like private keys. I've come to think
  of this as the running example's *neighborhood*, so I created a
  getter for this:
  
      ```elixir
      def neighborhood(running), do: step_value!(running, :repo_setup)
      ```
      
* What I described as the "expanded params" above are created in the
  next step (which substitutes values from the neighborhood into the
  original params). That step's keyword has the unfortunate name `:params`.
  So here's a getter:
  
      ```elixir
      def expanded_params(running), do: step_value!(running, :params)
      ```

Notice that I've blurred the distinction between parameters that came
from the user and ones that live in the history. I think that's a good
thing. And I'm happy that I'm able to isolate early mistakes behind an
API. (I should still fix some of the bad names. But not just now.)

## Terse uses of getters in client code

A problem with wrapping a nested structure in an API with getters
is that you lose Elixir's concise `.` notation. You'll have to type
something like `RunningExample.field_checks(running)` instead of
`running.field_checks`.

For that reason, I'll typically use a shorthand notation in
the beginning of client functions:

```elixir
use Example.From

def check_new_fields(running, which_step) do
  from(running, use: [:neighborhood, :name, :field_checks])
  from_history(running, to_be_checked: which_step)
  ...
```

That is the same as:

```elixir
def check_new_fields(running, which_step) do
  neighborhood = RunningExample.neighborhood(:running)
  name = RunningExample.name(:running)
  field_checks = RunningExample.field_checks(:running)
  
  to_be_checked = RunningExample.step_value!(running, which_step)
  ...
```

The code to produce that isn't trivial to write, but it
should be easy for you to copy and tweak as needed. The `from` macro should be
entirely general-purpose:

```elixir
  defmacro from(running, use: keys) do
    assert_existence(keys, 1)
    varlist = Enum.map(keys, &one_var/1)    
    calls = Enum.map(keys, &(field_access(&1, running)))
    emit(varlist, calls)
  end
```

## Terse stubbing of getters in test code

The code that `from` generates is actually slightly more complicated than
I described above. It sets up that use of a getter for stubbing:

```elixir
  neighborhood = mockable(RunningExample).neighborhood(:running)
                 ^^^^^^^^^^^^^^^^^^^^^^^^
```

(Specifically, it uses the `mockery` package, which provides low-ceremony mocking
and stubbing that still allows asynchronous testing.)

For `RunningExample`, I've created `RunningStubs`, which lets tests be
written like this:

```elixir

# These are defaults that can be overridden in individual tests.
setup do
  stub(name: :example, neighborhood: %{}, usually_ignore: [])
  :ok
end

test "..." do 
  stub(field_checks: %{name: "Bossie"}, ...)
  stub_history(inserted_value: ...)
  ...
  assert ...
end
```

The tests are now about *concepts* that the client code depends on
(like "the neighborhood"). They are entirely not about *structure*.

The code for `RunningStubs` is very simple:

```elixir
  defmacro stub(kws) do
    for {key, val} <- kws do
      Given.expand(RunningExample, [{key, 1}], [:running], val)
    end
  end

  defmacro stub_history(kws) do
    for {key, val} <- kws do
      Given.expand(RunningExample, [step_value!: 2], [:running, key], val)
    end
  end
```


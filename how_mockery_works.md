# How Mockery works

Mockery uses two neat Erlang/Elixir features: the process dictionary
and custom handling of calls to module functions that don't exist
("method_missing"). Mockery Extras demonstrates a third: parsing
function calls in macros. I thought it would be fun to write them up.

## How to use Mockery

Starting with a fresh Elixir project, I'll write a function,
`days_from`, that calculates how many days lie between today and a
given date:

```elixir
iex(2)> days_from(~D[2000-01-01])
7759
```

The implementation is trivial:

```elixir
  def days_from(date) do
    Date.diff(Date.utc_today, date)
  end
```


Testing is harder. What goes in the `????` below?

```elixir
  test "days_from" do
    assert days_from(~D[2000-01-01]) == ????
  end
```

If it's some calculation involving `Date.utc_today`, there are problems:

1. The date might change while the test is running. (If you think that's too
   unlikely to worry about, pretend we're testing `microseconds_from`.)
   
2. The calculation is probably going to repeat the logic under test. If
   there's an off-by-one error and the value should be `7758` instead
   of `7759`, the test won't catch it.
   
3. The test doesn't really say anything useful about the function. If
   it happens that it should say that today is one day away from
   today (for some weird business reason), you might want to document that.
   
By a conservative count, 32,011,005 words have been written on
how to handle this issue. For a simple case like this, a lot of people
would favor adding an overridable default argument that can be used in
a test:

```elixir
  def days_from(date, today \\ Date.utc_today) do
    Date.diff(today, date)
  end
```

I'm not going to add to that argument, though I definitely Have
Opinions. Since this page is about how Mockery works, our solution
will use it. That solution looks like this:

```elixir
  test "today is zero days from today (not one!)" do
    today = ~D[2001-02-03]
    mock Date, [utc_today: 0], fn -> today end   # <<<<<<<<<<<<
    assert days_from(today) == 0
  end
```

That says that, while the test is running, we want a call to
`Date.utc_today/0` to return `~D[2001-02-03]`. There's a simpler
notation for always returning the same value, but this is the most
general and so best to use when explaining how Mockery works.

This package provides a notation I like better:

```elixir
    given Date.utc_today, return: today
```

I'll explain how that works later. It's just a simple(ish) macro on
top of `mock`.

I just said what we **want** `Date.utc_today/0` to do. But that's not
what it will do, not yet. To make it return the constant value, we have to annotate *the
specific function call we want to affect*. (That's unusual among
mocking packages. It keeps one use of Mockery from interfering with
another, even if they're exercising the same `Date.utc_today` and
running concurrently.)

So the definition of `days_from` will look like this:

```elixir
  import Mockery.Macro

  def days_from(date) do
    Date.diff(
      mockable(Date).utc_today(),
      ^^^^^^^^^^^^^^
      date)
  end
```

Note: the parentheses after `utc_today` are *required* in this case. Leave them off, ad you'll get a confusing error from the Elixir compiler. I'll explain it later. 

## What the `mockable` macro does (part 1)

`mockable` is a macro, which means that it rewrites code at compile
time. For the moment, I'll pretend that all it does is change the name
of the module it wraps. That is, after the macro executes, Elixir will
compile this code:

```elixir
    Date.diff(
      Mockery.Proxy.MacroProxy.utc_today(),
      ^^^^^^^^^^^^^^^^^^^^^^^^
      date)
```

When the test calls `days_from/1`, that function will in turn call 
`Mockery.Proxy.MacroProxy.utc_today()`.

### Calling missing functions

The `Mockery.Proxy.MacroProxy` module doesn't have a `utc_today/0`
function, so you'd nomally expect to see an `UndefinedFunctionError`
when the code was executed, one saying "function
Mockery.Proxy.MacroProxy.utc_today/0 is undefined or private". You
don't because of a special definition in that module:

```elixir
  def unquote(:"$handle_undefined_function")(name, args) do
    ...
  end
```

That definition looks odd because it's taking advantage of an Erlang
feature: if an unknown function is called *and* the target module has
a function named `$handle_undefined_function`, then that function is
called instead. 

Elixir doesn't allow `def $handle_undefined_function`, so you have to
go through a two-step dance:

1. The ultimate name of an Elixir function is an atom. That's why you
   can call `Date.utc_today` like this:
   
   ```elixir
   apply Date, :utc_today, []
   ```
   
   The way to create weirdly-named Elixir atoms is to surround the weird part
   with quotes:
   
   ```
   iex(1)> :"this is weird"
   :"this is weird"
   ```
   
2. But you can't hand that to `def` because it's a macro that converts its first
   argument into a function name, and it doesn't accept atom notation. That is,
   the following doesn't work:
   
   ```elixir
   def :id(x), do: x
   ```
   
   You can, however, do the (non)conversion yourself using unquote:

    ```
    def unquote(:id)(x), do: x
    ```

It's weird, but it works.

`$handle_undefined_function` is given the name of the attempted
function (`utc_today`) and its argument list (`[]`). In our example
use of `mock`, it should call our zero-argument function that returns
`~D[2001-01-01]`. But how does it find that function?

## The process dictionary

Every Erlang process has attached to it a *mutable* key-value
store. Like many "mostly-functional languages", Elixir provides escape
hatches to deal with cases where being strictly functional is more
trouble than it's worth. Very often, such escape hatches are
associated with concurrency or threading, and the process dictionary
is no exception. It is inaccessible from outside its owning process,
so it cannot share any information - such as mocking information -
with other processes.

As it happens, each ExUnit test runs inside its own process, so each has
its own private process dictionary.

The contents of the process dictionary can be fetched with
`Process.get/0`. Given this test:

```elixir
    today = ~D[2001-02-03]
    mock Date, [utc_today: 0], fn -> today end
    IO.inspect Process.get
    ...
    
````

you'd see this:

```elixir
[
  {:rand_seed, ...} # state for calculating the next random number
  
  {{Mockery, {Date, {:utc_today, 0}}}, #Function<7.34045286/0/2>},
   ^^^^^^^^ lookup key ^^^^^^^^^^^^^^  ^^^^^^ lookup value ^^^^^^^
]
```

The process dictionary is something like a `Keyword` list, but doesn't
require atoms as arguments.

`Mockery.Proxy.MacroProxy.$handle_undefined_function` should find that
that `Mockery` entry and call the associated function. It does that by...

[*record scratch sound effect*](https://www.youtube.com/watch?v=CfBCD1IjRo0)

It can't do that because it is given only the name of the function
(`:utc_today`) and the arglist (in this case, the empty list). From
that, it knows part of the key will be `{utc_today, 0}`, but it has
no access to the module name, `Date`.


## A complicated little dance

However, `$handle_undefined_function` does have access to the process
dictionary. So the `mockable` macro does more than substitute
`Mockery.Proxy.MacroProxy` for `Date`. It also puts `Date` in the
process dictionary. Given that you've written this:

```elixir
    mockery(Date).utc_today
```

... the compiler compiles this:

```elixir
    (
     Process.push(:__mockery_module_stack, Date)
     Mockery.Proxy.MacroProxy
    ).utc_today()
```

So, just before the call to `utc_today`, the executing code pushes `Date` into
the process dictionary.

There's not actually a `Process.push`, so the real code uses
`Process.get/2` and `Process.put/2`. I also changed the name from
`Mockery.MockableModule` to `:__mockery_module_stack` because I think
the latter is clearer and because there's not actually a module named
  `Mockery.MockableModule` - it's just used as a likely-to-be-unique
atom.

The above explains why you get a strange error message if you leave
the parentheses off `utc_today()`. The elixir compiler believes a form
like `(...).name` must be a map or structure dereference. Since it's not, you get this error (using the real Mockery code here):

```
warning: incompatible types:

    map() !~ Mockery.Proxy.MacroProxy

in expression:

    # lib/glorb.ex:6
    (    
  mocked_calls = Process.get(Mockery.MockableModule, [])    
  Process.put(Mockery.MockableModule, [{Date, nil} | mocked_calls])    
  Mockery.Proxy.MacroProxy    
).utc_today

Conflict found at
  lib/glorb.ex:6: Glorb.days_from/1
```

### The undefined-function handler follows the lead

Immediately after `Date` is pushed into the process dictionary, the
code tries to call `Mockery.Proxy.MacroProxy.utc_today` and enters
`Mockery.Proxy.MacroProxy.$handle_undefined_function`. That pops
`Date` off the `:__mockable_module_stack`, then combines it with the
function name and argument list to look up this key:

```elixir
  {Mockery, {Date, {:utc_today, 0}}}
```

Then it calls the function, which returns `~D[2001-02-03]`.

### Why a stack?

You may wonder why `:__mockable_module_stack` is a stack instead of just a value. The reason is code like this:

```
mockable(BigModule).do_something(
  mockable(SmallModule.provide_something)
  )
```

The sequence of events is first-in, last-out:

1. Push `BigModule` onto the stack.
2. Push `SmallModule` onto the stack.
3. Handle the undefined `provide_something` and return a value.
4. Handle the undefined `do_something` and return a value.

## Postscript: Macros that parse function calls

This package provides `given`, which I think is more pleasant for
common uses of Mockery. Here's an example:

```elixir
    given RunningExample.name(:running), return: "fred"
```

The interesting bit about this notation is how a macro can transform what looks
like a function call (`RunningExample.name(:running)`) into what `mock` wants:

```elixir
    mock RunningExample, [name: 1]
```

More generally, a function call form can be translated into what
Elixir/Erlang often calls MFA format, standing for Module, Function,
Arguments. The MFA format for `RunningExample.name(:running)` is
`{RunningExample, :name, [:running]}`. Below I'll show how to pick apart
each different kind of function call.

### `Macro.decompose_call`

Elixir has a built-in way to dissect function call forms. Here's how it works
on `Date.utc_string/1`:

```elixir
iex(1)> funcall = quote do: Date.utc_string
iex(2)> Macro.decompose_call(funcall)
{{:__aliases__, [alias: false], [:Date]}, :utc_string, []}
                                 ^^^^^    ^^^^^^^^^^^  ^^
```

We have all the information to create an MFA or to describe a function
call to Mockery. A multi-component module name produces a list:

```elixir
iex(4)> funcall = quote do: List.Chars.to_charlist(5)
iex(5)> r = Macro.decompose_call(funcall)
{{:__aliases__, [alias: false], [:List, :Chars]}, :to_charlist, [5]}
                                ^^^^^^^^^^^^^^^
```

If you want an MFA, you have to stitch the modules back together:

```elixir
iex(30)> {{:__aliases__, _, aliases},  fun_atom, args} = r
iex(32)> Enum.reduce(aliases, :Elixir, fn alias, acc ->
                              ^^^^^^^
...(32)>   Module.safe_concat(acc, alias)
           ^^^^^^^^^^^^^^^^^^
...(32)> end)
List.Chars
``` 

Notice that the beginning value of the reduction is `:Elixir`, which
is silently prepended to all Elixir modules (so that they don't
conflict with Erlang). I don't know of a situation in which
concatenating `[:Elixir, List, Chars]` is different than
`[List, Chars]`, but it's a convenient starting value.

`Module.safe_concat` ensures that the component modules are actually
available. In the following example, I misspell `Chars`, so I get an
error:

```elixir
iex(40)> Module.safe_concat([List, Char])
** (ArgumentError) argument error
```

If you've nicknamed or abbreviated a module name with `alias` you get more results:

```elixir
iex(6)> alias List.Chars, as: C
iex(7)> funcall = quote do: C.to_charlist(5)
iex(8)> Macro.decompose_call(funcall)
{{:__aliases__, [alias: List.Chars], [:C]}, :to_charlist, [5]}
                        ^^^^^^^^^^
```

You get both the abbreviation and the real name. For uses like
`given`, where the results of composing a call are immediately used in
a macro, you don't need the real name.

Things are a bit different when you call a function without a prepending module name, like when you use `import` or the function is defined in the same module as the call:

```elixir
iex(10)> import IO.ANSI
iex(11)> funcall = quote do: cursor_up(5)
iex(12)> Macro.decompose_call(funcall)
{:cursor_up, [5]}

The decomposition gives no access to the module. When using these in a macro, you need to substitute `__MODULE__` which, at compile time, refers to the current module.
```

#### Anonymous functions

`Macro.decompose_call` isn't for use with anonymous functions:

```elixir
iex(18)> funcall = quote do: (fn a, b -> a + x end).(1, 2)
iex(19)> Macro.decompose_call(funcall)
:error
```

When I want to work with anonymous functions, I given them their own
syntax. For example, in [Ecto Test DSL], I have a notation for
describing how one field in a structure should depend on
another. Here's an example of the module form:

```elixir
field_transformations(
  date_diff: on_success(Date.diff(Date.utc_today, :start))
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
)
```


That means that the default expected value for the `date_diff` field
is the result of applying `Date.diff` to today's date and the value of
the `:start` field.

However, when working with an anonymous function, the format is:

```elixir
  age_plus: on_success(&(&1+1), applied_to: [:age])
```

(This version of `on_success` is actually a function rather than a macro.)

   
### `MacroX.decompose_call_alt`

I find the output of `decompose_call` a bit cumbersome for my uses, so
I've written [an alternative](lib/util/macro_x.ex). Use it if you like: everything in this package is public domain.


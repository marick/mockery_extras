An example of [Stubbing complex structures](../stubbing_complex_structures.md). 

```text
.
├── lib
│   ├── code_under_test.ex
│   ├── from.ex
│   ├── running_example.ex
│   └── unimportant
│       └── params.ex
└── test
    ├── steps_test.exs
    ├── support
    │   └── running_stubs.ex
    └── test_helper.exs
```

* [lib/running_example.ex](lib/running_example.ex)

  This shows a complex structure, `Example.RunningExample`, and how its getters are declared.
  
* [lib/code_under_test.ex](lib/code_under_test.ex)

  A terser way to write client code that uses values from within the complex
  data structure. (The actual name of the module is `Example.Steps`.)
  
* [lib/from.ex](lib/from.ex)

  The implementation of the `from` macro used in the above. This is code
  to copy, paste, and tweak. 
  
* [test/steps_test.exs](test/steps_test.exs)

  Tests of `Example.Steps` that show the use of stubbing to isolate tests
  from changes to the complex data structure.
  
* [test/support/running_stubs.ex](test/support/running_stubs.ex)

  Support code for any tests of `RunningExample` client code. This is code to
  copy, paste, and tweak.

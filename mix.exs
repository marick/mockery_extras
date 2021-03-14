defmodule MockeryExtras.MixProject do
  use Mix.Project

  @github "https://github.com/marick/mockery_extras"
  @version "0.1.0"

  def project do
    [
      description: """
      Helper functions and documentation for use with the Mockery package.
      """,
      
      app: :mockery_extras,
      version: @version,
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Docs
      name: "Mockery Extras",
      source_url: @github,
      docs: [
        main: "MockeryExtras",
      ],

      package: [
        contributors: ["marick@exampler.com"],
        maintainers: ["marick@exampler.com"],
        licenses: ["Unlicense"],
        links: %{
          "GitHub" => @github
        },
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
  

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:mockery, "~> 2.3.0"},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end

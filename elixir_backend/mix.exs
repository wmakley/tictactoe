defmodule Tictactoe.MixProject do
  use Mix.Project

  def project do
    [
      app: :tictactoe,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Tictactoe.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.14"},
      # {:plug_cowboy, "~> 2.0"}
      {:bandit, ">= 1.0.0-pre.3"},
      {:websock, "~> 0.5.1"},
      {:websock_adapter, "~> 0.5.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end

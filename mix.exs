defmodule PayNL.Mixfile do
  use Mix.Project

  def project do
    [
      app: :pay_nl,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        coveralls: :test
      ],
      dialyzer: [
        ignore_warnings: "dialyzer.ignore-warnings",
        flags: [
          :unmatched_returns,
          :error_handling,
          :race_conditions,
        ],
        paths: ["_build/dev/lib/pay_nl/ebin"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PayNL.Supervisor, []}
    ]
  end

  defp deps do
    [
      {:cortex, ">= 0.0.0", only: [:dev, :test]},
      {:exvcr, ">= 0.0.0", only: [:dev, :test]},
      {:ecto, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:httpotion, ">= 0.0.0"},
      {:excoveralls, ">= 0.0.0", only: [:test]},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:credo, ">= 0.0.0", only: [:test, :dev]},
    ]
  end
end

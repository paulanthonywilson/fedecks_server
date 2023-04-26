defmodule FedecksServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :fedecks_server,
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.6"},
      {:ex_doc, "~> 0.29.1", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      description:
        "Adds an websocket endpoint to Phoenix for communicating with a FedecksClient (conceived to be a Nerves device)",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" =>
          "https://github.com/paulanthonywilson/https://github.com/paulanthonywilson/fedecks_server"
      }
    ]
  end

  def docs do
    [main: "readme", extras: ["README.md", "CHANGELOG.md"]]
  end
end

defmodule FedecksServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :fedecks_server,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test]},
      {:phoenix, "~> 1.6"}
    ]
  end
end

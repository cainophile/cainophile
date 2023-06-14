defmodule Cainophile.MixProject do
  use Mix.Project

  def project do
    [
      app: :cainophile,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      source_url: "https://github.com/cainophile/cainophile",
      package: [
        licenses: ["Apache-2.0"],
        links: %{"GitHub" => "https://github.com/cainophile/cainophile"}
      ]
    ]
  end

  defp description() do
    "Cainophile is a library to assist you in building Change data capture (CDC) systems in Elixir. "
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:epgsql, "~> 4.7"},
      {:pgoutput_decoder, "~> 0.1.0"},
      {:mox, ">= 0.5.1", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end

defmodule Electric.Phoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :electric_phoenix,
      version: "0.1.2",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      consolidate_protocols: Mix.env() in [:dev, :prod],
      deps: deps(),
      name: "Electric Phoenix",
      docs: docs(),
      package: package(),
      description: description(),
      source_url: "https://github.com/electric-sql/electric_phoenix",
      homepage_url: "https://electric-sql.com"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Electric.Phoenix.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:electric_client, "~> 0.1.2"},
      {:nimble_options, "~> 1.1"},
      {:phoenix_live_view, "~> 0.20"},
      {:plug, "~> 1.0"},
      {:jason, "~> 1.0"},
      {:ecto_sql, "~> 3.10", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:floki, "~> 0.36", only: [:test]}
    ]
  end

  defp docs do
    [
      main: "Electric.Phoenix"
    ]
  end

  defp package do
    [
      links: %{
        "Electric SQL" => "https://electric-sql.com"
      },
      licenses: ["Apache-2.0"]
    ]
  end

  defp description do
    "A work-in-progress adapter to integrate Electric SQL's streaming updates into Phoenix."
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end

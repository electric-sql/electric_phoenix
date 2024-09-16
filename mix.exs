defmodule Electric.Phoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :electric_phoenix,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
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
    "A work-in-progress adapter to integrate Electric SQL's streaming udpates into Phoenix."
  end
end

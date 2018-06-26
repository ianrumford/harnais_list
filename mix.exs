defmodule Harnais.List.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :harnais_list,
      version: @version,
      elixir: "~> 1.6.0",
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/ianrumford/harnais_list",
      homepage_url: "https://github.com/ianrumford/harnais_list",
      docs: [extras: ["./README.md", "./CHANGELOG.md"]],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:harnais_error, ">= 0.1.1"},
      {:plymio_codi, ">= 0.3.0"},
      {:ex_doc, "~> 0.18.3", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Ian Rumford"],
      files: ["lib", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/ianrumford/harnais_list"}
    ]
  end

  defp description do
    """
    harnais_list: The List Harness for the Harnais Family
    """
  end
end

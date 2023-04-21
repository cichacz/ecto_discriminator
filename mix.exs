defmodule EctoDiscriminator.MixProject do
  use Mix.Project

  @source_url "https://github.com/cichacz/ecto_discriminator"
  @version "0.3.3"

  def project do
    [
      app: :ecto_discriminator,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0", only: [:test, :dev]},
      {:postgrex, ">= 0.0.0", only: :test},
      {:jason, "~> 1.2", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp description() do
    "Ecto extension that adds a tiny bit of inheritance for the schemas."
  end

  defp package do
    [
      maintainers: ["Cichacz"],
      licenses: ["MIT"],
      links: %{"github" => "https://github.com/cichacz/ecto_discriminator"},
      files: [
        "lib/ecto_discriminator",
        "mix.exs",
        "README.md"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end

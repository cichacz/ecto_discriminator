import Config

config :ecto_discriminator, EctoDiscriminator.Repo,
  database: "ecto_discriminator_repo_test",
  pool: Ecto.Adapters.SQL.Sandbox

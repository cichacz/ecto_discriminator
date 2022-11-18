import Config

config :ecto_discriminator, EctoDiscriminator.Repo,
  database: "ecto_discriminator_repo_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  log: false

config :ecto_discriminator, ecto_repos: [EctoDiscriminator.Repo]

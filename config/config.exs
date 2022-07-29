import Config

config :ecto_discriminator, EctoDiscriminator.Repo,
  database: "ecto_discriminator_repo",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

config :ecto_discriminator, ecto_repos: [EctoDiscriminator.Repo]

import_config "#{Mix.env()}.exs"
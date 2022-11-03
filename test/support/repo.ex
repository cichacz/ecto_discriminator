defmodule EctoDiscriminator.Repo do
  use Ecto.Repo,
    otp_app: :ecto_discriminator,
    adapter: Ecto.Adapters.Postgres
end

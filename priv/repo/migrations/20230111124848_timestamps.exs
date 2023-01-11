defmodule EctoDiscriminator.Repo.Migrations.Timestamps do
  use Ecto.Migration

  def change do
    alter table(:some_table) do
      timestamps()
    end
  end
end

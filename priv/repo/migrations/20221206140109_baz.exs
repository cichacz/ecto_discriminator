defmodule EctoDiscriminator.Repo.Migrations.Baz do
  use Ecto.Migration

  def change do
    alter table(:some_table) do
      add :is_special, :boolean
    end
  end
end

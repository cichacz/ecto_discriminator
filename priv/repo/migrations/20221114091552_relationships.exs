defmodule EctoDiscriminator.Repo.Migrations.Relationships do
  use Ecto.Migration

  def change do
    alter table(:some_table) do
      add :sibling_id, references(:some_table)
      add :parent_id, references(:some_table)
    end
  end
end

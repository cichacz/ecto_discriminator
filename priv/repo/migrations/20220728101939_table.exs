defmodule EctoDiscriminator.Repo.Migrations.Table do
  use Ecto.Migration

  def change do
    create table(:some_table) do
      add :title, :string
      add :type, :string
      add :source, :string
    end
  end
end

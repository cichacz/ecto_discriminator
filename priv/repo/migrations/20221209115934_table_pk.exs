defmodule EctoDiscriminator.Repo.Migrations.TablePk do
  use Ecto.Migration

  def change do
    create table(:some_table_pk, primary_key: false) do
      add :type, :string, null: false, primary_key: true
      add :title, :string
      add :source, :string
    end
  end
end

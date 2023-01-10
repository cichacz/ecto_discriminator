defmodule EctoDiscriminator.Repo.Migrations.BarContent do
  use Ecto.Migration

  def change do
    create table(:bar_content) do
      add :bar_id, references(:some_table)
      add :name, :string
      add :status, :integer
      add :baz, :boolean
    end
  end
end

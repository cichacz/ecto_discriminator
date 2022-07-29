defmodule EctoDiscriminator.Repo.Migrations.JsonContent do
  use Ecto.Migration

  def change do
    alter table(:some_table) do
      add :content, :json
    end
  end
end

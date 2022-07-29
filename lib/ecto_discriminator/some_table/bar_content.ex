defmodule EctoDiscriminator.SomeTable.BarContent do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :status, :integer
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :status])
    |> validate_required([:name])
  end
end

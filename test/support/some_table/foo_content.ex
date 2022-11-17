defmodule EctoDiscriminator.SomeTable.FooContent do
  use Ecto.Schema

  import Ecto.Changeset

  embedded_schema do
    field :length, :integer
    field :date, :utc_datetime
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:length])
    |> validate_required([:length])
    |> put_change(:date, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end

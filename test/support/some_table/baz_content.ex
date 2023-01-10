defmodule EctoDiscriminator.SomeTable.BazContent do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable.BarContent do
    field :baz, :boolean
    belongs_to :bar, EctoDiscriminator.SomeTable.Baz
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:baz])
    |> validate_required(:baz)
  end
end

defmodule EctoDiscriminator.SomeTable.Baz do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable.Foo do
    field :is_special, :boolean
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:is_special])
    |> validate_required([:is_special])
  end
end

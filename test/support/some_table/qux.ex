defmodule EctoDiscriminator.SomeTable.Qux do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias EctoDiscriminator.SomeTable.Foo

  # make sure base schemas can be referenced using alias
  schema Foo do
    field :is_special, :boolean
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:is_special])
    |> validate_required([:is_special])
  end
end

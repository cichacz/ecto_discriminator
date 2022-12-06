defmodule EctoDiscriminator.SomeTable.Qux do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable.Baz do
    field :is_last, :boolean, virtual: true
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
  end
end

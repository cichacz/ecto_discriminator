defmodule EctoDiscriminator.SomeTable.Qux do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias EctoDiscriminator.SomeTable.Baz

  # make sure base schemas can be referenced using alias
  schema Baz do
    field :is_last, :boolean, virtual: true
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
  end
end

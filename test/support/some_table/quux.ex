defmodule EctoDiscriminator.SomeTable.Quux do
  use EctoDiscriminator.Schema

  alias EctoDiscriminator.SomeTable.Qux

  # make sure base schemas can be referenced using alias
  schema Qux do
    field :is_last, :boolean, virtual: true
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
  end
end

defmodule EctoDiscriminator.SomeTable.FooPk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTablePk do
    field :source, :string
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:source])
  end
end

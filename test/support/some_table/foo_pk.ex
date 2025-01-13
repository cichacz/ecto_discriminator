defmodule EctoDiscriminator.SomeTable.FooPk do
  use EctoDiscriminator.Schema

  schema EctoDiscriminator.SomeTablePk do
    field :source, :string
    field :title, Ecto.Enum, default: :b
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
  end
end

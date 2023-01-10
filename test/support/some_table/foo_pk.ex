defmodule EctoDiscriminator.SomeTable.FooPk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTablePk do
    field :source, :string
    field :title, Ecto.Enum, default: :b
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:source])
  end

  defimpl EctoDiscriminator.DiscriminatorSchema do
    def diverged_changeset(_, _), do: raise("There is no diverged schema for #{@for}")

    def cast_base(data, params, source) do
      struct = data.__struct__
      discriminator = struct.__schema__(:discriminator)

      # we have to change type of our struct to call changeset of source schema
      data
      |> Map.put(:__struct__, source)
      |> source.changeset(params)
      # replace data & types with current schema to be able to continue in original changeset
      |> Map.put(:data, data)
      |> Map.put(:types, struct.__changeset__())
      # add discriminator field to changeset
      |> cast(params, [discriminator])
      |> validate_required(discriminator)
    end
  end
end

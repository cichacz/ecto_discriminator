defprotocol EctoDiscriminator.DiscriminatorSchema do
  @moduledoc false

  def diverged_changeset(struct, params)
  def cast_base(struct, params, source)
end

defimpl EctoDiscriminator.DiscriminatorSchema, for: Any do
  import Ecto.Changeset

  def diverged_changeset(struct, params \\ %{}), do: cast_diverged(struct, params)

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

  defp cast_diverged(%Ecto.Changeset{} = changeset, params) do
    changeset.data
    |> cast_diverged(params)
    |> Ecto.Changeset.merge(changeset)
  end

  defp cast_diverged(%_{} = data, params) do
    struct = data.__struct__
    discriminator = struct.__schema__(:discriminator)
    discriminator_struct = params[discriminator] || params[to_string(discriminator)] || struct

    # just call changeset from the derived schema and hope it calls cast_base to pull fields from the base schema
    data
    |> Map.put(:__struct__, discriminator_struct)
    |> discriminator_struct.changeset(params)
  end
end

defprotocol EctoDiscriminator.DiscriminatorSchema do
  @moduledoc """
  Protocol for defining behaviour of changesets on discriminator-enabled schemas.

  In most cases there is no need to alter this logic, however if there is some extra logic needed
  to be executed everytime some diverged schema changeset is being created
  it can be injected by overriding this protocol.

  Could be useful especially for some side effects that doesn't look "good"
  when put directly inside base changeset function
  """

  @doc """
  Calls `changeset/2` function from diverged type.

  In general, this function works the same like calling `changeset/2` on diverged schema with `cast_base/3` inside.
  It becomes useful when you want to create changeset for diverged struct,
  but the data is coming from external source (like user input).
  This makes it possible to use generic naming like `SomeTable`
  in places where there could be multiple diverged types inserted by the same function, to keep code clean.

  Type is inferred from the discriminator field in `params` or from passed struct.

  Every module that uses `EctoDiscriminator.Schema` derives the basic implementation.
  There is also a helper method to avoid aliasing `EctoDiscriminator.DiscriminatorSchema` everywhere.

  ## Examples

      changeset = DiscriminatorSchema.diverged_changeset(%SomeTable{}, %{type: SomeTable.Foo})
      changeset.data #=> %SomeTable.Foo{...}

  You can call the same thing from any module that uses `EctoDiscriminator.schema`:

      changeset = SomeTable.diverged_changeset(%SomeTable{}, %{type: SomeTable.Foo})
      changeset.data #=> %SomeTable.Foo{...}

  If type is missing from `params` it will be taken from the passed struct:

      changeset = SomeTable.diverged_changeset(%SomeTable.Foo{}, %{title: "abc"})
      changeset.data #=> %SomeTable.Foo{...}
  """
  def diverged_changeset(struct, params \\ %{})

  @doc """
  Calls `changeset/2` function from base type.

  Use this inside changeset function of a diverged schema to call base changeset.

  By default it calls `changeset/2` from base schema to apply logic for common fields
  and then returns changeset for further modifications.

  It can be placed anywhere in the changeset, but the safest place should be the beginning.
  `cast_base/3` won't contain changes for fields that are overriden by diverged schema.

  Every module that uses `EctoDiscriminator.Schema` derives the basic implementation.
  There is also a helper method to avoid aliasing `EctoDiscriminator.DiscriminatorSchema` everywhere.

  ## Examples

      def changeset(struct, params) do
        struct
        |> ...
        |> cast_base(params)
        |> ...
      end
  """
  def cast_base(struct, params, source)
end

defimpl EctoDiscriminator.DiscriminatorSchema, for: Any do
  import Ecto.Changeset

  def diverged_changeset(data, params) do
    data
    |> change()
    |> EctoDiscriminator.DiscriminatorSchema.diverged_changeset(params)
  end

  def cast_base(data, params, source) do
    data
    |> change()
    |> EctoDiscriminator.DiscriminatorSchema.cast_base(params, source)
  end
end

defimpl EctoDiscriminator.DiscriminatorSchema, for: Ecto.Changeset do
  import Ecto.Changeset

  def diverged_changeset(%{data: data} = changeset, params) do
    struct = data.__struct__
    discriminator = struct.__schema__(:discriminator)
    diverged_schema = params[discriminator] || params[to_string(discriminator)] || struct

    data = struct(diverged_schema, Map.from_struct(data))

    # just call changeset from the derived schema and hope it calls cast_base to pull fields from the base schema
    diverged_changeset = diverged_schema.changeset(data, params)

    changeset
    # replace data & types with diverged schema to be able to continue in original changeset
    |> Map.put(:data, data)
    |> Map.put(:types, diverged_schema.__changeset__())
    |> Ecto.Changeset.merge(diverged_changeset)
  end

  def cast_base(%{data: data} = changeset, params, source) do
    struct = data.__struct__
    discriminator = struct.__schema__(:discriminator)

    base_changeset =
      changeset
      |> Map.update!(:data, fn data -> Map.put(data, :__struct__, source) end)
      |> Map.put(:types, source.__changeset__())
      |> source.changeset(params)
      # replace data & types with current schema to be able to continue in original changeset
      |> Map.put(:data, data)
      |> Map.put(:types, struct.__changeset__())
      # drop from changes keys that are overwritten in diverged schema
      |> Map.update!(:changes, &Map.drop(&1, struct.__schema__(:unique_fields)))
      # add discriminator field to changeset
      |> cast(params, [discriminator])
      |> validate_required(discriminator)
      |> validate_change(discriminator, &validate_discriminator_value(&1, &2, source))

    Ecto.Changeset.merge(changeset, base_changeset)
  end

  defp validate_discriminator_value(discriminator, module_name, source) do
    with(
      :loaded <- :code.module_status(module_name),
      true <- source.__schema__(:source) == module_name.__schema__(:source)
    ) do
      []
    else
      false -> [{discriminator, "sources don't match"}]
      _ -> [{discriminator, "not found"}]
    end
  end
end

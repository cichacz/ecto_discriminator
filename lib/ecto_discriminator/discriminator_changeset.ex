defprotocol EctoDiscriminator.DiscriminatorChangeset do
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

  In general, this function works the same like calling `changeset/2` on diverged schema with `cast_base/2` inside.
  It becomes useful when you want to create changeset for diverged struct,
  but the data is coming from external source (like user input).
  This makes it possible to use generic naming like `SomeTable`
  in places where there could be multiple diverged types inserted by the same function, to keep code clean.

  Type is inferred from the discriminator field in `params` or from passed struct.

  Every module that uses `EctoDiscriminator.Schema` derives the basic implementation.
  There is also a helper method to avoid aliasing `EctoDiscriminator.DiscriminatorChangeset` everywhere.

  ## Examples

      changeset = DiscriminatorChangeset.diverged_changeset(%SomeTable{}, %{type: SomeTable.Foo})
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
  Outputs changeset for base schema from a diverged one.

  This makes it possible to reduce diverged struct to base version in places where we have polymorphic relationship,
  to avoid loading the same data in multiple ways.

  Type is inferred from the discriminator field in passed struct.

  Every module that uses `EctoDiscriminator.Schema` derives the basic implementation.
  There is also a helper method to avoid aliasing `EctoDiscriminator.DiscriminatorChangeset` everywhere.

  ## Examples

      changeset = DiscriminatorChangeset.base_changeset(%SomeTable.Foo{not_in_base: 1}, %{not_in_base_param: 1})
      changeset.data #=> %SomeTable{...} - won't contain "not_in" values
      changeset.changes #=> %{}

  You can call the same thing from any module that uses `EctoDiscriminator.schema`:

      changeset = SomeTable.base_changeset(%SomeTable.Foo{}, %{})
      changeset.data #=> %SomeTable{...}
  """
  def base_changeset(struct, params \\ %{})

  @doc """
  Calls `changeset/2` function from base type.

  Use this inside changeset function of a diverged schema to call base changeset.

  By default it calls `changeset/2` from base schema to apply logic for common fields
  and then returns changeset for further modifications.

  It can be placed anywhere in the changeset, but the safest place should be the beginning.
  `cast_base/2` won't contain changes for fields that are overriden by diverged schema.

  Every module that uses `EctoDiscriminator.Schema` derives the basic implementation.
  There is also a helper method to avoid aliasing `EctoDiscriminator.DiscriminatorChangeset` everywhere.

  ## Examples

      def changeset(struct, params) do
        struct
        |> ...
        |> cast_base(params)
        |> ...
      end
  """
  def cast_base(struct, params)
end

defimpl EctoDiscriminator.DiscriminatorChangeset, for: Any do
  import Ecto.Changeset

  def diverged_changeset(data, params) do
    data
    |> change()
    |> EctoDiscriminator.DiscriminatorChangeset.diverged_changeset(params)
  end

  def base_changeset(data, params) do
    data
    |> change()
    |> EctoDiscriminator.DiscriminatorChangeset.base_changeset(params)
  end

  def cast_base(data, params) do
    data
    |> change()
    |> EctoDiscriminator.DiscriminatorChangeset.cast_base(params)
  end
end

defimpl EctoDiscriminator.DiscriminatorChangeset, for: Ecto.Changeset do
  import Ecto.Changeset

  def diverged_changeset(%{data: data} = changeset, params) do
    struct = data.__struct__
    discriminator = struct.__schema__(:discriminator)

    diverged_schema =
      params[discriminator] || params[to_string(discriminator)] ||
        Ecto.Changeset.get_field(changeset, discriminator) ||
        struct

    if struct != diverged_schema do
      data = EctoDiscriminator.Schema.to_base(data, diverged_schema)

      # just call changeset from the derived schema and hope it calls cast_base to pull fields from the base schema
      diverged_changeset = diverged_schema.changeset(data, params)

      changeset
      # replace data & types with ones from diverged changeset to be able to continue in original changeset
      |> Map.put(:data, diverged_changeset.data)
      |> Map.put(:types, diverged_changeset.types)
      |> Ecto.Changeset.merge(diverged_changeset)
    else
      # we can just safely run the changeset
      diverged_schema.changeset(changeset, params)
    end
  end

  def base_changeset(%{data: data} = changeset, params) do
    data = data.__struct__.to_base(data)
    source = data.__struct__

    changeset
    |> Map.put(:data, data)
    |> Map.put(:types, source.__changeset__())
    |> source.changeset(params)
  end

  def cast_base(%{data: data} = changeset, params) do
    struct = data.__struct__
    discriminator = struct.__schema__(:discriminator)

    new_changeset =
      changeset
      |> base_changeset(params)
      |> transform_source_changeset(struct, data)
      # add discriminator field to changeset
      |> cast(params, [discriminator])
      |> validate_required(discriminator)

    Ecto.Changeset.merge(changeset, new_changeset)
  end

  defp transform_source_changeset(
         %Ecto.Changeset{changes: changes, errors: errors} = changeset,
         struct,
         data
       ) do
    # drop changes and errors keys that are overwritten in diverged schema
    changes = Map.drop(changes, struct.__schema__(:unique_fields))
    errors = Keyword.drop(errors, struct.__schema__(:unique_fields))
    valid? = errors == []

    # replace data & types with current schema to be able to continue in original changeset
    %{
      changeset
      | data: data,
        types: struct.__changeset__(),
        changes: changes,
        errors: errors,
        valid?: valid?
    }
  end
end

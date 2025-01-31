defmodule EctoDiscriminator.Schema do
  @moduledoc """
  Wrapper around `Ecto.Schema` that enables inheritance of schema fields.

  It has been built to mimic `Ecto.Schema` as much as possible.

  ## Base schema

  To make a base schema you have to do two things:
  1. Change `use Ecto.Schema` to `use EctoDiscriminator.Schema`:

          defmodule SomeTable do
            use EctoDiscriminator.Schema

  2. Add `EctoDiscriminator.DiscriminatorType` field to schema (check module documentation for more examples):

          schema "some_table" do
            field :type, EctoDiscriminator.DiscriminatorType
            ...
          end

  Base schemas should ideally contain only fields that are common across all diverged schemas (like timestamps).
  There is no problem with having other fields defined if someone needs it for some functionality though.
  Any field can be overriden by diverged schema.

  #### Diverged changeset

  Base schemas have predefined function, based on [`DiscriminatorChangeset.diverged_changeset/2`](`EctoDiscriminator.DiscriminatorChangeset.diverged_changeset/2`),
  that allows creating changesets for diverged schemas directly from base (check [here](`EctoDiscriminator.DiscriminatorChangeset.diverged_changeset/2`) for more).

  ## Diverged schema

  To make a diverged schema you have to do two things:
  1. Change `use Ecto.Schema` to `use EctoDiscriminator.Schema`:

          defmodule SomeTable.Foo do
            use EctoDiscriminator.Schema

  2. Define schema with name of base schema as a source:

          schema SomeTable do
            field ...
            ...
          end

  Diverged schemas can contain any field supported by `Ecto.Schema`.

  #### Inheriting struct-related stuff

  ##### @derive

  Any `@derive` declarations put in base schema will be applied to the diverged schema. You can still overwrite those for particular schema if needed.

  #### Going back to base struct

  ##### Base struct

  Diverged schemas have predefined function `to_base/1` that applies simple modifications in order to get base struct from diverged.

  ##### Base changeset

  Diverged schemas have predefined function, based on [`DiscriminatorChangeset.base_changeset/2`](`EctoDiscriminator.DiscriminatorChangeset.base_changeset/2`),
  that allows creating changesets for base schemas directly from diverged (check [here](`EctoDiscriminator.DiscriminatorChangeset.base_changeset/2`) for more).

  #### Casting base fields

  Diverged schemas have predefined function, based on [`DiscriminatorChangeset.cast_base/2`](`EctoDiscriminator.DiscriminatorChangeset.cast_base/2`),
  that allows running base changesets inside changeset of diverged schema
  (check [here](`EctoDiscriminator.DiscriminatorChangeset.cast_base/2`) for more).

  ## Querying

  Diverged schemas have some logic injected that allows very simple querying:

      MyApp.Repo.all(SomeTable.Foo)

  This will generate SQL similar to this:

      SELECT ... FROM some_table WHERE discriminator = "Elixir.SomeTable.Foo"

  This functionality should be enough in most cases,
  however if the injected `where` condition causes some issues (eg. in some advanced SQL) you can exclude it on the beginning:

      SomeTable.Foo
      |> exclude(:where)
      |> MyApp.Repo.all()
      #=> SELECT ... FROM some_table
  """

  @discriminator_type EctoDiscriminator.DiscriminatorType
  @discriminator_type_alias @discriminator_type
                            |> Module.split()
                            |> Enum.map(&String.to_atom/1)

  defmacro __using__(_), do: set_up_schema()

  defmacro __before_compile__(env) do
    inheritance_helpers(env)
  end

  @doc """
  Main building block for inheritance logic.

  `schema/2` wraps `Ecto.Schema.schema/2`, adding some features required to support idea of this library.

  For base schema, `source` should be the name of a DB table:

      schema "some_table" do

  For diverged schema, `source` must be the name of a base module:

      schema SomeTable do

  Additionally, inside `schema/2` of the base schema you have to add field which will be acting as a discriminator:

      field :type, EctoDiscriminator.DiscriminatorType
  """
  # for base schema, when source is actually table name
  # here we only store some module attributes, and schema is actually injected in __before_compile__
  # this makes it possible to read @discriminator attribute of schema module and add it to Ecto schema
  defmacro schema(source, do: fields) when is_binary(source) do
    # store fields in module attribute to retrieve them in before_compile handler
    Module.put_attribute(__CALLER__.module, :fields_def, fields)

    helpers =
      quote do
        # nothing to do, we're already in base
        def to_base(%__MODULE__{} = struct), do: struct
        def __schema__(:unique_fields), do: []
      end

    # helpers must come last to use __MODULE__
    [call_ecto_schema(source, nil, [fields]), helpers]
  end

  # for diverged schema when source is name of the module from which we inherit fields
  defmacro schema(source, do: fields) do
    source_module = Macro.expand(source, __CALLER__)
    caller_module = __CALLER__.module
    merged_fields = get_merged_fields(source_module, caller_module, fields)
    unique_fields_macro = unique_fields_macro(merged_fields, fields)

    # primary key must be explicitly set before ecto schema macro kicks off
    primary_key_def =
      case source_module.__schema__(:primary_key_def) do
        {name, @discriminator_type, opts} ->
          {name, @discriminator_type, [{:default, caller_module} | opts]}

        pk ->
          pk
      end

    primary_key =
      quote do
        if is_nil(@primary_key) do
          @primary_key unquote(Macro.escape(primary_key_def))
        end
      end

    # call genuine Ecto.Schema and inject our stuff
    schema =
      source_module.__schema__(:source)
      |> call_ecto_schema(source_module, merged_fields)
      |> inject_where(source_module)

    helpers = diverged_helpers(source_module)

    Module.put_attribute(caller_module, :fields_def, merged_fields)

    [primary_key, schema, helpers, unique_fields_macro]
  end

  # transforms `struct` to `destination`
  def to_base(%source{} = struct, destination) do
    state = get_in(struct, [Access.key(:__meta__), Access.key(:state)])

    data =
      struct
      |> Map.from_struct()
      |> maybe_update_meta(destination)
      # take only unique items that hold some value
      # we want to use nil values only if it came from the persisted entitys
      |> Enum.reject(fn {key, value} ->
        match?(%Ecto.Association.NotLoaded{}, value) ||
          key in source.__schema__(:unique_fields) ||
          (is_nil(value) && state == :built)
      end)
      # we have to recursively map things to their base variants (if available)
      |> Enum.map(fn {key, value} ->
        case destination.__schema__(:embed, key) do
          %{related: related} when is_struct(value) ->
            {key, to_base(value, related)}

          _ ->
            {key, value}
        end
      end)
      |> Enum.into(%{})

    struct(destination, data)
  end

  defp maybe_update_meta(%{__meta__: %{schema: _}} = map, destination) do
    # have to update __meta__ because it comes from different schema
    put_in(map, [Access.key(:__meta__), Access.key(:schema)], destination)
  end

  defp maybe_update_meta(map, _destination), do: map

  defp set_up_schema() do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]

      @before_compile EctoDiscriminator.Schema
      @derive EctoDiscriminator.DiscriminatorChangeset

      # use protocol to get out-of-the-box consolidation
      # Dialyzer doesn't really pick up this protocol properly and will issue warnings within each schema
      defprotocol Diverged do
        Protocol.def(dummy(struct))
      end
    end
  end

  defp call_ecto_schema(source_table, nil, fields) do
    import Ecto.Schema, only: [schema: 2]

    base_derived =
      quote unquote: false do
        # expose derived Protocols to be inherited
        derived = Module.get_attribute(__MODULE__, :derive, [])

        def __schema__(:derived), do: unquote(derived)
      end

    schema =
      quote do
        schema unquote(source_table) do
          (unquote_splicing(fields))
        end
      end

    [base_derived, schema]
  end

  defp call_ecto_schema(source_table, source_module, fields) do
    # inherit any derived protocols
    derived =
      quote bind_quoted: [base_derived: source_module.__schema__(:derived)] do
        derived = Module.get_attribute(__MODULE__, :derive, [])

        derived
        |> Kernel.++(base_derived)
        |> Enum.uniq_by(fn
          {k, _} -> k
          k when is_atom(k) -> k
        end)
        # remove those already defined in current schema after filtering out inherited ones
        |> Enum.reject(&Enum.member?(derived, &1))
      end

    schema = call_ecto_schema(source_table, nil, fields)

    quote do
      to_be_derived = unquote(derived)
      unquote(schema)
      Protocol.__derive__(to_be_derived, __MODULE__, __ENV__)
    end
  end

  defp unique_fields_macro(merged_fields, fields) do
    {_, existing_field_names} =
      fields
      |> Macro.prewalk([], fn
        # return nil to avoid going inside this AST
        {_, _, [name | _]}, acc when is_atom(name) -> {nil, [name | acc]}
        other, acc -> {other, acc}
      end)

    {_, unique_fields_names} =
      merged_fields
      |> Macro.prewalk([], fn
        # return nil to avoid going inside this AST
        {_, meta, [name | _]}, acc when is_atom(name) ->
          if name in existing_field_names && !Keyword.has_key?(meta, :duplicate) do
            # from all fields we treat as unique only the ones that current schema defines and have different type
            {nil, [name | acc]}
          else
            {nil, acc}
          end

        other, acc ->
          {other, acc}
      end)

    quote do
      def __schema__(:unique_fields), do: unquote(unique_fields_names)
    end
  end

  defp get_merged_fields(source_module, caller_module, fields) do
    {pk_name, _, _} = pk_def = source_module.__schema__(:primary_key_def)

    existing_fields_by_name =
      source_module.__schema__(:fields_def)
      |> Macro.prewalk(fn
        {:field, meta, [name, {:__aliases__, _, @discriminator_type_alias} = alias | rest]} ->
          # set default value to the module that's requesting common fields
          rest = merge_rest_options(rest, default: caller_module)
          {:field, meta, [name, alias | rest]}

        # resolve embeds aliases on the source module level
        # this applies only when embed is defined inline (rest is not empty)
        {:embeds_one, meta,
         [
           field,
           {:__aliases__, _, alias}
           | rest
         ]}
        when rest != [] ->
          {:embeds_one, meta, [field, {:__aliases__, meta, [Elixir, source_module | alias]}]}

        # we have to do some extra rewritting for relationships
        {:has_one, meta, [field, type | rest]} ->
          rest =
            with %{related_key: key} <- source_module.__schema__(:association, field) do
              case rest do
                [] -> [[foreign_key: key]]
                [opts] -> [Keyword.put(opts, :foreign_key, key)]
              end
            else
              _ -> rest
            end

          {:has_one, meta, [field, type | rest]}

        other ->
          other
      end)
      |> ast_kv_by_field_name()
      # add primary key to existing fields for comparison
      |> Keyword.put(pk_name, pk_def)

    fields
    |> ast_kv_by_field_name()
    |> Keyword.merge(existing_fields_by_name, fn
      # if there is conflict on field that is discriminator in base schema then abort
      _, _, {_, _, [name, {:__aliases__, _, @discriminator_type_alias}, _]} ->
        raise_for_override(name)

      # the same as above but discriminator is primary key
      _, _, {name, @discriminator_type, _} ->
        raise_for_override(name)

      _,
      {field_type, _, [name, type | rest]} = new,
      {field_type, meta, [name, existing_type | existing_rest]} ->
        # otherwise in case of conflict and matching types, merge options
        if Macro.expand(type, __ENV__) == Macro.expand(existing_type, __ENV__) do
          rest = merge_rest_options(existing_rest, rest)
          add_duplicate_meta({field_type, meta, [name, type | rest]})
        else
          new
        end

      # in all other cases just pick the new one
      _, new, _old ->
        new
    end)
    # drop primary key since it's not part of fields def
    |> Keyword.delete(pk_name)
    |> Keyword.values()
    # reverse to mantain the same order as in code this is important in terms of relationships
    |> Enum.reverse()
  end

  defp ast_kv_by_field_name(ast) do
    {_, ast_kv} =
      Macro.prewalk(ast, [], fn
        # return nil to avoid going inside this AST
        {_, _, [name | _]} = ast, acc when is_atom(name) -> {nil, [{name, ast} | acc]}
        # in case we call macro inside schema
        {name, _, _} = ast, acc when name != :__block__ -> {nil, [{name, ast} | acc]}
        other, acc -> {other, acc}
      end)

    ast_kv
  end

  defp add_duplicate_meta(ast) do
    update_in(ast, [Access.elem(1)], &Keyword.put(&1, :duplicate, true))
  end

  defp merge_rest_options(rest, opts) do
    {opts, opts_rest} =
      case opts do
        [op | rest] -> {op, rest}
        op -> {op, []}
      end

    opts = List.wrap(opts)

    case rest do
      [] when opts == [] -> []
      [] -> [opts]
      [existing | _] -> [Keyword.merge(existing, opts) | opts_rest]
    end
  end

  defp diverged_helpers(source) do
    source_protocol = Module.concat(source, Diverged)

    helpers =
      quote generated: true do
        defimpl unquote(source_protocol) do
          def dummy(_), do: nil
        end

        def to_base(%__MODULE__{} = struct),
          do: EctoDiscriminator.Schema.to_base(struct, unquote(source))
      end

    changeset_helpers =
      if function_exported?(source, :changeset, 2) do
        quote bind_quoted: [source: source] do
          defp cast_base(data, params),
            do: EctoDiscriminator.DiscriminatorChangeset.cast_base(data, params)

          # add special changeset that will make possible to produce base schema changesets using diverged module name
          def base_changeset(struct, params \\ %{}),
            do: EctoDiscriminator.DiscriminatorChangeset.base_changeset(struct, params)
        end
      end

    [helpers, changeset_helpers]
  end

  defp inheritance_helpers(env) do
    fields_def =
      Module.get_attribute(env.module, :fields_def)
      |> Macro.prewalk(fn
        # resolve aliases from module that defines those helpers
        {:__aliases__, meta, _} = ast ->
          {:__aliases__, meta, Macro.expand(ast, env) |> module_to_atoms()}

        # resolve module attributes before diverged schema calls for fields_def
        {:@, _, [{var_name, _, _}]} ->
          Module.get_attribute(env.module, var_name)

        other ->
          other
      end)

    primary_key = Module.get_attribute(env.module, :primary_key)

    discriminator_name = lookup_discriminator_field_name(fields_def, primary_key)

    protocol_name = Module.concat(env.module, Diverged)

    quote generated: true do
      # expose fields from source schema so diverged schemas can add them to their schemas
      # we need this because when fields go through ecto schema there is no simple way of retrieving their full definition
      def __schema__(:fields_def), do: unquote(Macro.escape(fields_def))

      def __schema__(:primary_key_def), do: unquote(Macro.escape(primary_key))

      # add discriminator variant of __schema__ function so any schema can directly get the discriminator field name
      def __schema__(:discriminator), do: unquote(discriminator_name)

      # add __schema__ function that returns list of diverged modules
      def __schema__(:diverged) do
        case unquote(protocol_name).__protocol__(:impls) do
          {:consolidated, list} -> list
          _ -> []
        end
      end

      # add special changeset that will make possible to produce diverged schema changesets using base module name
      def diverged_changeset(struct, params \\ %{}),
        do: EctoDiscriminator.DiscriminatorChangeset.diverged_changeset(struct, params)
    end
  end

  # adds default where clause to the query to reduce results to single type
  defp inject_where(schema, source) do
    import Ecto.Query, only: [where: 2]

    field = source.__schema__(:discriminator)
    virtual_fields = source.__schema__(:virtual_fields)

    if field in virtual_fields do
      # if discriminator is virtual field then we don't apply `where`
      schema
    else
      prefix = source.__schema__(:prefix)
      source_table = source.__schema__(:source)

      updated_schema_query_fn =
        quote bind_quoted: [prefix: prefix, source_table: source_table, field: field] do
          def __schema__(:query) do
            query = %Ecto.Query{
              from: %Ecto.Query.FromExpr{
                source: {unquote(source_table), __MODULE__},
                prefix: unquote(prefix)
              }
            }

            where(query, [{unquote(field), unquote(__MODULE__)}])
          end
        end

      Macro.prewalk(schema, fn
        {:schema, _, _} = ast ->
          # do this to get AST after running schema macro
          Macro.expand_once(ast, __ENV__)

        # make sure this def comes from Ecto
        {:def, _, [{:__schema__, [context: Ecto.Schema], [:query]}, _]} ->
          updated_schema_query_fn

        other ->
          other
      end)
    end
  end

  defp lookup_discriminator_field_name(fields, primary_key) do
    {_, discriminator_name} =
      fields
      |> Macro.prewalk(nil, fn
        {:field, _, [name, {:__aliases__, _, @discriminator_type_alias} | _]} = ast, _ ->
          {ast, name}

        other, acc ->
          {other, acc}
      end)

    # if base schema haven't defined discriminator explicitly, try to look in other places and eventually raise an error
    if is_nil(discriminator_name) do
      case primary_key do
        {name, @discriminator_type, _} ->
          name

        _ ->
          raise ArgumentError,
                "EctoDiscriminator requires a field with type #{inspect(@discriminator_type)} to work."
      end
    else
      discriminator_name
    end
  end

  defp module_to_atoms(module) do
    module
    |> Module.split()
    |> Enum.map(&String.to_atom/1)
  end

  defp raise_for_override(name) do
    raise ArgumentError, "Field `#{name}` is used as the discriminator and can't be overriden"
  end
end

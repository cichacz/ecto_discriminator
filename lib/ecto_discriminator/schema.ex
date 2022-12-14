defmodule EctoDiscriminator.Schema do
  @discriminator_type EctoDiscriminator.DiscriminatorType
  @discriminator_type_alias @discriminator_type
                            |> Module.split()
                            |> Enum.map(&String.to_atom/1)

  defmacro __using__(_), do: set_up_schema()

  defmacro __before_compile__(env) do
    inheritance_helpers(env)
  end

  # for base schema, when source is actually table name
  # here we only store some module attributes, and schema is actually injected in __before_compile__
  # this makes it possible to read @discriminator attribute of schema module and add it to Ecto schema
  defmacro schema(source, do: fields) when is_binary(source) do
    # store fields in module attribute to retrieve them in before_compile handler
    Module.put_attribute(__CALLER__.module, :fields_def, fields)

    call_ecto_schema(source, [fields])
  end

  # for diverged schema when source is name of the module from which we inherit fields
  defmacro schema(source, do: fields) do
    source_module = Macro.expand(source, __CALLER__)
    caller_module = __CALLER__.module
    common_fields = get_common_fields(source_module, caller_module, fields)
    fields = [fields, common_fields]

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
      |> call_ecto_schema(fields)
      |> inject_where(source_module)

    helpers = diverged_helpers(source_module)

    Module.put_attribute(caller_module, :fields_def, fields)

    [primary_key, schema, helpers]
  end

  def lookup_discriminator_field_name(fields, primary_key) do
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

  defp set_up_schema() do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]

      @before_compile EctoDiscriminator.Schema
      @derive EctoDiscriminator.DiscriminatorSchema
    end
  end

  defp call_ecto_schema(source_table, fields) do
    import Ecto.Schema, only: [schema: 2]

    quote do
      schema unquote(source_table) do
        (unquote_splicing(fields))
      end
    end
  end

  defp get_common_fields(source_module, caller_module, existing_fields) do
    {_, existing_field_names} =
      existing_fields
      |> Macro.prewalk([], fn
        # return nil to avoid going inside this AST
        {_, _, [name | _]}, acc when is_atom(name) -> {nil, [name | acc]}
        other, acc -> {other, acc}
      end)

    source_module
    |> apply(:__schema__, [:fields_def])
    |> process_common_fields(existing_field_names, caller_module)
  end

  defp process_common_fields(common_fields_ast, existing_field_names, caller_module) do
    common_fields_ast
    |> Macro.prewalk(fn
      {:field, meta, [name, {:__aliases__, _, @discriminator_type_alias} = alias | rest]} ->
        if name in existing_field_names do
          raise "Field #{name} is used as the discriminator and can't be overriden"
        end

        # set default value to the module that's requesting common fields
        rest =
          case rest do
            [] -> [[default: caller_module]]
            [opts] -> [Keyword.put(opts, :default, caller_module)]
          end

        {:field, meta, [name, alias | rest]}

      {_, _, [name | _]} = ast when is_atom(name) ->
        # we want only fields that aren't overridden in current schema
        unless name in existing_field_names do
          ast
        end

      other ->
        other
    end)
  end

  defp diverged_helpers(source) do
    if function_exported?(source, :changeset, 2) do
      quote bind_quoted: [source: source] do
        defp cast_base(%Ecto.Changeset{} = changeset, params) do
          changeset.data
          |> cast_base(params)
          |> merge(changeset)
        end

        defp cast_base(%_{} = data, params),
          do: EctoDiscriminator.DiscriminatorSchema.cast_base(data, params, unquote(source))
      end
    end
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

    discriminator_name =
      EctoDiscriminator.Schema.lookup_discriminator_field_name(fields_def, primary_key)

    quote do
      # expose fields from source schema so diverged schemas can add them to their schemas
      # we need this because when fields go through ecto schema there is no simple way of retrieving their full definition
      def __schema__(:fields_def), do: unquote(Macro.escape(fields_def))

      def __schema__(:primary_key_def), do: unquote(Macro.escape(primary_key))

      # add discriminator variant of __schema__ function so any schema can directly get the discriminator field name
      def __schema__(:discriminator), do: unquote(discriminator_name)

      # add special changeset that will make possible to produce diverged schema changesets using base module name
      def diverged_changeset(struct, params \\ %{}),
        do: EctoDiscriminator.DiscriminatorSchema.diverged_changeset(struct, params)
    end
  end

  # adds default where clause to the query to reduce results to single type
  defp inject_where(schema, source) do
    import Ecto.Query, only: [where: 2]

    updated_schema_query_fn =
      quote bind_quoted: [source: source] do
        prefix = source.__schema__(:prefix)
        source_table = source.__schema__(:source)
        field = source.__schema__(:discriminator)

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

  defp module_to_atoms(module) do
    module
    |> Module.split()
    |> Enum.map(&String.to_atom/1)
  end
end

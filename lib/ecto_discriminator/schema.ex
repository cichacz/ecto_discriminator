defmodule EctoDiscriminator.Schema do
  defmacro __using__(_), do: set_up_schema()

  # for base schema, when source is actually table name
  # here we only store some module attributes, and schema is actually injected in __before_compile__
  # this makes it possible to read @discriminator attribute of schema module and add it to Ecto schema
  defmacro schema(source, do: fields) when is_binary(source) do
    discriminator_field = build_discriminator_field(__CALLER__.module)
    fields = [fields, discriminator_field]

    schema = call_ecto_schema(source, [fields])
    macros = common_fields_macro(fields)
    helpers = define_helpers()

    [helpers, macros, schema]
  end

  # for diverged schema when source is name of the module from which we inherit fields
  defmacro schema(source, do: fields) do
    source_module = Macro.expand(source, __ENV__)
    base_module = get_base_module(source_module)
    common_fields = get_common_fields(source_module, fields)

    source_table = base_module.__schema__(:source)
    diverged_helpers = define_diverged_helpers(source_module, base_module)

    # call genuine Ecto.Schema and inject our stuff
    schema_ast =
      source_table
      |> call_ecto_schema([fields, common_fields])
      |> inject_where(base_module)

    # build common_fields_macro so others can inherit from this schema
    macros = common_fields_macro([fields, common_fields])

    [diverged_helpers, macros, schema_ast]
  end

  defp set_up_schema() do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]
    end
  end

  defp build_discriminator_field(base_module) do
    import Ecto.Schema, only: [field: 2]

    quote do
      # if we are injecting it to the base schema then there should be no default value
      default = if unquote(base_module) == __MODULE__, do: nil, else: __MODULE__
      field(@discriminator, EctoDiscriminator.AtomType, default: default)
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

  defp get_common_fields(source, existing_fields) do
    existing_field_names =
      existing_fields
      |> Macro.prewalk(fn
        {_, _, [name | _]} when is_atom(name) -> name
        other -> other
      end)
      |> case do
        {_, _, names} -> names
        name -> [name]
      end

    quote do
      import unquote(source), only: [common_fields: 1]
      unquote(source).common_fields(unquote(existing_field_names))
    end
  end

  # used to retrieve base schema (the one that doesn't inherit from anything)
  defp get_base_module(source) do
    apply(source, :__schema__, [:base_module])
  rescue
    FunctionClauseError -> source
  end

  # expose fields from source schema so diverged schemas can add them to their schemas
  # we need this because when fields go through ecto schema there is no simple way of retrieving their full definition
  defp common_fields_macro(common_fields_ast) do
    quote do
      defmacro common_fields(existing_field_names) do
        unquote(Macro.escape(common_fields_ast))
        |> Macro.prewalk(fn
          {_, _, [name | _]} = ast when is_atom(name) ->
            # we want only fields that aren't overridden in current schema
            unless name in existing_field_names do
              ast
            end

          other ->
            other
        end)
      end
    end
  end

  defp define_helpers() do
    quote do
      def __schema__(:discriminator), do: @discriminator

      def diverged_changeset(struct, params \\ %{}), do: cast_diverged(struct, params)

      defp cast_diverged(%Ecto.Changeset{} = changeset, params) do
        changeset.data
        |> cast_diverged(params)
        |> Ecto.Changeset.merge(changeset)
      end

      defp cast_diverged(%_{} = data, params) do
        discriminator_struct = Map.get(params, @discriminator, data.__struct__)

        if function_exported?(discriminator_struct, :changeset, 2) do
          # just call changeset from the derived schema and hope it calls cast_base to pull fields from the base schema
          data
          |> Map.put(:__struct__, discriminator_struct)
          |> discriminator_struct.changeset(params)
        else
          data
        end
      end
    end
  end

  defp define_diverged_helpers(source, base_module) do
    quote bind_quoted: [source: source, base_module: base_module] do
      # for diverged schemas set it based on base schema
      @discriminator base_module.__schema__(:discriminator)

      def __schema__(:base_module), do: unquote(base_module)

      if function_exported?(source, :changeset, 2) do
        import Ecto.Changeset

        field = base_module.__schema__(:discriminator)

        defp cast_base(%Ecto.Changeset{} = changeset, params) do
          changeset.data
          |> cast_base(params)
          |> merge(changeset)
        end

        defp cast_base(%_{} = struct, params) do
          # we have to change type of our struct to call changeset of source schema
          struct
          |> Map.put(:__struct__, unquote(source))
          |> unquote(source).changeset(params)
          # replace data & types with current schema to be able to continue in original changeset
          |> Map.put(:data, struct)
          |> Map.put(:types, __MODULE__.__changeset__())
          # add discriminator field to changeset
          |> cast(params, [unquote(field)])
          |> validate_required(unquote(field))
        end
      end
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
end

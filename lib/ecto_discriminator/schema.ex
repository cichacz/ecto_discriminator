defmodule EctoDiscriminator.Schema do
  defmacro __using__(_), do: set_up_schema()

  # this has to be done as the last thing in the module so the discriminator attribute is readable at compile time
  defmacro __before_compile__(_env) do
    import Ecto.Schema, only: [field: 3]

    discriminator_root = Module.get_attribute(__CALLER__.module, :discriminator_root)

    if discriminator_root do
      discriminator_name = Module.get_attribute(__CALLER__.module, :discriminator)
      source_table = Module.get_attribute(__CALLER__.module, :source_table)

      {:__block__, block_meta, common_fields_ast} =
        Module.get_attribute(__CALLER__.module, :common_fields)

      discriminator_field = build_discriminator_field(discriminator_name)
      fields = {:__block__, block_meta, [discriminator_field | common_fields_ast]}

      schema = call_ecto_schema(source_table, [fields])
      macros = common_fields_macro(fields, discriminator_name)
      schema_fn = define_helpers(discriminator_name)

      [schema, macros, schema_fn]
    end
  end

  # for root schema, when source is actually table name
  # here we only store some module attributes, and schema is actually injected in __before_compile__
  # this makes it possible to read @discriminator attribute of schema module and add it to Ecto schema
  defmacro schema(source, do: fields) when is_binary(source) do
    Module.put_attribute(__CALLER__.module, :discriminator_root, true)
    Module.put_attribute(__CALLER__.module, :common_fields, fields)
    Module.put_attribute(__CALLER__.module, :source_table, source)
  end

  # for child schema when source is name of root module
  defmacro schema(source, do: fields) do
    common_fields = get_common_fields(source, fields)
    source_table = quote(do: unquote(source).__schema__(:source))
    changeset_helpers = define_changeset_helpers(source)

    # call genuine Ecto.Schema and inject our stuff
    schema_ast =
      source_table
      |> call_ecto_schema([fields, common_fields])
      |> inject_where(source)

    [schema_ast, changeset_helpers]
  end

  defp set_up_schema() do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]

      @before_compile EctoDiscriminator.Schema
    end
  end

  defp build_discriminator_field(discriminator) do
    import Ecto.Schema, only: [field: 2]

    quote do
      field(unquote(discriminator), EctoDiscriminator.AtomType)
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
      import unquote(source)
      common_fields(unquote(existing_field_names))
    end
  end

  # expose fields from source schema so children can add them to their schemas
  # we need this because when fields go through ecto schema there is no simple way of retrieving their full definition
  defp common_fields_macro(common_fields_ast, discriminator_name) do
    quote do
      defmacro common_fields(existing_field_names) do
        unquote(Macro.escape(common_fields_ast))
        |> Macro.prewalk(fn
          {head, meta, [unquote(discriminator_name) | _] = opts} = ast ->
            # set default value to the module that's requesting default fields
            {head, meta, opts ++ [[default: __CALLER__.module]]}

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

  defp define_helpers(discriminator_name) do
    quote do
      def __schema__(:discriminator), do: unquote(discriminator_name)
    end
  end

  defp define_changeset_helpers(source) do
    quote do
      if function_exported?(unquote(source), :changeset, 2) do
        def cast_base(struct, params) do
          # we have to change type of our struct to call changeset of source schema
          struct
          |> Map.put(:__struct__, unquote(source))
          |> unquote(source).changeset(params)
          # replace data & types with current schema to be able to continue in original changeset
          |> Map.put(:data, struct)
          |> Map.put(:types, struct.__struct__.__changeset__())
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

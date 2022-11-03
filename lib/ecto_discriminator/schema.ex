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

      quote do
        unquote(schema)
        unquote(macros)
      end
    end
  end

  # for root schema, when schema is actually table name
  # here we only store some module attributes, and schema is actually injected in __before_compile__
  defmacro schema(source, do: fields) when is_binary(source) do
    Module.put_attribute(__CALLER__.module, :discriminator_root, true)
    Module.put_attribute(__CALLER__.module, :common_fields, fields)
    Module.put_attribute(__CALLER__.module, :source_table, source)
  end

  # for child schema when schema is name of root module
  defmacro schema(source, do: fields) do
    # we have to call source schema during runtime to receive discriminator field data
    common_fields = get_common_fields(source, fields)
    source_table = quote(do: unquote(source).__schema__(:source))

    # call genuine Ecto.Schema and inject our logic
    source_table
    |> call_ecto_schema([fields, common_fields])
    |> inject_where(source)
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
    quote do
      import unquote(source)
      common_fields(unquote(existing_fields))
    end
  end

  # expose fields from source schema so children can add them to their schemas
  defp common_fields_macro(common_fields_ast, discriminator_name) do
    quote do
      # this macro can be called only during compilation, otherwise put_attribute will fail
      defmacro common_fields(existing_fields) do
        Module.put_attribute(__CALLER__.module, :discriminator, unquote(discriminator_name))

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

        unquote(Macro.escape(common_fields_ast))
        |> Macro.prewalk(fn
          {head, meta, [unquote(discriminator_name) | _] = opts} = ast ->
            # set default value to the module that's requesting default fields
            {head, meta, opts ++ [[default: __CALLER__.module]]}

          {_, _, [name | _]} = ast when is_atom(name) ->
            unless name in existing_field_names do
              ast
            end

          other ->
            other
        end)
      end
    end
  end

  # adds default where clause to the query to reduce results to single type
  defp inject_where(schema, source) do
    import Ecto.Query, only: [where: 2]

    updated_schema_query_fn =
      quote bind_quoted: [source: source] do
        value = __MODULE__
        field = Module.get_attribute(__MODULE__, :discriminator)
        prefix = Module.get_attribute(__MODULE__, :schema_prefix)
        source_table = source.__schema__(:source)

        def __schema__(:query) do
          query = %Ecto.Query{
            from: %Ecto.Query.FromExpr{
              source: {unquote(source_table), __MODULE__},
              prefix: unquote(prefix)
            }
          }

          where(query, [{unquote(field), unquote(value)}])
        end
      end

    Macro.prewalk(schema, fn
      {:schema, [context: __MODULE__, import: Ecto.Schema], _} = ast ->
        Macro.expand_once(ast, __ENV__)

      {:def, _, [{:__schema__, [context: Ecto.Schema], [:query]}, _]} ->
        updated_schema_query_fn

      other ->
        other
    end)
  end
end

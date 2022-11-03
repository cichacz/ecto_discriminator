defmodule EctoDiscriminator.Schema do
  defmacro __using__(discriminator) do
    if discriminator do
      Module.register_attribute(__CALLER__.module, :discriminator, persist: true)
      Module.put_attribute(__CALLER__.module, :discriminator, discriminator)
    end

    set_up_schema()
  end

  # for root schema, when schema is actually table name
  defmacro schema(source, do: fields) when is_binary(source) do
    discriminator = Module.get_attribute(__CALLER__.module, :discriminator)

    discriminator_field = build_discriminator_field(discriminator)
    macros = fields_macros(fields)
    schema = call_ecto_schema(source, fields, discriminator_field)

    quote do
      unquote(macros)
      unquote(schema)
    end
  end

  # for child schema when schema is name of root module
  defmacro schema(source, do: fields) do
    module_name = __CALLER__.module
    discriminator = Module.get_attribute(Macro.expand(source, __ENV__), :discriminator)

    discriminator_field = build_discriminator_field(discriminator, module_name)

    common_fields = get_common_fields(source, fields)
    queryable = inject_where(source)
    schema = call_ecto_schema(source, fields, common_fields, discriminator_field)

    quote do
      unquote(queryable)
      unquote(schema)
    end
  end

  defp set_up_schema() do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]
    end
  end

  defp build_discriminator_field(discriminator, default \\ nil) do
    import Ecto.Schema, only: [field: 2]

    quote do
      field(unquote(discriminator), EctoDiscriminator.AtomType, default: unquote(default))
    end
  end

  defp get_common_fields(source, existing_fields) do
    quote do
      import unquote(source)
      common_fields(unquote(existing_fields))
    end
  end

  defp fields_macros(common_fields_ast) do
    quote do
      defmacro common_fields(existing_fields \\ []) do
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
          {_, _, [name | _]} = ast when is_atom(name) ->
            unless name in existing_field_names do
              ast
            end

          other ->
            other
        end)
        |> Macro.expand(__ENV__)
      end
    end
  end

  defp call_ecto_schema(source, fields, discriminator_field) when is_binary(source) do
    import Ecto.Schema, only: [schema: 2]

    quote do
      schema unquote(source) do
        unquote(fields)
        unquote(discriminator_field)
      end
    end
  end

  defp call_ecto_schema(source, fields, common_fields, discriminator_field) do
    import Ecto.Schema, only: [schema: 2]

    quote do
      source_table = unquote(source).__schema__(:source)

      schema source_table do
        unquote(fields)
        unquote(common_fields)
        unquote(discriminator_field)
      end
    end
  end

  defp inject_where(source) do
    import Ecto.Query, only: [where: 2]

    discriminator = Module.get_attribute(Macro.expand(source, __ENV__), :discriminator)

    quote bind_quoted: [source: source, field: discriminator] do
      value = __MODULE__

      prefix = Module.get_attribute(__MODULE__, :schema_prefix)
      source_table = source.__schema__(:source)

      # unfortunately we have to overwrite it that ugly way...
      # it will warn that the original __schema__(:query) can't match because of this one
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
  end
end

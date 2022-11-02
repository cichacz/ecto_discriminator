defmodule EctoDiscriminator.Schema do
  defmacro __using__(_), do: set_up_schema()

  # this has to be done as the last thing in the module so the attribute is readable at compile time
  defmacro __before_compile__(_env) do
    import Ecto.Schema, only: [field: 3]

    discriminator_name = Module.get_attribute(__CALLER__.module, :discriminator)

    if discriminator_name do
      {:field, meta, opts} = build_discriminator_field(discriminator_name)

      quote do
        defmacro discriminator_field_name(), do: unquote(discriminator_name)

        defmacro discriminator_field(default) do
          {:field, unquote(meta), unquote(opts) ++ [[default: default]]}
        end
      end
    end
  end

  # for root schema, when schema is actually table name
  defmacro schema(source, do: fields) when is_binary(source) do
    discriminator =
      quote do
        Module.get_attribute(__MODULE__, :discriminator)
      end

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
    module_name = to_string(__CALLER__.module)

    discriminator_field =
      quote do
        import unquote(source), only: [discriminator_field: 1]
        discriminator_field(unquote(module_name))
      end

    common_fields = get_common_fields(source)
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

      @before_compile EctoDiscriminator.Schema
    end
  end

  defp build_discriminator_field(discriminator) do
    import Ecto.Schema, only: [field: 2]

    quote do
      field(unquote(discriminator), :string)
    end
  end

  defp get_common_fields(source) do
    quote do
      import unquote(source)
      common_fields()
    end
  end

  defp fields_macros(common_fields_ast) do
    quote do
      defmacro common_fields(), do: unquote(Macro.escape(common_fields_ast))
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

    discriminator_field =
      quote do
        import unquote(source), only: [discriminator_field_name: 0]
        discriminator_field_name()
      end

    quote bind_quoted: [source: source, field: discriminator_field] do
      value = to_string(__MODULE__)

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

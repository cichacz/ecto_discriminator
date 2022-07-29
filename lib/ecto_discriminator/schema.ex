defmodule EctoDiscriminator.Schema do
  defmacro __using__([discriminator]) do
    quote do
      use Ecto.Schema

      # replace original macro
      import Ecto.Schema, except: [schema: 2]
      import EctoDiscriminator.Schema, only: [schema: 2]

      Module.put_attribute(__MODULE__, :discriminator, unquote(discriminator))
    end
  end

  defmacro schema(source, do: block) do
    import Ecto.Schema, only: [schema: 2]

    fields = add_discriminator_field(block)
    schema = call_ecto_schema(source, fields)
    queryable = inject_where(source)

    quote do
      unquote(queryable)
      unquote(schema)
    end
  end

  defp add_discriminator_field(fields) do
    import Ecto.Schema, only: [field: 3]

    quote do
      {field_name, value} = Module.get_attribute(__MODULE__, :discriminator)

      unquote(fields)
      field(field_name, :string, default: value)
    end
  end

  defp call_ecto_schema(source, fields) do
    import Ecto.Schema, only: [schema: 2]

    quote do
      schema(unquote(source), do: unquote(fields))
    end
  end

  defp inject_where(source) do
    import Ecto.Query, only: [where: 2]

    quote bind_quoted: [
            source: source
          ] do
      {field, value} = Module.get_attribute(__MODULE__, :discriminator)
      prefix = Module.get_attribute(__MODULE__, :schema_prefix)

      # unfortunately we have to overwrite it that ugly way...
      def __schema__(:query) do
        query = %Ecto.Query{
          from: %Ecto.Query.FromExpr{
            source: {unquote(source), __MODULE__},
            prefix: unquote(prefix)
          }
        }

        where(query, [{unquote(field), unquote(value)}])
      end
    end
  end
end

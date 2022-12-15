defmodule EctoDiscriminator.DiscriminatorType do
  @moduledoc """
  A custom type used by the `EctoDiscriminator.Schema` to know which field should be used for its logic.

  `EctoDiscriminator.DiscriminatorType` field holds name of the diverged module. Field name can be anything.
  User has to mark exactly one field in the base schema with this type. Diverged schemas will inherit this setting.
  Forgetting to add this field will result in compilation error.
  Basic setup:

      field :type, EctoDiscriminator.DiscriminatorType

  You can also use it as a primary key:

      @primary_key {:id, EctoDiscriminator.DiscriminatorType, []}

  You can configure any options that are supported by `Ecto.Schema`
  (except `virtual` and `default` from obvious reasons).

      field :discriminator, EctoDiscriminator.DiscriminatorType, load_in_query: false

  When it comes to the migrations, the underlying type is just `:string`.
  That said, it's completely fine to create migration with string field:

      add :type, :string

  It's possible to be more restrictive and provide an enum inside DB.
  Keep in mind that module name will be stored in form `Elixir.Module.Name`.
  """

  use Ecto.Type

  def type, do: :string
  def cast(value), do: {:ok, value}
  def load(value), do: {:ok, String.to_existing_atom(value)}
  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def dump(_), do: :error
end

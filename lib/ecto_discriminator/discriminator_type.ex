defmodule EctoDiscriminator.DiscriminatorType do
  @moduledoc """
  Type used by the discriminator field to be able to dump module names to the database
  """

  use Ecto.Type
  def type, do: :string
  def cast(value), do: {:ok, value}
  def load(value), do: {:ok, String.to_existing_atom(value)}
  def dump(value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def dump(_), do: :error
end

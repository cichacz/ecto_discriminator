defmodule EctoDiscriminator.SomeTablePk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias Ecto.Enum

  @primary_key {:type, EctoDiscriminator.DiscriminatorType, []}
  schema "some_table_pk" do
    # make sure field types can contain aliases
    field :title, Enum, values: [:a, :b, :c]
  end

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
  end
end

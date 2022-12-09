defmodule EctoDiscriminator.SomeTablePk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @primary_key {:type, EctoDiscriminator.DiscriminatorType, []}
  schema "some_table_pk" do
    field :title, :string
  end

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
  end
end

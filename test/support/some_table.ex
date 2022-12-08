defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @discriminator :type

  schema "some_table" do
    field :title, :string
    field :content, :map
    belongs_to :parent, EctoDiscriminator.SomeTable.Foo
  end

  def changeset(%__MODULE__{} = struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :content])
    |> put_assoc(:parent, params[:parent])
  end
end

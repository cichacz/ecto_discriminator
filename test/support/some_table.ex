defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema "some_table" do
    field :title, :string
    field :content, :map
    field :type, EctoDiscriminator.DiscriminatorType
    belongs_to :parent, EctoDiscriminator.SomeTable.Foo
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :content])
    |> put_assoc(:parent, params[:parent])
  end
end

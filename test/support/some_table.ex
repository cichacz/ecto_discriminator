defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @discriminator :type

  schema "some_table" do
    field :title, :string
    field :content, :map
    belongs_to :parent, EctoDiscriminator.SomeTable.Foo
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :type])
    |> put_assoc(:parent, params[:parent])
    |> validate_required(:type)
  end
end

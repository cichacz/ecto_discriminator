defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema, type: "foo"

  import Ecto.Changeset

  schema "some_table" do
    field :title, :string
    embeds_one :content, EctoDiscriminator.SomeTable.FooContent
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
    |> cast_embed(:content, required: true)
  end
end

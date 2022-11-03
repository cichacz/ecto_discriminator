defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    field :source, :string
    embeds_one :content, EctoDiscriminator.SomeTable.FooContent
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
    |> cast_embed(:content, required: true)
  end
end

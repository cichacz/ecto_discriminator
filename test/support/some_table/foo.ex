defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    field :source, :string
    embeds_one :content, EctoDiscriminator.SomeTable.FooContent
    has_one :sibling, EctoDiscriminator.SomeTable.Bar, foreign_key: :sibling_id
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> discriminated_changeset(params)
    |> cast(params, [:source])
    |> cast_embed(:content, required: true)
  end
end

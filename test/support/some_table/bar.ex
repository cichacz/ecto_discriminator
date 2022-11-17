defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    embeds_one :content, EctoDiscriminator.SomeTable.BarContent
    belongs_to :sibling, EctoDiscriminator.SomeTable.Foo
    has_one :child, EctoDiscriminator.SomeTable, foreign_key: :parent_id
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> discriminated_changeset(params)
    |> cast_embed(:content)
    |> put_assoc(:sibling, params[:sibling])
  end
end

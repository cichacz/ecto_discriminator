defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    embeds_one :content, EctoDiscriminator.SomeTable.BarContent
    belongs_to :sibling, EctoDiscriminator.SomeTable.Foo
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast_embed(:content)
    |> put_assoc(:sibling, params[:sibling])
  end
end

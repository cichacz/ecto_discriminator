defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    embeds_one :content, EctoDiscriminator.SomeTable.BarContent
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
    |> cast_embed(:content)
  end
end

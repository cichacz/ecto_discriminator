defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema, type: "bar"

  import Ecto.Changeset

  schema "some_table" do
    field :title, :string
    embeds_one :content, EctoDiscriminator.SomeTable.BarContent
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
    |> cast_embed(:content)
  end
end

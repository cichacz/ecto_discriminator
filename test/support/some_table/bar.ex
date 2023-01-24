defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:title]}
  schema EctoDiscriminator.SomeTable do
    has_one :content, EctoDiscriminator.SomeTable.BarContent
    belongs_to :sibling, EctoDiscriminator.SomeTable.Foo
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title])
    |> cast_assoc(:content)
    |> put_assoc(:sibling, params[:sibling])
    # test different order
    |> cast_base(params)
  end
end

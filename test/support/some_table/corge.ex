defmodule EctoDiscriminator.SomeTable.Corge do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable.Bar do
    field :is_special, :boolean
    # content is inherited from Bar
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:is_special])
    |> validate_required([:is_special])
  end
end

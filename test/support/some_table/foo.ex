defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    field :source, :string
    embeds_one :content, EctoDiscriminator.SomeTable.FooContent
    has_one :sibling, EctoDiscriminator.SomeTable.Bar, foreign_key: :sibling_id
    has_one :child, EctoDiscriminator.SomeTable, foreign_key: :parent_id
    has_one :myself, through: [:pk, :not_pk]
  end

  def changeset(struct, params \\ %{}) do
    struct
    # we need to clean the validation status before proceeding
    |> clear_validation_state()
    |> cast_base(params)
    |> cast(params, [:source])
    |> cast_embed(:content, required: true)
  end

  defp clear_validation_state(%Ecto.Changeset{} = changeset) do
    %{changeset | valid?: true, errors: []}
  end

  defp clear_validation_state(other), do: other
end

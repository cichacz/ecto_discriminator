defmodule EctoDiscriminator.SomeTable.Baz do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable do
    field :is_special, :boolean
    has_one :content, EctoDiscriminator.SomeTable.BazContent, foreign_key: :bar_id
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:is_special])
    |> cast_assoc(:content)
    |> validate_required([:is_special])
  end

  defimpl EctoDiscriminator.DiscriminatorChangeset do
    def diverged_changeset(_, _), do: raise("There is no diverged schema for #{@for}")

    def base_changeset(data, params) do
      data
      |> change()
      |> EctoDiscriminator.DiscriminatorChangeset.base_changeset(params)
    end

    def cast_base(data, params) do
      data
      |> change()
      |> EctoDiscriminator.DiscriminatorChangeset.cast_base(params)
    end
  end
end

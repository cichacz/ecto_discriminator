defmodule EctoDiscriminator.SomeTable.FooPk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTablePk do
    field :source, :string
    field :title, Ecto.Enum, default: :b
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
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

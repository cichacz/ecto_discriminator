defmodule EctoDiscriminator.SomeTable.BarContent do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema "bar_content" do
    field :name, :string
    field :status, :integer
    field :type, EctoDiscriminator.DiscriminatorType, virtual: true
    belongs_to :bar, EctoDiscriminator.SomeTable.Bar
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:name, :status])
    |> validate_required(:name)
  end
end

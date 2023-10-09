defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:title, :content, :type]}
  schema "some_table" do
    field :title, :string
    field :content, :map
    field :type, EctoDiscriminator.DiscriminatorType
    belongs_to :parent, EctoDiscriminator.SomeTable.Foo
    belongs_to :pk, EctoDiscriminator.SomeTablePk, foreign_key: :type, references: :type, define_field: false
    has_one :self, through: [:pk, :not_pk]

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :content])
    |> put_assoc(:parent, params[:parent])
  end
end

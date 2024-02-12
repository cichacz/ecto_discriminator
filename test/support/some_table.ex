defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:title, :content, :type]}
  schema "some_table" do
    field :title, :string
    field :content, :map
    field :type, EctoDiscriminator.DiscriminatorType
    belongs_to :parent, EctoDiscriminator.SomeTable.Foo

    belongs_to :pk, EctoDiscriminator.SomeTablePk,
      foreign_key: :type,
      references: :type,
      define_field: false

    has_one :self, through: [:pk, :not_pk]

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :content])
    |> maybe_put_assoc(:parent, params)
  end

  defp maybe_put_assoc(changeset, key, attrs) do
    case attrs[key] do
      %Ecto.Association.NotLoaded{} ->
        changeset

      nil ->
        changeset

      value ->
        put_assoc(changeset, key, value)
    end
  end
end

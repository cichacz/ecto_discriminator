defmodule EctoDiscriminator.SomeTablePk do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias Ecto.Enum

  @values [:a, :b, :c]

  @primary_key {:type, EctoDiscriminator.DiscriminatorType, []}
  schema "some_table_pk" do
    field :source, :integer
    # make sure field types can contain aliases and module attributes
    field :title, Enum, values: @values

    belongs_to :not_pk, EctoDiscriminator.SomeTable, foreign_key: :type, references: :type, define_field: false
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :source])
  end
end

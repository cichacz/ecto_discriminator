defmodule EctoDiscriminator.SomeTable.Quux do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias EctoDiscriminator.SomeTable.Qux

  @values [a: 1, b: 2, c: 3]

  # make sure base schemas can be referenced using alias
  schema Qux do
    # make sure field types can contain calls on module attributes
    field :title, Ecto.Enum, values: Keyword.keys(@values)
    field :is_last, :boolean, virtual: true

    embeds_one :content, Content, primary_key: false, on_replace: :update do
      field :quux_text, :string
    end
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:title])
    |> cast_embed(:content, required: true, with: &content_changeset/2)
  end

  def content_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:quux_text])
    |> validate_required([:quux_text])
  end
end

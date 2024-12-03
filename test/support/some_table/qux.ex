defmodule EctoDiscriminator.SomeTable.Qux do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  alias EctoDiscriminator.SomeTable.Foo

  # make sure base schemas can be referenced using alias
  schema Foo do
    field :is_special, :boolean

    embeds_one :content, Content, primary_key: false, on_replace: :update do
      field :text, :string
    end
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast(params, [:is_special])
    |> cast_embed(:content, required: true, with: &content_changeset/2)
    |> validate_required([:is_special])
  end

  def content_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:text])
    |> validate_required([:text])
  end
end

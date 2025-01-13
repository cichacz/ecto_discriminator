defmodule EctoDiscriminator.SomeTable.Grault do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  schema EctoDiscriminator.SomeTable.Qux do
    embeds_one :content, Content, primary_key: false, on_replace: :update do
      field :grault_text, :string
    end
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast_base(params)
    |> cast_embed(:content, required: true, with: &content_changeset/2)
  end

  def content_changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:grault_text])
    |> validate_required([:grault_text])
  end
end

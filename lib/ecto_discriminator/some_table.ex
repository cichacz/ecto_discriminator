defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  import Ecto.Changeset

  @discriminator :type
  
  schema "some_table" do
    field :title, :string
    field :content, :map
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:title, :type])
  end

end

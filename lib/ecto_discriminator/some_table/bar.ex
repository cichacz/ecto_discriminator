defmodule EctoDiscriminator.SomeTable.Bar do
  use EctoDiscriminator.Schema, type: "bar"

  schema "some_table" do
    field :title, :string
  end

end

defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema, type: "foo"

  schema "some_table" do
    field :title, :string
  end
end

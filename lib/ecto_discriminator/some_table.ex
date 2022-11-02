defmodule EctoDiscriminator.SomeTable do
  use EctoDiscriminator.Schema

  @discriminator :type
  
  schema "some_table" do
    field :title, :string
  end

end

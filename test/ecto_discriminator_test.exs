defmodule EctoDiscriminatorTest do
  use EctoDiscriminator.RepoCase
  doctest EctoDiscriminator

  alias EctoDiscriminator.SomeTable

  test "greets the world" do
    assert EctoDiscriminator.hello() == :world
  end

  test "adds discriminator field" do
    fields = SomeTable.Foo.__schema__(:fields)
    assert Enum.member?(fields, :type)
  end

  test "inserts different schema" do
    %SomeTable.Foo{title: "Foo one"}
    |> Repo.insert()

    %SomeTable.Bar{title: "Bar one"}
    |> Repo.insert()

    %SomeTable.Bar{title: "Bar two"}
    |> Repo.insert()

    rows = SomeTable.Foo |> Repo.all()

    assert length(rows) == 1

    rows = SomeTable.Bar |> Repo.all()

    assert length(rows) == 2
  end
end

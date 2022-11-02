defmodule EctoDiscriminatorTest do
  use EctoDiscriminator.RepoCase
  doctest EctoDiscriminator

  alias EctoDiscriminator.SomeTable

  describe "root schema" do
    test "properly sets up schema" do
      fields = SomeTable.__schema__(:fields)
      assert fields == [:id, :title, :type]
    end

    test "provides access to discriminator column definition" do
      import SomeTable
      assert :type == discriminator_field_name()

      assert {:field, _, [:type | _]} =
               Macro.expand_once(
                 quote(do: discriminator_field(to_string(SomeTable.Foo))),
                 __ENV__
               )
    end

    test "provides easy access to schema fields" do
      import SomeTable
      common_fields = Macro.expand_once(quote(do: common_fields()), __ENV__)
      assert {:field, _, [:title, :string]} = common_fields
    end
  end

  describe "child schema" do
    test "has discriminator field" do
      fields = SomeTable.Foo.__schema__(:fields)
      assert Enum.member?(fields, :type)
    end

    test "inserts different schema" do
      content = %{length: 7}

      SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one", content: content})
      |> Repo.insert!()

      # we allow for empty content in Bar
      SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two"})
      |> Repo.insert!()

      content = %{name: "asdf"}

      SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", content: content})
      |> Repo.insert!()

      rows = SomeTable.Foo |> Repo.all()

      assert length(rows) == 1

      # check if mapped properly
      assert SomeTable.FooContent ==
               get_in(rows, [Access.at(0), Access.key(:content), Access.key(:__struct__)])

      assert 7 == get_in(rows, [Access.at(0), Access.key(:content), Access.key(:length)])

      rows = SomeTable.Bar |> Repo.all()

      assert length(rows) == 2
    end

    test "rejects invalid data" do
      assert_raise ArgumentError, fn ->
        content = %{length: 7}

        %SomeTable.Bar{title: "Bar two", content: content}
        |> Repo.insert!()
      end

      changeset = SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one"})
      refute changeset.valid?

      content = %{status: 3}

      changeset = SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", content: content})
      refute changeset.valid?
    end
  end
end

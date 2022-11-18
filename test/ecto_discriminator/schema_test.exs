defmodule EctoDiscriminator.SchemaTest do
  use EctoDiscriminator.RepoCase, async: true

  alias EctoDiscriminator.Schema

  alias EctoDiscriminator.SomeTable

  doctest Schema

  describe "base schema" do
    test "properly sets up schema" do
      fields = SomeTable.__schema__(:fields)
      assert fields == [:id, :type, :title, :content, :parent_id]
    end

    test "provides access to common schema fields definitions" do
      import SomeTable
      {:__block__, _, common_fields} = Macro.expand_once(quote(do: common_fields([])), __ENV__)

      assert [
               # macro should set default value for discriminator column to the value of callers module
               {:field, _, [:type, _, [default: __MODULE__]]},
               {:field, _, [:title, :string]},
               {:field, _, [:content, :map]},
               {:belongs_to, _, [:parent, _]}
             ] = common_fields
    end

    test "provides access to discriminator name" do
      discriminator_name = SomeTable.__schema__(:discriminator)
      assert :type == discriminator_name
    end

    test "can insert child schemas" do
      SomeTable.changeset(%SomeTable{}, %{title: "Foo one", type: SomeTable.Foo})
      |> Repo.insert!()

      rows = SomeTable.Foo |> Repo.all()

      assert length(rows) == 1
    end
  end

  describe "child schema" do
    test "doesn't define common fields macro" do
      available_macros = SomeTable.Foo.__info__(:macros)
      assert [] == available_macros
    end

    test "has common fields injected" do
      fields = SomeTable.Foo.__schema__(:fields)
      assert fields == [:id, :source, :content, :type, :title, :parent_id]
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

    test "allows setting fields from base schema" do
      # check if we can set common fields
      foo =
        SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one", content: %{length: 7}})
        |> Repo.insert!()

      # check if we can set common relationships
      child =
        SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", parent: foo})
        |> Repo.insert!()

      # check if we can set custom relationships
      bar =
        SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", sibling: foo})
        |> Repo.insert!()

      child_preload_chain = [parent: [:parent, sibling: [:parent, sibling: [:parent]]]]

      child_preloaded = SomeTable |> Repo.get(child.id) |> Repo.preload(child_preload_chain)

      bar_preloaded = bar |> Repo.preload(sibling: [:parent])

      [foo_preloaded] =
        SomeTable.Foo
        |> Repo.all()
        |> Repo.preload(
          child: child_preload_chain,
          sibling: [:parent, sibling: [:parent]]
        )

      assert %{sibling: ^bar, child: ^child_preloaded} = foo_preloaded
      assert %{sibling: ^foo} = bar_preloaded
      assert foo_preloaded.child.parent.sibling == bar
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

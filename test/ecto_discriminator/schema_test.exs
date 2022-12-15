defmodule EctoDiscriminator.SchemaTest do
  use EctoDiscriminator.RepoCase, async: true

  alias EctoDiscriminator.Schema

  alias EctoDiscriminator.SomeTable
  alias EctoDiscriminator.SomeTablePk

  doctest Schema

  describe "base schema" do
    test "properly sets up schema" do
      fields = SomeTable.__schema__(:fields)
      assert MapSet.new(fields) == MapSet.new([:id, :type, :title, :content, :parent_id])
    end

    test "provides access to common schema fields definitions" do
      {:__block__, _, common_fields} = SomeTable.__schema__(:fields_def)

      assert [
               {:field, _, [:title, :string]},
               {:field, _, [:content, :map]},
               {:field, _, [:type, _]},
               {:belongs_to, _, [:parent, _]}
             ] = common_fields
    end

    test "doesn't set default value for discriminator" do
      struct = %SomeTable{}
      assert struct.type == nil
    end

    test "provides access to discriminator name" do
      discriminator_name = SomeTable.__schema__(:discriminator)
      assert :type == discriminator_name
    end

    test "can create diverged changesets" do
      SomeTable.diverged_changeset(%SomeTable.Bar{})
      |> Repo.insert!()

      rows = SomeTable.Bar |> Repo.all()

      assert length(rows) == 1
    end

    test "can insert diverged schemas" do
      SomeTable.diverged_changeset(%SomeTable{}, %{
        title: "Foo one",
        source: "asdf",
        type: SomeTable.Foo,
        content: %{length: 7}
      })
      |> Repo.insert!()

      rows = SomeTable.Foo |> Repo.all()

      assert length(rows) == 1
    end

    test "can insert diverged schemas with string keys" do
      SomeTable.diverged_changeset(%SomeTable{}, %{
        "title" => "Bar one",
        "type" => SomeTable.Bar
      })
      |> Repo.insert!()

      rows = SomeTable.Bar |> Repo.all()

      assert length(rows) == 1
    end

    test "can insert diverged schemas with primary key discriminator" do
      SomeTablePk.diverged_changeset(%SomeTablePk{}, %{
        title: :b,
        source: "asdf",
        type: SomeTable.FooPk,
        content: %{length: 7}
      })
      |> Repo.insert!()

      rows = SomeTable.FooPk |> Repo.all()

      assert length(rows) == 1
    end

    test "validates diverged schemas" do
      assert {:error, %{errors: [content: {"can't be blank", [validation: :required]}]}} =
               SomeTable.diverged_changeset(%SomeTable{}, %{
                 title: "Foo one",
                 source: "asdf",
                 type: SomeTable.Foo
               })
               |> Repo.insert()

      assert {:error, %{errors: [content: {"can't be blank", [validation: :required]}]}} =
               SomeTable.diverged_changeset(%SomeTable.Foo{}, %{
                 title: "Foo one",
                 source: "asdf"
               })
               |> Repo.insert()
    end
  end

  describe "diverged schema" do
    test "provides access to common schema fields definitions" do
      [{:__block__, _, common_fields}, {:__block__, _, parent_common_fields}] =
        SomeTable.Foo.__schema__(:fields_def)

      content_module =
        EctoDiscriminator.SomeTable.FooContent
        |> Module.split()
        |> Enum.map(&String.to_atom/1)

      assert [
               {:field, _, [:source, :string]},
               {:embeds_one, _, [:content, {_, _, ^content_module}]},
               {:has_one, _, [:sibling, _, _]},
               {:has_one, _, [:child, _, _]}
             ] = common_fields

      assert [
               {:field, _, [:title, :string]},
               # nil-ified :content because we override it in Foo
               nil,
               {:field, _,
                [
                  :type,
                  {:__aliases__, _, [:EctoDiscriminator, :DiscriminatorType]},
                  [default: SomeTable.Foo]
                ]},
               {:belongs_to, _, [:parent, _]}
             ] = parent_common_fields
    end

    test "has common fields injected" do
      fields = SomeTable.Foo.__schema__(:fields)
      assert MapSet.new(fields) == MapSet.new([:id, :source, :content, :type, :title, :parent_id])
    end

    test "sets default value for discriminator" do
      struct = %SomeTable.Foo{}
      assert struct.type == SomeTable.Foo
    end

    test "inserts different schema" do
      content = %{length: 7}

      SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one", content: content})
      |> Repo.insert!()

      rows = SomeTable.Foo |> Repo.all()

      assert length(rows) == 1

      # we allow for empty content in Bar
      SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two"})
      |> Repo.insert!()

      rows = SomeTable.Bar |> Repo.all()

      assert length(rows) == 1

      SomeTable.FooPk.changeset(%SomeTable.FooPk{}, %{title: :b})
      |> Repo.insert!()

      rows = SomeTable.FooPk |> Repo.all()

      assert length(rows) == 1

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

    test "handles complex queries" do
      foo =
        SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one", content: %{length: 7}})
        |> Repo.insert!()

      bar =
        SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", sibling: foo})
        |> Repo.insert!()

      [bar_preloaded] =
        SomeTable.Bar
        |> join(:left, [bar], foo in assoc(bar, :sibling))
        |> preload([bar, foo], [:parent, sibling: {foo, [:parent]}])
        |> Repo.all()

      assert bar_preloaded == %{bar | sibling: foo}
    end

    test "rejects invalid data" do
      # should fail because content has different fields
      assert_raise ArgumentError, fn ->
        content = %{length: 7}

        %SomeTable.Bar{title: "Bar two", content: content}
        |> Repo.insert!()
      end

      # should fail because content is required
      changeset = SomeTable.Foo.changeset(%SomeTable.Foo{}, %{title: "Foo one"})
      refute changeset.valid?

      # should fail because "name" is required
      content = %{status: 3}

      changeset = SomeTable.Bar.changeset(%SomeTable.Bar{}, %{title: "Bar two", content: content})
      refute changeset.valid?

      changeset =
        SomeTable.Qux.changeset(%SomeTable.Qux{}, %{
          title: "Qux",
          is_special: false,
          is_qux: true
        })

      refute changeset.valid?
    end

    test "can be base schema for another one" do
      SomeTable.Baz.changeset(%SomeTable.Baz{}, %{
        title: "Baz",
        source: "bar",
        content: %{length: 3},
        is_special: true
      })
      |> Repo.insert!()

      assert [baz_from_repo] = SomeTable.Baz |> preload(:parent) |> Repo.all()
      assert baz_from_repo.is_special == true

      SomeTable.Qux.changeset(%SomeTable.Qux{}, %{
        title: "Qux",
        source: "baz",
        content: %{length: 3},
        is_special: false,
        is_qux: true
      })
      |> Repo.insert!()

      assert [qux_from_repo] = SomeTable.Qux |> preload(:parent) |> Repo.all()
      # make sure it was properly stored and fetched.
      assert qux_from_repo.is_special === false
    end

    test "can override schema protocol" do
      assert_raise RuntimeError, fn ->
        EctoDiscriminator.DiscriminatorSchema.diverged_changeset(%SomeTable.FooPk{})
      end
    end
  end
end

defmodule EctoDiscriminator.DiscriminatorChangesetTest do
  use EctoDiscriminator.RepoCase, async: true

  alias EctoDiscriminator.DiscriminatorChangeset

  alias EctoDiscriminator.SomeTable

  doctest DiscriminatorChangeset

  describe "diverged_changeset/2" do
    test "sets proper metadata" do
      entry =
        DiscriminatorChangeset.diverged_changeset(%SomeTable{}, %{
          title: "Foo one",
          source: "asdf",
          type: SomeTable.Foo,
          content: %{length: 7}
        })
        |> Ecto.Changeset.apply_action!(:insert)

      assert %Ecto.Schema.Metadata{schema: SomeTable.Foo, source: "some_table", state: :built} ==
               entry.__meta__
    end

    test "sets proper owners of relationships" do
      entry =
        DiscriminatorChangeset.diverged_changeset(%SomeTable.Foo{}, %{
          title: "Foo one",
          source: "asdf",
          is_special: true,
          type: SomeTable.Qux,
          content: %{length: 7}
        })
        |> Ecto.Changeset.apply_action!(:insert)

      assert %Ecto.Association.NotLoaded{
               __field__: :sibling,
               __owner__: SomeTable.Qux,
               __cardinality__: :one
             } == entry.sibling
    end

    test "keeps metadata state" do
      foo =
        SomeTable.diverged_changeset(%SomeTable{parent: nil}, %{
          title: "Foo one",
          source: "asdf",
          type: SomeTable.Foo,
          content: %{length: 7}
        })
        |> Repo.insert!()

      changeset = DiscriminatorChangeset.diverged_changeset(foo, %{})

      assert %{} == changeset.changes
      assert changeset.valid?

      assert foo == Ecto.Changeset.apply_action!(changeset, :insert)
    end
  end

  describe "base_changeset/3" do
    test "returns itself on base schema" do
      changeset =
        DiscriminatorChangeset.base_changeset(
          %SomeTable{parent: nil},
          %{title: "abc", source: "source", content: %{length: 7}},
          SomeTable
        )

      assert %Ecto.Changeset{
               data: %SomeTable{type: nil},
               changes: %{title: "abc", content: %{length: 7}}
             } = changeset

      assert %SomeTable{type: nil, title: "abc", content: %{length: 7}, parent: nil} ==
               Ecto.Changeset.apply_action!(changeset, :insert)
    end

    test "returns changeset for base schema" do
      changeset =
        DiscriminatorChangeset.base_changeset(
          %SomeTable.Foo{parent: nil, source: "asdf"},
          %{title: "abc", source: "source", content: %{length: 7}},
          SomeTable
        )

      assert %Ecto.Changeset{
               data: %SomeTable{type: SomeTable.Foo},
               changes: %{title: "abc", content: %{length: 7}}
             } = changeset

      assert %SomeTable{type: SomeTable.Foo, title: "abc", content: %{length: 7}, parent: nil} ==
               Ecto.Changeset.apply_action!(changeset, :insert)
    end

    test "keeps metadata state" do
      foo =
        SomeTable.diverged_changeset(%SomeTable{parent: nil}, %{
          title: "Foo one",
          source: "asdf",
          type: SomeTable.Foo,
          content: %{length: 7}
        })
        |> Repo.insert!()

      changeset = DiscriminatorChangeset.base_changeset(foo, %{}, SomeTable)

      assert %{} == changeset.changes
      assert changeset.valid?

      assert %SomeTable{
               __meta__: %Ecto.Schema.Metadata{
                 context: nil,
                 prefix: nil,
                 schema: EctoDiscriminator.SomeTable,
                 source: "some_table",
                 state: :loaded
               },
               type: SomeTable.Foo,
               id: foo.id,
               inserted_at: foo.inserted_at,
               updated_at: foo.updated_at,
               title: foo.title,
               content: foo.content,
               parent: foo.parent
             } ==
               Ecto.Changeset.apply_action!(changeset, :insert)
    end
  end

  describe "cast_base/3" do
    test "properly merges new changesets" do
      changeset =
        DiscriminatorChangeset.cast_base(
          %SomeTable.Foo{},
          %{title: "abc", source: "source", content: %{length: 7}},
          SomeTable
        )

      # content is overridden in Foo with different type so can't be a change in base changeset
      assert %{title: "abc", parent: nil} == changeset.changes

      changeset =
        DiscriminatorChangeset.cast_base(
          %SomeTable.FooPk{},
          %{title: "abc", source: "source"},
          EctoDiscriminator.SomeTablePk
        )

      # all fields are overriden in FooPk
      assert %{} == changeset.changes
    end

    test "properly merges existing changesets" do
      changeset =
        DiscriminatorChangeset.cast_base(
          %SomeTable.Foo{},
          %{title: "abc", source: "source", content: %{length: 7}},
          SomeTable
        )

      changeset =
        DiscriminatorChangeset.cast_base(
          changeset,
          %{title: "def"},
          SomeTable
        )

      # content is overridden in Foo with different type so can't be a change in base changeset
      assert %{title: "def", parent: nil} == changeset.changes
    end
  end
end

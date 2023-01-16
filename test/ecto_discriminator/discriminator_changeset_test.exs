defmodule EctoDiscriminator.DiscriminatorChangesetTest do
  use ExUnit.Case, async: true

  alias EctoDiscriminator.DiscriminatorChangeset

  alias EctoDiscriminator.SomeTable

  doctest DiscriminatorChangeset

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

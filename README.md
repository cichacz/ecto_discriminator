# EctoDiscriminator

## Motivation

This small library was built to support table-per-hierarchy inheritance pattern (TPH) popular in Microsoft's Entity
Framework.  
TPH uses a single table to store the data for all types in the hierarchy, and a discriminator column is used to identify
which type each row represents.

It is similar to [Polymorphic Embed](https://hexdocs.pm/polymorphic_embed/readme.html) with few key differences.  
Thanks to this library, those entities can be fully separated structs, which brings many simplifications during
inserting and querying.  
You can also add any extra fields that will exist only in one struct (for example virtual ones or relationships).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `ecto_discriminator` to your
list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_discriminator, "~> 0.1.0"}
  ]
end
```

## Usage

### Schema

It has been built to mimic `Ecto.Schema` as much as possible. That said, the only changes to do in base schema are:

1. Replace Schema module

```diff
defmodule EctoDiscriminator.SomeTable do
-   use Ecto.Schema
+   use EctoDiscriminator.Schema
```

2. Define discriminator column name

```diff
+   @discriminator :type
    schema "some_table" do
```

Then you can add some diverged schemas

```elixir
defmodule EctoDiscriminator.SomeTable.Foo do
  use EctoDiscriminator.Schema

  schema EctoDiscriminator.SomeTable do
    embeds_one :content, EctoDiscriminator.SomeTable.BarContent
  end
end
```

Library will do the rest. Querying for diverged schema automatically adds filter to SQL.  

### Changeset

To reduce repetitive usage of `cast` with a list of common fields for diverged schemas you can
call `cast_base(params)` to automatically apply changeset from base schema.  
This function **won't** be available if base schema doesn't have any `changeset/2` function

Some may find it useful to insert diverged schema directly from the base (by specifying discriminator value in changeset params).  
This is doable by calling `diverged_changeset` function on base schema.

## Examples

You can see example setup in `test` directory.
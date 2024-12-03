# Changelog

## v0.4.4
    
* Bug fix
    * Fixed merging of more complex fields like `embeds_one`

## v0.4.3
    
* Bug fix
    * Fixed `EctoDiscriminator.Schema.to_base/2` to properly pass nil values

## v0.4.2
    
* Bug fix
    * Fixed `diverged_changeset/2` to properly calculate default values

## v0.4.1
    
* Bug fix
    * Fixed definition of fields in diverged schema to allow more complex relationships definitions

## v0.4.0

* Enhancements
    * You can transform diverged schema to its base by calling `DivergedSchema.to_base(%DivergedSchema{})`
    
* Bug fix
    * Fixed `__meta__[:state]` for entities loaded from DB

## v0.3.3
    
* Bug fix
    * Fixed situations where `diverged_changeset/2` was returning incorrect owners of relationships

## v0.3.2

* Enhancements
    * You can get list of all diverged schemas by calling `BaseSchema.__schema__(:diverged)`
    
* Bug fix
    * Fixed situations where `diverged_changeset/2` may have been receiving different structs

## v0.3.1

* Enhancements
    * Added support for inheritance of `@derive`. Now you don't have to duplicate declarations for things like `Jason.Encoder`
    
* Bug fix
    * Fixed value of `__meta__` after running `diverged_changeset/2`

## v0.3.0

* Breaking changes
    * Renamed `EctoDiscriminator.DiscriminatorSchema` to `EctoDiscriminator.DiscriminatorChangeset` since it focuses on
      adding extra functionality to the changesets rather than schemas

## v0.2.9

* Bug fix
    * Fixed usage of macros inside `schema` definition

## v0.2.8

* Enhancements
    * Discriminator can now be a `virtual` field. This is useful when table is referenced by other table(s)

## v0.2.7

* Enhancements
    * Discriminator field name inside `diverged_changeset/2` can be now determined from struct/changeset field
    * Overriden fields with matching types will have their options merged

## v0.2.6

* Bug fix
    * Changed way how `DiscriminatorChangeset` is used. It should be more flexible now. Previously sometimes the changes
      weren't properly reflected

## v0.2.5

* Bug fix
    * Fixed `diverged_changeset/2` default implementation. Previous logic wasn't creating proper diverged struct.

## v0.2.4

* Enhancements
    * Added documentation for the project
    * `cast_base/3` now won't return changes for overriden fields due to possible type differences.

## v0.2.3

* Enhancements
    * Major refactor of `EctoDiscriminator.Schema`
# Changelog

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
    * Changed way how `DiscriminatorSchema` is used. It should be more flexible now. Previously sometimes the changes
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
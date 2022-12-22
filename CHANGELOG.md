# Changelog

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
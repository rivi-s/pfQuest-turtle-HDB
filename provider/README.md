# Embedded HearthDB provider

This directory is part of `pfQuest-turtle`, not a separately installable addon.
`core.lua` implements asynchronous read-only database queries for pfQuest's HDB
adapter. HearthDB client support is required. English Vanilla data is supported;
Turtle uses one combined Vanilla/Turtle database.

Runtime database: `pfQuest-turtle/provider/data/pfquest-turtle.sqlite`.
Run `/pfqhdb` to check the database-owning addon and open state.

See [../HDB.md](../HDB.md) for building and packaging. Keep generated databases
out of source history. Never load both legacy separate providers alongside this
embedded layout; remove their addon folders when upgrading.

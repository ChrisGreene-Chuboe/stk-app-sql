# Summary

The purpose of this directory is to start playing with data through nushell.

## Nushell

Start nushell:

```bash
nu
```

## Source

Before you can begin, please source the script from the test directory:

```nu
source  sql-templates/show.nu
```

## First Commands

Now you can start playing.

Show all tables:

```nu
show
```

Show all Actors:

```nu
show actor
```

Show all Actors whose name begins with 's':

```nu
show actor | where name =~ 's'
```

Note that we are using nu's table feature to limit the results (not the database). This means you could be returning many rows from the database only to show a few in nu.

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
source  cli/show.nu
```

## Getting Started

Now you can start playing.

Show all tables:

```nu
show
```

Show all actors:

```nu
show actor
```

## Result Where Example

Show actors using the nushell table `where` name begins with 's'. This means the database is returning all rows, and Nushell only shows a sub-selection.

```nu
show actor | where name =~ 's'
```

Show actors using the SQL `where` name begins with 's' using a database where clause.

```nu
show actor -w " lower(name) like 's%'"
show actor --where " lower(name) like 's%'"
```

## Result First Example

Using Nushell:

Show two actors using the `first` Nushell limiter. This means the database is returning all rows, and Nushell only shows the first couple.

```nu
show actor | first 2
```

Show two actors using the SQL `first` limiter.

```nu
show actor -f 2
show actor --first 2
```

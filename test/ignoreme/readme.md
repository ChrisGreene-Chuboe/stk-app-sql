# IGNORE THIS DIRECTORY

⚠️ **This directory should be ignored and is no longer relevant.**

This directory contains outdated Nushell CLI experiments that have been superseded by the main modules in `../modules/`. 

## Why This Directory Exists

This directory has been renamed from `cli/` to `ignoreme/` to indicate it should not be used. The contents are preserved for historical reference only.

## Current Approach

For current CLI functionality, use the modules in `../modules/` instead:

```nu
# Use the current approach
use modules *
"test event" | .append event "my-topic"
event list
```

## Do Not Use

❌ Do not source or use any files from this directory
❌ Do not follow the instructions below (they are outdated)
❌ Do not reference this code in new development

---

## Outdated Instructions (For Reference Only)

The following instructions are **OUTDATED** and should **NOT** be followed:

<details>
<summary>Click to view outdated content</summary>

The purpose of this directory is to start playing with data through nushell.

### Nushell

Start nushell:

```bash
nu
```

### Source

Before you can begin, please source the script from the test directory:

```nu
source  ignoreme/show.nu
```

### Getting Started

Now you can start playing.

Show all tables:

```nu
show
```

Show all actors:

```nu
show actor
```

### Result Where Example

Show actors using the nushell table `where` name begins with 's'. This means the database is returning all rows, and Nushell only shows a sub-selection.

```nu
show actor | where name =~ 's'
```

Show actors using the SQL `where` name begins with 's' using a database where clause.

```nu
show actor -w " lower(name) like 's%'"
show actor --where " lower(name) like 's%'"
```

### Result First Example

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

</details>
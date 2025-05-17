# Chuck-Stack Nushell Modules

This directory contains Nushell modules for interacting with the chuck-stack database.

## Modules

- **stk_event**: Commands for working with the `stk_event` table

## Usage

Import all modules with:

```nu
use modules *
```

Or import specific modules:

```nu
use modules/stk_event *
```

## Module Structure

Each module follows a standard structure:
- `mod.nu`: The main module file containing commands
- `README.md`: Documentation for the module

The root `mod.nu` file exports all sub-modules for easy access.

## Development

When adding new modules:
1. Create a new directory for your module
2. Add a `mod.nu` file with your commands
3. Add a `README.md` file with documentation
4. Update the root `mod.nu` file to export your module
# STK Tutor Module

This module provides interactive tutorials for learning chuck-stack patterns and operations.

## Important Note

**This module is auto-generated** from `chuckstack.github.io/src-ls/cli-tutor.md` during the build process.

**Do not edit `mod.nu` directly** - changes will be overwritten.

## Module Type

This is a **System Wrapper Module** that provides tutorial functionality without database operations.

## Architecture

1. **Content**: Lives in `chuckstack.github.io/src-ls/cli-tutor.md`
2. **Generator**: `tutor-generate` command in `stk_utility` module
3. **Output**: This generated `stk_tutor` module

## Usage

```nu
stk tutor         # Start the interactive tutor
stk tutor ops     # Operations learning track  
stk tutor ops begin   # Start operations tutorial
stk tutor dev     # Development learning track
stk tutor dev begin   # Start development tutorial
stk list          # See all available tutorial sections
```

## Build Process

During chuck-stack build/setup:

```nu
# Generate stk_tutor module from markdown
open ../../../chuckstack.github.io/src-ls/cli-tutor.md | tutor-generate | save -f modules/stk_tutor/mod.nu
```

## Implementation

The `tutor-generate` utility command (in `stk_utility`) converts markdown into interactive nushell commands. This functionality was originally from the [nu-tutor2](https://github.com/chuckstack/nu-tutor2) project and has been integrated into chuck-stack with enhanced error handling and chuck-stack specific features.
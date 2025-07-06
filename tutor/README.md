# Chuck-Stack Tutor Build Tools

This directory contains build scripts for the chuck-stack tutorial system.

## Scripts

- `regenerate-tutor.nu` - Regenerates the stk_tutor module from markdown

## Usage

After updating the tutorial content in `chuckstack.github.io/src-ls/cli-tutor.md`:

```bash
cd chuck-stack-core/tutor
nu regenerate-tutor.nu
```

This will regenerate the `stk_tutor` module with the latest content.

## Architecture

The tutor system consists of:
1. **Content**: `chuckstack.github.io/src-ls/cli-tutor.md`
2. **Generator**: `tutor-generate` utility in `stk_utility`
3. **Output**: `modules/stk_tutor/mod.nu`
4. **Build Tools**: This directory
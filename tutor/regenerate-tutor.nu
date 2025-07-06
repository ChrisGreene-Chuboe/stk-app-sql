#!/usr/bin/env nu

# Regenerate stk_tutor module from markdown
# Run this script after updating chuckstack.github.io/src-ls/cli-tutor.md

use ../modules/stk_utility/mod.nu tutor-generate

print "Regenerating stk_tutor module from cli-tutor.md..."
open ../../chuckstack.github.io/src-ls/cli-tutor.md | tutor-generate | save -f ../modules/stk_tutor/mod.nu
print "✓ Successfully regenerated modules/stk_tutor/mod.nu"
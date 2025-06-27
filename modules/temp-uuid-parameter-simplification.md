# UUID Parameter Simplification Plan

## Overview

Following the code review that identified missing `--uu` parameters in several modules and the subsequent implementation that added boilerplate code, this document outlines a plan to simplify the modules by creating a reusable utility function.

## Problem Statement

After adding `--uu` parameter support to stk_request, stk_todo, stk_tag, and stk_event modules, each module now contains identical 8-line blocks of code for UUID extraction in both `get` and `revoke` commands. This results in:
- ~64 lines of duplicated code across 4 modules
- Maintenance burden when changes are needed
- Potential for inconsistencies

## Current Boilerplate Pattern

Each module's `get` and `revoke` commands contain this pattern:

```nushell
let uu = if ($in | is-empty) {
    if ($uu | is-empty) {
        error make { msg: "UUID required via piped input or --uu parameter" }
    }
    $uu
} else {
    ($in | extract-single-uu)
}
```

## Proposed Solution

### 1. New Utility Function

Add to `stk_utility/mod.nu`:

```nushell
# Extract UUID from either piped input or --uu parameter
#
# This helper consolidates the common pattern of accepting a UUID from either:
# - Piped input (string, record with 'uu' field, or table)
# - --uu parameter
#
# This reduces boilerplate in commands that support dual UUID input methods.
#
# Examples:
#   # With piped input
#   "uuid-string" | extract-uu-with-param
#   {uu: "uuid", name: "test"} | extract-uu-with-param
#   
#   # With --uu parameter
#   "" | extract-uu-with-param "uuid-from-param"
#   
#   # With custom error message
#   $in | extract-uu-with-param $uu --error-msg "Tag UUID required"
#
# Returns: String UUID
# Error: Throws error if no UUID provided via either method
export def extract-uu-with-param [
    uu?: string  # The --uu parameter value
    --error-msg: string = "UUID required via piped input or --uu parameter"
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        if ($uu | is-empty) {
            error make { msg: $error_msg }
        }
        $uu
    } else {
        ($piped_input | extract-single-uu --error-msg $error_msg)
    }
}
```

### 2. Module Updates

Replace the 8-line boilerplate in each module with:

```nushell
let uu = ($in | extract-uu-with-param $uu)
```

For custom error messages (like in stk_tag):

```nushell
let uu = ($in | extract-uu-with-param $uu --error-msg "UUID required: pipe in the UUID of the tag to get")
```

## Implementation Steps

1. ✅ Document plan (this file)
2. ✅ Add `extract-uu-with-param` to stk_utility/mod.nu
3. ✅ Update stk_request get/revoke commands
4. ✅ Update stk_todo get/revoke commands
5. ✅ Update stk_tag get/revoke commands (with custom error messages)
6. ✅ Update stk_event get/revoke commands
7. ⏳ Test all affected commands
8. ⏳ Update temp-best-practices-uuid-enhancement.md with new pattern

## Benefits

- **Code Reduction**: ~64 lines removed
- **Consistency**: Standardized UUID handling across all modules
- **Maintainability**: Single source of truth for dual-input UUID extraction
- **Flexibility**: Custom error messages still supported
- **Future-proof**: Easy to extend pattern to other parameter types

## Testing Checklist

After implementation, verify these scenarios for each module:

- [ ] Piped string UUID: `"uuid" | module get`
- [ ] Piped record: `{uu: "uuid", name: "test"} | module get`
- [ ] Piped table: `module list | first | module get`
- [ ] Parameter only: `module get --uu "uuid"`
- [ ] No input (error): `module get`
- [ ] Empty parameter (error): `module get --uu ""`

## Future Considerations

This pattern could be extended to:
- Generic parameter extraction (not just UUIDs)
- Multiple parameter support
- Other common boilerplate patterns identified in the codebase
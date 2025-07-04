# Chuck-Stack Test Templates

These templates make it easy to create comprehensive tests for new chuck-stack modules without thinking about test patterns.

## Template Versioning

Each template includes a `Template Version: YYYY-MM-DD` timestamp. This allows:
- Finding tests created with older template versions: `grep -r "Template Version: 2025-01-04" suite/`
- Identifying tests that might benefit from regeneration with newer templates
- Tracking template evolution over time

When updating templates, always update the version date.

## Quick Start

1. Copy `test-module-template.nu` to `suite/test-yourmodule.nu`
2. Replace `MODULE` with your module name (e.g., `item`, `bp`, `project`)
3. Replace `PREFIX` with a 2-letter prefix (e.g., `si` for stk_item)
4. Copy relevant patterns from the pattern templates
5. Delete patterns that don't apply to your module

## Available Patterns

### Core Patterns (Most modules need these)
- **crud-pattern.template.nu** - Basic create, list, get, revoke operations
- **uuid-input-pattern.template.nu** - Tests all UUID input variations (string, record, table, --uu)

### Optional Patterns (Based on module features)
- **type-support-pattern.template.nu** - If module has `_type` table
- **json-pattern.template.nu** - If table has `record_json` column
- **template-pattern.template.nu** - If table has `is_template` column
- **header-line-pattern.template.nu** - For modules with header-line relationships
- **parent-child-pattern.template.nu** - If table has `parent_uu` column

## Example: Creating test for new "contract" module

```bash
# 1. Copy template
cp templates/test-module-template.nu suite/test-contract.nu

# 2. Edit suite/test-contract.nu header section
# Replace:
#   MODULE -> contract (in comments and test names)
#   PREFIX -> co (in test_suffix line)
#   TYPE_KEY -> "SERVICE" (or appropriate type)

# 3. Copy patterns (assuming contract has types and JSON)
# - Copy crud-pattern content, replace MODULE -> contract
# - Copy uuid-input-pattern content, replace MODULE -> contract  
# - Copy type-support-pattern content, replace MODULE -> contract
# - Copy json-pattern content, replace MODULE -> contract

# 4. Run test
chmod +x suite/test-contract.nu
nix-shell --run "./suite/test-contract.nu"
```

## Pattern Substitutions

When copying patterns, replace these placeholders:
- `MODULE` - Your module name (e.g., `item`, `bp`, `project`)
- `PREFIX` - Two-letter test prefix (e.g., `si`, `bp`, `pr`)
- `TYPE_KEY` - Valid type search key (e.g., `"SERVICE"`, `"ACCOUNT"`)
- `HEADER` - Header module name (e.g., `project`)
- `LINE` - Line command suffix (e.g., `line`)

## Tips

1. Start with CRUD and UUID patterns - these apply to almost all modules
2. Add optional patterns based on your table's columns
3. Remove any assertions that don't apply
4. Add module-specific tests at the end
5. Keep test suffix pattern for idempotency

## Benefits

- **No thinking required** - Just copy, replace, done
- **Comprehensive coverage** - All standard patterns tested
- **Consistent** - Every module tested the same way
- **Fast** - Create full test in < 5 minutes
- **Maintainable** - Update patterns in one place
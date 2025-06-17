# Chuck-Stack Testing Guide

This guide provides patterns for testing chuck-stack nushell modules in the test environment.

## Table of Contents

- [Quick Start](#quick-start)
- [Testing Philosophy](#testing-philosophy)
- [Test Environment](#test-environment)
- [Writing Tests](#writing-tests)
- [Running Tests](#running-tests)
- [Common Issues](#common-issues)
- [Maintenance Tasks](#maintenance-tasks)
- [Document Maintenance Guidelines](#document-maintenance-guidelines)

## Quick Start

Run existing tests:
```bash
cd test
nix-shell --run "./suite/test-simple.nu"
nix-shell --run "./suite/test-project.nu"
nix-shell --run "cd suite && ./test-all.nu"
```

Create new test:
```bash
# Create test file with executable permissions
echo '#!/usr/bin/env nu' > suite/test-feature.nu
chmod +x suite/test-feature.nu
# Edit test following patterns in suite/test-simple.nu
```

## Testing Philosophy

### Purpose
Chuck-stack tests validate that:
- Module commands work as documented
- Database operations execute correctly
- Help examples actually function
- Pipeline patterns integrate properly

### Help Example Testing
Commands include examples in their `--help` documentation. Tests validate these examples work in practice, ensuring documentation stays accurate.

### Assertion-Based Testing
Tests use nushell's `assert` command to verify expected outcomes rather than just checking execution success. See `suite/test-simple.nu` for the reference pattern.

## Test Environment

### Architecture
The test environment uses a **nushell-first architecture**:
- PostgreSQL setup via `start-test.nu`
- Database migrations via `chuck-stack-nushell-psql-migration`
- Automatic cleanup via `stop-test.nu`
- Isolated `/tmp/stk-test-*` workspace

### Test Directory Structure
When `nix-shell` runs, it creates a temporary test workspace:
```
/tmp/stk-test-XXXXX/
├── modules/          # Copied from ../modules
├── migrations/       # Database migrations
├── suite/            # Test scripts
│   ├── test-*.nu
│   └── ...
└── ...              # Other test files
```

**IMPORTANT**: The modules are copied to `./modules` within the test directory, while test files are in `./suite`, which is why test files use `use ../modules *` to access the modules.

### Key Components
- **nix-shell**: Provides PostgreSQL and dependencies
- **start-test.nu**: Initializes database and runs migrations
- **migrate command**: Manages database migrations (replaces sqlx-cli)
- **psql commands**: Execute database operations

### Environment Variables
- `PGHOST`, `PGUSER`, `PGDATABASE`: Standard PostgreSQL connection
- `STK_PG_ROLE`: Current database role
- `STK_TEST_DIR`: Test workspace directory

### Database Access
Always use the `api` schema for function calls:
```sql
-- Correct
SELECT api.get_table_name_uu_json('uuid-here'::uuid);

-- Incorrect (permission denied)
SELECT private.get_table_name_uu_json('uuid-here'::uuid);
```

## Writing Tests

### Test Structure Template
```nushell
#!/usr/bin/env nu

echo "=== Testing module functionality ==="

# Import modules and assertions
use ../modules *
use std/assert

# Test basic functionality
echo "=== Testing basic command ==="
let result = (command parameters)

# Verify with assertions
assert (($result | length) > 0) "Should return results"
assert ($result.field.0 | str contains "expected") "Field should match"

echo "=== All tests completed successfully ==="
```

### Key Patterns

#### 1. Always Make Tests Executable
```bash
chmod +x suite/test-new.nu  # Required before first run
```

#### 2. Import Requirements
```nushell
use ../modules *    # Access module commands (test files are in suite/)
use std/assert      # Enable assertions
```

#### 3. Assertion Syntax
```nushell
# Wrap comparisons in parentheses
assert (($result | length) > 0) "Error message"

# Access list elements with .0
assert ($result.field.0 == "value") "Field should match"
```

#### 4. Standard Output
End all tests with:
```nushell
echo "=== All tests completed successfully ==="
```

### Testing Patterns

#### UUID Piping
```nushell
let uuid = ($result.uu.0)
let details = ($uuid | command get)
```

#### Type Resolution
```nushell
let result = (command new "name" --type-search-key "TYPE_ENUM")
```

#### Request/Event Attachment
```nushell
let attached = ($uuid | .append request "investigation")
```

#### Parent-Child Relationships (parent_uu)
```nushell
# Create parent-child relationship via piped UUID (only method)
let parent = (project new "Parent Project")
let parent_uuid = ($parent.uu.0)
let child = ($parent_uuid | project new "Sub-project")

# Test validation - parent UUID must belong to correct table
let request = (.append request "test-request")
let request_uuid = ($request.uu.0)
let invalid_result = (do { $request_uuid | project new "Test" } | complete)
assert ($invalid_result.exit_code != 0) "Should fail with wrong table UUID"
assert ($invalid_result.stderr | str contains "Invalid parent UUID") "Should show validation error"
```

## Running Tests

### Claude Code Requirements
**CRITICAL**: Claude Code cannot use interactive nix-shell. Always use `--run`:

```bash
# Correct for Claude Code
nix-shell --run "./suite/test-script.nu"

# Incorrect (exits immediately)
nix-shell
./suite/test-script.nu
```

### Execution Patterns

#### Single Test
```bash
nix-shell --run "./suite/test-simple.nu"
```

#### Verify Success
```bash
nix-shell --run "./suite/test-event.nu" 2>&1 | grep "=== All tests completed successfully ==="
```

#### Debug Output (Last 50 Lines)
```bash
nix-shell --run "./suite/test-new.nu" 2>&1 | tail -50
```

#### Efficient Multi-Test
```bash
# Run all with filtered output
nix-shell --run "cd suite && ./test-all.nu" 2>/dev/null | grep -E "PASSED|FAILED"
```

### Debugging Migration Failures

Since migrations run automatically when entering nix-shell, migration errors will prevent test execution. To debug:

```bash
# Quick check for migration errors
nix-shell --run "echo 'Migration check'" 2>&1 | grep -i error

# See detailed migration output (last 50 lines)
nix-shell --run "echo 'Migration check'" 2>&1 | tail -50

# Find specific migration that failed
nix-shell --run "echo 'Migration check'" 2>&1 | grep -B5 -A5 "error"

# Check migration status manually
nix-shell --run "migrate status ./migrations" 2>&1
```

Common migration error patterns:
- **Syntax errors**: Check for missing semicolons or parentheses
- **Dependency errors**: Ensure referenced tables/types exist
- **Permission errors**: Verify correct role is set in migration header
- **Enum errors**: Check enum values are properly quoted

### Debugging Tests

When tests fail, use targeted output:
```bash
# See end of output
nix-shell --run "./suite/test-failing.nu" 2>&1 | tail -50

# Find specific errors
nix-shell --run "./suite/test-failing.nu" 2>&1 | grep -A5 "Error"

# Check assertion failures
nix-shell --run "./suite/test-failing.nu" 2>&1 | grep -B2 "Assertion failed"
```

## Common Issues

### Permission Denied
```bash
# Problem
./suite/test-new.nu  # Error: Permission denied

# Solution
chmod +x suite/test-new.nu
```

### Module Not Found
```nushell
# Problem
let result = (command params)  # Error: Command not found

# Solution
use ../modules *  # Add at top of test
```

### NULL Values Returned as Strings
```nushell
# Problem
assert ($result.parent_uu.0 == null)  # Fails because NULL is "null" string

# Solution (temporary)
assert ($result.parent_uu.0 == "null")  # Check for string "null"

# Explanation
The .psqlrc-nu configuration sets \pset null 'null' to distinguish
NULL from empty strings in CSV format. This causes PostgreSQL NULL
values to be returned as the string "null" rather than nushell's
native null type. A future enhancement will convert these strings
back to proper null values in the psql exec command.
```

### Assertion Syntax Error
```nushell
# Problem
assert ($result | length) > 0 "message"  # Error: expected bool

# Solution
assert (($result | length) > 0) "message"  # Wrap in parentheses
```

### List Access Error
```nushell
# Problem
assert ($result.field | str contains "text")  # Error: can't convert list

# Solution
assert ($result.field.0 | str contains "text")  # Access first element
```

### Nushell String Escaping
```nushell
# Problem
let sql = $"INSERT INTO table (column) VALUES ('value')"  # Parse error

# Solution
let sql = $"INSERT INTO table \(column) VALUES \('value')"  # Escape parentheses
```

## Maintenance Tasks

### Updating Migration Tool

When `chuck-stack-nushell-psql-migration` is updated:

1. **Get new commit hash**:
   ```bash
   cd chuck-stack-nushell-psql-migration
   git log --format="%H" -1
   ```

2. **Update shell.nix**:
   - Find `migrationUtilSrc` section
   - Update `rev` with new commit hash
   - Use placeholder SHA256: `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`

3. **Get correct SHA256**:
   ```bash
   cd test
   timeout 30 nix-shell --command "echo 'testing'" 2>&1 | grep "got:"
   ```

4. **Update with correct hash**:
   - Replace placeholder with the "got:" value

5. **Test update**:
   ```bash
   nix-shell --run "echo 'Update successful'"
   ```

### Migration Commands

Current commands (via chuck-stack-nushell-psql-migration):
```bash
# From within test directory
migrate status ./migrations
migrate run ./migrations
migrate add ./migrations "description"
```

### Role Switching

For DDL operations:
```bash
export PGUSER=stk_superuser
export STK_PG_ROLE=stk_superuser
```

Default role is `stk_login` with `stk_api_role`.

## Document Maintenance Guidelines

### Core Principles
- **Clear and concise**: Remove redundancy, focus on essential information
- **Logical flow**: Start with overview, progress to specifics, end with references
- **Serve AI needs**: Provide concrete examples and templates that can be directly applied
- **Avoid line numbers**: Use searchable string references (e.g., "see Parameters Record Pattern")
- **Current patterns only**: Remove historical context and deprecated approaches
- **Maintain TOC**: Update table of contents when adding or removing major sections
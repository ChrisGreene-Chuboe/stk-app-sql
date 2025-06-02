# Testing Notes

## Database Function Access

**Important**: Always use the `api` schema for function calls in testing and nushell modules.

- ✅ Correct: `SELECT api.get_table_name_uu_json('uuid-here'::uuid);`
- ❌ Incorrect: `SELECT private.get_table_name_uu_json('uuid-here'::uuid);` (permission denied)

The `api` schema provides the public interface following chuck-stack conventions, while `private` schema functions are internal implementation details.

## Test Environment Setup

1. Start test environment: `cd test && nix-shell`
2. Default user is `stk_login` with `stk_api_role` 
3. For DDL testing, switch to superuser:
   ```bash
   export PGUSER=stk_superuser
   export STK_PG_ROLE=stk_superuser
   ```

## Quick Function Tests

```sql
-- Create test data
INSERT INTO api.stk_event (name) VALUES ('test-event');
INSERT INTO api.stk_request (name, description) VALUES ('test-request', 'test description');

-- Test UUID lookup
SELECT api.get_table_name_uu_json(uu) FROM api.stk_event LIMIT 1;
SELECT api.get_table_name_uu_json(uu) FROM api.stk_request LIMIT 1;

-- Test non-existent UUID
SELECT api.get_table_name_uu_json('00000000-0000-0000-0000-000000000000'::uuid);
```

## Nushell Module Testing

### Test Scripts
- `test-simple.nu` - **Reference implementation** for assertion-based testing patterns
- `test-request.nu` - Comprehensive request module functionality test
- `test-event.nu` - Complete event module testing with request integration
- `test-todo-list.nu` - Complete todo list module testing with hierarchical todos

### Testing Best Practices

**IMPORTANT**: Before adding new tests or modifying existing tests, review `test-simple.nu` as the reference implementation for proper assertion-based testing.

#### Use Assertions for Verification
Tests should use nushell's `assert` command to verify expected outcomes rather than relying on "command doesn't fail" testing:

```nushell
# Import assert functionality
use std/assert

# Capture command results
let result = ("Test data" | .append request "test-name")

# Assert on specific outcomes
assert ($result | columns | any {|col| $col == "uu"}) "Result should contain a 'uu' field"
assert ($result.uu | is-not-empty) "UUID field should not be empty"
```

#### Testing Pattern Requirements
1. **Import std/assert**: Always include `use std/assert` at the top of test scripts
2. **Capture results**: Store command outputs in variables for verification
3. **Assert outcomes**: Verify specific expected results, not just execution success
4. **Clear messages**: Provide descriptive assertion failure messages
5. **Reference test-simple.nu**: Follow the established patterns for consistency

### Manual Testing
```nushell
# Import modules
use modules *

# Test basic request creation
"test request" | .append request "test-name"

# Test attached request
"attached request" | .append request "test-name" --attach $some_uuid

# Test event request
"investigate this" | event request $event_uuid
```

### Running Tests

**IMPORTANT**: All nushell tests must be run within the nix-shell environment to access the PostgreSQL database and required dependencies.

```bash
# Single test execution (REQUIRED approach)
nix-shell --run "./test-simple.nu"
nix-shell --run "./test-request.nu" 
nix-shell --run "./test-event.nu"
nix-shell --run "./test-todo-list.nu"

# Run all tests in sequence
for test in test-*.nu { nix-shell --run $"./($test)" }

# Interactive testing (start shell first, then run commands)
nix-shell
# Inside nix-shell:
./test-simple.nu
./test-request.nu
./test-event.nu
./test-todo-list.nu
```

**Why nix-shell is required:**
- Sets up temporary PostgreSQL instance with test database
- Runs database migrations automatically
- Configures environment variables (PGUSER, PGHOST, etc.)
- Provides access to nushell modules and psql commands
- Automatically cleans up on exit
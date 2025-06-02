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

## Help Example Testing Philosophy

### Intent and Benefits

The chuck-stack testing strategy includes validating examples from command `--help` documentation to ensure:

1. **Documentation Accuracy**: Examples in `--help` actually work as shown
2. **Living Documentation**: Help text stays current with code changes
3. **User Confidence**: Users can trust that documented examples will work
4. **Regression Prevention**: Changes that break documented examples are caught
5. **Single Source of Truth**: Examples serve dual purpose as docs and tests

### Documentation-Test Integration Strategy

The complementary strategy between README and `--help` extends to testing:
- **README**: Conceptual understanding and discovery (not directly tested)
- **`--help`**: Implementation examples that become test cases
- **Tests**: Validate that help examples work in practice

### Help Example Standards for Testing

When writing examples in command help comments:

1. **Use Realistic Data**: Examples should use data patterns that can be tested
   ```nushell
   # Good: "User login successful" | .append event "authentication"
   # Avoid: "some text" | .append event "some-name"
   ```

2. **Include Variable Patterns**: Use consistent variable naming for substitution
   ```nushell
   # Good: event get $event_uuid
   # Good: "investigate error" | event request $error_event_uuid  
   ```

3. **Show Progressive Complexity**: Start simple, build to advanced usage
   ```nushell
   # Basic: event list
   # Filtered: event list | where name == "authentication"
   # Piped: event list | get uu.0 | event get $in
   ```

4. **Demonstrate Integration**: Show how commands work together
   ```nushell
   # Create and attach: "investigate this" | event request $event_uuid
   ```

### Testing Implementation Approach

Tests should validate help examples through:

1. **Manual Test Cases First**: Start by manually implementing key examples in test scripts
2. **Variable Substitution**: Replace example variables with real test data
3. **Result Validation**: Assert expected outcomes, not just execution success
4. **Progressive Automation**: Eventually extract and validate examples automatically

### Example Testing Pattern

```nushell
# In test script
echo "=== Testing help examples ==="

# Test example: "User login successful" | .append event "authentication"
let result = ("User login successful" | .append event "authentication")
assert ($result | columns | any {|col| $col == "uu"}) "Event creation should return UUID"

# Test example: event list | where name == "authentication"
let filtered = (event list | where name == "authentication")
assert ($filtered | length) > 0 "Should find authentication events"
```

This approach ensures documentation and code stay synchronized while building user confidence in the examples provided.
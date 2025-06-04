# Testing Notes

## Database Function Access

**Important**: Always use the `api` schema for function calls in testing and nushell modules.

- ✅ Correct: `SELECT api.get_table_name_uu_json('uuid-here'::uuid);`
- ❌ Incorrect: `SELECT private.get_table_name_uu_json('uuid-here'::uuid);` (permission denied)

The `api` schema provides the public interface following chuck-stack conventions, while `private` schema functions are internal implementation details.

## Test Environment Setup

### Nushell-First Architecture

The chuck-stack test environment now uses a **nushell-first architecture** where all database setup, migrations, and operations are handled through nushell scripts rather than bash.

### Starting the Environment

1. **Start test environment**: `cd test && nix-shell`
   - Automatically runs `start-test.nu` for complete environment setup
   - Uses `chuck-stack-nushell-psql-migration` for database operations
   - Sets up PostgreSQL, runs migrations, generates schema details
   - Configures PostgREST and aichat integration

2. **Default user** is `stk_login` with `stk_api_role` 

3. **For DDL testing**, switch to superuser:
   ```bash
   export PGUSER=stk_superuser
   export STK_PG_ROLE=stk_superuser
   ```

### Migration Management (Nushell-Based)

The environment now uses **chuck-stack-nushell-psql-migration** instead of sqlx-cli:

```bash
# Migration status and management (run from $STK_TEST_DIR)
migrate status ./migrations          # Show migration status
migrate history ./migrations         # Show migration history  
migrate run ./migrations --dry-run   # Test without applying
migrate add ./migrations <description> # Create new migration
migrate validate ./migrations        # Validate migration files

# Legacy commands are no longer available:
# sqlx migrate run    ❌ (replaced with: migrate run ./migrations)
# sqlx migrate add    ❌ (replaced with: migrate add ./migrations <description>)
```

### Environment Scripts

- **start-test.nu**: Comprehensive environment setup (database, migrations, schema generation)
- **stop-test.nu**: Clean environment teardown
- **Shell integration**: `nix-shell` automatically calls these scripts

### Best Practices for Nushell/PostgreSQL Integration

1. **Use standard PostgreSQL environment variables**: 
   - `PGHOST`, `PGUSER`, `PGDATABASE` (no more `DATABASE_URL`)
   
2. **Migration file compatibility**: 
   - Existing SQL files work unchanged
   - Standard PostgreSQL SQL syntax (no tool-specific extensions)
   
3. **Nushell SQL patterns**:
   ```nushell
   # Escape opening parentheses in SQL strings
   let sql = $"INSERT INTO table \(column) VALUES \('value')"  # ✅ Correct
   let sql = $"INSERT INTO table (column) VALUES ('value')"    # ❌ Parse error
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
1. **Import modules and assert**: Always include both module imports and assert functionality
   ```nushell
   use ../modules *
   use std/assert
   ```
2. **Make test executable**: Always make test files executable after creation
   ```bash
   chmod +x test-new-feature.nu
   ```
3. **Capture results**: Store command outputs in variables for verification
4. **Assert outcomes**: Verify specific expected results, not just execution success
5. **Clear messages**: Provide descriptive assertion failure messages
6. **Reference test-simple.nu**: Follow the established patterns for consistency

#### Common Testing Pitfalls and Solutions

**❌ Assertion Syntax Errors**
```nushell
# WRONG: Missing parentheses around comparison
assert ($result | length) > 0 "Should have results"  # Error: expected bool, found int

# CORRECT: Wrap comparison in parentheses
assert (($result | length) > 0) "Should have results"
```

**❌ Module Import Issues**
```nushell
# WRONG: Missing module import
let result = (item new "test")  # Error: Command `item` not found

# CORRECT: Import modules first
use ../modules *
let result = (item new "test")
```

**❌ Data Access Errors**  
```nushell
# WRONG: Accessing string field directly on list result
assert ($result.name | str contains "test")  # Error: can't convert list<bool> to bool

# CORRECT: Access first element of list result
assert ($result.name.0 | str contains "test")
```

**❌ Permission Issues**
```bash
# WRONG: File not executable
./test-new-feature.nu  # Error: Permission denied

# CORRECT: Make file executable first
chmod +x test-new-feature.nu
./test-new-feature.nu
```

**✅ Complete Test Creation Checklist**
1. Create test file with `#!/usr/bin/env nu` shebang
2. Import modules: `use ../modules *` and `use std/assert`
3. Make file executable: `chmod +x test-filename.nu`
4. Use proper assertion syntax with parentheses around comparisons
5. Access list result fields with `.0` for first element
6. Run test with `nix-shell --run "./test-filename.nu"`

## Standardized Test Output

**IMPORTANT**: All tests must end with the exact same success message for consistent verification:

```
=== All tests completed successfully ===
```

This standard output enables reliable test verification using grep:
```bash
# Verify test success
nix-shell --run "./test-module.nu" 2>&1 | grep "=== All tests completed successfully ==="
```

**✅ Complete Test Template**
```nushell
#!/usr/bin/env nu

echo "=== Testing module functionality ==="

# REQUIRED: Import modules and assert
use ../modules *
use std/assert

echo "=== Testing command ==="
let result = (command_to_test "parameter")

echo "=== Verifying results ==="
# CORRECT: Wrap comparisons in parentheses
assert (($result | length) > 0) "Should return results"
# CORRECT: Access list elements with .0
assert ($result.field.0 | str contains "expected") "Field should match"
# CORRECT: Boolean fields can be accessed directly if single result
assert ($result.is_active.0) "Should be active"

echo "=== All tests completed successfully ==="
```

### Running Tests

**IMPORTANT**: All nushell tests must be run within the nix-shell environment to access the PostgreSQL database and required dependencies.

```bash
# Single test execution (REQUIRED approach)
nix-shell --run "./test-simple.nu"
nix-shell --run "./test-request.nu" 
nix-shell --run "./test-event.nu"
nix-shell --run "./test-todo-list.nu"

# Verify test success using standardized output
nix-shell --run "./test-event.nu" 2>&1 | grep "=== All tests completed successfully ==="

# Run all tests in sequence
for test in test-*.nu { nix-shell --run $"./($test)" }

# Run all tests and verify success
for test in test-*.nu { 
    echo "Testing $test..."
    if (nix-shell --run $"./($test)" 2>&1 | grep "=== All tests completed successfully ===" | is-empty) {
        echo "❌ FAILED: $test"
    } else {
        echo "✅ PASSED: $test"
    }
}

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
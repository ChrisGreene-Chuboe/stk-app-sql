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
- `test-simple.nu` - Basic standalone request creation test
- `test-request.nu` - Comprehensive request module functionality test

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
```bash
# Run simple test
./test-simple.nu

# Run comprehensive test
./test-request.nu
```
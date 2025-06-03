# Chuck-Stack Module Development Guide

This guide provides comprehensive standards for creating new chuck-stack nushell modules that integrate with the PostgreSQL-based application framework.

## New Module Creation Checklist

### 1. ✅ Module Structure
Create the standard directory structure:
```
stk_module_name/
├── mod.nu           # Main module commands
└── readme.md        # Conceptual documentation
```

### 2. ✅ Constants Pattern
All modules must start with standardized constants:

```nushell
# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_module_name"
const STK_DEFAULT_LIMIT = 10
const STK_MODULE_COLUMNS = "name, description, record_json"  # Content fields first
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"  # Metadata and ID last
```

### 3. ✅ Column Ordering Philosophy
**Content First, Identifiers Last**: Organize columns to prioritize human-readable content:

1. **Content fields** (name, description, record_json) - What users care about most
2. **Temporal fields** (created, updated) - Important for sorting and filtering  
3. **Status fields** (is_revoked) - Operational state information
4. **Identifier fields** (uu) - Technical references (accessed by name when needed)

**Implementation**: Always pass `STK_MODULE_COLUMNS $STK_BASE_COLUMNS` to maintain this order.

### 4. ✅ Command Naming Patterns
Follow these standard command patterns:

#### Core CRUD Operations
- `module list` - List recent records (uses STK_DEFAULT_LIMIT)
- `module get <uu>` - Retrieve specific record by UUID
- `module revoke <uu>` - Soft delete (set revoked timestamp)

#### Content Creation
- `.append module` - Primary creation command (takes piped input)
- `module new` - Alternative creation (parameterized input)

#### Integration Commands
- `module request <uu>` - Create request attached to module record
- `module link <uu>` - Link to other entities (if applicable)

### 5. ✅ Help Documentation Standards
Every command must include rich help comments with:

#### Required Sections
```nushell
# Brief description of what the command does
#
# Longer explanation of purpose, context, and when to use it.
# Explain how this command fits into chuck-stack workflows.
# Include any important behavioral notes or limitations.
#
# Accepts piped input:
#   string - Description text (stored in description field)
#   OR
#   none
#
# Examples:
#   Simple usage example
#   Complex pipeline example  
#   Integration with other commands
#   Real-world workflow example
#
# Returns: Description of return value structure
# Error: When command fails and what to expect
export def "command name" [
    param: type    # Parameter description
] {
    # implementation
}
```

#### Piped Input Documentation Standards
**REQUIRED**: Every command must include an "Accepts piped input" section:

- **For commands that accept piped input**: Specify the data type and purpose
  ```nushell
  # Accepts piped input:
  #   string - Event description text (stored in description field)
  ```

- **For commands that don't accept piped input**: Explicitly state "none"
  ```nushell
  # Accepts piped input: none
  ```

This section must appear after the main description and before the Examples section.

#### Documentation Guidelines
- **Practical examples**: Show real-world usage, not just syntax
- **Pipeline integration**: Demonstrate nushell pipeline patterns
- **Chuck-stack context**: Explain how commands fit into workflows
- **Error guidance**: Document failure conditions clearly

### 6. ✅ README Documentation Pattern
Module READMEs follow the discovery-oriented pattern:

#### Required Sections
1. **Conceptual Overview**: Why the module exists and its role
2. **Integration with Chuck-Stack**: How it fits the broader system
3. **Available Commands**: List with brief descriptions
4. **Quick Start**: Import and basic usage examples
5. **Learn More**: Links to related chuck-stack documentation

#### Documentation Philosophy
- **README for concepts**, `--help` for implementation details
- Focus on discovery and understanding, not command syntax
- Guide users to built-in help for detailed usage
- Avoid duplicating command details between README and help

### 7. ✅ Testing Requirements
**See [../test/TESTING_NOTES.md](../test/TESTING_NOTES.md) for comprehensive testing standards.**

Key requirements for module tests:
- Follow assertion-based testing patterns from `test-simple.nu`
- Test all primary commands with descriptive error messages
- End with standardized output: `=== All tests completed successfully ===`
- Make test files executable: `chmod +x test-module.nu`
- Run tests in nix-shell environment

### 8. ✅ Integration Patterns
Modules should integrate cleanly with the chuck-stack ecosystem:

#### Database Integration
- Always use `api` schema for function calls
- Follow chuck-stack postgres conventions
- Use soft deletes (revoke) instead of hard deletes
- Leverage existing infrastructure (entities, types, etc.)

#### Module Interaction
- Support piping between modules
- Create cross-module workflows (events → requests → todos)
- Use UUID references for entity relationships
- Maintain audit trails through events

#### Nushell Integration
- Embrace functional programming patterns
- Support pipeline data processing
- Return structured data (tables/records)
- Use consistent error handling

## Implementation Templates

### Basic Module Template
```nushell
# Module Constants
const STK_SCHEMA = "api"
const STK_PRIVATE_SCHEMA = "private"
const STK_TABLE_NAME = "stk_module"
const STK_DEFAULT_LIMIT = 10
const STK_MODULE_COLUMNS = "name, description, record_json"
const STK_BASE_COLUMNS = "created, updated, is_revoked, uu"

# Primary creation command
#
# Brief description of what this command does and its purpose
# in the chuck-stack system context.
#
# Accepts piped input:
#   string - Module description text (stored in description field)
#
# Examples:
#   "content text" | .append module "module-name"
#   "detailed content" | .append module "name" --metadata '{"key": "value"}'
#
# Returns: The UUID of the newly created module record
export def ".append module" [
    name: string                    # The name/topic of the record
    --metadata(-m): string          # Optional JSON metadata
] {
    let table = $"($STK_SCHEMA).($STK_TABLE_NAME)"
    let metadata_json = if ($metadata | is-empty) { "'{}'" } else { $"'($metadata)'" }
    let sql = $"INSERT INTO ($table) \(name, description, record_json) VALUES \('($name)', '($in)', ($metadata_json)::jsonb) RETURNING uu"
    
    psql exec $sql
}

# List recent records
#
# Displays the most recent module records to help with discovery
# and investigation. Use returned UUIDs with other commands.
#
# Accepts piped input: none
#
# Examples:
#   module list
#   module list | where name =~ "pattern"
#
# Returns: name, description, record_json, created, updated, is_revoked, uu
export def "module list" [] {
    psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_MODULE_COLUMNS $STK_BASE_COLUMNS $STK_DEFAULT_LIMIT
}

# Get specific record by UUID
#
# Retrieves complete details for a single module record when you need
# to inspect its contents or extract specific data.
#
# Accepts piped input: none
#
# Examples:
#   module get "uuid-here"
#   module list | get uu.0 | module get $in
#
# Returns: name, description, record_json, created, updated, is_revoked, uu
export def "module get" [
    uu: string  # UUID of the record to retrieve
] {
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_MODULE_COLUMNS $STK_BASE_COLUMNS $uu
}

# Soft delete record (revoke)
#
# Performs a soft delete by setting the revoked timestamp. Use this
# instead of hard deleting to maintain audit trails.
#
# Accepts piped input: none
#
# Examples:
#   module revoke "uuid-here"
#   module list | where name == "old" | get uu.0 | module revoke $in
#
# Returns: Revocation status and timestamp information
export def "module revoke" [
    uu: string  # UUID of the record to revoke
] {
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $uu
}
```

### README Template
```markdown
# STK Module Name

Brief description of what this module does and why it exists in chuck-stack.

## Conceptual Overview

**Primary Purpose**: Explain the main role this module plays...

**Integration Role**: How it fits with other chuck-stack components...

## Integration with Chuck-Stack

- **Pattern compliance**: How it follows chuck-stack conventions
- **Related modules**: Which other modules it works with
- **Workflow integration**: Where it fits in business processes

## Available Commands

Brief list of commands with one-line descriptions:

```nu
module list      # Browse recent records
module get       # Inspect specific records  
module revoke    # Soft delete records
.append module   # Create new records
```

**For complete usage details, examples, and best practices:**

```nu
module list --help
.append module --help
```

## Quick Start

```nu
# Import the module
use modules *

# Basic usage
"content" | .append module "name"

# Check results
module list
```

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Related Module Documentation](../stk_related/readme.md)
```

## Quality Checklist

Before considering a module complete, verify:

- [ ] Constants follow the standard pattern
- [ ] Column ordering prioritizes content fields
- [ ] All commands have rich help documentation
- [ ] README focuses on concepts, not implementation
- [ ] Tests follow patterns from [../test/TESTING_NOTES.md](../test/TESTING_NOTES.md)
- [ ] Module integrates with existing chuck-stack patterns
- [ ] Code follows nushell best practices
- [ ] Documentation is discoverable and helpful

## Reference Implementation

The [stk_event module](stk_event/) serves as the canonical example of these patterns. Study its structure, documentation, and tests when creating new modules.
# Chuck-Stack Nushell Modules

These modules provide idiomatic nushell commands for working with chuck-stack's PostgreSQL-based application framework. They transform database operations into functional, pipeline-friendly commands that integrate seamlessly with nushell's data processing capabilities.

## Why These Modules Exist

Chuck-stack uses PostgreSQL as both database and application server, following specific [postgres conventions](https://chuck-stack.org/postgres-conventions.html). These nushell modules bridge the gap between raw SQL and nushell's structured data philosophy, providing:

- **Type-safe database operations** with structured input/output
- **Pipeline-friendly commands** that work naturally with nushell tables
- **Consistent patterns** across all chuck-stack database interactions
- **Event-driven workflows** that support audit trails and async processing

## Available Modules

See the [main module file](mod.nu) for the current list of available modules with descriptions. Each module focuses on a specific chuck-stack table or concept. Use `<module> --help` or `help <command>` to explore detailed usage for any command.

## Quick Start

```nu
# Import all chuck-stack modules
use modules *

# Log an event and get its UUID
"User login successful" | .append event "authentication"

# list events
event list

# List recent events and work with results
let events = (event list)
$events.0.uu  # Get first event's UUID
$events | where name == "authentication"  # Filter by event type
```

## Common Nushell + Chuck-Stack Patterns

### Store List Results in Variables
Instead of re-running list commands, store results for multiple operations:

```nu
# Store the result once
let events = (event list)

# Reference by index multiple times
$events.0.uu        # First event UUID
$events.2.name      # Third event name
$events | length    # Count of events

# Use with other commands
$events.1.uu | event get $in
"follow up needed" | event request $events.0.uu
```

### Pipeline Data Processing
Leverage nushell's pipeline strengths with chuck-stack data:

```nu
# Chain filtering and processing
event list 
| where name =~ "error" 
| each { |row| $"Event ($row.uu): ($row.record_json.text)" }
| str join "\n"

# Process and create requests
event list 
| where created > (date now) - 1hr
| where name == "critical"
| each { |event| "urgent review" | event request $event.uu }
```

### Working with JSON Data
Chuck-stack stores structured data in PostgreSQL JSONB columns:

```nu
# Extract JSON content from events
let events = (event list)
$events | select name record_json.text created

# Process JSON data in pipelines
event list 
| get record_json 
| where $it.severity? == "high"
| length
```

## Integration with Chuck-Stack

These modules implement chuck-stack's core patterns:

- **Event-driven architecture**: All significant actions create events
- **Request tracking**: Link follow-up actions to events via requests  
- **UUID-based references**: Consistent entity identification
- **JSON-structured data**: Flexible data storage in JSONB columns
- **Audit trails**: Immutable event logs with soft-delete (revoke)

## Module Development

### Module Structure
Each module follows a standard structure:
- `mod.nu`: The main module file containing commands
- `readme.md`: Documentation for the module

The root `mod.nu` file exports all sub-modules for easy access.

### Adding New Modules
When creating new modules:
1. Create a new directory for your module
2. Add a `mod.nu` file with your commands
3. Add a `readme.md` file with documentation  
4. Update the root `mod.nu` file to export your module
5. Follow the [stk_event module](stk_event/) as your documentation template

## Learn More

- [CLI Design Philosophy](cli-design.md) - Design methodologies and patterns used in chuck-stack commands
- [Chuck-Stack PostgreSQL Conventions](https://chuck-stack.org/postgres-conventions.html)
- [Event Module Documentation](stk_event/readme.md)
- [Nushell Pipeline Fundamentals](https://www.nushell.sh/book/pipelines.html)

For detailed command usage, use nushell's built-in help system: `help <command>` or `<command> --help`.

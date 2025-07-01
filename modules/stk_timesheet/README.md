# STK Timesheet Module

The `stk_timesheet` module provides time tracking functionality within chuck-stack by wrapping the `stk_event` table with timesheet-specific commands.

## Conceptual Overview

Timesheets in chuck-stack are specialized events that record time spent on various activities. Each timesheet entry:
- Must be attached to another record (project, task, request, etc.)
- Stores duration in minutes for precision
- Includes a start date/time
- Can have an optional description

This design allows flexible time tracking across any chuck-stack entity while maintaining data integrity through JSON schema validation.

## Architecture

The module is a domain wrapper around `stk_event`, filtering to only `TIMESHEET` type events. Time data is stored in the `record_json` field with schema validation ensuring:
- Required `start_date` (timestamp)
- Required `minutes` (0-1440 range)
- Optional `description`

## Quick Start

Record time against a project:
```nushell
$project_uuid | .append timesheet --hours 2.5 --description "Code review"
```

View all timesheet entries:
```nushell
timesheet list
```

Calculate total hours for a project:
```nushell
timesheet list | where table_name_uu_json.uu == $project_uuid | get record_json.minutes | math sum | $in / 60
```

## Integration Patterns

### Time Entry Workflow
1. Identify the record to track time against (project, task, etc.)
2. Use `.append timesheet` with the record's UUID piped in
3. Specify duration as either `--minutes` or `--hours`
4. Optionally add `--description` and `--start-date`

### Reporting and Analysis
Leverage nushell's pipeline capabilities:
- Filter by date: `where record_json.start_date > "2024-01-01"`
- Group by day: `group-by { $in.record_json.start_date | into datetime | format date "%Y-%m-%d" }`
- Sum totals: `get record_json.minutes | math sum`
- Join with projects: `elaborate name table_name`

## Commands

For detailed command usage, use the built-in help:
- `.append timesheet --help`
- `timesheet list --help`
- `timesheet get --help`
- `timesheet revoke --help`
- `timesheet types --help`

## Related Concepts

- **stk_event**: The underlying table that stores timesheet data
- **stk_project**: Common attachment target for project time tracking
- **stk_project_line**: Track time against specific tasks within projects
- **stk_request**: Track time spent on support tickets or requests

## Learn More

- [Event Module Documentation](../stk_event/README.md)
- [Project Module Documentation](../stk_project/README.md)
- [Chuck-Stack Conventions](../../../chuckstack.github.io/src-ls/postgres-convention/)
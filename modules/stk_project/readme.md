# STK Project Module

The `stk_project` module provides commands for managing projects and project lines in the chuck-stack system. Projects represent client work, internal initiatives, research efforts, or maintenance activities that can contain multiple line items and tasks.

## Core Concept

Projects in chuck-stack serve as containers for organizing work into manageable units. Each project can have multiple project lines representing specific tasks, milestones, deliverables, or resource allocations. This hierarchical structure enables detailed project management and billing integration.

## Project Types

Projects are classified using these built-in types:
- **CLIENT**: Client projects for external customers (default)
- **INTERNAL**: Internal company projects
- **RESEARCH**: Research and development projects  
- **MAINTENANCE**: Maintenance and support projects

## Project Line Types

Project lines are classified using these built-in types:
- **TASK**: Project tasks or work items (default)
- **MILESTONE**: Project milestones or checkpoints
- **DELIVERABLE**: Project deliverables or outputs
- **RESOURCE**: Project resource allocations

## Quick Start

```nushell
# Create a simple project (uses default CLIENT type)
project new "Website Redesign"

# Create a project with description and type
project new "CRM Development" --type "INTERNAL" --description "Internal CRM system development"

# List recent projects
project list

# Get project details including type information
project list | get uu.0 | project detail $in

# View available project types
project types

# Add a line to a project
project line new $project_uu "User Authentication" --type "TASK" --description "Implement user auth system"

# List project lines
project line list $project_uu

# Get line details with type information
project line list $project_uu | get uu.0 | project line detail $in

# View available line types
project line types
```

## Integration with Chuck-Stack

Projects integrate seamlessly with other chuck-stack concepts:
- **Hierarchy**: Support parent-child relationships for sub-projects
- **Line Items**: Project lines can be tagged with `stk_item` for billing purposes
- **Events**: Generate events for project milestones and status changes
- **Requests**: Create follow-up actions and todos for projects and lines
- **Templates**: Create project and line templates for consistent project setup
- **Entity Ownership**: Projects belong to specific entities for multi-tenant isolation

## Command Discovery

For detailed usage of any command, use the `--help` flag:
```nushell
project new --help
project list --help
project detail --help
project line new --help
project line list --help
project line types --help
```

## Learn More

For deeper understanding of chuck-stack conventions and architecture, see:
- [PostgreSQL conventions documentation](../../chuckstack.github.io/src-ls/postgres-conventions.md)
- [Sample table convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md)
- [Entity and type patterns](../../chuckstack.github.io/src-ls/postgres-convention/enum-type-convention.md)
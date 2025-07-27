# STK Entity Module

Entities represent organizational units within chuck-stack that can own records and enable specific business capabilities.

## Core Concepts

### What is an Entity?

An entity is an organizational container that:
- Represents companies, departments, divisions, or business units
- Provides ownership context for records and transactions
- Supports hierarchical parent-child relationships
- Enables specific capabilities based on type

### Entity Types

Chuck-stack supports different entity types for different purposes:

- **General (*) Entities**: Standard organizational units for grouping and ownership
- **Transactional (TRX) Entities**: Enable financial operations like invoicing and accounting

### Key Features

- **Hierarchical Structure**: Create parent-child relationships between entities
- **Type-Driven Behavior**: Entity type determines available operations
- **Template Support**: Create reusable entity templates
- **Soft Delete**: Entities are revoked, not deleted, preserving history

## Common Patterns

### Creating Organizational Hierarchy

```nu
# Create parent company
let company = (entity new "Digital Consulting LLC" --type-search-key "TRX")

# Create divisions under the company
$company | entity new "West Coast Division"
$company | entity new "East Coast Division"

# Create departments under divisions
entity list | where name == "West Coast Division" | entity new "Sales Department"
```

### Setting Up for Invoicing

Transactional entities enable financial operations:

```nu
# Create a TRX entity for invoicing
entity new "My Consulting Business" --type-search-key "TRX" --description "Primary business entity for client invoicing"
```

## Integration with Chuck-Stack

Entities integrate throughout chuck-stack:
- **Invoicing**: TRX entities enable invoice creation and processing
- **Projects**: Can be assigned to entities for ownership
- **Business Partners**: Interact with entities in transactions
- **Accounting**: TRX entities support financial posting

## Discovery

Use tab completion to explore entity commands:
```nu
entity <tab>     # See all available commands
entity new --help     # Detailed help for any command
```

## Learn More

- See [postgres-convention](../../chuckstack.github.io/src-ls/postgres-convention/) for database design patterns
- Review migration files for entity table structure
- Check demo scripts for practical examples
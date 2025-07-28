# Business Partner Module

The Business Partner (BP) module manages financial relationships in chuck-stack. A Business Partner represents anyone you engage with financially - customers, vendors, employees, contractors, or partners.

## Core Concepts

### Entity Types vs Business Roles

Business Partners have two distinct aspects:

1. **Entity Type** (via `type_uu`): Defines the structural nature of the BP
   - `ORGANIZATION` - Companies, corporations, or legal entities
   - `INDIVIDUAL` - People or sole proprietors  
   - `GROUP` - Groups of related entities

2. **Business Roles** (via tags): Defines how you interact with the BP
   - `BP_CUSTOMER` - Buys from you
   - `BP_VENDOR` - Sells to you
   - `BP_EMPLOYEE` - Works for you
   - `BP_CONTRACTOR` - Provides services

A single BP can have multiple roles - for example, a company might be both a customer and a vendor.

### Templates

BP templates provide standardized starting points for creating new partners. Create templates with common settings, then use them to ensure consistency across similar partners.

### Hierarchies

Business Partners support parent-child relationships for modeling:
- Corporate subsidiaries
- Franchise relationships
- Department structures
- Consolidated groups

## Quick Start

```bash
# Create a new business partner
bp new "ACME Corporation"

# List recent partners
bp list

# Add customer role to a BP
bp list | where name == "ACME Corporation" | tag append --type-search-key bp-customer

# Create from template
bp list --templates | where name == "Standard Customer" | bp new "New Customer Inc"
```

## Integration with Chuck-Stack

- **Invoices**: Reference BPs via `table_name_uu_json`
- **Tags**: Assign roles and attributes (addresses, contacts)
- **Events**: Track BP interactions and history
- **Documents**: Attach contracts and agreements

## Learn More

For detailed command usage, use the built-in help:
```bash
bp new --help
bp list --help
bp get --help
```

See also:
- Tag module for managing BP roles and attributes
- Invoice module for financial transactions
- Chuck-stack [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for design patterns
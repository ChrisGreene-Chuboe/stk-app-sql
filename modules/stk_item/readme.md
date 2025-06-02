# STK Item Module

The `stk_item` module provides commands for managing items in the chuck-stack system. Items represent products, services, accounts, or charges that can be referenced throughout business processes like orders, invoices, and inventory management.

## Core Concept

Items in chuck-stack serve a similar purpose to `m_product` in iDempiere ERP systems. They represent the fundamental "things" that your business deals with - whether physical products, intangible services, accounting charges, or other categorizable entities.

## Item Types

Items are classified using these built-in types:
- **PRODUCT-STOCKED**: Physical products tracked in inventory
- **PRODUCT-NONSTOCKED**: Physical products not tracked in inventory  
- **ACCOUNT**: Accounting items representing charges or accounts
- **SERVICE**: Service items for labor, consulting, or intangible deliverables

## Quick Start

```nushell
# Create a simple item (uses default SERVICE type)
item new "Consulting Hours"

# Create a product with description
item new "Laptop Computer" --type "PRODUCT-STOCKED" --description "High-performance business laptop"

# List recent items
item list

# Get item details including type information
item list | get uu.0 | item detail $in

# View available item types
item types
```

## Integration with Chuck-Stack

Items integrate seamlessly with other chuck-stack concepts:
- **Orders**: Reference items in order lines
- **Invoices**: Include items in invoice line items  
- **Inventory**: Track quantities for stocked products
- **Accounting**: Use account-type items for charges and fees
- **Templates**: Create item templates for consistent product creation

## Command Discovery

For detailed usage of any command, use the `--help` flag:
```nushell
item new --help
item list --help
item types --help
```

## Learn More

For deeper understanding of chuck-stack conventions and architecture, see:
- [PostgreSQL conventions documentation](../../chuckstack.github.io/src-ls/postgres-conventions.md)
- [Sample table convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md)
- [Entity and type patterns](../../chuckstack.github.io/src-ls/postgres-convention/enum-type-convention.md)
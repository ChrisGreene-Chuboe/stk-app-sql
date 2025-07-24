# Chuck-Stack Invoice Module

The invoice module provides comprehensive invoice management for both sales and purchase transactions in chuck-stack. It follows the header-line pattern where invoices contain header information with multiple line items.

## Module Purpose

Invoices are essential financial documents that:
- Record sales to customers (SALES_* types)
- Record purchases from vendors (PURCHASE_* types)
- Support various transaction types (standard, credit memo, deposit)
- Maintain audit trails for financial reporting
- Enable template-based recurring billing

## Core Concepts

### Invoice Header
The invoice header (`stk_invoice`) contains:
- Business partner reference (customer or vendor)
- Invoice metadata (dates, terms, totals)
- Processing status for accounting integration
- Template support for recurring invoices

### Invoice Lines
Invoice lines (`stk_invoice_line`) represent:
- Products or services being billed
- Descriptive text lines
- Discounts or adjustments
- References to catalog items

### Business Partner Integration
Invoices directly reference business partners through a foreign key relationship. The BP provides:
- Customer/vendor information
- Payment terms and credit limits
- Billing and shipping addresses
- Tax identification

### Type-Driven Behavior
Invoice types determine transaction behavior:
- **SALES_STANDARD** - Regular customer invoices
- **SALES_CREDIT_MEMO** - Customer refunds/adjustments
- **SALES_DEPOSIT** - Customer prepayments
- **PURCHASE_STANDARD** - Vendor bills
- **PURCHASE_CREDIT_MEMO** - Vendor refunds/adjustments
- **PURCHASE_DEPOSIT** - Vendor prepayments

## Quick Start

```nushell
# Create a customer invoice
bp list | where name == "ACME Corp" | invoice new "INV-2024-001"

# Add line items
$invoice_uuid | invoice line new "Consulting Services" --json '{"quantity": 40, "unit_price": 150}'
$invoice_uuid | invoice line new "Travel Expenses" --json '{"total": 500}'

# View invoice with lines
$invoice_uuid | invoice get | lines

# Create from template
invoice list --templates | first | invoice new "March Invoice"
```

## Key Features

### Pipeline Integration
The module embraces nushell's pipeline philosophy:
```nushell
# Business partner to invoice pipeline
bp list | where name == "Customer" | invoice new "Monthly Invoice"

# Invoice to lines pipeline
invoice list | first | invoice line new "Service Item"
```

### Template Support
Create reusable invoice templates for recurring billing scenarios.

### JSON Flexibility
Store structured data in `record_json` for:
- Payment terms and due dates
- Tax calculations
- Shipping information
- Custom fields

### Processing Status
Track invoice lifecycle with `processed` column:
- Draft invoices can be edited
- Processed invoices are posted to accounting
- Future: Add edit protection for processed invoices

## Integration Points

### Business Partners
- Direct FK ensures valid BP reference
- Clone BP data to preserve historical accuracy
- Support both customer and vendor invoices

### Items Catalog
- Optional item references in lines
- Service and product tracking
- Future: Automatic pricing from catalog

### Financial Reporting
- Aggregate invoice data for reports
- Track outstanding receivables/payables
- Export for accounting systems

## Design Decisions

### Why Direct BP Foreign Key?
Unlike flexible tag-based relationships, invoices have a permanent, required relationship with exactly one business partner. This warrants a direct foreign key for data integrity.

### Why Clone BP Data?
Business partner information can change over time. By cloning relevant data (addresses, terms) to the invoice, we preserve historical accuracy and prevent retroactive changes.

### Service-First Approach
Initial implementation focuses on services and digital delivery without complex inventory or warehouse concepts. Physical product handling can be added later as needed.

## Future Enhancements

- Payment tracking and application
- Tax calculation engine
- Multi-currency support
- Approval workflows
- Email delivery integration
- Accounting system posting

## Command Reference

For detailed command usage and examples, use the built-in help:

```nushell
invoice --help
invoice new --help
invoice line new --help
```

The help system provides comprehensive examples and parameter descriptions for all invoice operations.
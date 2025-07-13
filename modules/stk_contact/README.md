# STK Contact Module

The stk_contact module manages contact records for people associated with business partners in the chuck-stack system.

## Module Purpose

Contacts represent individuals who work with or for business partners. They store flexible attributes like email, phone, and address as JSON metadata. Contacts provide the human connection points for business relationships.

## Core Concepts

- **Contact**: A person associated with a business partner
- **Business Partner Link**: Optional foreign key relationship to stk_business_partner
- **Flexible Attributes**: Contact details stored in record_json (email, phone, address, etc.)
- **Type System**: Extensible contact types via stk_contact_type table

## Quick Start

```nushell
# Create a new contact
contact new "John Smith"

# List recent contacts
contact list

# Get specific contact details
contact list | where name == "John Smith" | contact get

# Create contact with business partner
contact new "Jane Doe" --business-partner-uu $bp_uuid

# Create contact with attributes
contact new "Bob Wilson" --json '{"email": "bob@example.com", "phone": "555-1234"}'
```

## Command Reference

Type `contact <tab>` to see available commands, then use `--help` on any command for detailed documentation:

- `contact new --help` - Create new contacts
- `contact list --help` - Browse existing contacts
- `contact get --help` - Retrieve contact details
- `contact revoke --help` - Soft delete contacts
- `contact types --help` - View available contact types

## Integration with Chuck-Stack

Contacts integrate with:
- **Business Partners**: Link contacts to organizations or individuals
- **Tags**: Categorize contacts for reporting and filtering
- **Events**: Track interactions and activities with contacts

## Learn More

- See `bp` module for business partner management
- Review [chuck-stack conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for system patterns
- Type `contact` for module overview
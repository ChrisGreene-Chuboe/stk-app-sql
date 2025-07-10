# STK Link Module

The chuck-stack link system provides flexible many-to-many relationships between any records without modifying database schemas. Links enable connections like "contact works for multiple business partners" or "project references multiple documents" through a polymorphic linking table.

## Conceptual Overview

**Polymorphic Relationships**: Links connect any two chuck-stack records using the `table_name_uu_json` pattern. This polymorphic design avoids join tables for every relationship type while maintaining referential integrity.

**Directional Semantics**: Links support both BIDIRECTIONAL (both records "know" about each other) and UNIDIRECTIONAL (only source knows about target) relationships. This models real-world relationships accurately - some connections are mutual, others are one-way references.

For BIDIRECTIONAL links, the system provides true symmetric behavior - regardless of which record was the "source" when creating the link, both records see the relationship. This means a bidirectional link from A to B automatically enables B to see A, matching intuitive expectations for mutual relationships.

**Flexible Input Handling**: Link commands accept UUIDs, records, or tables as input for both source and target. This flexibility enables natural command chaining and pipeline operations without manual data extraction.

**Enrichment Pattern**: The `links` pipeline command (in stk_psql) enriches any record stream with associated link data, similar to how `lines` adds line items. This enables discovery of relationships during data exploration.

## Integration with Chuck-Stack

Links integrate with the broader chuck-stack ecosystem:

- **Type System**: Uses `stk_link_type` for BIDIRECTIONAL/UNIDIRECTIONAL semantics
- **JSON Storage**: Leverages `table_name_uu_json` columns for polymorphic references
- **Convention Compliance**: Follows all chuck-stack [postgres conventions](../../chuckstack.github.io/src-ls/postgres-convention/) for consistency

## Available Commands

This module provides five core commands for link management:

```nu
link new     # Create relationships between records
link list    # Browse all links in the system
link get     # Inspect specific links
link revoke  # Soft delete links
link types   # List available link types
```

**For complete usage details, examples, and best practices, use the built-in help:**

```nu
link new --help
link list --help
link get --help
link revoke --help
link types --help
```

## Quick Start

```nu
# Import the module
use modules *

# Link contact to business partner
$contact_uu | link new $business_partner_uu --description "Part-time consultant"

# Link using records from queries
contact list | where name == "John" | link new (bp list | where name == "ACME Corp")

# View all links in the system
link list

# Enrich records with their links (using stk_psql)
contact list | links | table
```

## Use Case: Contact with Multiple Business Partners

Chuck-stack contacts have a primary `business_partner_uu` field, but real-world relationships are often more complex. Links enable modeling these additional relationships:

```nu
# Primary employer (stored in contact table)
contact new "Jane Smith" --business-partner-uu $tech_corp_uu

# Additional relationships via links
$jane_uu | link new $nonprofit_uu --description "Board member"
$jane_uu | link new $consulting_firm_uu --description "Independent contractor"

# Discover all relationships using the pipeline enrichment
contact get --uu $jane_uu | links
```

## Link Types

**BIDIRECTIONAL** (default): Both records can discover the link. Perfect for mutual relationships like "partners with" or "collaborates with". When you create a bidirectional link from A to B, B automatically sees the link back to A - the relationship truly works both ways.

**UNIDIRECTIONAL**: Only the source record sees the link. Ideal for one-way references like "references document" or "inspired by". The target record has no awareness of the link.

## Understanding Link Direction with `links` Command

The `links` enrichment command in stk_psql provides directional filtering:

- **Default behavior**: Shows all relationships (bidirectional links appear from both perspectives)
- **`--outgoing`**: Shows only relationships where the record reaches out to others
- **`--incoming`**: Shows only relationships where others reach out to the record
- **`--all-directions`**: Explicitly shows everything (same as default)

For bidirectional links, the distinction between "incoming" and "outgoing" is logical rather than physical - a friendship is both incoming and outgoing depending on perspective.

## Learn More

- [Chuck-Stack Postgres Conventions](../../chuckstack.github.io/src-ls/postgres-convention/)
- [Table Name UU JSON Pattern](../../chuckstack.github.io/src-ls/postgres-convention/column-convention.md#table_name_uu_json) - Understanding polymorphic references
- [Sample Table Convention](../../chuckstack.github.io/src-ls/postgres-convention/sample-table-convention.md) - How links follow chuck-stack patterns
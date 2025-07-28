# STK Entity Module
# This module provides commands for working with stk_entity tables

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_entity"
const STK_ENTITY_COLUMNS = [search_key, name, description, is_template, is_valid]

# Entity module overview
export def "entity" [] {
    r#'Entities represent organizational units that can own transactions and records.
Entities support hierarchical structures through parent-child relationships.

Type 'TRX' entities enable financial transactions and invoicing.
Type '*' entities are general purpose non-transactional units.

Type 'entity <tab>' to see available commands.
'#
}

# Create a new entity with specified name and type
#
# This is the primary way to create entities in the chuck-stack system.
# Entities represent organizational units like companies, departments, or projects
# that can own records and transactions. TRX entities enable financial operations.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input:
#   string - UUID of parent entity for creating sub-entities (optional)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'entity list | where'
#
# Examples:
#   entity new "Digital Consulting LLC"
#   entity new "Sales Department" --description "Sales and business development"
#   entity new "Acme Corp" --type-search-key trx --description "Transactional entity for invoicing"
#   "12345678-1234-5678-9012-123456789abc" | entity new "Regional Office"
#   entity list | where name == "Parent Company" | entity new "Subsidiary"
#   entity list | first | entity new "Division" --description "Part of parent entity"
#   entity new "Template Corp" --template --type-search-key trx
#   
# Returns: The UUID and name of the newly created entity record
# Note: Uses chuck-stack conventions for automatic type assignment
export def "entity new" [
    name: string                    # The name of the entity to create
    --type-uu: string              # Type UUID (use 'entity types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --search-key(-s): string       # Optional search key (unique identifier)
    --description(-d): string      # Optional description of the entity
    --template                     # Mark this entity as a template
] {
    # Handle optional piped parent UUID
    let piped_input = $in
    let parent_uuid = if ($piped_input | is-not-empty) {
        # Extract UUID from various input types
        let uuid = ($piped_input | extract-single-uu)
        # Validate that the UUID exists in the entity table
        psql validate-uuid-table $uuid $STK_TABLE_NAME
    } else {
        null
    }
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($type_record.uu? | default null)
        search_key: ($search_key | default null)
        description: ($description | default null)
        parent_uu: ($parent_uuid | default null)
        is_template: ($template | default false)
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List the 10 most recent entities from the chuck-stack system
#
# Displays entities in chronological order (newest first) to help you
# monitor recent activity, track entity status, or review organizational structure.
# This is typically your starting point for entity investigation.
# Use the returned UUIDs with other entity commands for detailed work.
# Type information is always included for all entities.
#
# Accepts piped input: none
#
# Examples:
#   entity list
#   entity list 20
#   entity list --all
#   entity list --all 100
#   entity list --templates
#   entity list --detail
#   entity list name description type_enum
#   entity list --all name description is_revoked
#
# Returns: Table of entity records with essential columns
# Note: Default shows only active (non-revoked, non-template) entities
export def "entity list" [
    limit: int = 10                # Number of entities to return (default: 10)
    ...columns: string             # Specific columns to display (overrides default columns)
    --all(-a)                      # Include ALL records (templates AND revoked entities)
    --templates(-t)                # Show ONLY template entities (excludes regular entities)
    --detail(-d)                   # Show all columns (equivalent to select *)
] {
    # Build args array with base parameters
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append (if ($columns | is-empty) { $STK_ENTITY_COLUMNS } else { $columns })
    
    # Add optional flags dynamically
    let args = if $all { $args | append "--all" } else { $args }
    let args = if $templates { $args | append "--templates" } else { $args }
    let args = if $detail { $args | append "--detail" } else { $args }
    
    # Execute with spread operator
    psql list-records ...$args | first $limit
}

# Get details for a specific entity from the chuck-stack system
#
# Retrieves complete information about an entity, including metadata,
# hierarchical relationships, and type classification.
# Always includes related type information for context.
#
# Accepts piped input:
#   string - UUID of the entity to retrieve
#   record - A record containing a 'uu' field  
#   table - Output from entity commands (uses first row)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | entity get
#   entity list | where name == "Digital Consulting LLC" | entity get
#   entity list | first | entity get
#   entity get --uu "12345678-1234-5678-9012-123456789abc"
#
# Returns: Single entity record with all details
# Note: Type information is always included for context
export def "entity get" [
    --uu: string                   # Entity UUID (alternative to piped input)
] {
    # Extract UUID from piped input or parameter - enhanced with utility function
    let entity_uuid = ($in | extract-uu-with-param $uu)
    
    # Always include type for entity get operations
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_ENTITY_COLUMNS $entity_uuid
}

# Revoke an entity in the chuck-stack system (soft delete)
#
# Marks an entity as revoked, preserving the historical record while
# removing it from active use. Revoked entities won't appear in standard
# listings but remain available for audit and historical reference.
#
# Accepts piped input:
#   string - UUID of the entity to revoke
#   record - A record containing a 'uu' field
#   table - Output from entity commands (uses first row)
#   list<any> - List of records (will revoke all)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | entity revoke
#   entity list | where name == "Old Department" | entity revoke
#   entity list | first | entity revoke
#   entity list | where type_enum == "TRX" | first 3 | entity revoke
#   entity revoke --uu "12345678-1234-5678-9012-123456789abc"
#
# Returns: Confirmation of the revoked entity(ies)
# Note: This is a soft delete - data is preserved for historical reference
export def "entity revoke" [
    --uu: string                   # Entity UUID (alternative to piped input)
] {
    # Extract UUID from piped input or parameter - enhanced with utility function
    let entity_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $entity_uuid
}

# Show available entity types in the chuck-stack system
#
# Lists all configured entity types, helping you understand the different
# organizational structures available.
# Types determine the behavior and capabilities of entities.
# 
# Examples:
#   entity types
#   entity types | where type_enum == "TRX"
#   entity types | where is_default
#
# Returns: Table of available entity types with their characteristics
export def "entity types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}
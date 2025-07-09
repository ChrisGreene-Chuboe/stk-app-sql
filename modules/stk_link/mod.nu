# STK Link Module
# This module provides commands for working with stk_link table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_link"
const STK_LINK_COLUMNS = [search_key, description, source_table_name_uu_json, target_table_name_uu_json]

# Link module overview
export def "link" [] {
    r#'Links enable many-to-many relationships between any chuck-stack records
without modifying database structure. Create connections between contacts,
projects, documents, or any other records.

Links can be bidirectional (both records "know" about each other) or
unidirectional (only source knows about target).

Type 'link <tab>' to see available commands.
'#
}

# Create a new link between two records
#
# Creates a relationship between a source record (piped input) and a target record
# (first parameter). Both source and target accept flexible input: UUID strings,
# records with 'uu' field, or tables (uses first row). The link type determines
# if the relationship is bidirectional or unidirectional.
#
# Accepts piped input:
#   string - UUID of source record to link from
#   record - Record with 'uu' field to link from
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # String UUIDs
#   $contact_uu | link new $business_partner_uu --description "Secondary employer"
#   
#   # Record inputs
#   contact get --uu $uuid | link new (bp get --uu $partner_uuid)
#   
#   # Table inputs (from list/where commands)
#   contact list | where name == "John" | link new (bp list | where name == "ACME Corp")
#   
#   # Mixed inputs
#   $contact_uu | link new (project list | where name == "Q4 Initiative") --description "Project lead"
#   
#   # Specify link type (defaults to BIDIRECTIONAL)
#   $doc_uu | link new $project_uu --type-search-key UNIDIRECTIONAL --description "Reference document"
#
# Returns: The UUID of the newly created link record
export def "link new" [
    target: any                     # Target UUID as string, record, or table
    --description(-d): string = ""  # Description of the relationship
    --type-search-key: string       # Link type (BIDIRECTIONAL or UNIDIRECTIONAL)
    --type-uu: string              # Link type UUID (alternative to search key)
] {
    # Extract source and target data with automatic error checking and table_name lookup
    let source = ($in | extract-uu-table-name).0
    let target = ($target | extract-uu-table-name).0
    
    # Build table_name_uu_json objects directly - table_name is always populated
    let source_table_name_uu = {table_name: $source.table_name, uu: $source.uu}
    let target_table_name_uu = {table_name: $target.table_name, uu: $target.uu}
    
    # Type resolution
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key | get uu)
    } else if ($type_uu | is-not-empty) {
        $type_uu
    } else {
        null
    }
    
    # Convert table_name_uu objects to JSON strings
    let source_json = ($source_table_name_uu | to json)
    let target_json = ($target_table_name_uu | to json)
    
    # Build parameters
    mut params = {
        description: $description
        source_table_name_uu_json: $source_json
        target_table_name_uu_json: $target_json
    }
    
    # Only add type_uu if resolved
    if ($resolved_type_uu != null) {
        $params = ($params | insert type_uu $resolved_type_uu)
    }
    
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List all links in the system
#
# Returns all link records. Use --all to include revoked links.
# Results can be filtered using standard nushell operations.
#
# Examples:
#   # List all active links
#   link list
#   
#   # Include revoked links
#   link list --all
#   
#   # Filter by description
#   link list | where description =~ "consultant"
#   
#   # Count links by type
#   link list | group-by type_name | transpose key count | update count { get count | length }
#
# Returns: search_key, description, source_table_name_uu_json, target_table_name_uu_json, created, updated, is_revoked, uu
export def "link list" [
    --all(-a)           # Include revoked links
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_LINK_COLUMNS
    
    # Add --all flag to args if needed  
    let args = if $all { $args | append "--all" } else { $args }
    
    # Execute query
    psql list-records ...$args
}

# Retrieve a specific link by its UUID
#
# Fetches complete details for a single link record including type information.
#
# Accepts piped input:
#   string - The UUID of the link to retrieve
#   record - Record with 'uu' field to retrieve
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | link get
#   link list | get 0 | link get
#   
#   # Using --uu parameter
#   link get --uu "12345678-1234-5678-9012-123456789abc"
#   
#   # Examine link details
#   $link_uu | link get | get source_table_name_uu_json
#
# Returns: Complete link record with type information
export def "link get" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_LINK_COLUMNS $target_uuid
}

# Revoke (soft delete) a link
#
# Marks a link as revoked, effectively removing the relationship between records.
# The link record is retained for audit purposes but excluded from normal listings.
#
# Accepts piped input:
#   string - The UUID of the link to revoke
#   record - Record with 'uu' field to revoke
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # Revoke a specific link
#   $link_uu | link revoke
#   
#   # Find and revoke a link
#   $contact_uu | link list | where description == "Former employer" | link revoke
#   
#   # Using --uu parameter
#   link revoke --uu $link_uu
#
# Returns: Confirmation message
export def "link revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}

# List available link types
#
# Shows the types of links that can be created between records.
# BIDIRECTIONAL links work in both directions, while UNIDIRECTIONAL
# links only work from source to target.
#
# Examples:
#   link types
#   link types | where is_default
#
# Returns: Link type records with enum values and descriptions
export def "link types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}


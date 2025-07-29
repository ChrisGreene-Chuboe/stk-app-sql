# STK Tag Module
# This module provides commands for working with stk_tag table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_tag"
const STK_TAG_COLUMNS = [search_key, description, table_name_uu_json, record_json]

# Tag module overview
export def "tag" [] {
    r#'Tags attach flexible metadata to any chuck-stack record.
Each tag type defines validation rules through JSON Schema.

Tags enable cross-cutting concerns like business roles, classifications,
and custom attributes without modifying core tables.

Type 'tag <tab>' to see available commands.
'#
}

# Create a new tag to attach metadata to any record
#
# Tags provide flexible metadata storage with optional JSON Schema validation.
# You must pipe in a UUID of the record you want to tag. The tag type determines
# what validation rules apply to the metadata you provide. You must specify the
# type using one of: --type-name, --type-search-key, or --type-uu.
# Use --json to provide structured data that will be validated against the type's schema.
#
# Accepts piped input:
#   string - UUID of record to tag (required)
#   record - Record with 'uu' field to tag (required)
#   table - Table with first row containing the record to tag (required)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | .append tag --type-search-key address --json '{"address1": "123 Main St", "city": "Austin", "postal": "78701"}'
#   project list | get uu.0 | .append tag --search-key "headquarters" --type-name "Physical Address" --json '{"address1": "456 Oak Ave", "city": "Dallas", "state": "TX", "postal": "75001"}'
#   project list | get 0 | .append tag --type-search-key address --description "Main office"
#   project list | where name == "HQ" | .append tag --type-name "Physical Address" --json $address_data
#   item list | get uu.0 | .append tag --type-uu $email_type_uu --json '{"email": "support@example.com"}'
#   "12345678-1234-5678-9012-123456789abc" | .append tag --type-search-key none --description "Special handling required"
#   invoice list | get uu.0 | .append tag --search-key "billing-addr" --type-name "Physical Address" --json $address_data
#   
#   # Interactive examples:
#   project list | first | .append tag --type-search-key address --interactive
#   $project_uu | .append tag --type-name "Physical Address" --interactive --description "Main office"
#
# Returns: The UUID of the newly created tag record
# Note: Exactly one type parameter (--type-name, --type-search-key, or --type-uu) must be provided
export def ".append tag" [
    --search-key(-k): string            # Optional search key for the tag (defaults to UUID if not provided)
    --description(-d): string = ""      # Description of the tag (optional)
    --type-name: string                 # Lookup type by name field
    --type-search-key: string           # Lookup type by search_key field  
    --type-uu: string                   # Lookup type by UUID
    --json(-j): string                  # JSON data to store in record_json field (validated against type schema)
    --interactive                       # Interactively build JSON data using the type's schema
] {
    # Extract attachment data from piped input (required for tags)
    let attach_data = ($in | extract-attach-from-input)
    
    # UUID is required for tags
    if ($attach_data == null) or ($attach_data.uu? | is-empty) {
        error make {
            msg: "UUID required: pipe in the UUID of the record you want to tag"
        }
    }
    
    # Resolve type using utility function (handles validation and resolution)
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key --type-name $type_name)
    
    # Validate that type was provided (required for tags)
    if ($type_record == null) {
        error make {
            msg: "Type required: provide one of --type-name, --type-search-key, or --type-uu"
        }
    }
    
    # Handle JSON input - one line replaces multiple lines of boilerplate
    let record_json = (resolve-json $json $interactive $type_record)
    
    # Get table_name_uu as nushell record
    let table_name_uu = if ($attach_data.table_name? | is-not-empty) {
        # We have the table name - use it directly (no DB lookup)
        {table_name: $attach_data.table_name, uu: $attach_data.uu}
    } else {
        # No table name - look it up using psql command
        psql get-table-name-uu $attach_data.uu
    }
    
    # Build parameters record following the pattern
    let base_params = {
        description: ($description | default null)
        type_uu: $type_record.uu
        table_name_uu_json: ($table_name_uu | to json)  # Convert to JSON string for psql new-record
        record_json: $record_json  # Already a JSON string from parse-json
    }
    
    # Use provided search_key or default to type's search_key
    let params = if ($search_key | is-not-empty) {
        $base_params | insert search_key $search_key
    } else {
        # Use the type's search_key as default
        $base_params | insert search_key $type_record.search_key
    }
    
    # Use generic psql command to create the record
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List tags with optional filtering
#
# Displays tags to help you view metadata attachments and their associated records.
# Type information is always included for all tags.
#
# Accepts piped input: none
#
# Examples:
#   tag list                              # List recent tags
#   tag list --all                        # Include revoked tags
#   tag list | where search_key =~ "address"
#   tag list | where type_enum == "ADDRESS"
#
# Using elaborate to resolve foreign key references:
#   tag list | elaborate                  # Resolve with default columns
#   tag list | elaborate search_key table_name  # Show referenced table names
#
# Returns: search_key, description, table_name_uu_json, record_json, created, updated, is_revoked, uu, type_enum, type_name, type_description
export def "tag list" [
    --all(-a)     # Include revoked tags
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TAG_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Execute query
    psql list-records ...$args
}

# Get detailed information about a specific tag
#
# Retrieves complete details for a single tag including its metadata,
# validation schema, and the record it's attached to.
# Useful for debugging or viewing complex tag data.
#
# Accepts piped input:
#   string - UUID of the tag to get
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the tag record
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | tag get
#   tag list | get uu.0 | tag get
#   tag list | get 0 | tag get
#   tag list | where search_key == "headquarters" | tag get
#   
#   # Using --uu parameter
#   tag get --uu "12345678-1234-5678-9012-123456789abc"
#   tag get --uu $tag_uuid
#
# Returns: Tag record fields including type information
export def "tag get" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_TAG_COLUMNS $uu
}

# Revoke (soft delete) a tag
#
# Marks a tag as revoked without removing it from the database.
# This preserves audit history while making the tag inactive.
#
# Accepts piped input:
#   string - UUID of the tag to revoke
#   record - Record with 'uu' field containing the UUID
#   table - Table with first row containing the tag record
#
# Examples:
#   # Using piped input
#   "12345678-1234-5678-9012-123456789abc" | tag revoke
#   tag list | get uu.0 | tag revoke
#   tag list | get 0 | tag revoke
#   tag list | where search_key == "old-address" | tag revoke
#   
#   # Using --uu parameter
#   tag revoke --uu "12345678-1234-5678-9012-123456789abc"
#   tag revoke --uu $tag_uuid
#   
#   # Bulk operations
#   tag list | where search_key =~ "deprecated" | each { |row| tag revoke --uu $row.uu }
#
# Returns: Success message with revoked UUID
export def "tag revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    # Pass columns without 'name' since stk_tag uses 'search_key' instead
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid [uu, search_key, revoked, is_revoked]
}

# List available tag types with their validation schemas
#
# Shows all tag types defined in the system including their JSON Schema
# validation rules. Use this to understand what types are available
# and what data structure each type expects.
#
# Examples:
#   tag types                                    # List all tag types
#   tag types | where type_enum == "ADDRESS"     # Show ADDRESS type details
#   tag types | select type_enum name description | table
#   tag types | where record_json != {}          # Show types with validation schemas
#
# Returns: type_enum, search_key, name, description, record_json (schema), is_default
export def "tag types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}

# Add a 'tags' column to records, fetching associated stk_tag records
#
# This command enriches piped records with a 'tags' column containing
# their associated tag records. It uses the table_name_uu_json pattern
# to find tags that reference the input records.
#
# Examples:
#   project list | tags                          # Default columns
#   project list | tags --detail                 # All tag columns
#   project list | tags search_key record_json   # Specific columns
#
# Returns: Original records with added 'tags' column containing array of tag records
export def tags [
    ...columns: string  # Specific columns to include in tag records
    --detail(-d)        # Include all columns (select *)
    --all(-a)           # Include revoked tags
] {
    $in | psql append-table-name-uu-json $STK_SCHEMA $STK_TABLE_NAME "tags" $STK_TAG_COLUMNS ...$columns --detail=$detail --all=$all
}

# Clone a tag to a different target record
#
# Creates a new tag with identical data (type, record_json, description) but
# attached to a different record. This is useful for preserving historical data
# when copying information between records (e.g., cloning a business partner's
# bill-to address to an invoice).
#
# The cloned tag gets a new UUID and creation timestamp, making it independent
# of the source tag. Changes to the source tag do not affect clones.
#
# Accepts piped input:
#   string - UUID of the tag to clone (required)
#   record - Record with 'uu' field of the tag to clone (required)
#
# Examples:
#   # Clone a specific tag to an invoice
#   $address_tag_uuid | tag clone $invoice_uuid
#   
#   # Clone from a tag record
#   bp list | first | tags | where type_search_key == "address-bill-to" | first | tag clone $invoice_uuid
#   
#   # Clone with parameter instead of positional
#   $tag_uuid | tag clone --target-uu $invoice_uuid
#
# Returns: Record of the newly created cloned tag
export def "tag clone" [
    target_uuid?: string    # UUID of the record to attach the cloned tag to
    --target-uu: string     # Alternative to positional parameter
] {
    # Extract source tag UUID from piped input
    let source_uuid = ($in | extract-single-uu)
    
    # Get target UUID from positional or parameter
    let target = ($target_uuid | default $target_uu)
    
    if ($target | is-empty) {
        error make {msg: "Target UUID required: provide target record UUID"}
    }
    
    # Get table_name and uu for the target
    let target_table_name_uu = (psql get-table-name-uu $target)
    
    if ($target_table_name_uu | is-empty) {
        error make {msg: $"Target record not found: ($target)"}
    }
    
    # Build override for the new attachment point
    let overrides = {
        table_name_uu_json: ($target_table_name_uu | to json)
    }
    
    # Clone and return full record
    clone-record $source_uuid $overrides
}

# Clone a tag of a specific type from a source record to the piped target
#
# Finds a tag of the specified type on the source record and clones it to
# the target record (provided via pipeline). This is a higher-level operation
# that combines tag search and clone in one step.
#
# Useful for workflows like copying a business partner's bill-to address
# to an invoice during invoice creation.
#
# Accepts piped input:
#   string - UUID of the target record to receive the cloned tag (required)
#   record - Record with 'uu' field of the target (required)
#
# Examples:
#   # Clone bill-to address from BP to invoice
#   $invoice_uuid | tag clone-from $bp_uuid --type-search-key address-bill-to
#   
#   # Clone from a BP record to an invoice record
#   invoice list | first | tag clone-from $bp.uu --type-search-key address-bill-to
#   
#   # Clone using type UUID instead of search key
#   $invoice | tag clone-from $bp_uuid --type-uu $bill_to_type_uuid
#
# Returns: Record of the newly created cloned tag
export def "tag clone-from" [
    source_uuid: string         # UUID of the source record to clone tag from
    --type-search-key: string   # Search key of the tag type to clone
    --type-uu: string          # UUID of the tag type to clone (alternative to search key)
] {
    # Extract target UUID from piped input
    let target_uuid = ($in | extract-single-uu)
    
    # Validate type specification
    if ($type_search_key | is-empty) and ($type_uu | is-empty) {
        error make {msg: "Type specification required: provide --type-search-key or --type-uu"}
    }
    
    # Get all tags from the source record
    # First get the record so we can pipe it to tags
    let source_record = (psql get-table-name-uu $source_uuid)
    let source_tags = ($source_record | tags --detail)  # Use --detail to get all columns including type info
    
    if ($source_tags | is-empty) or ($source_tags.tags | is-empty) {
        error make {msg: $"No tags found on source record: ($source_uuid)"}
    }
    
    # Filter to find matching tag by type
    let matching_tags = ($source_tags.tags | where {|tag|
        if ($type_search_key | is-not-empty) {
            $tag.type_search_key == $type_search_key
        } else {
            $tag.type_uu == $type_uu
        }
    })
    
    if ($matching_tags | is-empty) {
        let type_desc = if ($type_search_key | is-not-empty) {
            $"type search key '($type_search_key)'"
        } else {
            $"type UUID '($type_uu)'"
        }
        error make {msg: $"No tag with ($type_desc) found on source record"}
    }
    
    if ($matching_tags | length) > 1 {
        error make {msg: "Multiple tags of the same type found - ambiguous clone request"}
    }
    
    # Clone the found tag to the target
    $matching_tags | first | get uu | tag clone $target_uuid
}

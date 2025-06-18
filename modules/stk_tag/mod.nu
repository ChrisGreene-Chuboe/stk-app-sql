# STK Tag Module
# This module provides commands for working with stk_tag table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_tag"
const STK_TAG_COLUMNS = [search_key, description, table_name_uu_json, record_json]

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
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | .append tag --type-search-key ADDRESS --json '{"address1": "123 Main St", "city": "Austin", "postal": "78701"}'
#   project list | get uu.0 | .append tag --search-key "headquarters" --type-name "Physical Address" --json '{"address1": "456 Oak Ave", "city": "Dallas", "state": "TX", "postal": "75001"}'
#   item list | get uu.0 | .append tag --type-uu $email_type_uu --json '{"email": "support@example.com"}'
#   "12345678-1234-5678-9012-123456789abc" | .append tag --type-search-key NONE --description "Special handling required"
#   invoice list | get uu.0 | .append tag --search-key "billing-addr" --type-name "Physical Address" --json $address_data
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
] {
    let piped_uuid = $in
    
    # UUID is required for tags
    if ($piped_uuid | is-empty) {
        error make {
            msg: "UUID required: pipe in the UUID of the record you want to tag"
        }
    }
    
    # Ensure exactly one type lookup method is provided
    let type_params = [
        ($type_name | is-not-empty)
        ($type_search_key | is-not-empty)
        ($type_uu | is-not-empty)
    ] | where { $in } | length
    
    if $type_params == 0 {
        error make {
            msg: "Type required: provide one of --type-name, --type-search-key, or --type-uu"
        }
    }
    
    if $type_params > 1 {
        error make {
            msg: "Only one type parameter allowed: use either --type-name, --type-search-key, or --type-uu"
        }
    }
    
    # Resolve type record based on the parameter provided
    let type_record = if ($type_uu | is-not-empty) {
        # Fetch the type record by UUID
        psql exec $"SELECT * FROM api.stk_tag_type WHERE uu = '($type_uu)'" | get 0
    } else if ($type_search_key | is-not-empty) {
        # Use flexible psql command to resolve type by search_key
        psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key
    } else {
        # Use flexible psql command to resolve type by name
        psql get-type $STK_SCHEMA $STK_TABLE_NAME --name $type_name
    }
    
    let resolved_type_uu = $type_record.uu
    
    # Handle JSON parameter
    let record_json = if ($json | is-empty) { 
        {}  # Empty object
    } else { 
        ($json | from json)  # Parse JSON string
    }
    
    # Use api.get_table_name_uu_json to populate table_name_uu_json
    let table_name_uu_json_result = (
        psql exec $"SELECT ($STK_SCHEMA).get_table_name_uu_json\('($piped_uuid)') as result"
    )
    let table_name_uu_json = (
        $table_name_uu_json_result.0.result
        | from json
    )
    
    # Build parameters record following the pattern
    let base_params = {
        description: ($description | default null)
        type_uu: $resolved_type_uu
        table_name_uu_json: ($table_name_uu_json | to json)  # Convert back to JSON string for psql new-record
        record_json: ($record_json | to json)  # Convert back to JSON string for psql new-record
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
# Use --detail to include type information for all tags.
#
# Accepts piped input: none
#
# Examples:
#   tag list                              # List recent tags
#   tag list --detail                     # Include type information
#   tag list --all                        # Include revoked tags
#   tag list | where search_key =~ "address"
#   tag list --detail | where type_enum == "ADDRESS"
#
# Using elaborate to resolve foreign key references:
#   tag list | elaborate                  # Resolve with default columns
#   tag list | elaborate search_key table_name  # Show referenced table names
#
# Returns: search_key, description, table_name_uu_json, record_json, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
export def "tag list" [
    --detail(-d)  # Include detailed type information for all tags
    --all(-a)     # Include revoked tags
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_TAG_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Choose command and execute with spread - no nested if/else!
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}

# Get detailed information about a specific tag
#
# Retrieves complete details for a single tag including its metadata,
# validation schema, and the record it's attached to.
# Useful for debugging or viewing complex tag data.
#
# Accepts piped input:
#   string - UUID of the tag to get
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | tag get
#   tag list | get uu.0 | tag get
#   tag list | where search_key == "headquarters" | get uu.0 | tag get --detail
#
# Returns: Tag record fields
# Returns (with --detail): Includes type information
export def "tag get" [
    --detail(-d)  # Include type information
] {
    let uu = $in
    
    if ($uu | is-empty) {
        error make {
            msg: "UUID required: pipe in the UUID of the tag to get"
        }
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_TAG_COLUMNS $uu
    }
}

# Revoke (soft delete) a tag
#
# Marks a tag as revoked without removing it from the database.
# This preserves audit history while making the tag inactive.
#
# Accepts piped input:
#   string - UUID of the tag to revoke
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | tag revoke
#   tag list | get uu.0 | tag revoke
#   tag list | where search_key == "old-address" | get uu | tag revoke
#
# Returns: Success message with revoked UUID
export def "tag revoke" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make {
            msg: "UUID required: pipe in the UUID of the tag to revoke"
        }
    }
    
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
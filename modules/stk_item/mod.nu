# STK Item Module
# This module provides commands for working with stk_item table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_item"
const STK_ITEM_COLUMNS = [name, description, is_template, is_valid, record_json]

# Item module overview
export def "item" [] {
    print "Items are the building blocks of business transactions:
products, services, fees, discounts, taxes, or chart of accounts.

Items can be organized hierarchically and tagged for flexible categorization.

Type 'item <tab>' to see available commands.
"
}


# Create a new item with specified name and type
#
# This is the primary way to create items in the chuck-stack system.
# Items represent products, services, accounts, or charges that can be
# referenced in orders, invoices, inventory, and other business processes.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input: none
#
# Examples:
#   item new "Laptop Computer"
#   item new "Consulting Service" --description "Professional IT consulting"
#   item new "Shipping Fee" --type-search-key "account" --description "Standard shipping charge"
#   item new "Software License" --type-uu "123e4567-e89b-12d3-a456-426614174000"
#   item new "Premium Service" --json '{"features": ["24/7 support", "priority access"]}'
#
# Returns: The UUID and name of the newly created item record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "item new" [
    name: string                    # The name of the item to create
    --type-uu: string              # Type UUID (use 'item types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the item
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    # Validate that only one type parameter is provided
    if (($type_uu | is-not-empty) and ($type_search_key | is-not-empty)) {
        error make {msg: "Specify either --type-uu or --type-search-key, not both"}
    }
    
    # Resolve type if search key is provided
    let resolved_type_uu = if ($type_search_key | is-not-empty) {
        (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key | get uu)
    } else {
        $type_uu
    }
    
    # Handle json parameter - validate if provided, default to empty object
    let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: ($resolved_type_uu | default null)
        description: ($description | default null)
        stk_entity_uu: ($entity_uu | default null)
        record_json: $record_json  # Already a JSON string from parse-json
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List the 10 most recent items from the chuck-stack system
#
# Displays items in chronological order (newest first) to help you
# browse available products, services, and charges. This is typically
# your starting point for item management and selection.
# Use the returned UUIDs with other item commands for detailed work.
# Use --detail to include type information for all items.
#
# Accepts piped input: none
#
# Examples:
#   item list
#   item list --detail
#   item list | where name =~ "laptop"
#   item list --detail | where type_enum == "PRODUCT-STOCKED"
#   item list | where is_template == true
#   item list | where is_revoked == false
#   item list | select name description | table
#
# Create a useful alias:
#   def il [] { item list | select name description search_key }  # Concise item view
#
# Using elaborate to resolve foreign key references:
#   item list | elaborate                                            # Resolve with default columns
#   item list | elaborate name type_enum                             # Show item names with type
#   item list | elaborate --all | select name type_uu_resolved.name  # Show items with type names
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Only shows the 10 most recent items - use direct SQL for larger queries
export def "item list" [
    --detail(-d)  # Include detailed type information for all items
    --all(-a)     # Include revoked items
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_ITEM_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Choose command and execute with spread - no nested if/else!
    if $detail {
        psql list-records-with-detail ...$args
    } else {
        psql list-records ...$args
    }
}

# Retrieve a specific item by its UUID
#
# Fetches complete details for a single item when you need to
# inspect its properties, verify its state, or extract specific
# data. Use this when you have a UUID from item list or from
# other system outputs. Use --detail to include type information.
#
# Accepts piped input:
#   string - The UUID of the item to retrieve (required via pipe or --uu parameter)
#   record - Record with 'uu' field to retrieve
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | item get
#   item get --uu "12345678-1234-5678-9012-123456789abc"
#   item list | get uu.0 | item get
#   item list | get 0 | item get
#   $item_uuid | item get | get description
#   item get --uu $item_uuid --detail | get type_enum
#   $uu | item get | if $in.is_revoked { print "Item was revoked" }
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "item get" [
    --detail(-d)  # Include detailed type information
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let uu = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make { msg: "UUID required via piped input or --uu parameter" }
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
    
    if $detail {
        psql detail-record $STK_SCHEMA $STK_TABLE_NAME $uu
    } else {
        psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS $uu
    }
}

# Revoke an item by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, items are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the item to revoke (required via pipe or --uu parameter)
#   record - Record with 'uu' field to revoke
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   item list | where name == "obsolete-product" | get uu.0 | item revoke
#   item list | where name == "obsolete-product" | get 0 | item revoke
#   item list | where name == "obsolete-product" | item revoke
#   item list | where is_template == true | each { |row| $row | item revoke }
#   "12345678-1234-5678-9012-123456789abc" | item revoke
#   item revoke --uu "12345678-1234-5678-9012-123456789abc"
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or item is already revoked
export def "item revoke" [
    --uu: string  # UUID as parameter (alternative to piped input)
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make { msg: "UUID required via piped input or --uu parameter" }
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
    
    psql revoke-record $STK_SCHEMA $STK_TABLE_NAME $target_uuid
}


# List available item types using generic psql list-types command
#
# Shows all available item types that can be used when creating items.
# Use this to see valid type options and their descriptions before
# creating new items with specific types.
#
# Accepts piped input: none
#
# Examples:
#   item types
#   item types | where type_enum == "SERVICE"
#   item types | where is_default == true
#   item types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all item types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "item types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}
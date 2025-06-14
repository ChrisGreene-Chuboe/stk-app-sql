# STK Item Module
# This module provides commands for working with stk_item table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_item"
const STK_ITEM_COLUMNS = [name, description, is_template, is_valid]

# Note: Type resolution is now handled by the generic psql resolve-type command

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
#   item new "Shipping Fee" --type "ACCOUNT" --description "Standard shipping charge"
#   item new "Software License" --type "PRODUCT-NONSTOCKED"
#
# Returns: The UUID and name of the newly created item record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "item new" [
    name: string                    # The name of the item to create
    --type(-t): string             # Item type: PRODUCT-STOCKED, PRODUCT-NONSTOCKED, ACCOUNT, SERVICE
    --description(-d): string      # Optional description of the item
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
] {
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        name: $name
        type_uu: (if ($type | is-empty) { 
            null 
        } else { 
            psql resolve-type $STK_SCHEMA $STK_TABLE_NAME $type
        })
        description: ($description | default null)
        entity_uu: ($entity_uu | default null)
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
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, type_description from joined type table
# Note: Only shows the 10 most recent items - use direct SQL for larger queries
export def "item list" [
    --detail(-d)  # Include detailed type information for all items
    --all(-a)     # Include revoked items
] {
    # TODO: This nested if/else pattern is not ideal. We need to find a way to build
    # command arguments dynamically in nushell. Currently, spread operators (...$args)
    # are not supported for function calls, forcing us to use this verbose approach.
    # Future parameters will make this even more complex.
    if $detail {
        if $all {
            psql list-records-with-detail $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS --all
        } else {
            psql list-records-with-detail $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS
        }
    } else {
        if $all {
            psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS --all
        } else {
            psql list-records $STK_SCHEMA $STK_TABLE_NAME $STK_ITEM_COLUMNS
        }
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
#   string - The UUID of the item to retrieve (required via pipe)
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | item get
#   item list | get uu.0 | item get
#   $item_uuid | item get | get description
#   $item_uuid | item get --detail | get type_enum
#   $uu | item get | if $in.is_revoked { print "Item was revoked" }
#
# Returns: name, description, is_template, is_valid, created, updated, is_revoked, uu
# Returns (with --detail): Includes type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "item get" [
    --detail(-d)  # Include detailed type information
] {
    let uu = $in
    
    if ($uu | is-empty) {
        error make { msg: "UUID required via piped input" }
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
#   string - The UUID of the item to revoke (required via pipe)
#
# Examples:
#   item list | where name == "obsolete-product" | get uu.0 | item revoke
#   item list | where is_template == true | each { |row| $row.uu | item revoke }
#   "12345678-1234-5678-9012-123456789abc" | item revoke
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or item is already revoked
export def "item revoke" [] {
    let target_uuid = $in
    
    if ($target_uuid | is-empty) {
        error make { msg: "UUID required via piped input" }
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
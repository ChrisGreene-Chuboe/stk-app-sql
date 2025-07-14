# STK Contact Module
# This module provides commands for working with stk_contact table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_contact"
const STK_CONTACT_COLUMNS = [name, description, is_valid, stk_business_partner_uu, record_json]

# Contact module overview
export def "contact" [] {
    r#'Contacts represent people associated with business partners:
employees, decision makers, technical contacts, or billing contacts.

Contacts can be linked to business partners and store flexible attributes
like email, phone, and address in their record_json field.

Type 'contact <tab>' to see available commands.
'#
}

# Create a new contact with specified name
#
# This is the primary way to create contacts in the chuck-stack system.
# Contacts represent people who work with or for business partners.
# Contact attributes like email, phone, and address are stored as JSON metadata.
# The system automatically assigns default type via triggers if not specified.
#
# Accepts piped input:
#   Business partner record with 'uu' and 'table_name' fields
#   Table containing business partner data (uses first row)
#
# Examples:
#   contact new "John Smith"
#   contact new "Jane Doe" --description "Primary contact"
#   contact new "Bob Wilson" --json '{"email": "bob@example.com", "phone": "555-1234"}'
#   contact new "Alice Johnson" --business-partner-uu "123e4567-e89b-12d3-a456-426614174000"
#   bp list | where name == "Acme Corp" | contact new "Technical Support"
#   $business_partner | contact new "Sales Representative"
#
# Returns: The UUID and name of the newly created contact record
# Note: Uses chuck-stack conventions for automatic type assignment
export def "contact new" [
    name: string                    # The name of the contact to create
    --type-uu: string              # Type UUID (use 'contact types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the contact
    --business-partner-uu: string  # Optional business partner UUID
    --json(-j): string             # Optional JSON data to store in record_json field
] {
    # Extract info from piped input if provided
    let extracted = if ($in | is-not-empty) {
        ($in | extract-uu-table-name)
    } else {
        null
    }
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Handle json parameter - validate if provided, default to empty object
    let record_json = try { $json | parse-json } catch { error make { msg: $in.msg } }
    
    # Build parameters record internally - eliminates cascading if/else logic
    mut params = {
        name: $name
        type_uu: ($type_record.uu? | default null)
        description: ($description | default null)
        stk_business_partner_uu: ($business_partner_uu | default null)
        record_json: $record_json  # Already a JSON string from parse-json
    }
    
    # Add foreign key from piped input if present (overrides parameter if both provided)
    if ($extracted != null) {
        let fk_column = $"($extracted.table_name)_uu"
        $params = ($params | upsert $fk_column $extracted.uu)
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-record $STK_SCHEMA $STK_TABLE_NAME $params
}

# List the 10 most recent contacts from the chuck-stack system
#
# Displays contacts in chronological order (newest first) to help you
# browse available contacts. This is typically your starting point for
# contact management and selection.
# Use the returned UUIDs with other contact commands for detailed work.
#
# Accepts piped input: none
#
# Examples:
#   contact list
#   contact list --all
#   contact list | where name =~ "Smith"
#   contact list | where stk_business_partner_uu != null
#   contact list | where is_valid == true
#   contact list | select name description stk_business_partner_uu | table
#
# Create a useful alias:
#   def cl [] { contact list | select name stk_business_partner_uu search_key }
#
# Returns: name, description, is_valid, stk_business_partner_uu, created, updated, is_revoked, uu
# Note: Only shows the 10 most recent contacts - use direct SQL for larger queries
export def "contact list" [
    --all(-a)     # Include revoked contacts
] {
    # Build complete arguments array including flags
    let args = [$STK_SCHEMA, $STK_TABLE_NAME] | append $STK_CONTACT_COLUMNS
    
    # Add --all flag to args if needed
    let args = if $all { $args | append "--all" } else { $args }
    
    # Execute query
    psql list-records ...$args
}

# Retrieve a specific contact by its UUID
#
# Fetches complete details for a single contact when you need to
# inspect its properties, verify its state, or extract specific
# data. Use this when you have a UUID from contact list or from
# other system outputs. Type information is always included.
#
# Accepts piped input:
#   string - The UUID of the contact to retrieve (required via pipe or --uu parameter)
#   record - Record with 'uu' field to retrieve
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | contact get
#   contact get --uu "12345678-1234-5678-9012-123456789abc"
#   contact list | get uu.0 | contact get
#   contact list | get 0 | contact get
#   $contact_uuid | contact get | get record_json
#   contact get --uu $contact_uuid | get stk_business_partner_uu
#
# Returns: name, description, is_valid, stk_business_partner_uu, record_json, created, updated, is_revoked, uu, type information
# Error: Returns empty result if UUID doesn't exist
export def "contact get" [
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
    
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_CONTACT_COLUMNS $uu
}

# Revoke a contact by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, contacts are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the contact to revoke (required via pipe or --uu parameter)
#   record - Record with 'uu' field to revoke
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   contact list | where name == "old-contact" | get uu.0 | contact revoke
#   contact list | where name == "old-contact" | get 0 | contact revoke
#   contact list | where name == "old-contact" | contact revoke
#   "12345678-1234-5678-9012-123456789abc" | contact revoke
#   contact revoke --uu "12345678-1234-5678-9012-123456789abc"
#
# Returns: uu, name, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or contact is already revoked
export def "contact revoke" [
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

# List available contact types using generic psql list-types command
#
# Shows all available contact types that can be used when creating contacts.
# Use this to see valid type options and their descriptions before
# creating new contacts with specific types.
#
# Accepts piped input: none
#
# Examples:
#   contact types
#   contact types | where type_enum == "GENERAL"
#   contact types | where is_default == true
#   contact types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all contact types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "contact types" [] {
    psql list-types $STK_SCHEMA $STK_TABLE_NAME
}
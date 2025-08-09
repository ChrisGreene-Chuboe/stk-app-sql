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
#   contact new "Mary Johnson" --search-key "CONTACT-001" --description "Main contact"
#   
#   # Interactive examples:
#   contact new "Sarah Connor" --type-search-key employee --interactive
#   bp list | first | contact new "IT Manager" --interactive --description "Main tech contact"
#
# Returns: The UUID and name of the newly created contact record
# Note: Uses chuck-stack conventions for automatic type assignment
export def "contact new" [
    name: string                    # The name of the contact to create
    --type-uu: string              # Type UUID (use 'contact types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --search-key(-s): string       # Optional search key (unique identifier)
    --description(-d): string      # Optional description of the contact
    --business-partner-uu: string  # Optional business partner UUID
    --json(-j): string             # Optional JSON data to store in record_json field
    --interactive                  # Interactively build JSON data using the type's schema
] {
    # Extract info from piped input if provided
    let extracted = if ($in | is-not-empty) {
        # Use --first since we only need one parent record
        ($in | extract-uu-table-name --first)
    } else {
        null
    }
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Handle JSON input - one line replaces 15 lines of boilerplate
    let record_json = (resolve-json $json $interactive $type_record)
    
    # Build parameters record internally - eliminates cascading if/else logic
    mut params = {
        name: $name
        type_uu: ($type_record.uu? | default null)
        search_key: ($search_key | default null)
        description: ($description | default null)
        stk_business_partner_uu: ($business_partner_uu | default null)
        record_json: $record_json  # Already a JSON string from parse-json
    }
    
    # Add foreign key from piped input if present (overrides parameter if both provided)
    if ($extracted != null) {
        let fk_column = $"($extracted.table_name)_uu"
        if not (column-exists $fk_column $STK_TABLE_NAME) {
            error make { msg: $"Cannot link ($extracted.table_name) to ($STK_TABLE_NAME) - no foreign key relationship exists" }
        }
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
# Accepts piped input:
#   Business partner record with 'uu' and 'table_name' fields
#   Table containing business partner data (uses first row)
#
# Examples:
#   contact list
#   contact list --all
#   contact list | where name =~ "Smith"
#   contact list | where stk_business_partner_uu != null
#   contact list | where is_valid == true
#   contact list | select name description stk_business_partner_uu | table
#   bp list | where name == "Acme Corp" | contact list
#   $business_partner | contact list
#
# Create a useful alias:
#   def cl [] { contact list | select name stk_business_partner_uu search_key }
#
# Returns: name, description, is_valid, stk_business_partner_uu, created, updated, is_revoked, uu
# Note: Returns all contacts by default - use --limit to control the number returned
export def "contact list" [
    --all(-a)     # Include revoked contacts
    --limit(-l): int  # Maximum number of records to return
] {
    # Extract info from piped input if provided
    let extracted = if ($in | is-not-empty) {
        # Use --first since we only filter by one parent record
        ($in | extract-uu-table-name --first)
    } else {
        null
    }
    
    # Build where constraints if we have foreign key input
    let where_constraints = if ($extracted != null) {
        let fk_column = $"($extracted.table_name)_uu"
        if not (column-exists $fk_column $STK_TABLE_NAME) {
            error make { msg: $"Cannot filter ($STK_TABLE_NAME) by ($extracted.table_name) - no foreign key relationship exists" }
        }
        {$fk_column: $extracted.uu}
    } else {
        {}
    }
    
    # Direct call - psql handles null limit internally
    psql list-records $STK_SCHEMA $STK_TABLE_NAME --all=$all --limit=$limit --where=$where_constraints --priority-columns=$STK_CONTACT_COLUMNS
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
    let uu = ($in | extract-uu-with-param $uu)
    
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
    let target_uuid = ($in | extract-uu-with-param $uu)
    
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

# Edit a contact's JSON data interactively or programmatically
#
# Modifies the record_json field of an existing contact. This command supports
# both direct JSON replacement and interactive editing based on the contact's
# type schema. The interactive mode shows current values and allows selective updates.
#
# Accepts piped input:
#   string - The UUID of the contact to edit (required via pipe or --uu parameter)
#   record - Record with 'uu' field to edit
#   table - Table of records, uses first row's 'uu' field
#
# Examples:
#   # Interactive editing with schema guidance
#   contact list | where name == "John Smith" | contact edit --interactive
#   contact edit --uu $uuid --interactive
#   
#   # Direct JSON replacement
#   contact edit --uu $uuid --json '{"email": "newemail@example.com"}'
#   $contact_uuid | contact edit --json '{"phone": "555-9999"}'
#   
#   # Pipeline from list
#   contact list | first | contact edit --interactive
#
# Returns: The updated contact record with all fields
# Error: Fails if contact not found or JSON is invalid
export def "contact edit" [
    --uu: string              # UUID as parameter (alternative to piped input)
    --json(-j): string        # Direct JSON replacement
    --interactive             # Interactively edit JSON data using the type's schema
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    # Get the current record
    let current = (psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_CONTACT_COLUMNS $target_uuid)
    
    if ($current | is-empty) {
        error make {msg: "Contact not found"}
    }
    
    # Validate parameters
    if ($json != null) and $interactive {
        error make {msg: "Cannot use both --interactive and --json flags"}
    }
    
    if ($json == null) and (not $interactive) {
        error make {msg: "Must specify either --json or --interactive"}
    }
    
    # Get type information for interactive mode
    let type_record = if $interactive {
        psql get-type $STK_SCHEMA $STK_TABLE_NAME --uu $current.type_uu
    } else {
        null
    }
    
    # Determine new JSON content
    let new_json = if $interactive {
        # Use existing interactive-json with --edit parameter
        $type_record | interactive-json --edit $current.record_json
    } else {
        # Direct JSON replacement - validate syntax
        try { $json | parse-json } catch { error make { msg: $in.msg } }
    }
    
    # Update the record
    let sql = $"UPDATE ($STK_SCHEMA).($STK_TABLE_NAME) SET record_json = '($new_json)'::jsonb WHERE uu = '($target_uuid)'"
    psql exec $sql
    
    # Return updated record
    psql get-record $STK_SCHEMA $STK_TABLE_NAME $STK_CONTACT_COLUMNS $target_uuid
}

# Add contact data to records via foreign key relationship
#
# Enriches piped records with their associated contacts by adding a 'contacts' 
# column containing related contact records. This follows the generic foreign key
# discovery pattern used throughout chuck-stack.
#
# Accepts piped input:
#   Table of records to enrich (must have a foreign key relationship to contacts)
#   Single record to enrich (will be treated as a single-row table)
#
# Examples:
#   bp list | contacts
#   bp list | contacts name description  # Specific columns only
#   bp list | contacts --detail           # All contact columns
#   bp list | contacts --all              # Include revoked contacts
#   bp list | contacts --table            # Always return table format
#   $bp | contacts                        # Single record input
#
# Returns: Original records with added 'contacts' column containing arrays of contact records
# Note: Records without matching foreign keys get empty arrays
export def "contacts" [
    ...columns: string  # Specific contact columns to include (default: standard columns)
    --detail(-d)        # Include all contact columns (overrides column list)
    --all(-a)           # Include revoked contacts
] {
    $in | psql append-foreign-key $STK_SCHEMA $STK_TABLE_NAME "contacts" $STK_CONTACT_COLUMNS ...$columns --detail=$detail --all=$all
}
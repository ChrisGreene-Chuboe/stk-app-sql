# STK Address Module
# This module provides AI-powered address commands built on the stk_tag table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_tag"
const STK_ADDRESS_TYPE_KEY = "address"

# Address module overview
export def "address" [] {
    r#'Addresses attach location data to any chuck-stack record as tags.
Each address is validated against the ADDRESS tag type schema.

Supports both AI-powered natural language input and direct JSON entry.
Natural language is the default for ease of use.

Type 'address <tab>' to see available commands.
'#
}

# Append an address tag to a record using natural language, JSON, or interactive input
#
# This command creates an address tag attached to the specified record.
# By default, it uses AI to convert natural language address text into
# structured JSON. With --json, you can provide pre-structured address data.
# With --interactive, you can build the address data interactively using the type's schema.
#
# Pipeline Input:
#   string - UUID of the record to attach the address to
#   record - Record containing a 'uu' field
#   table - Single-row table from commands like 'project list | where'
#
# Examples:
#   # Add address using natural language (AI)
#   $project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681"
#   
#   # Add address with direct JSON input
#   $project_uuid | .append address --json '{"address1": "123 Main St", "city": "Austin", "postal": "78701"}'
#   
#   # Add address from variable
#   let addr = {address1: "123 Main St", city: "Austin", postal: "78701"}
#   project list | first | .append address --json ($addr | to json)
#   
#   # Add shipping address with custom type
#   $contact_uuid | .append address "123 Main St Austin TX" --type-search-key address-ship-to
#   
#   # Add address with custom AI model
#   $entity_uuid | .append address "123 Main St" --model gpt-4
#   
#   # Add address interactively
#   $project_uuid | .append address --interactive
#   project list | first | .append address --interactive --type-search-key address-bill-to
#   
#   # Build address JSON interactively then attach
#   let addr_json = (tag types | where search_key == "ADDRESS" | first | interactive-json)
#   $project_uuid | .append address --json $addr_json
#
# Returns:
#   record - The created address tag with structured data
#
# Errors:
#   - When no UUID is provided via pipeline
#   - When ADDRESS tag type is not found
#   - When AI conversion fails (if using natural language)
#   - When JSON is invalid or missing required fields (if using --json)
#   - When --json and --interactive are both specified
#   - When tag creation fails
export def ".append address" [
    address_text?: string         # Natural language address text (required unless --json or --interactive is provided)
    --type-search-key: string = $STK_ADDRESS_TYPE_KEY  # Tag type search key (default: ADDRESS)
    --model: string               # AI model to use (optional, ignored with --json or --interactive)
    --json: string                # Direct JSON input matching ADDRESS schema (alternative to address_text)
    --interactive                 # Interactively build address data using the type's schema
] {
    # Extract attachment data from piped input
    let attach_data = ($in | extract-attach-from-input)
    
    if ($attach_data | is-empty) {
        error make {msg: "Target UUID required via piped input"}
    }
    
    let target_uuid = $attach_data.uu
    
    # Validate input: either address_text, --json, or --interactive must be provided
    if ($address_text | is-empty) and ($json | is-empty) and (not $interactive) {
        error make {msg: "Either address text, --json parameter, or --interactive flag is required"}
    }
    
    # Check for conflicting input methods
    let input_methods = []
    let input_methods = if ($address_text | is-not-empty) { $input_methods | append "address_text" } else { $input_methods }
    let input_methods = if ($json | is-not-empty) { $input_methods | append "json" } else { $input_methods }
    let input_methods = if $interactive { $input_methods | append "interactive" } else { $input_methods }
    
    if ($input_methods | length) > 1 {
        error make {msg: "Cannot specify multiple input methods: choose one of address text, --json, or --interactive"}
    }
    
    # Get the tag type
    let tag_type = (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key)
    
    if ($tag_type | is-empty) {
        error make {msg: $"Tag type with search key '($type_search_key)' not found"}
    }
    
    # Handle the three input modes
    if $interactive {
        # Use interactive mode - delegate to tag command which handles it
        $attach_data | .append tag --type-search-key $type_search_key --interactive
    } else if ($json | is-not-empty) {
        # Direct JSON input - validate and create tag
        $attach_data | .append tag --type-search-key $type_search_key --json $json
    } else {
        # AI conversion from natural language
        let schema = ($tag_type | get record_json)
        let structured_address = if ($model | is-not-empty) {
            ($address_text | ai text-to-json --schema $schema --model $model)
        } else {
            ($address_text | ai text-to-json --schema $schema)
        }
        let address_json = ($structured_address | to json)
        
        # Create the tag with the structured address data
        $attach_data | .append tag --type-search-key $type_search_key --json $address_json
    }
}
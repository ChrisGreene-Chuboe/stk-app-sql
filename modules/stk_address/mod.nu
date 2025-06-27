# STK Address Module
# This module provides AI-powered address commands built on the stk_tag table

# Module Constants
const STK_SCHEMA = "api"
const STK_TABLE_NAME = "stk_tag"
const STK_ADDRESS_TYPE_KEY = "ADDRESS"

# Append an address tag to a record using natural language
#
# This command uses AI to convert natural language address text into
# structured JSON that matches the ADDRESS tag type schema, then
# creates a tag attached to the specified record.
#
# Pipeline Input:
#   string - UUID of the record to attach the address to
#   record - Record containing a 'uu' field
#   table - Single-row table from commands like 'project list | where'
#
# Examples:
#   # Add address to a project
#   $project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681"
#   
#   # Add address with record input
#   project list | first | .append address "123 Main St Austin TX"
#   
#   # Add address with type specification
#   $contact_uuid | .append address "ship to: 123 Main St Austin TX 78701" --type-search-key ADDRESS_SHIP_TO
#   
#   # Add address with custom AI model
#   $entity_uuid | .append address "123 Main St" --model gpt-4
#
# Returns:
#   record - The created address tag with structured data
#
# Errors:
#   - When no UUID is provided via pipeline
#   - When ADDRESS tag type is not found
#   - When AI conversion fails
#   - When tag creation fails
export def ".append address" [
    address_text: string          # Natural language address text
    --type-search-key: string = $STK_ADDRESS_TYPE_KEY  # Tag type search key (default: ADDRESS)
    --model: string               # AI model to use (optional)
] {
    # Extract UUID from piped input (string, record, or table)
    let target_uuid = ($in | extract-single-uu --error-msg "Target UUID required via piped input")
    
    # Get the tag type and its schema
    let tag_type = (psql get-type $STK_SCHEMA $STK_TABLE_NAME --search-key $type_search_key)
    
    if ($tag_type | is-empty) {
        error make {msg: $"Tag type with search key '($type_search_key)' not found"}
    }
    
    # Extract the JSON schema from tag type
    let schema = ($tag_type | get record_json)
    
    # Convert address text to JSON using AI
    let structured_address = if ($model | is-not-empty) {
        ($address_text | ai text-to-json --schema $schema --model $model)
    } else {
        ($address_text | ai text-to-json --schema $schema)
    }
    
    # Create the tag with the structured address data
    $target_uuid | .append tag --type-search-key $type_search_key --json ($structured_address | to json)
}
# STK Utility Module
# Provides shared utility functions for chuck-stack modules

# Extract UUID and table_name from various input types (foundation utility)
#
# PURPOSE: Normalize any input containing UUIDs into records with both 'uu' and 'table_name' fields.
# Automatically looks up table_name when missing, enforcing chuck-stack's principle that these always go together.
#
# INPUT TYPES:
# - String UUID: "uuid-string" → looks up table_name from database
# - Record with 'uu': {uu: "uuid", ...} → preserves table_name if present, otherwise looks it up
# - Table/list with 'uu' column: [{uu: "uuid"}, ...] → processes each row
#
# RETURN TYPES:
# - Single inputs (string/record) → RECORD {uu: string, table_name: string}
# - Multiple inputs (table/list) → TABLE [{uu: string, table_name: string}, ...]
# - With --first: Takes only the first record (useful for tables)
# - With --table: Always returns table format (useful for uniform processing)
# - With both: Returns a single-row table (first record in table format)
#
# WHEN TO USE:
# - When you need both UUID and table_name for polymorphic operations
# - For commands that work with multiple chuck-stack tables (links, attachments)
# - As foundation for other extraction utilities
# - Use --first when you only want one record from a table
# - Use --table when you need consistent table format for scripting
# - Use both when you want a single-row table
#
# Examples:
#   "uuid-string" | extract-uu-table-name
#   # Returns: {uu: "uuid-string", table_name: "stk_project"}
#
#   project list | first | extract-uu-table-name  
#   # Returns: {uu: "uuid", table_name: "stk_project"}
#
#   project list | extract-uu-table-name
#   # Returns: [{uu: "uuid1", table_name: "stk_project"}, ...]
#
#   # Take first record as single record
#   bp list | extract-uu-table-name --first
#   # Returns: {uu: "...", table_name: "..."}
#
#   # Force table output
#   "uuid" | extract-uu-table-name --table
#   # Returns: [{uu: "...", table_name: "..."}]
#
#   # Take first record as single-row table
#   bp list | extract-uu-table-name --first --table
#   # Returns: [{uu: "...", table_name: "..."}]
#
# Error: Empty input, missing 'uu' field, or UUID not found in database
export def extract-uu-table-name [
    --first  # Take only the first record (for tables with multiple rows)
    --table  # Force table output format
] {
    let input = $in
    
    if ($input | is-empty) {
        error make { msg: "Input required: must be a UUID string, record with 'uu' field, or table with 'uu' column" }
    }
    
    # Step 1: Convert to table format quickly (minimal work)
    let input_type = ($input | describe)
    let as_table = (
        if $input_type == "string" {
            # Just wrap string in table - no lookup yet
            [{uu: $input, table_name: null}]
        } else if ($input_type | str starts-with "record") {
            # Just wrap record in table - no validation yet
            [$input]
        } else if (($input_type | str starts-with "table") or ($input_type == "list<any>")) {
            # Already a table - pass through
            $input
        } else {
            error make { msg: $"Input must be a string UUID, record, or table with 'uu' field, got ($input_type)" }
        }
    )
    
    # Step 2: Apply --first early to minimize work
    let to_process = if $first and ($as_table | length) > 0 {
        [$as_table.0]
    } else {
        $as_table
    }
    
    # Step 3: Validate and process only what we need
    if ($to_process | length) == 0 {
        error make { msg: "Table must contain at least one row" }
    }
    
    let processed = ($to_process | each { |row|
        let uuid = $row.uu?
        if ($uuid | is-empty) {
            error make { msg: "Record must contain 'uu' field" }
        }
        
        # Look up table_name only if missing
        if ($row.table_name? | is-empty) {
            let record = (psql get-table-name-uu $uuid)
            {uu: $record.uu, table_name: $record.table_name}
        } else {
            {uu: $uuid, table_name: $row.table_name}
        }
    })
    
    # Step 4: Determine output format
    if $table {
        # Always return as table
        $processed
    } else if $first and not $table {
        # With --first (and no --table), always return single record
        $processed.0
    } else if ($processed | length) == 1 and not ($input_type | str starts-with "table") and not ($input_type == "list<any>") {
        # Return single record if input was scalar and we have one result
        $processed.0
    } else {
        # Return as table
        $processed
    }
}

# Extract a single UUID string from piped input
#
# PURPOSE: Simple UUID extraction when you only need the UUID string, not table_name.
# Common in commands that already know which table they're working with.
#
# INPUT TYPES:
# - String UUID: passed through directly
# - Record with 'uu': extracts the uu field
# - Table: extracts UUID from first row
#
# WHEN TO USE:
# - In 'new' commands when creating parent-child relationships
# - When passing UUID to functions expecting string parameter
# - When table_name is irrelevant to the operation
#
# Examples:
#   "uuid-string" | extract-single-uu  # Returns: "uuid-string"
#   {uu: "uuid", name: "test"} | extract-single-uu  # Returns: "uuid"
#   project list | first | extract-single-uu  # Returns: "uuid"
#
# Returns: String UUID
# Error: Empty input or missing 'uu' field
export def extract-single-uu [
    --error-msg: string = "UUID required via piped input"
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        error make { msg: $error_msg }
    }
    
    # Handle string UUID directly
    if ($piped_input | describe) == "string" {
        return $piped_input
    }
    
    # For records/tables, use extract-uu-table-name with --first to get single record
    let extracted = ($piped_input | extract-uu-table-name --first)
    if ($extracted | is-empty) {
        error make { msg: "No valid UUID found in input" }
    }
    
    # Now we always get a single record back
    $extracted.uu
}

# Extract attachment data from piped input or --attach parameter (null-safe wrapper)
#
# PURPOSE: This is a specialized wrapper around extract-uu-table-name that provides
# null-safe behavior for optional attachments in .append commands.
#
# WHY THIS EXISTS:
# While extract-uu-table-name throws errors on empty input (required behavior for most
# commands), some commands like 'event .append' and 'request .append' need to support
# OPTIONAL attachments. This wrapper provides that null-safe behavior while also
# handling the dual input pattern (pipe OR --attach parameter).
#
# USAGE PATTERNS:
# 1. Optional attachments (stk_event, stk_request): Returns null when no input
#    - Allows creating standalone records without attachments
# 2. Required attachments (stk_tag, stk_timesheet, stk_address): Caller checks for null
#    - These modules throw their own specific error messages
#
# SPECIAL BEHAVIOR:
# - When using --attach parameter with a UUID string, returns {uu: "uuid", table_name: null}
# - The caller is responsible for looking up table_name if needed
# - This differs from piped input where table_name is automatically looked up
#
# Examples:
#   project list | first | extract-attach-from-input  # Returns {uu: "...", table_name: "stk_project"}
#   "" | extract-attach-from-input "uuid-string"       # Returns {uu: "uuid-string", table_name: null}
#   "" | extract-attach-from-input                     # Returns null (no error)
#
# Returns: Record with 'uu' and 'table_name' fields, or null
export def extract-attach-from-input [
    attach?: string  # The --attach parameter value (optional)
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        # No piped input, use --attach parameter
        if ($attach == null or ($attach | is-empty)) {
            null
        } else {
            {uu: $attach, table_name: null}
        }
    } else {
        # Wrapper behavior: extract-uu-table-name handles all validation and lookup
        # Use --first to always get a single record
        ($piped_input | extract-uu-table-name --first)
    }
}

# Extract UUID from either piped input OR --uu parameter
#
# PURPOSE: Support dual input methods for get/revoke commands.
# Allows users to provide UUID via pipe OR command parameter for flexibility.
#
# INPUT SOURCES (uses first available):
# 1. Piped input: String, record with 'uu', or table
# 2. --uu parameter: Direct UUID string
#
# WHEN TO USE:
# - Exclusively in get/revoke commands that accept --uu parameter
# - When implementing dual input pattern for user convenience
#
# Examples:
#   # Via pipe
#   "uuid" | request get  # extract-uu-with-param handles this internally
#   project list | first | request get  # extracts uu from record
#   
#   # Via parameter
#   request get --uu "uuid"  # no piped input needed
#   
#   # In implementation
#   let uuid = ($in | extract-uu-with-param $uu)
#
# Returns: String UUID
# Error: No UUID provided via either pipe or parameter
export def extract-uu-with-param [
    uu?: string  # The --uu parameter value
    --error-msg: string = "UUID required via piped input or --uu parameter"
] {
    let piped_input = $in
    
    if ($piped_input | is-empty) {
        if ($uu | is-empty) {
            error make { msg: $error_msg }
        }
        $uu
    } else {
        ($piped_input | extract-single-uu --error-msg $error_msg)
    }
}

# Parse and validate JSON string with consistent error handling
#
# This helper provides standardized JSON validation across chuck-stack modules.
# It ensures JSON can be parsed and returns either the parsed data or the original
# string, depending on the return-parsed flag. This creates a consistent pattern
# for modules that accept --json parameters.
#
# The standard pattern for modules is:
# 1. Accept --json parameter as string
# 2. Validate it can be parsed (syntax check)
# 3. Pass the original string to database for schema validation
#
# Examples:
#   # Basic validation (returns original string for database)
#   let json_string = ('{"key": "value"}' | parse-json)
#   
#   # Get parsed data for inspection
#   let parsed = ('{"key": "value"}' | parse-json --return-parsed)
#   
#   # Handle empty input with default
#   let record_json = ($json | parse-json --default "{}")
#   
#   # One-liner for modules with optional JSON
#   let record_json = try { $json | parse-json --default "{}" } catch { error make { msg: $in.msg } }
#   
#   # Handle invalid JSON
#   try {
#       '{invalid json}' | parse-json
#   } catch { |err|
#       print $err.msg  # "Invalid JSON format"
#   }
#
# Returns: Original JSON string (default) or parsed data (with --return-parsed)
# Error: Throws standardized error if JSON cannot be parsed

# resolve-type: Resolves type record from --type-uu, --type-search-key, or --type-name parameters
#
# PURPOSE: Standardize type resolution logic across all chuck-stack modules.
# Validates that only one type parameter is provided and returns the complete type record.
# Supports enum filtering for domain-specific type constraints.
#
# PARAMETERS:
# - --schema: Database schema (e.g., "api")
# - --table: Table name for type lookup (e.g., "stk_item")
# - --type-uu: Direct UUID parameter value
# - --type-search-key: Search key parameter value
# - --type-name: Name parameter value
# - --enum: Optional list of allowed type_enum values for filtering/validation
#
# VALIDATION:
# - Errors if more than one type parameter is provided
# - Returns null if no parameters are provided and no default type exists
# - If enum provided, validates resolved type matches allowed values
#
# Examples:
#   # Direct UUID (returns type record)
#   let type_record = (resolve-type --schema "api" --table "stk_item" --type-uu $type_uu)
#   
#   # Search key lookup (returns type record)
#   let type_record = (resolve-type --schema "api" --table "stk_item" --type-search-key $type_search_key)
#   
#   # Name lookup (returns type record)
#   let type_record = (resolve-type --schema "api" --table "stk_item" --type-name $type_name)
#   
#   # Domain wrapper with enum constraint (returns TODO-only types)
#   let type_record = (resolve-type --schema "api" --table "stk_request" --type-name $type --enum ["TODO"])
#   
#   # In module - get just the UUID:
#   let resolved_type_uu = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key | get uu?)
#   
#   # In module - get the full record for interactive features:
#   let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
#
# Returns: Complete type record (with uu, name, type_enum, json_schema, etc.) or null
# Error: If multiple parameters provided, lookup fails, or type doesn't match enum constraint
export def resolve-type [
    --schema: string        # Database schema (required)
    --table: string         # Table name for type lookup (required)
    --type-uu: string      # Direct type UUID
    --type-search-key: string  # Type search key
    --type-name: string    # Type name
    --enum: list<string> = []  # Optional type enum constraint(s) for filtering
] {
    # Validate required parameters
    if ($schema | is-empty) or ($table | is-empty) {
        error make {msg: "Both --schema and --table are required"}
    }
    
    # Count how many type parameters were provided
    let type_params = [
        ($type_uu | is-not-empty)
        ($type_search_key | is-not-empty)
        ($type_name | is-not-empty)
    ] | where { $in } | length
    
    # Validate that only one type parameter is provided
    if $type_params > 1 {
        error make {msg: "Specify only one of --type-uu, --type-search-key, or --type-name"}
    }
    
    # If no type parameters provided, look for best available type
    if $type_params == 0 {
        # Get all types, optionally filtered by enum
        let all_types = if ($enum | length) > 0 {
            psql list-types $schema $table --enum $enum
        } else {
            psql list-types $schema $table
        }
        
        if ($all_types | is-empty) {
            return null
        }
        
        # Sort by is_default DESC (true first), then by created ASC (oldest first)
        # This ensures we get defaults when available, but still get a type when no defaults exist
        return ($all_types | sort-by -r is_default created | first)
    }
    
    # Resolve and return complete type record
    # If enum is specified, we need to validate the result matches the enum
    let type_record = if ($type_name | is-not-empty) {
        psql get-type $schema $table --name $type_name
    } else if ($type_search_key | is-not-empty) {
        psql get-type $schema $table --search-key $type_search_key
    } else if ($type_uu | is-not-empty) {
        psql get-type $schema $table --uu $type_uu
    } else {
        null
    }
    
    # If enum constraint provided, validate the type matches
    if ($enum | length) > 0 and ($type_record != null) {
        if ($type_record.type_enum not-in $enum) {
            error make { msg: $"Type '($type_record.name)' has type_enum '($type_record.type_enum)' which is not in allowed enum [($enum | str join ', ')]" }
        }
    }
    
    $type_record
}

# Resolve JSON data from --json parameter or --interactive flag with type record
#
# PURPOSE: Standardize JSON handling logic across all chuck-stack modules.
# Handles mutual exclusivity, type validation, and JSON parsing in one line.
#
# PARAMETERS:
# - --json: Direct JSON string parameter value
# - --interactive: Interactive mode flag value
# - --type-record: Type record (from resolve-type) - can be null
#
# BEHAVIOR:
# - Validates --json and --interactive are mutually exclusive
# - For interactive mode: validates type record exists with schema
# - For direct JSON: parses and validates syntax
# - Returns empty object "{}" when neither is provided
#
# Examples:
#   # In module implementation (one line replaces 15):
#   let record_json = (resolve-json --json $json --interactive $interactive --type-record $type_record)
#   
#   # With direct JSON
#   resolve-json --json '{"key": "value"}'
#   
#   # With interactive mode
#   resolve-json --interactive --type-record $type_record
#   
#   # With neither (returns "{}")
#   resolve-json
#
# Returns: Valid JSON string ready for database storage
# Error: If validation fails or parameters are invalid
export def resolve-json [
    json_param: any         # Direct JSON string parameter (null if not provided)
    interactive_flag: bool  # Interactive mode flag value
    type_record: any        # Type record for interactive mode (null if not provided)
] {
    # Check mutual exclusivity
    if ($json_param != null) and $interactive_flag {
        error make {msg: "Cannot use both --interactive and --json flags"}
    }
    
    # Handle interactive mode
    if $interactive_flag {
        if ($type_record == null) {
            error make {msg: "Interactive mode requires a type with JSON schema. Use --type-search-key, --type-uu, or ensure a default type exists with a schema."}
        }
        # Use interactive JSON builder
        $type_record | interactive-json
    } else if ($json_param != null) {
        # Handle direct JSON - validate syntax
        try { $json_param | parse-json } catch { error make { msg: $in.msg } }
    } else {
        # Neither provided - return empty object
        "{}"
    }
}

export def parse-json [
    --return-parsed  # Return parsed data instead of original string
    --default: string = "{}"  # Default value when input is empty (typically "{}")
] {
    let json_string = $in
    
    # Handle empty input with default if specified
    if ($json_string | is-empty) {
        if ($default | is-not-empty) {
            return $default  # Return default JSON string
        } else {
            error make { msg: "JSON string cannot be empty" }
        }
    }
    
    # Attempt to parse JSON for validation
    let parsed = try {
        $json_string | from json
    } catch {
        error make { msg: "Invalid JSON format" }
    }
    
    # Return based on flag
    if $return_parsed {
        $parsed
    } else {
        $json_string  # Return original string for database
    }
}

# Generate interactive nushell commands from markdown
#
# Converts a markdown file into an interactive nushell script following the
# nu-tutor2 pattern. This enables creating tutorials that work both as web
# documentation and interactive command-line experiences.
#
# Markdown Structure:
# - H1 (#) defines the tutor name (typically ignored for command generation)
# - H2 (##) and deeper define commands and subcommands
# - First word after # symbols becomes the command name
# - Content after the heading becomes the command body
# - Don't skip heading levels when going deeper
#
# Examples:
#   # Convert tutorial markdown to nushell commands
#   open tutorial.md | tutor-generate | save -f tutorial.nu
#   
#   # Generate from chuck-stack cli-tutor.md
#   open cli-tutor.md | tutor-generate | save -f stk_tutor/mod.nu
#   
#   # Validate markdown structure
#   open tutorial.md | tutor-generate --validate-only
#
# Markdown Example:
#   ## stk
#   ### tutor
#   Welcome to the tutorial
#   #### ops
#   Operations tutorial content
#
# Generated Commands:
#   export def "stk" [] { ... }
#   export def "stk tutor" [] { ... }
#   export def "stk tutor ops" [] { ... }
#   export def "stk list" [] { ... }  # Auto-generated list command
#
# Returns: String containing generated nushell code
# Error: Throws error if markdown structure is invalid
#
# Based on: https://github.com/chuckstack/nu-tutor2
export def tutor-generate [
    --validate-only  # Only validate structure, don't generate code
] {
    let markdown = $in
    
    if ($markdown | is-empty) {
        error make { msg: "No markdown content provided" }
    }
    
    # Split markdown into headings and create info columns
    let list_indent_char = "  "
    let list_indent_id = "- "
    
    mut table_source = $markdown
    | split row -r '(?m)(?<=^)(?=#)' 
    | enumerate 
    | where (($it.item | str length) > 0)
    | insert indent { |row|
        ($row.item | split row ' ' | first | str length) - 1
    }
    | insert command { |row|
        $row.item | str replace -r '^#+\s' '' | split words | first
    } 
    | insert body { |row|
        $row.item | lines | skip 1 | str join "\n"
    }
    | insert list { |row|
        (0..$row.indent | each {$list_indent_char} | str join) | append $list_indent_id | append $row.command | str join
    }
    | insert command-prefix []
    
    # Validate structure
    mut previous_indent = 0
    for row in $table_source {
        if $row.indent > $previous_indent {
            if ($row.indent - $previous_indent) > 1 {
                error make { msg: $"Invalid markdown: jumped from H($previous_indent + 1) to H($row.indent + 1) at '($row.command)'" }
            }
        }
        $previous_indent = $row.indent
    }
    
    if $validate_only {
        return "Markdown structure is valid"
    }
    
    # Build command hierarchy
    mut result = []
    mut previous_command = ""
    mut previous_command_list = []
    $previous_indent = 0
    
    for row in $table_source {
        let new_row = if $row.indent > $previous_indent {
            $previous_command_list = ($previous_command_list | append $previous_command)
            $row | update command-prefix $previous_command_list
        } else if $row.indent < $previous_indent {
            $previous_command_list = ($previous_command_list | drop ($previous_indent - $row.indent))
            $row | update command-prefix $previous_command_list
        } else {
            $row | update command-prefix $previous_command_list
        }
        
        $previous_command = $row.command
        $previous_indent = $row.indent
        $result = ($result | append $new_row)
    }
    
    # Helper function for syntax highlighting
    let nu_light = r#'
        def nu-light [] {
            $in
            | split row '`'
            | enumerate
            | each { if $in.index mod 2 == 1 { $in.item | nu-highlight } else { $in.item } }
            | str join
        } '#
    
    # Generate commands
    let nu_command = $result 
    | each { |row| 
        $"export def \"($row.command-prefix | str join ' ')($row.command-prefix | length | if $in > 0 { ' ' } else { '' })($row.command)\" [] {r#' ($row.body)'#\n | nu-light \n}\n"
    } 
    | str join "\n"
    
    # Generate list command
    let title_command = $result | first | get command
    let list_command = $result | get list | str join "\n"
    let list_command_def = $"export def \"($title_command) list\" [] {r#'($list_command)'#\n | nu-light \n}\n"
    
    # Combine all parts
    $"($nu_light)\n\n($nu_command)\n($list_command_def)"
}

# Interactively build JSON data based on a type's schema
#
# This command reads the pg_jsonschema from a type record and guides
# the user through building valid JSON data interactively. It supports
# both creating new JSON and editing existing JSON data.
#
# The type record must contain:
# - record_json.pg_jsonschema: The JSON schema definition
# - name: The type name (for display)
# - table_name: The type table name (e.g., 'stk_tag_type')
#
# Pipeline Input:
#   record - Type record containing schema (from 'xxx types' commands)
#
# Examples:
#   # Build JSON for a specific type
#   tag types | where search_key == "ADDRESS" | first | interactive-json
#   
#   # Edit existing JSON data
#   tag types | where search_key == "ADDRESS" | first | interactive-json --edit $current_json
#   
#   # Select type interactively then build JSON
#   project types | input list "Select type:" --fuzzy | interactive-json
#   
#   # Build various type schemas
#   bp types | where search_key == "ORGANIZATION" | first | interactive-json
#   bp types | where search_key == "INDIVIDUAL" | first | interactive-json
#   event types | where search_key == "TIMESHEET" | first | interactive-json
#   
#   # Edit existing address with interactive prompts
#   let addr = '{"address1": "123 Main", "city": "Austin", "postal": "78701"}'
#   tag types | where search_key == "ADDRESS" | first | interactive-json --edit $addr
#   
#   # Complete workflow: build JSON then use it
#   let json = (tag types | where search_key == "ADDRESS" | first | interactive-json)
#   $project_uuid | .append tag --type-search-key ADDRESS --json $json
#
# Returns:
#   string - Valid JSON string matching the type's schema
#
# Errors:
#   - When no type record is provided via pipeline
#   - When type has no pg_jsonschema defined
#   - When user cancels the operation
export def "interactive-json" [
    --edit: any        # Existing JSON (string or record) to edit (optional)
] {
    let type_record = $in
    
    # Validate input
    if ($type_record | is-empty) {
        error make {msg: "Type record required via piped input"}
    }
    
    # Extract schema from json_schema field
    let schema = ($type_record.record_json.json_schema? | default {})
    
    if ($schema | is-empty) {
        error make {msg: "Type has no JSON schema defined"}
    }
    
    # Extract type info
    let type_name = ($type_record.name | default "Data")
    let table_name = ($type_record.table_name | default "unknown")
    
    # Determine primary table name (strip _type suffix if present)
    let primary_table = if ($table_name | str ends-with "_type") {
        $table_name | str replace "_type" ""
    } else {
        $table_name
    }
    
    # Build or edit JSON interactively
    let result = if ($edit != null) {
        # Handle both string and record inputs
        let current = if ($edit | describe | str starts-with "string") {
            $edit | from json
        } else {
            $edit  # Already a record
        }
        interactive-build-json $schema --current $current --type-name $type_name
    } else {
        interactive-build-json $schema --type-name $type_name
    }
    
    # Return as JSON string
    $result | to json
}

# Helper: Build JSON interactively from schema
def interactive-build-json [
    schema: record
    --current: record = {}
    --type-name: string = "Data"
] {
    print $"=== ($type_name) Entry ==="
    if not ($current | is-empty) {
        print "(Editing existing data - press Enter to keep current values)"
    }
    print "Required fields marked with *"
    print ""
    
    let properties = ($schema.properties | default {})
    let required = ($schema.required | default [])
    
    # Build prompts from schema
    let prompts = (
        $properties 
        | transpose field spec
        | each {|prop|
            {
                field: $prop.field
                spec: $prop.spec
                required: ($prop.field in $required)
                current: ($current | get -i $prop.field)
            }
        }
    )
    
    # Collect values
    let result = (
        $prompts 
        | reduce -f {} {|prompt, acc|
            let value = interactive-collect-field $prompt
            
            if ($value | describe) == "nothing" {
                $acc  # Skip null values
            } else {
                $acc | insert $prompt.field $value
            }
        }
    )
    
    # Validate required fields
    let missing = $required | where {|field| 
        ($result | get -i $field | is-empty)
    }
    
    if ($missing | length) > 0 {
        print ""
        print $"Missing required fields: ($missing | str join ', ')"
        print "Please provide all required fields."
        print ""
        # Recursive call to try again
        interactive-build-json $schema --current $result --type-name $type_name
    } else {
        # Review and confirm
        print ""
        let required_fields = $required  # Capture for use in closure
        $result 
        | transpose field value 
        | each {|row|
            let is_required = ($row.field in $required_fields)
            {
                Field: $"($row.field)(if $is_required { '*' } else { '' })"
                Value: ($row.value | to text | str substring 0..50)
            }
        }
        | table
        print ""
        
        let action = ["accept" "edit" "cancel"] | input list "Action: "
        
        match $action {
            "accept" => $result
            "edit" => {
                print ""
                print "=== Edit ==="
                interactive-build-json $schema --current $result --type-name $type_name
            }
            "cancel" => {
                error make {msg: "Cancelled by user"}
            }
        }
    }
}

# Helper: Collect value for a single field
def interactive-collect-field [prompt: record] {
    let field_name = $prompt.field
    let is_required = $prompt.required
    let current_value = $prompt.current
    let spec = $prompt.spec
    
    # Build prompt text
    let prompt_text = if ($current_value | is-not-empty) {
        $"($field_name)(if $is_required { '*' } else { '' }) [($current_value)]: "
    } else {
        $"($field_name)(if $is_required { '*' } else { '' }): "
    }
    
    # Handle different field types
    let value = match ($spec.type | default "string") {
        "string" => {
            if ($spec.enum? | is-not-empty) {
                # Enum field - use list selection
                if ($current_value | is-not-empty) {
                    let choices = $spec.enum | prepend $"[current] ($current_value)"
                    let choice = ($choices | input list $"Select ($field_name):" --fuzzy)
                    if ($choice | str starts-with "[current]") {
                        $current_value
                    } else {
                        $choice
                    }
                } else {
                    $spec.enum | input list $"Select ($field_name):" --fuzzy
                }
            } else {
                # Regular string input
                let val = (input $prompt_text)
                if ($val | is-empty) and ($current_value | is-not-empty) {
                    $current_value  # Keep current
                } else if $val == "delete" and not $is_required {
                    null  # Remove field
                } else if ($val | is-empty) and $is_required {
                    # Required field needs a value
                    print $"  ($field_name) is required"
                    interactive-collect-field $prompt  # Retry
                } else {
                    $val
                }
            }
        }
        "number" => {
            # Numeric input with validation
            let val = (input $prompt_text)
            if ($val | is-empty) and ($current_value | is-not-empty) {
                $current_value
            } else if ($val | is-empty) and not $is_required {
                null
            } else {
                try {
                    $val | into float
                } catch {
                    print "  Invalid number"
                    interactive-collect-field $prompt  # Retry
                }
            }
        }
        "integer" => {
            # Integer input with validation
            let val = (input $prompt_text)
            if ($val | is-empty) and ($current_value | is-not-empty) {
                $current_value
            } else if ($val | is-empty) and not $is_required {
                null
            } else {
                try {
                    $val | into int
                } catch {
                    print "  Invalid integer"
                    interactive-collect-field $prompt  # Retry
                }
            }
        }
        "boolean" => {
            # Boolean selection
            let current_str = if ($current_value | is-not-empty) { 
                $current_value | to text 
            } else { 
                "none" 
            }
            let choices = if ($current_value | is-not-empty) {
                ["true" "false" $"[current] ($current_str)"]
            } else {
                ["true" "false"]
            }
            let choice = ($choices | input list $"($field_name): ")
            
            if ($choice | str starts-with "[current]") {
                $current_value
            } else {
                $choice | into bool
            }
        }
        _ => {
            # Default to string for unknown types
            input $prompt_text
        }
    }
    
    $value
}

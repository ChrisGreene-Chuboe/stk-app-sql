# STK Utility Module
# Provides shared utility functions for chuck-stack modules

# Extract uu and table_name from string, record, or table format
#
# This helper function extracts uu and table_name from various input types into a consistent table format
# with 'uu' and optional 'table_name' columns. This allows modules to handle input
# uniformly and sets the foundation for future multi-record support.
#
# Consuming modules currently use only the first record (.0) from the returned table.
#
# Note: Also accepts list<any> type which occurs when nushell can't infer table schema.
# This is common with PostgreSQL query results. See: https://github.com/nushell/nushell/discussions/10897
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", name: "test"} | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: null}]
#
#   {uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project", name: "test"} | extract-uu-table-name
#   # Returns: table with one row: [{uu: "12345678-1234-5678-9012-123456789abc", table_name: "stk_project"}]
#
#   project list | extract-uu-table-name  # Returns full table (even if typed as list<any>)
#   # Returns: table with all rows: [{uu: "uuid1", table_name: "stk_project"}, {uu: "uuid2", table_name: "stk_project"}, ...]
#
# Returns: Table with 'uu' and 'table_name' columns, or empty table if input is empty
# Error: Throws error if any record/table row lacks 'uu' field
export def extract-uu-table-name [] {
    let input = $in
    
    if ($input | is-empty) {
        return []
    }
    
    let input_type = ($input | describe)
    
    if $input_type == "string" {
        # String UUID - return as single-row table
        return [{uu: $input, table_name: null}]
    } else if ($input_type | str starts-with "record") {
        # Single record - extract uu and optional table_name
        let uuid = $input.uu?
        if ($uuid | is-empty) {
            error make { msg: "Record must contain 'uu' field" }
        }
        let table_name = $input.table_name?
        return [{uu: $uuid, table_name: $table_name}]
    } else if (($input_type | str starts-with "table") or ($input_type == "list<any>")) {
        # Table or list<any> - normalize each row
        # Note: list<any> is common when nushell can't infer table schema, especially
        # with PostgreSQL results. See: https://github.com/nushell/nushell/discussions/10897
        if ($input | length) == 0 {
            return []
        }
        
        # Process all rows
        return ($input | each { |row|
            let uuid = $row.uu?
            if ($uuid | is-empty) {
                error make { msg: "Table row must contain 'uu' field" }
            }
            let table_name = $row.table_name?
            {uu: $uuid, table_name: $table_name}
        })
    } else {
        error make { msg: $"Input must be a string UUID, record, or table with 'uu' field, got ($input_type)" }
    }
}

# Extract a single UUID from piped input with validation
#
# This helper reduces the repetitive UUID extraction pattern used in commands like
# 'request get' and 'request revoke'. It handles string UUIDs, records, and tables,
# always returning a single UUID string.
#
# Examples:
#   "uuid-string" | extract-single-uu
#   {uu: "uuid", name: "test"} | extract-single-uu
#   request list | first | extract-single-uu
#
# Returns: String UUID
# Error: Throws error if input is empty or no valid UUID found
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
    
    # For records/tables, use extract-uu-table-name
    let extracted = ($piped_input | extract-uu-table-name)
    if ($extracted | is-empty) {
        error make { msg: "No valid UUID found in input" }
    }
    $extracted.0.uu
}

# Extract attachment data from piped input or --attach parameter
#
# This helper simplifies the common pattern of extracting attachment data
# from either piped input or an --attach parameter. Used in commands that
# support attaching records to other records.
#
# The function returns the exact same structure as the original code:
# - null if no attachment
# - {uu: string, table_name: string|null} if attachment found
#
# Examples:
#   project list | first | extract-attach-from-input
#   "" | extract-attach-from-input "uuid-string"
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
        # Extract uu and table_name, then get first row
        let extracted = ($piped_input | extract-uu-table-name)
        if ($extracted | is-empty) {
            null
        } else {
            $extracted.0
        }
    }
}

# Extract UUID from either piped input or --uu parameter
#
# This helper consolidates the common pattern of accepting a UUID from either:
# - Piped input (string, record with 'uu' field, or table)
# - --uu parameter
#
# This reduces boilerplate in commands that support dual UUID input methods.
#
# Examples:
#   # With piped input
#   "uuid-string" | extract-uu-with-param
#   {uu: "uuid", name: "test"} | extract-uu-with-param
#   
#   # With --uu parameter
#   "" | extract-uu-with-param "uuid-from-param"
#   
#   # With custom error message
#   $in | extract-uu-with-param $uu --error-msg "Tag UUID required"
#
# Returns: String UUID
# Error: Throws error if no UUID provided via either method
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
# Returns:
#   string - Valid JSON string matching the type's schema
#
# Errors:
#   - When no type record is provided via pipeline
#   - When type has no pg_jsonschema defined
#   - When user cancels the operation
export def "interactive-json" [
    --edit: string        # Existing JSON string to edit (optional)
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
    let result = if ($edit | is-not-empty) {
        let current = ($edit | from json)
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
        print "=== Review ==="
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

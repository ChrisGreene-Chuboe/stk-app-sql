# STK AI Module
# This module provides AI-powered text transformation commands for chuck-stack

# Module Constants
const STK_AI_TOOL = "claude"

# Convert natural language text to JSON matching a provided schema
# This command uses AI to transform unstructured text into structured JSON
# that conforms to a given JSON schema specification.
#
# Examples:
#   # Convert address text using schema from tag type
#   let address_schema = (tag types | where search_key == "ADDRESS" | first | get record_json)
#   "123 Main St Austin TX 78701" | ai text-to-json --schema $address_schema
#   
#   # Convert using inline schema
#   "John Doe, CEO" | ai text-to-json --schema {properties: {name: {type: "string"}, title: {type: "string"}}}
#   
#   # Include domain-specific instruction files (base JSON_RESPONSE.md is auto-included)
#   # Instructions are combined and included in the prompt
#   let address_instructions = [([$env.FILE_PWD ".." "stk_address" "ADDRESS_FORMAT.md"] | path join)]
#   "123 Main St" | ai text-to-json --schema $schema --instructions $address_instructions
#
# Pipeline Input:
#   text: string - The natural language text to convert
#
# Parameters:
#   --schema: record - JSON schema as a nushell record (use 'get record_json' on tag type)
#   --instructions: list<string> - Additional instruction file paths
#
# Returns:
#   record - Parsed JSON object matching the provided schema
#
# Errors:
#   - When schema is not provided
#   - When AI tool (claude) is not available
#   - When AI returns invalid JSON
export def "ai text-to-json" [
    --schema(-s): record      # JSON schema as a record (from tag type record_json)
    --instructions: list<string> = []  # Domain-specific instruction file paths (JSON_RESPONSE.md auto-included)
] {
    let text = $in
    
    if ($text | is-empty) {
        error make {msg: "Text input required via pipeline"}
    }
    
    # Validate schema input
    if ($schema == null) {
        error make {msg: "Schema must be provided via --schema parameter"}
    }
    
    # Build combined instructions from files
    # Look for the file relative to the modules directory
    let module_dir = (["modules", "stk_ai"] | path join)
    let base_instructions_path = ([$module_dir "JSON_RESPONSE.md"] | path join)
    mut combined_instructions = ""
    
    # Add base instructions if they exist
    if ($base_instructions_path | path exists) {
        $combined_instructions = (open $base_instructions_path)
    }
    
    # Add domain-specific instruction files
    if ($instructions | is-not-empty) {
        for file in $instructions {
            if ($file | path exists) {
                $combined_instructions = $"($combined_instructions)\n\n# Additional Instructions\n\n(open $file)"
            } else {
                print $"Warning: Instruction file not found: ($file)"
            }
        }
    }
    
    # Build complete prompt with instructions and schema
    let prompt = $"($combined_instructions)

Convert the following text into JSON matching this schema:

Schema:
```json
($schema | to json --indent 2)
```

Text to convert: ($text)

Return raw JSON only - no markdown formatting, no code blocks, no triple backticks."
    
    # Execute AI command with --output-format json for structured output
    let result = (do { echo $prompt | ^$STK_AI_TOOL -p --output-format json } | complete)
    
    if $result.exit_code != 0 {
        error make {msg: $"AI conversion failed: ($result.stderr)"}
    }
    
    # Parse claude's JSON wrapper and extract the result field
    let claude_response = try {
        $result.stdout | str trim | from json
    } catch {
        error make {msg: $"Claude returned invalid JSON wrapper: ($result.stdout)"}
    }
    
    # Extract and parse the actual JSON from the result field
    try {
        $claude_response.result | from json
    } catch {
        # If result contains markdown blocks, try to extract JSON
        let clean_json = $claude_response.result 
            | str replace -r '```json\n' ''
            | str replace -r '\n```' ''
            | str trim
        
        try {
            $clean_json | from json
        } catch {
            error make {msg: $"AI returned invalid JSON: ($claude_response.result)"}
        }
    }
}

# Test AI connectivity and configuration
# Verifies that the AI tool is properly configured and accessible.
#
# Examples:
#   # Test AI connection
#   ai test
#   
#   # Test and return result
#   let is_working = (ai test)
#
# Returns:
#   bool - true if AI is working, false otherwise
#
# Side Effects:
#   Prints status message to console
export def "ai test" [] {
    try {
        let result = (do { echo "Respond with exactly: WORKING" | ^$STK_AI_TOOL -p } | complete)
        
        if ($result.exit_code == 0 and ($result.stdout | str trim | str contains "WORKING")) {
            print $"✓ AI connection successful \(($STK_AI_TOOL))"
            true
        } else {
            print $"✗ AI test failed: unexpected response"
            false
        }
    } catch {
        print $"✗ AI connection failed: ($STK_AI_TOOL) not available"
        false
    }
}


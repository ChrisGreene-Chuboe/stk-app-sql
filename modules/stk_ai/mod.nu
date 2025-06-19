# STK AI Module
# This module provides AI-powered text transformation commands for chuck-stack

# Module Constants
const STK_DEFAULT_MODEL = "claude:claude-3-7-sonnet-20250219"
const STK_AI_TOOL = "aichat"

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
#   # Use specific AI model
#   "Product info..." | ai text-to-json --schema $schema --model gpt-4
#
# Pipeline Input:
#   text: string - The natural language text to convert
#
# Parameters:
#   --schema: record - JSON schema as a nushell record (use 'get record_json' on tag type)
#   --model: string - AI model to use (default: claude:claude-3-7-sonnet-20250219)
#
# Returns:
#   record - Parsed JSON object matching the provided schema
#
# Errors:
#   - When schema is not provided
#   - When AI tool (aichat) is not available
#   - When AI returns invalid JSON
export def "ai text-to-json" [
    --schema(-s): record      # JSON schema as a record (from tag type record_json)
    --model(-m): string = $STK_DEFAULT_MODEL  # AI model to use
] {
    let text = $in
    
    if ($text | is-empty) {
        error make {msg: "Text input required via pipeline"}
    }
    
    # Validate schema input
    if ($schema == null) {
        error make {msg: "Schema must be provided via --schema parameter"}
    }
    
    # Build AI prompt
    let prompt = $"Convert the following text into JSON matching this schema:

Schema:
```json
($schema | to json --indent 2)
```

Text to convert: ($text)

Return ONLY valid JSON that matches the schema. Do not include any explanation or markdown formatting."
    
    # Execute AI command
    let result = (do { ^echo $prompt | ^$STK_AI_TOOL --no-stream --model $model} | complete)
    
    if $result.exit_code != 0 {
        error make {msg: $"AI conversion failed: ($result.stderr)"}
    }
    
    # Parse and validate JSON response
    try {
        $result.stdout | str trim | from json
    } catch {
        error make {msg: $"AI returned invalid JSON: ($result.stdout)"}
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
        let result = (do { ^$STK_AI_TOOL --model $STK_DEFAULT_MODEL "Respond with exactly: WORKING" } | complete)
        
        if ($result.exit_code == 0 and ($result.stdout | str trim) == "WORKING") {
            print $"✓ AI connection successful \(($STK_AI_TOOL) with ($STK_DEFAULT_MODEL))"
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


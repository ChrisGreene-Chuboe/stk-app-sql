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
#   # Include domain-specific instruction files (base JSON_RESPONSE.md is auto-included)
#   # Files are passed to aichat using -f parameters for native file handling
#   let address_instructions = [([$env.FILE_PWD ".." "stk_address" "ADDRESS_FORMAT.md"] | path join)]
#   "123 Main St" | ai text-to-json --schema $schema --instructions $address_instructions
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
    
    # Build list of instruction files to include
    # Look for the file relative to the modules directory
    let module_dir = (["modules", "stk_ai"] | path join)
    let base_instructions_path = ([$module_dir "JSON_RESPONSE.md"] | path join)
    mut instruction_files = []
    
    # Add base instructions if they exist
    if ($base_instructions_path | path exists) {
        $instruction_files = ($instruction_files | append $base_instructions_path)
    }
    
    # Add domain-specific instruction files
    if ($instructions | is-not-empty) {
        for file in $instructions {
            if ($file | path exists) {
                $instruction_files = ($instruction_files | append $file)
            } else {
                print $"Warning: Instruction file not found: ($file)"
            }
        }
    }
    
    # Build AI prompt (main content only, instructions in files)
    let prompt = $"Convert the following text into JSON matching this schema:

Schema:
```json
($schema | to json --indent 2)
```

Text to convert: ($text)"
    
    # Build aichat command with -f parameters for each instruction file
    mut ai_args = ["--no-stream", "--model", $model]
    
    # Add -f parameters for each instruction file
    for file in $instruction_files {
        $ai_args = ($ai_args | append ["-f", $file])
    }
    
    # Create immutable copy for use in closure
    let final_args = $ai_args
    
    # Execute AI command with instruction files
    let result = (do { echo $prompt | ^$STK_AI_TOOL ...$final_args } | complete)
    
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


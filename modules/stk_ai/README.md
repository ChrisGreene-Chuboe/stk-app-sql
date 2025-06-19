# STK AI Module

## Overview

The `stk_ai` module provides AI-powered text transformation capabilities for chuck-stack. It acts as a wrapper around AI tools (currently `aichat`) to enable natural language processing within chuck-stack workflows.

## Purpose

This module enables chuck-stack to convert unstructured natural language text into structured JSON data that conforms to predefined schemas. This is particularly useful for:

- Converting address strings into structured address records
- Parsing contact information from text
- Transforming product descriptions into structured data
- Any scenario where you need to extract structured data from natural language

## Integration with Chuck-Stack

The `stk_ai` module is designed to work seamlessly with chuck-stack's type system:

1. **Tag Types**: Schemas are typically retrieved from tag type `record_json` fields
2. **Pipeline Operations**: All commands accept input via nushell pipelines
3. **Error Handling**: Consistent error reporting following chuck-stack patterns

## Quick Start

```nushell
# Test AI connectivity
ai test

# Convert text to JSON using a tag type schema
let schema = (tag types | where search_key == "ADDRESS" | first | get record_json)
"123 Main St Austin TX 78701" | ai text-to-json --schema $schema
```

## Commands

For detailed command usage and examples, use the built-in help:

```nushell
ai text-to-json --help
ai test --help
ai info --help
```

## Prerequisites

- `aichat` must be installed and configured
- Valid AI model access (default: gpt-4o-mini)

## Related Documentation

- [Tag Module](../stk_tag/README.md) - For understanding tag types and schemas
- [Address Module](../stk_address/README.md) - Example of AI integration for addresses
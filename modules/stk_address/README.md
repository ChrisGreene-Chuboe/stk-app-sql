# STK Address Module

## Overview

The `stk_address` module provides flexible address entry for chuck-stack. It offers both AI-powered natural language conversion and direct JSON input for structured address data that matches the ADDRESS tag type schema.

## Purpose

This module simplifies address data entry by providing two methods:
1. Natural language input with AI conversion for ease of use
2. Direct JSON input when AI is unavailable or when working with pre-structured data

Both methods ensure data consistency through database validation against the ADDRESS type's JSON schema.

## Key Features

- **Natural Language Input**: Enter addresses as simple text strings with AI conversion
- **Direct JSON Input**: Submit pre-structured address data without AI dependency
- **Schema Validation**: All addresses are validated against the ADDRESS type's JSON schema
- **Type Support**: Works with various address types (ADDRESS, ADDRESS_SHIP_TO, etc.)
- **Flexible Integration**: Choose the method that best fits your workflow

## Quick Start

```nushell
# Add an address using natural language (requires AI)
$project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681"

# Add an address using direct JSON (no AI required)
$project_uuid | .append address --json '{"address1": "3508 Galena Hills Loop", "city": "Round Rock", "state": "TX", "postal": "78681"}'

# Add a shipping address with custom type
$order_uuid | .append address --json $addr_data --type-search-key ADDRESS_SHIP_TO

# Use a specific AI model for natural language
$entity_uuid | .append address "123 Main St Austin TX" --model gpt-4
```

## Command

For detailed command usage and examples, use the built-in help:

```nushell
.append address --help  # Shows both natural language and JSON input options
```

## Prerequisites

### For Natural Language Input (.append address)
- `stk_ai` module must be available and configured
- `aichat` must be installed with a valid AI model
- ADDRESS tag type must exist in the database

### For Direct JSON Input (.append address --json)
- ADDRESS tag type must exist in the database
- JSON must include required fields: address1, city, postal

## Related Documentation

- [Tag Module](../stk_tag/README.md) - Understanding the underlying tag system
- [AI Module](../stk_ai/README.md) - AI capabilities and configuration
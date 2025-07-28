# STK Address Module

## Overview

The `stk_address` module provides flexible address entry for chuck-stack. It offers both AI-powered natural language conversion and direct JSON input for structured address data that matches the ADDRESS tag type schema.

## Purpose

This module simplifies address data entry by providing two methods:
1. Natural language input with AI conversion for ease of use
2. Direct JSON input when AI is unavailable or when working with pre-structured data

Both methods ensure data consistency through database validation against the ADDRESS type's JSON schema.

### Address Types

Chuck-stack supports multiple address types for different purposes:
- **`address`** - General purpose addresses (headquarters, offices, etc.)
- **`address-bill-to`** - Billing addresses for invoices and financial documents
- **`address-ship-to`** - Shipping/delivery addresses for physical goods or services

All address types share the same JSON schema but provide semantic meaning through their type designation.

## Key Features

- **Natural Language Input**: Enter addresses as simple text strings with AI conversion
- **Direct JSON Input**: Submit pre-structured address data without AI dependency
- **Schema Validation**: All addresses are validated against the ADDRESS type's JSON schema
- **Type Support**: Works with multiple address types for different purposes
- **Flexible Integration**: Choose the method that best fits your workflow

## Quick Start

```nushell
# Add a general address using natural language (requires AI)
$project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681"

# Add a billing address using direct JSON (no AI required)
$bp_uuid | .append address --json '{"address1": "456 Finance Blvd", "city": "Jersey City", "state": "NJ", "postal": "07302"}' --type-search-key address-bill-to

# Add a shipping address
$order_uuid | .append address --json $addr_data --type-search-key address-ship-to

# Use natural language with specific type
$entity_uuid | .append address "123 Main St Austin TX" --type-search-key address-bill-to

# List all address types available
tag types | where type_enum == "ADDRESS"
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
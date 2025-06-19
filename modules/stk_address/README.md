# STK Address Module

## Overview

The `stk_address` module provides AI-powered address entry for chuck-stack. It uses AI to convert natural language address strings into structured JSON that matches the ADDRESS tag type schema.

## Purpose

This module simplifies address data entry by allowing users to input addresses in natural language format, which are then automatically converted to structured data and stored as tags. This eliminates the need for manual JSON formatting while ensuring data consistency.

## Key Features

- **Natural Language Input**: Enter addresses as simple text strings
- **AI-Powered Conversion**: Automatically structures address data using AI
- **Type Support**: Works with various address types (ADDRESS, ADDRESS_SHIP_TO, etc.)
- **Simple Integration**: One command that handles the entire workflow

## Quick Start

```nushell
# Add an address to a project
$project_uuid | .append address "3508 Galena Hills Loop Round Rock TX 78681"

# Add a shipping address (when ADDRESS_SHIP_TO type exists)
$order_uuid | .append address "456 Oak Ave Dallas TX 75201" --type-search-key ADDRESS_SHIP_TO

# Use a specific AI model
$entity_uuid | .append address "123 Main St" --model gpt-4
```

## Command

For detailed command usage and examples, use the built-in help:

```nushell
.append address --help
```

## Prerequisites

- `stk_ai` module must be available and configured
- `aichat` must be installed with a valid AI model
- ADDRESS tag type must exist in the database

## Related Documentation

- [Tag Module](../stk_tag/README.md) - Understanding the underlying tag system
- [AI Module](../stk_ai/README.md) - AI capabilities and configuration
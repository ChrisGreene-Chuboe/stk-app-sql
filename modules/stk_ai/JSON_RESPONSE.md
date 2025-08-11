# JSON Response Instructions

## Critical Requirement
Return raw JSON only - no markdown formatting, no code blocks, no triple backticks.

## NULL Value Rules (CRITICAL)
- NEVER include null values in the JSON response
- Optional fields: OMIT completely if no value found (do not set to null)
- Required fields: MUST have actual string/number/boolean values (never null)
- If an optional field has no data, exclude it from the JSON entirely

## Schema Compliance
- All JSON Schema constraints are mandatory
- Required fields listed in the schema MUST have valid non-null values
- Data types must match exactly (string, number, boolean, array, object)
- Enums must use exact values from the provided options
- Patterns and format specifications must be satisfied

## Data Extraction Rules
- Extract maximum information from input text
- Parse structured data (addresses, names, codes) into appropriate fields
- Use context to fill required fields (e.g., "TX" implies state: "TX")
- For addresses: parse the text to extract all components (street, city, postal code)
- Make intelligent assumptions for required fields when needed
- Maintain consistency across related fields

## Format Standards
- Dates: ISO 8601 format (YYYY-MM-DD)
- States: Two-letter uppercase codes
- Numbers: Parse intelligently (currency symbols, percentages)
- Enums: Map to closest valid option when exact match unavailable

## Examples

Input: "John from Austin"
Schema: `{name: string, city: string, state: string, country: string}` (name, city, state required)
Output: `{"name": "John", "city": "Austin", "state": "TX"}`
Note: country is optional and not in input, so it's OMITTED (not set to null)

Input: "123 Main St, Austin TX 78701"
Schema: `{address1: string, address2: string, city: string, state: string, postal: string}` (address1, city, postal required)
Output: `{"address1": "123 Main St", "city": "Austin", "state": "TX", "postal": "78701"}`
Note: address2 is optional with no data, so it's OMITTED entirely

Input: "high priority task"  
Schema enum: ["low", "medium", "high", "critical"]
Output: `{"priority": "high"}`
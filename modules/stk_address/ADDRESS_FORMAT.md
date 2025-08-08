# Address Format Instructions

## Purpose
Provide domain-specific guidance for parsing and formatting address information beyond what can be expressed in JSON Schema constraints.

## Address Parsing Rules

### Component Identification
- **Business Names**: When a business name appears at the start, include it as part of address1 unless it's clearly an attention line
- **Attention/Care Of**: Lines starting with "Attn:", "C/O", or similar should go in address2
- **Building/Complex Names**: Include in address1 if it's the primary identifier, address2 if secondary
- **Multiple Lines**: Parse intelligently based on content, not just line breaks

### Field Mapping Strategy

#### address1 (Primary Location)
- Use proper case
- Street number and name
- Building name (if primary identifier)
- Business name (if integral to address)
- PO Box or Private Bag numbers

#### address2 (Secondary Details)  
- Use proper case
- Apartment, Suite, Unit numbers
- Floor information
- Attention or care-of lines
- Building name (if street address is primary)
- Additional delivery instructions

#### city
- Use proper case
- Full city name (not abbreviated)
- Suburb or district names in international contexts
- Neighborhood names only if no larger city designation exists
- Use proper case when referring to names (galena hills vs Galena Hills <preferred>)

#### state/province
- Always use standard 2-letter codes when applicable
- For US states: AL, AK, AZ, AR, CA, CO, CT, DE, FL, GA, HI, ID, IL, IN, IA, KS, KY, LA, ME, MD, MA, MI, MN, MS, MO, MT, NE, NV, NH, NJ, NM, NY, NC, ND, OH, OK, OR, PA, RI, SC, SD, TN, TX, UT, VT, VA, WA, WV, WI, WY
- For Canadian provinces: AB, BC, MB, NB, NL, NT, NS, NU, ON, PE, QC, SK, YT
- Full names for regions without standard codes

#### postal/zip
- Preserve original format (don't force reformatting unless invalid)
- Include extensions when provided (ZIP+4, Canadian postal codes)
- International formats vary - preserve as given

#### country
- Use ISO 3166-1 alpha-2 codes when explicit
- Default to "US" only when clear US indicators present (state codes, ZIP format)
- Omit if ambiguous rather than guess incorrectly

## Regional Intelligence

### United States Addresses
- Recognize common abbreviations: St, Ave, Blvd, Rd, Dr, Ln, Ct, Pl, Way, Pkwy
- Standard directionals: N, S, E, W, NE, NW, SE, SW
- Apartment designators: Apt, Suite, Ste, Unit, #
- ZIP codes: 5 digits or ZIP+4 format (12345 or 12345-6789)

### Canadian Addresses  
- Postal codes: A1A 1A1 format (letter-number-letter space number-letter-number)
- Province names often spelled out - convert to 2-letter codes
- "Centre" spelling vs "Center"
- May include both English and French street types

### International Considerations
- UK: Postcodes vary in format, counties may be included
- Australia: State names often spelled out, 4-digit postcodes
- Europe: Postal code before or after city depending on country
- Asia: Building/floor often more prominent than street number

## Intelligent Parsing Examples

### Example 1: Business Address
Input: "Apple Inc, One Apple Park Way, Cupertino CA 95014"
```json
{
  "address1": "One Apple Park Way",
  "address2": "Apple Inc",
  "city": "Cupertino",
  "state": "CA",
  "postal": "95014",
  "country": "US"
}
```

### Example 2: Apartment Address
Input: "John Smith, 123 Main Street Apt 4B, New York, NY 10001"
```json
{
  "address1": "123 Main Street",
  "address2": "Apt 4B",
  "city": "New York",
  "state": "NY",
  "postal": "10001",
  "country": "US"
}
```

### Example 3: International Address
Input: "10 Downing Street, Westminster, London SW1A 2AA, United Kingdom"
```json
{
  "address1": "10 Downing Street",
  "address2": "Westminster",
  "city": "London",
  "state": null,
  "postal": "SW1A 2AA",
  "country": "GB"
}
```

### Example 4: PO Box
Input: "PO Box 1234, Austin TX 78701"
```json
{
  "address1": "PO Box 1234",
  "address2": null,
  "city": "Austin",
  "state": "TX",
  "postal": "78701",
  "country": "US"
}
```

## Quality Checks

### Standardization
- Capitalize proper nouns consistently
- Use standard abbreviations where appropriate
- Don't over-abbreviate (keep "North" vs "N" if space permits)

### Validation
- State codes should match the city when known
- Postal codes should match expected format for country
- Required fields should never be empty strings (use null for optional)

### Completeness
- Extract all available information from the input
- Don't leave fields empty if they can be reasonably inferred
- Preserve apartment/suite numbers - they're critical for delivery

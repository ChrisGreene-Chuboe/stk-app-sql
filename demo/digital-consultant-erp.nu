#!/usr/bin/env nu
# Digital Consultant ERP Demo - Building a Complete Business Partner
# 
# This demo shows how to create a business partner with full context:
# - Basic information and attributes
# - Business roles via tags
# - Addresses with structured JSON data
# - Custom data in record_json
#
# To run: nu -l -c "source demo/digital-consultant-erp.nu"

use ../modules *

print "=== Building a Complete Business Partner ==="
print ""

# Step 1: Create the business partner
print "1. Creating business partner..."

# Create a client company with detailed information
let client = (bp new "ACME Corporation" 
    --type-search-key "ORGANIZATION" 
    --description "Enterprise retail company - our largest client" 
    --json '{
        "legal_name": "ACME Corporation Inc.",
        "tax_id": "12-3456789",
        "duns_number": "123456789",
        "website": "www.acme-corp.com",
        "industry": "Retail",
        "annual_revenue": "500M",
        "employee_count": 2500,
        "fiscal_year_end": "12/31",
        "payment_terms": "Net 30",
        "credit_limit": 100000,
        "primary_contact": "John Smith",
        "primary_phone": "+1-555-123-4567",
        "primary_email": "john.smith@acme-corp.com"
    }')

print $"✓ Created business partner: ($client.name.0) with UUID: ($client.uu.0)"
print ""

# Step 2: Add business roles via tags
print "2. Assigning business roles..."

# Mark as customer
let customer_tag = $client | .append tag --type-search-key "BP_CUSTOMER" --description "Premium customer since 2020"
print "✓ Tagged as BP_CUSTOMER"

# Could also be a vendor if they provide services to us
let vendor_tag = $client | .append tag --type-search-key "BP_VENDOR" --description "Also provides consulting services to us"
print "✓ Tagged as BP_VENDOR"

print ""


# Step 3: Add addresses
print "3. Adding addresses..."

# Headquarters address - using structured JSON
let hq_address = $client | .append address --json '{
    "address1": "123 Main Street",
    "address2": "Suite 1000",
    "city": "New York",
    "region": "NY",
    "postal": "10001",
    "country": "US"
}'
print "✓ Added headquarters address"

# Billing address - using structured JSON
let billing_address = $client | .append address --json '{
    "address1": "456 Finance Blvd",
    "city": "Jersey City",
    "region": "NJ",
    "postal": "07302",
    "country": "US"
}'
print "✓ Added billing address"

# Shipping address - using structured JSON
let shipping_address = $client | .append address --json '{
    "address1": "789 Warehouse Way",
    "city": "Newark",
    "region": "NJ",
    "postal": "07102",
    "country": "US"
}'
print "✓ Added shipping address"

print ""

# Step 4: Show the complete business partner profile
print "4. Business Partner Profile"
print "==========================="

# Get BP with details
let bp_detail = ($client | bp get --detail)
print $"Name: ($bp_detail.name)"
print $"Type: ($bp_detail.type_enum) - ($bp_detail.type_description)"
print $"Description: ($bp_detail.description)"
print $"Status: (if $bp_detail.is_valid { 'Valid' } else { 'Invalid' })"
print $"Created: ($bp_detail.created)"
print ""

# Show JSON attributes
print "Company Details:"
let details = $bp_detail.record_json
$details | items {|k, v| print $"  ($k): ($v)"}
print ""

# Show tags
print "Business Roles & Classifications:"
let bp_tags = $client | tags
$bp_tags | select type_enum description created | each {|t| 
    print $"  - ($t.type_enum): ($t.description)"
}
print ""

# Show addresses (which are stored as ADDRESS tags)
print "Addresses:"
let bp_addresses = $client | tags | where type_enum == "ADDRESS"
$bp_addresses | each {|a|
    let addr_data = $a.record_json | from json
    print $"  Address:"
    if ($addr_data.address1? | is-not-empty) {
        print $"    ($addr_data.address1) ($addr_data.address2? | default '')"
    }
    if ($addr_data.city? | is-not-empty) {
        print $"    ($addr_data.city), ($addr_data.region) ($addr_data.postal)"
    }
    print $"    Created: ($a.created)"
    print ""
}

print "=== Complete Business Partner Created ==="
print ""
print "This business partner now has:"
print "- Core company information with legal and financial details"
print "- Multiple business role tags (customer and vendor)"
print "- Multiple addresses for different purposes (HQ, billing, shipping)"
print ""
print "Next steps could include:"
print "- Adding contacts (employees) associated with this BP"
print "- Creating projects for this client"
print "- Setting up recurring invoices"
print "- Tracking interactions via events"

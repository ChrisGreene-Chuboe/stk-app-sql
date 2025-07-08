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

print "============================================"
print "=== Building a Complete Business Partner ==="
print "============================================"
print ""

# Step 1: Create the business partner
print "1. Creating business partner..."
print ""

# Create a client company with detailed information
let client = (bp new "ACME Corporation" 
    --type-search-key "ORGANIZATION" 
    --description "Enterprise retail company - our largest client" 
    --json '{
        "tax_id": "12-3456789",
        "duns_number": "123456789",
        "website": "www.acme-corp.com",
        "industry": "Retail",
        "annual_revenue": "500M",
        "employee_count": 2500,
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
print ""

# Mark as customer
let customer_tag = $client | .append tag --type-search-key "BP_CUSTOMER"
print "✓ Tagged as BP_CUSTOMER"
print ""

# Could also be a vendor if they provide services to us
let vendor_tag = $client | .append tag --type-search-key "BP_VENDOR"
print "✓ Tagged as BP_VENDOR"
print ""


# Step 3: Add addresses
print "3. Adding addresses..."
print ""

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
print ""

# Billing address - using structured JSON
let billing_address = $client | .append address --json '{
    "address1": "456 Finance Blvd",
    "city": "Jersey City",
    "region": "NJ",
    "postal": "07302",
    "country": "US"
}'
print "✓ Added billing address"
print ""

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
print "================================"
print "=== Business Partner Profile ==="
print "================================"
print ""

# Get BP with details and display as a record
print "Business Partner: returned from new"
$client | first | print 
print ""

print "Business Partner: returned from get"
$client | bp get | print
print ""

# Show JSON attributes as a formatted table
print "Company Details:"
let bp_detail = ($client | bp get )
$bp_detail.record_json | print
print ""

# Show tags as a table
print "Business Roles & Classifications:"
$client | bp get | tags | select type_enum description created | print
print ""

# Show addresses with their JSON data
print "Addresses:"
$client | bp get | tags | get tags | where {$in.search_key =~ ADDRESS} | table -e | print
print ""

print "========================================="
print "=== Complete Business Partner Created ==="
print "========================================="
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

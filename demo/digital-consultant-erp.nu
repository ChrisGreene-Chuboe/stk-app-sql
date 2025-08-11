#!/usr/bin/env nu
# Digital Consultant ERP Demo - Building a Complete Business Partner
# 
# This demo shows to create all the artifacts needed to create 
# and print a customer invoice for a digital consulting team.
# This demo shows:
# - How to create a new financial entity (set of books)
# - How to create a Business Partner and tag it the appropriate details.
# - This action shows: 
#   - basic information and attributes
#   - business roles via tags
# - How to add addresses with structured JSON data
# - This action shows:
#   - how to add an address to anything
#   - custom data in record_json
#
# To run: nu -l -c "source demo/digital-consultant-erp.nu"

use ../modules *

print "========================"
print "=== Create an Entity ==="
print "========================"
print ""

print "Create our consulting company entity (for invoicing)..."
print ""

# Create a 'trx' entity for our consulting company.
# If we had not specified 'trx' as the type, it would default to '*'.
# '*' is the default, non-transactional entity used to hold data.
let entity_myco = (entity new "My Consulting Company" 
    --type-search-key trx
    --search-key myco
    --description "Primary transactional entity for invoicing")

print $"✓ Created entity: ($entity_myco.name) with search key: ($entity_myco.search_key)"
print $"  Entity UUID: ($entity_myco.uu)"
print $"  Type: TRX \(transactional - can create invoices)"
print ""

print "================================="
print "=== Create a Business Partner ==="
print "================================="
print ""

print "Creating business partner..."
print ""

# Create a customer/BP with general information.
# Business Partners (BP) can be customers/vendors/employees/etc...
# BPs are anyone you engage with financially.
# Assign the BP to our 'trx' entity as a convenience.
# Because we set the entity to "My Consulting Company",
# future invoices will automatically go to that entity/company.
# Note: you can use the --interactive flag to prompt you for
# the below details.
let bp_acme = (bp new "ACME Corporation" 
    --type-search-key organization
    --search-key acme
    --entity-uu $entity_myco.uu
    --description "Enterprise retail company - our largest client" 
    --json '{
        "tax_id": "12-3456789",
        "duns_number": "123456789",
        "website": "www.acme-corp.com",
        "industry": "Retail",
        "annual_revenue": "500M",
        "employee_count": 2500,
        "primary_contact": "John Smith",
        "primary_phone": "+1-555-123-4567",
        "primary_email": "john.smith@acme-corp.com"
    }')

print $"✓ Created business partner: ($bp_acme.name) with UUID: ($bp_acme.uu)"
print ""

print "Add business roles via tags..."
print ""

# Mark as customer with customer-specific details
# Note: bp-customer knows what details it needs to be a customer.
# You can use the --interactive command to have the system prompt you.
let customer_tag = $bp_acme | .append tag --type-search-key bp-customer --json '{
    "payment_terms": "Net 30",
    "payment_terms_days": 30,
    "credit_limit": 100000,
    "currency": "USD",
    "price_list": "STANDARD",
    "tax_exempt": false
}'
print "✓ Tagged as BP_CUSTOMER with payment terms and credit limit"
print ""

# Also mark them as vendor (because they occasionally provide services to us)
# Note: the same Busienss Partner can participate in multiple roles using tags.
let vendor_tag = $bp_acme | .append tag --type-search-key bp-vendor --json '{
    "payment_terms": "Net 45",
    "payment_terms_days": 45,
    "our_account_number": "ACCT-0001",
    "payment_method": "ACH",
    "currency": "USD",
    "preferred_vendor": true
}'
print "✓ Tagged as BP_VENDOR with vendor payment terms"
print ""

print "Assigning contacts..."
print ""

# Add a contact
# Note: we are adding the contact to the BP.
# We use the '|' to say: add this contact to this BP.
$bp_acme | contact new "Julie Smith" --json '{
        "primary_phone": "+1-555-123-4567",
        "primary_email": "julie.smith@acme-corp.com"
    }'
print "✓ Added Julie Smith as a contact"
print ""

print "Adding addresses..."
print ""

# Headquarters address - using general (unspecified) address type.
$bp_acme | .append address --json '{
    "address1": "123 Main Street",
    "address2": "Suite 1000",
    "city": "New York",
    "region": "NY",
    "postal": "10001",
    "country": "US"
}'
print "✓ Added headquarters address (general)"
print ""

# Billing address - using specific bill-to type.
# Note: the use of `--type-search-key` below to
# specify the exact type.
$bp_acme | .append address --json '{
    "address1": "456 Finance Blvd",
    "city": "Jersey City",
    "region": "NJ",
    "postal": "07302",
    "country": "US"
}' --type-search-key address-bill-to
print "✓ Added billing address (bill-to)"
print ""

# Shipping address - using specific ship-to type
$bp_acme | .append address --json '{
    "address1": "789 Warehouse Way",
    "city": "Newark",
    "region": "NJ",
    "postal": "07102",
    "country": "US"
}' --type-search-key address-ship-to
print "✓ Added shipping address (ship-to)"
print ""

print "========================================"
print "=== Business Partner Profile Summary ==="
print "========================================"
print ""

# Get BP with details and display as a record.
# Note: `table -e` ensures details are printed.
print "Business Partner:"
$bp_acme | table -e | print
print ""

# Show JSON attributes as a formatted table
print "Business Partner attributes:"
$bp_acme.record_json | print
print ""

# Show tags as a table
print "Business Roles & Classifications:"
$bp_acme | tags | select type_enum description created | print
print ""

# Show addresses with their JSON data.
# This will be greatly simplified by when we add the `addresses`
# command to stk_address.
print "Addresses:"
$bp_acme | tags | get tags | where {$in.search_key =~ "address"} | table -e | print
print ""

print "======================================="
print "=== Creating Project for Client... ==="
print "======================================="
print ""

# Create a project for ACME Corporation
let project_acme = (project new "ACME Digital Transformation"
    --search-key acme-dt-2025
    --entity-uu $entity_myco.uu
    --description "Q1 2025 Digital transformation initiative"
    --json '{
        "start_date": "2025-01-01",
        "end_date": "2025-03-31",
        "budget": 50000,
        "status": "active",
        "project_manager": "Julie Smith"
    }')
print $"✓ Created project: ($project_acme.name) with search key: ($project_acme.search_key)"
print $"  Project UUID: ($project_acme.uu)"
print ""

# Link the project to the business partner via tag
$project_acme | .append tag --json $'{
    "bp_uu": "($bp_acme.uu)",
    "bp_name": "($bp_acme.name)",
    "relationship": "client"
}'
print $"✓ Linked project to business partner: ($bp_acme.name)"
print ""

print "Adding project deliverables..."
print ""

# Add project deliverables as project lines
$project_acme | project line new "System Architecture Review" --description "Comprehensive review of current system architecture" --json '{"estimated_hours": 40, "status": "pending"}'
print "✓ Added deliverable: System Architecture Review"

$project_acme | project line new "Cloud Migration Plan" --description "Detailed plan for cloud infrastructure migration" --json '{"estimated_hours": 60, "status": "pending"}'
print "✓ Added deliverable: Cloud Migration Plan"

$project_acme | project line new "Security Assessment" --description "Security audit and vulnerability assessment" --json '{"estimated_hours": 30, "status": "pending"}'
print "✓ Added deliverable: Security Assessment"

$project_acme | project line new "Implementation Roadmap" --description "Phased implementation strategy and timeline" --json '{"estimated_hours": 20, "status": "pending"}'
print "✓ Added deliverable: Implementation Roadmap"
print ""

print "======================================="
print "=== Creating Items for Invoicing... ==="
print "======================================="
print ""

# Note that we do not need to use the `let` keyword if we do not wish.
# We refer to these items as 'HC' and 'PSF' (search_key) below.
# We only use the variables (consultation and project_fee) for 
# providing feedback.
let item_hc = (item new "Hourly Consultation" 
    --search-key hc
    --type-search-key service
    --description "Professional consulting services")
print $"✓ Created item: ($item_hc.name) \(($item_hc.search_key))"

let item_psf = (item new "Project Setup Fee"
    --search-key psf
    --type-search-key service
    --description "One-time project initialization fee")
print $"✓ Created item: ($item_psf.name) \(($item_psf.search_key))"
print ""

print "======================================"
print "=== Creating Invoice for Client... ==="
print "======================================"
print ""

# We create invoices by piping ('|') a business partner into the new command.
# We can also create an invoice by piping in another invoice.
# The system is smart enough to look for the appropriate tags (address
# and bp) needed for invoice creation. If it finds them => success!
# We can also link the invoice to a project for tracking purposes.
let invoice = ($bp_acme | invoice new "INV-2025-001"
    --type-search-key sales-standard
    --entity-uu $entity_myco.uu
    --description "January 2025 Consulting Services - ACME Digital Transformation"
    --json $'{
        "project_uu": "($project_acme.uu)",
        "project_name": "($project_acme.name)",
        "project_phase": "Phase 1 - Assessment",
        "billing_period": "January 2025"
    }')
print $"✓ Created invoice: ($invoice.search_key) for ($bp_acme.name)"
print $"  Linked to project: ($project_acme.search_key)"
print ""

print "===================================="
print "=== Add Line Items to Invoice... ==="
print "===================================="
print ""

# Add consultation hours
$invoice | invoice line new hc --qty 40 --price 150
print "✓ Added 40 hours of consultation @ $150/hour"

# Add project setup fee
$invoice | invoice line new psf --qty 1 --price 2500
print "✓ Added project setup fee @ $2,500"

# Add a discount line (without item reference)
$invoice | invoice line new --description "Early payment discount (5%)" --type-search-key discount --json '{"discount_amount": -425, "discount_basis": "subtotal"}'
print "✓ Added early payment discount"
print ""

print "======================="
print "=== Invoice Summary ==="
print "======================="
print ""

# Display invoice header
print "Invoice Details:"
$invoice | invoice get | select search_key description type_enum created | print
print ""

# Display linked business partner
print $"Customer: ($bp_acme.name)"
print ""

# Display line items
print "Line Items:"
$invoice | invoice line list | select search_key description record_json | table -e | print
print ""

# Show totals by using the already-parsed JSON data
# Note: this is needlessly long
print "Invoice Totals:"
let lines = ($invoice | invoice line list)
let line_totals = ($lines | each {|line| 
    let json = $line.record_json
    {
        line: $line.search_key
        amount: (if ($json.price_extended? | is-not-empty) { $json.price_extended } else if ($json.discount_amount? | is-not-empty) { $json.discount_amount } else { 0 })
    }
})

let subtotal = ($line_totals | where amount > 0 | get amount | math sum)
let discount = ($line_totals | where amount < 0 | get amount | math sum | math abs)
let total = ($subtotal - $discount)

[
    [Description Amount];
    ["Subtotal" $subtotal]
    ["Discount" $"($discount)"]
    ["Total" $total]
] | print
print ""

# Show cloned tags on invoice
print "Preserved Business Context:"
$invoice | invoice get | tags | select tags | table -e | print
print ""

# Step 10: Generate PDF invoice
print "=============================="
print "=== Generating PDF Invoice ==="
print "=============================="
print ""

# Check if typst is available
if (which typst | is-empty) {
    print "⚠️  Typst not found - skipping PDF generation"
    print "   To generate PDFs, install typst: https://github.com/typst/typst"
} else {
    # Generate the PDF
    let pdf_path = ($invoice | invoice pdf)
    print $"✓ Generated PDF invoice: ($pdf_path)"
    
    # Show file size
    let pdf_info = (ls $pdf_path | first)
    print $"  File size: ($pdf_info.size)"
}
print ""

# define the bpp command as an example of a keyboard shortcut
def bpp [name: string] {
    bp list | where {($in.name =~ $name) or ($in.search_key =~ $name)} | first | tags search_key record_json | select name search_key tags
}

export def "demo-show" [] {
    r#'
==================================
=== Complete BP → Invoice Flow ===
==================================

This demonstration showed:

1. Entity Management:
   - Created a transactional entity for financial operations
   - Understood entity types (TRX vs *) and their purposes
   - Assigned search keys for easy reference

2. Business Partner Creation:
   - Built a complete organizational profile with structured data
   - Added custom attributes via JSON (tax ID, website, revenue)
   - Assigned to a transactional entity for automatic invoice routing

3. Role-Based Classification:
   - Applied multiple business roles using tags (customer AND vendor)
   - Configured role-specific attributes (payment terms, credit limits)
   - Demonstrated how one BP can have multiple commercial relationships

4. Contact Management:
   - Added contacts linked to business partners
   - Used pipeline syntax to establish relationships

5. Address Management:
   - Created multiple address types (general, bill-to, ship-to)
   - Used structured JSON for consistent address data
   - Demonstrated type-specific address classification

6. Project Management:
   - Created a project linked to the business partner
   - Defined project timeline, budget, and deliverables
   - Established project context for invoice tracking

7. Service Item Creation:
   - Built reusable service items with search keys
   - Classified items by type for proper accounting

8. Invoice Generation:
   - Created invoices by piping business partners
   - Linked invoice to specific project for tracking
   - Automatic inheritance of BP tags (addresses, terms)
   - Added multiple line item types (items, custom lines, discounts)

9. Financial Document Features:
   - Calculated invoice totals from line item data
   - Generated PDF output (when typst available)
   - Preserved business context through tag cloning
   - Project linkage for financial tracking

Key Concepts Demonstrated:
- Pipeline-oriented data flow (BP → Project → Invoice)
- Tag-based attribute system for flexible data modeling
- JSON storage for extensible business data
- Type system for classification and validation
- Automatic relationship inference and data inheritance
- Project-based financial tracking
'#
}

export def "demo-example" [] {
    r#'
====================================
=== Try These Commands Yourself! ===
====================================

Explore the data we just created with these commands:

# View all entities:
entity list

# Find ACME Corporation by name:
bp list | where name =~ ACME | first

# Find ACME Corporation by search_key:
bp list | where search_key == acme | first

# View ACME's complete profile with all tags:
bp list | where name =~ ACME | first | tags search_key record_json | select name search_key tags

# See ACME's addresses:
bp list | where name =~ ACME | first | tags search_key record_json | get tags | where search_key =~ address

# List all contacts for ACME:
bp list | where name =~ ACME | first | contacts name record_json

# View the project we created:
project list | where search_key == acme-dt-2025 | first

# View project with deliverables:
project list | where search_key == acme-dt-2025 | first | project line list

# See project deliverables with estimated hours:
project list | where search_key == acme-dt-2025 | first | project line list | select search_key description record_json

# View service items:
item list | where type_enum == SERVICE

# Find the invoice we created:
invoice list | where search_key == INV-2025-001

# View invoice with all line items:
invoice list | where search_key == INV-2025-001 | lines search_key description record_json | select search_key lines

# View just the invoice lines:
invoice list | where search_key == INV-2025-001 | invoice line list

# See inherited tags on the invoice:
invoice list | where search_key == INV-2025-001 | tags | select search_key tags

# Create another invoice for the same client:
bp list | where name =~ ACME | invoice new INV-2025-002 --description \"February services\"

# Add ACME to your favorites:
bp list | where name =~ ACME | .append tag --type-search-key favorite

# Adding a request to ACME:
bp list | where name =~ ACME | .append request \"request higher credit limit\" --type-search-key action

=======================================
=== Create Quick Keyboard Shortcuts ===
=======================================

Create quick custom shortcuts like a `bpp` (business partner profile) command/keystroke for common tasks.
Note that `bpp` is completely made up as an example of something you might want easy access to.

def bpp [name: string] {
    bp list | where {($in.name =~ $name) or ($in.search_key =~ $name)} | first | tags search_key record_json | select name search_key tags
}

Try it with our demo business partner:
  bpp ACME

This demonstrates how easy it is to create shortcuts for common tasks.
You can define similar commands for any frequently-used reports, queries or processes.
Another example might be `oor` for generating an 'open order report'.

=== Scroll up to see a summary and sample commands ===

'#
}

demo-show | print
demo-example | print

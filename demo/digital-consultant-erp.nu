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
let my_company = (entity new "My Consulting Company" 
    --type-search-key trx
    --search-key my-consulting
    --description "Primary transactional entity for invoicing")

print $"✓ Created entity: ($my_company.name) with search key: ($my_company.search_key)"
print $"  Entity UUID: ($my_company.uu)"
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
let client = (bp new "ACME Corporation" 
    --type-search-key organization
    --search-key acme
    --entity-uu $my_company.uu
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

print $"✓ Created business partner: ($client.name) with UUID: ($client.uu)"
print ""

print "Add business roles via tags..."
print ""

# Mark as customer with customer-specific details
# Note: bp-customer knows what details it needs to be a customer.
# You can use the --interactive command to have the system prompt you.
let customer_tag = $client | .append tag --type-search-key bp-customer --json '{
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
let vendor_tag = $client | .append tag --type-search-key bp-vendor --json '{
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
$client | contact new "Julie Smith" --json '{
        "primary_phone": "+1-555-123-4567",
        "primary_email": "julie.smith@acme-corp.com"
    }'
print "✓ Added Julie Smith as a contact"
print ""

print "Adding addresses..."
print ""

# Headquarters address - using general (unspecified) address type.
$client | .append address --json '{
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
$client | .append address --json '{
    "address1": "456 Finance Blvd",
    "city": "Jersey City",
    "region": "NJ",
    "postal": "07302",
    "country": "US"
}' --type-search-key address-bill-to
print "✓ Added billing address (bill-to)"
print ""

# Shipping address - using specific ship-to type
$client | .append address --json '{
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
$client | table -e | print
print ""

# Show JSON attributes as a formatted table
print "Business Partner attributes:"
$client.record_json | print
print ""

# Show tags as a table
print "Business Roles & Classifications:"
$client | tags | select type_enum description created | print
print ""

# Show addresses with their JSON data.
# This will be greatly simplified by when we add the `addresses`
# command to stk_address.
print "Addresses:"
$client | tags | get tags | where {$in.search_key =~ "address"} | table -e | print
print ""

print "======================================="
print "=== Creating Items for Invoicing... ==="
print "======================================="
print ""

# Note that we do not need to use the `let` keyword if we do not wish.
# We refer to these items as 'HC' and 'PSF' (search_key) below.
# We only use the variables (consultation and project_fee) for 
# providing feedback.
let consultation = (item new "Hourly Consultation" 
    --search-key hc
    --type-search-key service
    --description "Professional consulting services")
print $"✓ Created item: ($consultation.name) \(($consultation.search_key))"

let project_fee = (item new "Project Setup Fee"
    --search-key psf
    --type-search-key service
    --description "One-time project initialization fee")
print $"✓ Created item: ($project_fee.name) \(($project_fee.search_key))"
print ""

print "======================================"
print "=== Creating Invoice for Client... ==="
print "======================================"
print ""

# We create invoices by piping ('|') a business partner into the new command.
# We can also create an invoice by piping in another invoice.
# The system is smart enough to look for the appropriate tags (address
# and bp) needed for invoice creation. If it finds them => success!
let invoice = ($client | invoice new "INV-2025-001"
    --type-search-key sales-standard
    --entity-uu $my_company.uu
    --description "January 2025 Consulting Services")
print $"✓ Created invoice: ($invoice.search_key) for ($client.name)"
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
print $"Customer: ($client.name)"
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

print "=================================="
print "=== Complete BP → Invoice Flow ==="
print "=================================="
print ""

print "This demonstration showed:"
print ""

print "1. Entity Management:"
print "   - Created a transactional entity for financial operations"
print "   - Understood entity types (TRX vs *) and their purposes"
print "   - Assigned search keys for easy reference"
print ""

print "2. Business Partner Creation:"
print "   - Built a complete organizational profile with structured data"
print "   - Added custom attributes via JSON (tax ID, website, revenue)"
print "   - Assigned to a transactional entity for automatic invoice routing"
print ""

print "3. Role-Based Classification:"
print "   - Applied multiple business roles using tags (customer AND vendor)"
print "   - Configured role-specific attributes (payment terms, credit limits)"
print "   - Demonstrated how one BP can have multiple commercial relationships"
print ""

print "4. Contact Management:"
print "   - Added contacts linked to business partners"
print "   - Used pipeline syntax to establish relationships"
print ""

print "5. Address Management:"
print "   - Created multiple address types (general, bill-to, ship-to)"
print "   - Used structured JSON for consistent address data"
print "   - Demonstrated type-specific address classification"
print ""

print "6. Service Item Creation:"
print "   - Built reusable service items with search keys"
print "   - Classified items by type for proper accounting"
print ""

print "7. Invoice Generation:"
print "   - Created invoices by piping business partners"
print "   - Automatic inheritance of BP tags (addresses, terms)"
print "   - Added multiple line item types (items, custom lines, discounts)"
print ""

print "8. Financial Document Features:"
print "   - Calculated invoice totals from line item data"
print "   - Generated PDF output (when typst available)"
print "   - Preserved business context through tag cloning"
print ""

print "Key Concepts Demonstrated:"
print "- Pipeline-oriented data flow (BP → Invoice)"
print "- Tag-based attribute system for flexible data modeling"
print "- JSON storage for extensible business data"
print "- Type system for classification and validation"
print "- Automatic relationship inference and data inheritance"
print ""

print "===================================="
print "=== Try These Commands Yourself! ==="
print "===================================="
print ""

print "Explore the data we just created with these commands:"
print ""

print "# View all entities:"
print "entity list"
print ""

print "# Find ACME Corporation by name:"
print "bp list | where name =~ ACME | first"
print ""

print "# Find ACME Corporation by search_key:"
print "bp list | where search_key == acme | first"
print ""

print "# View ACME's complete profile with all tags:"
print "bp list | where name =~ ACME | first | tags search_key record_json | select name search_key tags"
print ""

print "# See ACME's addresses:"
print "bp list | where name =~ ACME | first | tags search_key record_json | get tags | where search_key =~ address"
print ""

print "# List all contacts for ACME:"
print "bp list | where name =~ ACME | first | contacts name record_json"
print ""

print "# View service items:"
print "item list | where type_enum == SERVICE"
print ""

print "# Find the invoice we created:"
print "invoice list | where search_key == INV-2025-001"
print ""

print "# View invoice with all line items:"
print "invoice list | where search_key == INV-2025-001 | lines search_key description record_json | select search_key lines"
print ""

print "# View just the invoice lines:"
print "invoice list | where search_key == INV-2025-001 | invoice line list"
print ""

print "# See inherited tags on the invoice:"
print "invoice list | where search_key == INV-2025-001 | tags | select search_key tags"
print ""

print "# Create another invoice for the same client:"
print "bp list | where name =~ ACME | invoice new INV-2025-002 --description \"February services\""
print ""

print "# Add ACME to your favorites:"
print "bp list | where name =~ ACME | .append tag --type-search-key favorite"
print ""

print "# Adding a request to ACME:"
print "bp list | where name =~ ACME | .append request \"request higher credit limit\" --type-search-key action"
print ""

print "======================================="
print "=== Create Quick Keyboard Shortcuts ==="
print "======================================="
print ""

print "Create quick custom shortcuts like a `bpp` (business partner profile) command/keystroke for common tasks."
print "Note that `bpp` is completely made up as an example of something you might want easy access to."
print ""

print "def bpp [name: string] {"
print "    bp list | where {($in.name =~ $name) or ($in.search_key =~ $name)} | first | tags search_key record_json | select name search_key tags"
print "}"

# Actually define the bpp command
def bpp [name: string] {
    bp list | where {($in.name =~ $name) or ($in.search_key =~ $name)} | first | tags search_key record_json | select name search_key tags
}
print "✓ Created 'bpp' command for for you."
print ""

print "Try it with our demo business partner:"
print "  bpp ACME"
print ""

print "This demonstrates how easy it is to create shortcuts for common tasks."
print "You can define similar commands for any frequently-used reports, queries or processes."
print "Another example might be `oor` for generating an 'open order report'."
print ""

print "=== Scroll up to see a summary and sample commands ==="
print ""

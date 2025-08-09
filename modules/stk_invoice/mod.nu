# STK Invoice Module
# This module provides commands for working with stk_invoice and stk_invoice_line tables

# Module Constants
const STK_SCHEMA = "api"
const STK_INVOICE_TABLE_NAME = "stk_invoice"
const STK_INVOICE_LINE_TABLE_NAME = "stk_invoice_line"
const STK_INVOICE_COLUMNS = [search_key, description, is_template, is_valid, record_json]
const STK_INVOICE_LINE_COLUMNS = [search_key, description, is_valid, record_json]

# Invoice module overview
export def "invoice" [] {
    r#'Invoices record sales and purchase transactions with business partners.
Invoices contain header information and line items for products/services.

Templates enable reusable invoice structures for recurring billing.
Invoices integrate with business partners and financial reporting.

Type 'invoice <tab>' to see available commands.
'#
}

# Create a new invoice with specified search key and type
#
# This is the primary way to create invoices in the chuck-stack system.
# Invoices represent sales transactions (customer invoices) or purchase
# transactions (vendor bills) with line items for products and services.
# The system automatically assigns default values via triggers if type is not specified.
#
# Accepts piped input:
#   string - UUID of business partner for this invoice (required)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'bp list | where'
#
# Examples:
#   $bp_uuid | invoice new "INV-2024-001"
#   bp list | where name == "ACME Corp" | invoice new "INV-2024-002" --description "Monthly consulting services"
#   bp list | first | invoice new "INV-2024-003" --type-search-key sales-standard
#   $customer_uuid | invoice new "DEP-2024-001" --type-search-key sales-deposit --description "50% project deposit"
#   $vendor_uuid | invoice new "BILL-2024-001" --type-search-key purchase-standard
#   $bp_uuid | invoice new "TEMPLATE-001" --template --json '{"payment_terms": "Net 30", "tax_rate": 0.08}'
#   
#   # Interactive examples:
#   $bp_uuid | invoice new "INV-2024-004" --type-search-key sales-standard --interactive
#   bp list | first | invoice new "BILL-2024-002" --interactive --description "Equipment purchase"
#
# Returns: The UUID and search_key of the newly created invoice record
# Note: Uses chuck-stack conventions for automatic entity and type assignment
export def "invoice new" [
    search_key: string              # The unique identifier/number of the invoice to create
    --type-uu: string              # Type UUID (use 'invoice types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the invoice
    --template                     # Mark this invoice as a template
    --entity-uu(-e): string        # Optional entity UUID (uses default if not provided)
    --json(-j): string             # Optional JSON data to store in record_json field
    --interactive                  # Interactively build JSON data using the type's schema
] {
    # Capture the original piped input for context cloning
    let piped_input = $in
    
    # Extract business partner UUID from piped input
    let bp_uuid = ($piped_input | extract-single-uu --error-msg "Business Partner UUID is required via piped input")
    
    # Validate the business partner exists
    psql validate-uuid-table $bp_uuid "stk_business_partner"
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_INVOICE_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Handle JSON input - one line replaces multiple lines of boilerplate
    let record_json = (resolve-json $json $interactive $type_record)
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        search_key: $search_key
        type_uu: ($type_record.uu? | default null)
        description: ($description | default null)
        is_template: ($template | default false)
        stk_entity_uu: ($entity_uu | default null)
        stk_business_partner_uu: $bp_uuid
        record_json: $record_json  # Already a JSON string from resolve-json
    }
    
    # Create the invoice
    let invoice_result = (psql new-record $STK_SCHEMA $STK_INVOICE_TABLE_NAME $params)
    let invoice_uuid = $invoice_result.uu
    
    # Clone business context tags from source
    # Define which tag types should be cloned to invoices (using kabab-case search keys)
    const INVOICE_CONTEXT_TAGS = [
        "bp-customer"          # Business rules: payment terms, credit limit, tax rules
        "address-bill-to"      # Billing address
    ]
    
    # Get source record info to enable cloning from any source type
    let source_info = try { 
        $piped_input | extract-uu-table-name 
    } catch { 
        null  # If we can't extract source info, skip cloning
    }
    
    if ($source_info != null) {
        # Clone each context tag type if it exists on the source
        for tag_type in $INVOICE_CONTEXT_TAGS {
            try {
                # Find and clone the tag
                $invoice_uuid | tag clone-from $source_info.uu --type-search-key $tag_type
                # print $"✓ Cloned ($tag_type) tag to invoice" # DEBUG
            } catch {
                # Tag type not found on source - that's OK, continue
                # let error_msg = $in.msg? | default "Unknown error"
                # print $"⚠️  Could not clone ($tag_type) tag: ($error_msg)" # DEBUG
                null
            }
        }
    }
    
    # Return the invoice creation result
    $invoice_result
}

# List invoices from the chuck-stack system
#
# Displays invoices in chronological order (newest first) to help you
# monitor recent transactions, track invoice status, or review billing history.
# This is typically your starting point for invoice investigation.
# Use the returned UUIDs with other invoice commands for detailed work.
# Type information is always included for all invoices.
#
# Accepts piped input: none
#
# Examples:
#   invoice list
#   invoice list | where is_template == true
#   invoice list | where type_enum == "SALES_STANDARD"
#   invoice list | where is_revoked == false
#   invoice list | select search_key description | table
#   invoice list | where search_key =~ "INV"
#   invoice list | lines  # Add lines column with all invoice line items
#   invoice list | lines | where {|i| ($i.lines | length) > 5}  # Invoices with more than 5 lines
#   invoice list | lines | get lines.0 | flatten  # Get all line items from all invoices
#
# Create a useful alias:
#   def il [] { invoice list | lines | select search_key description lines }  # Concise invoice view with lines
#
# Using resolve to resolve foreign key references:
#   invoice list | resolve                                          # Resolve with default columns
#   invoice list | resolve search_key stk_business_partner_uu       # Show business partner details
#   invoice list | resolve --detail | select search_key stk_business_partner_uu_resolved.name  # BP names
#
# Returns: search_key, description, is_template, is_valid, created, updated, is_revoked, uu, table_name, type_enum, type_name, type_description
# Note: Returns all invoices by default - use --limit to control the number returned
export def "invoice list" [
    --all(-a)     # Include revoked invoices
    --limit(-l): int  # Maximum number of records to return
] {
    # Direct call - psql handles null limit internally
    psql list-records $STK_SCHEMA $STK_INVOICE_TABLE_NAME --all=$all --limit=$limit --priority-columns=$STK_INVOICE_COLUMNS
}

# Retrieve a specific invoice by its UUID
#
# Fetches complete details for a single invoice when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from invoice list or from
# other system outputs. Type information is always included.
#
# Accepts piped input:
#   string - The UUID of the invoice to retrieve
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice list | where'
#
# Examples:
#   "12345678-1234-5678-9012-123456789abc" | invoice get
#   invoice list | get uu.0 | invoice get
#   invoice list | where search_key == "INV-2024-001" | invoice get
#   invoice list | first | invoice get
#   $invoice_uuid | invoice get | get description
#   $invoice_uuid | invoice get | get type_enum
#   $uu | invoice get | if $in.is_revoked { print "Invoice was revoked" }
#   $invoice_uuid | invoice get | lines  # Get invoice with all its line items
#   $invoice_uuid | invoice get | lines | get lines.0  # Extract just the lines
#   invoice get --uu "12345678-1234-5678-9012-123456789abc"
#   invoice get --uu $my_invoice_uuid
#
# Returns: search_key, description, is_template, is_valid, created, updated, is_revoked, uu, table_name, type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "invoice get" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let uu = ($in | extract-uu-with-param $uu)
    
    psql get-record $STK_SCHEMA $STK_INVOICE_TABLE_NAME $STK_INVOICE_COLUMNS $uu
}

# Revoke an invoice by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, invoices are considered cancelled and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the invoice to revoke
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice list | where'
#
# Examples:
#   invoice list | where search_key == "cancelled-invoice" | get uu.0 | invoice revoke
#   invoice list | where search_key == "cancelled-invoice" | invoice revoke
#   invoice list | where is_template == true | each { |row| $row.uu | invoice revoke }
#   "12345678-1234-5678-9012-123456789abc" | invoice revoke
#   invoice revoke --uu "12345678-1234-5678-9012-123456789abc"
#   invoice revoke --uu $cancelled_invoice_uuid
#
# Returns: uu, search_key, revoked timestamp, and is_revoked status
# Error: Command fails if UUID doesn't exist or invoice is already revoked
export def "invoice revoke" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_INVOICE_TABLE_NAME $target_uuid
}


# List available invoice types using generic psql list-types command
#
# Shows all available invoice types that can be used when creating invoices.
# Use this to see valid type options and their descriptions before
# creating new invoices with specific types.
#
# Accepts piped input: none
#
# Examples:
#   invoice types
#   invoice types | where type_enum == "SALES_STANDARD"
#   invoice types | where is_default == true
#   invoice types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all invoice types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "invoice types" [] {
    psql list-types $STK_SCHEMA $STK_INVOICE_TABLE_NAME
}



# Add a line item to an invoice by referencing an item or creating custom line
#
# Creates a new invoice line (product, service, discount, or description) 
# associated with a specific invoice. Invoice lines are the detailed items 
# that make up an invoice and can reference stk_item for product/service details.
# Line numbers are auto-generated (10, 20, 30...) if not explicitly provided.
#
# Accepts piped input:
#   string - The UUID of the invoice (required)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice list | where'
#
# Examples:
#   # Add item by search_key with quantity and price
#   $invoice_uuid | invoice line new "WIDGET-001" --qty 5 --price 29.99
#   $invoice_uuid | invoice line new "SERVICE-CONSULT" --qty 40 --price 150
#   
#   # Add custom line without item reference
#   $invoice_uuid | invoice line new --description "Custom service charge" --qty 1 --price 100
#   $invoice_uuid | invoice line new --description "Early payment discount" --type-search-key discount --price -50
#   
#   # Specify custom line number
#   $invoice_uuid | invoice line new "WIDGET-001" --line-number "15" --qty 2 --price 45.50
#   
#   # Full JSON control
#   $invoice_uuid | invoice line new --json '{"quantity": 40, "price_unit": 150, "price_extended": 6000}'
#   
#   # Interactive examples:
#   $invoice_uuid | invoice line new --type-search-key item --interactive
#   $invoice_uuid | invoice line new "WIDGET-001" --interactive
#
# Returns: The UUID and search_key of the newly created invoice line record
# Note: Line numbers auto-generate as 10, 20, 30... when not specified
export def "invoice line new" [
    item_search_key?: string        # Optional item search key to find and add to invoice
    --line-number(-l): string      # Optional line number (defaults to next available: 10, 20, 30...)
    --qty(-q): float               # Quantity for this line item
    --price(-p): float             # Unit price for this line item
    --type-uu: string              # Type UUID (use 'invoice line types' to find UUIDs)
    --type-search-key: string      # Type search key (unique identifier for type)
    --description(-d): string      # Optional description of the line
    --json(-j): string             # Optional JSON data to store in record_json field
    --interactive                  # Interactively build JSON data using the type's schema
] {
    # Extract UUID from piped input
    let invoice_uu = ($in | extract-single-uu --error-msg "Invoice UUID is required via piped input")
    
    # Look up item if search_key provided
    let item_info = if ($item_search_key | is-not-empty) {
        let item_result = (item list | where {|it| $it.search_key == $item_search_key or $it.name == $item_search_key})
        if ($item_result | is-empty) {
            error make {msg: $"Item with search_key or name '($item_search_key)' not found"}
        }
        $item_result | first
    } else {
        null
    }
    
    # Extract item UUID if found
    let item_uu = if ($item_info != null) { $item_info.uu } else { null }
    
    # Use item description if no description provided and item was found
    let final_description = if ($description | is-empty) and ($item_info != null) {
        $item_info.description | default $item_info.name
    } else {
        $description
    }
    
    # Resolve type using utility function
    let type_record = (resolve-type --schema $STK_SCHEMA --table $STK_INVOICE_LINE_TABLE_NAME --type-uu $type_uu --type-search-key $type_search_key)
    
    # Build JSON with quantity and price if provided
    let json_obj = if ($json | is-not-empty) {
        # User provided explicit JSON
        $json
    } else if ($qty != null) or ($price != null) {
        # Build JSON from parameters
        mut obj = {}
        if ($qty != null) { $obj = ($obj | insert quantity $qty) }
        if ($price != null) { $obj = ($obj | insert price_unit $price) }
        if ($qty != null) and ($price != null) {
            $obj = ($obj | insert price_extended ($qty * $price))
        }
        $obj | to json
    } else {
        null
    }
    
    # Handle JSON input - one line replaces multiple lines of boilerplate
    let record_json = (resolve-json $json_obj $interactive $type_record)
    
    # Build parameters record internally - eliminates cascading if/else logic
    let params = {
        search_key: ($line_number | default null)  # Will auto-generate if null
        type_uu: ($type_record.uu? | default null)
        description: ($final_description | default null)
        stk_item_uu: $item_uu
        record_json: $record_json  # Already a JSON string from resolve-json
    }
    
    # Single call with all parameters - no more cascading logic
    psql new-line-record $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME $invoice_uu $params
}

# List invoice lines for a specific invoice
#
# Displays all line items associated with an invoice to help you
# view invoice breakdown, track products/services, or manage billing details.
# Shows the most recent lines first for easy review.
#
# Accepts piped input:
#   string - The UUID of the invoice (required)
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice list | where'
#
# Examples:
#   $invoice_uuid | invoice line list
#   invoice list | where search_key == "INV-2024-001" | invoice line list
#   $invoice_uuid | invoice line list | select name description | table
#   $invoice_uuid | invoice line list | where search_key =~ "LINE"
#   $invoice_uuid | invoice line list | resolve  # Resolve all UUID references
#   $invoice_uuid | invoice line list | resolve | get type_uu_resolved  # See line type details
#
# Returns: search_key, description, is_valid, created, updated, is_revoked, uu, table_name
# Note: By default shows only active lines, use --all to include revoked
export def "invoice line list" [
    --all(-a)  # Include revoked invoice lines
    --limit(-l): int  # Maximum number of records to return
] {
    # Extract UUID from piped input
    let invoice_uu = ($in | extract-single-uu --error-msg "Invoice UUID is required via piped input")
    
    # Direct call - psql handles null limit internally
    psql list-line-records $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME $invoice_uu --all=$all --limit=$limit --priority-columns=$STK_INVOICE_LINE_COLUMNS
}

# Retrieve a specific invoice line by its UUID
#
# Fetches complete details for a single invoice line when you need to
# inspect its contents, verify its state, or extract specific
# data. Use this when you have a UUID from invoice line list or from
# other system outputs. Type information is always included.
#
# Accepts piped input: 
#   string - The UUID of the invoice line to retrieve
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice line list | where'
#
# Examples:
#   $invoice_uuid | invoice line list | get uu.0 | invoice line get
#   $invoice_uuid | invoice line list | where search_key == "LINE-002" | invoice line get
#   $invoice_uuid | invoice line list | first | invoice line get
#   $line_uuid | invoice line get | get description
#   $line_uuid | invoice line get | get type_enum
#   "12345678-1234-5678-9012-123456789abc" | invoice line get
#   invoice line get --uu "12345678-1234-5678-9012-123456789abc"
#   invoice line get --uu $my_line_uuid
#
# Returns: search_key, description, is_valid, created, updated, is_revoked, uu, type_enum, type_name, and other type information
# Error: Returns empty result if UUID doesn't exist
export def "invoice line get" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = if ($in | is-empty) {
        if ($uu | is-empty) {
            error make {msg: "Invoice line UUID is required via piped input or --uu parameter."}
        }
        $uu
    } else {
        ($in | extract-single-uu)
    }
    
    psql get-record $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME $STK_INVOICE_LINE_COLUMNS $target_uuid
}

# Revoke an invoice line by setting its revoked timestamp
#
# This performs a soft delete by setting the revoked column to now().
# Once revoked, invoice lines are considered inactive and won't appear in 
# normal selections. Use this instead of hard deleting to maintain
# audit trails and data integrity in the chuck-stack system.
#
# Accepts piped input: 
#   string - The UUID of the invoice line to revoke
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice line list | where'
#   list - Multiple UUIDs to revoke in bulk
#
# Examples:
#   $invoice_uuid | invoice line list | where search_key == "obsolete-item" | get uu.0 | invoice line revoke
#   $invoice_uuid | invoice line list | where search_key == "obsolete-item" | invoice line revoke
#   $invoice_uuid | invoice line list | where created < (date now) - 30day | get uu | invoice line revoke
#   "12345678-1234-5678-9012-123456789abc" | invoice line revoke
#   [$uuid1, $uuid2, $uuid3] | invoice line revoke
#   invoice line revoke --uu "12345678-1234-5678-9012-123456789abc"
#   invoice line revoke --uu $obsolete_line_uuid
#
# Returns: uu, search_key, revoked timestamp, and is_revoked status for each revoked line
# Error: Command fails if UUID doesn't exist or line is already revoked
export def "invoice line revoke" [
    --uu: string  # UUID as a parameter instead of piped input
] {
    # Extract UUID from piped input or --uu parameter
    let target_uuid = ($in | extract-uu-with-param $uu)
    
    psql revoke-record $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME $target_uuid
}


# List available invoice line types using generic psql list-types command
#
# Shows all available invoice line types that can be used when creating lines.
# Use this to see valid type options and their descriptions before
# creating new invoice lines with specific types.
#
# Accepts piped input: none
#
# Examples:
#   invoice line types
#   invoice line types | where type_enum == "ITEM"
#   invoice line types | where is_default == true
#   invoice line types | select type_enum name is_default | table
#
# Returns: uu, type_enum, name, description, is_default, created for all invoice line types
# Note: Uses the generic psql list-types command for consistency across chuck-stack
export def "invoice line types" [] {
    psql list-types $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME
}

# Generate a PDF for an invoice (POC)
#
# This is a proof-of-concept command that generates a PDF document
# from an invoice using Typst. The command uses resolve and flatten-record
# to automatically prepare all data with minimal code.
#
# Accepts piped input:
#   string - UUID of the invoice to generate PDF for
#   record - A record containing a 'uu' field
#   table - A single-row table from commands like 'invoice list | where'
#
# Examples:
#   $invoice_uuid | invoice pdf
#   invoice list | where search_key == "INV-2024-001" | invoice pdf
#   invoice list | first | invoice pdf --output /tmp/invoice.pdf
#   $invoice_uuid | invoice pdf --open
#
# Returns: Path to the generated PDF file
# Note: Requires 'typst' command to be available in PATH
export def "invoice pdf" [
    --output(-o): path              # Output file path (default: /tmp/invoice-{search_key}.pdf)
    --open                          # Open the PDF after generation
    --uu: string                    # UUID of the invoice (alternative to piped input)
] {
    # Extract invoice UUID from input
    let invoice_uuid = ($in | extract-uu-with-param $uu)
    
    # Get invoice with all foreign keys resolved and flattened
    let invoice = (
        psql get-record $STK_SCHEMA $STK_INVOICE_TABLE_NAME $STK_INVOICE_COLUMNS $invoice_uuid 
        | resolve --detail 
        | flatten-record --include-json --clean
    )
    
    if ($invoice | is-empty) {
        error make {msg: "Invoice not found"}
    }
    
    # Get invoice lines with resolved and flattened data
    let lines = (
        psql list-line-records $STK_SCHEMA $STK_INVOICE_LINE_TABLE_NAME $invoice_uuid --priority-columns=$STK_INVOICE_LINE_COLUMNS 
        | resolve --detail
        | flatten-record --include-json --clean
    )
    
    # Calculate totals from line items
    let line_totals = ($lines | each {|line|
        if ($line.price_extended? | is-not-empty) {
            $line.price_extended
        } else if ($line.discount_amount? | is-not-empty) {
            $line.discount_amount
        } else {
            0
        }
    })
    
    let subtotal = ($line_totals | where $it > 0 | math sum | default 0)
    let discount = ($line_totals | where $it < 0 | math sum | math abs | default 0)
    let total = ($subtotal - $discount)
    
    # Build simplified invoice data structure for Typst
    let invoice_data = {
        number: $invoice.search_key
        date: ($invoice.created | format date "%Y-%m-%d")
        due_date: ($invoice.due_date? | default "")
        
        seller: {
            name: ($invoice.entity_name | default "")
            address: ($invoice.entity_address? | default "")
            tax_id: ($invoice.entity_tax_id? | default "")
        }
        
        customer: {
            name: $invoice.business_partner_name
            address: ($invoice.business_partner_address? | default "")
        }
        
        items: ($lines | each {|line| {
            line: $line.search_key
            description: $line.description
            qty: ($line.quantity? | default 0)
            price: ($line.price_unit? | default 0)
            total: ($line.price_extended? | default 0)
        }})
        
        subtotal: $subtotal
        total: $total
    }
    
    # Determine output path
    let output_path = if ($output | is-not-empty) {
        $output
    } else {
        $"/tmp/invoice-($invoice.search_key).pdf"
    }
    
    # Write JSON data to temporary file
    let json_path = "/tmp/invoice-data.json"
    $invoice_data | to json | save -f $json_path
    
    # Get template path - use the test directory when in test environment, otherwise relative to module
    let template_path = if ("STK_TEST_DIR" in $env) {
        $env.STK_TEST_DIR | path join "template-print/invoice/invoice-simple.typ"
    } else {
        # In production, template would be relative to module location
        $env.FILE_PWD | path join "../../template-print/invoice/invoice-simple.typ"
    }
    
    # Check if typst is available
    let typst_check = (which typst | is-not-empty)
    if not $typst_check {
        error make {msg: "typst command not found. Please install typst to generate PDFs."}
    }
    
    # Copy template to /tmp so it can find the JSON file
    let temp_template = "/tmp/invoice-template.typ"
    cp $template_path $temp_template
    
    # Generate PDF using Typst from /tmp directory
    let result = (^typst compile $temp_template $output_path | complete)
    
    if $result.exit_code != 0 {
        error make {msg: $"PDF generation failed: ($result.stderr)"}
    }
    
    # Clean up temporary files
    rm -f $json_path
    rm -f $temp_template
    
    # Open PDF if requested
    if $open {
        if (which xdg-open | is-not-empty) {
            ^xdg-open $output_path
        } else if (which open | is-not-empty) {
            ^open $output_path
        } else {
            print $"PDF generated but no PDF viewer found. File saved to: ($output_path)"
        }
    }
    
    # Return the path to the generated PDF
    $output_path
}

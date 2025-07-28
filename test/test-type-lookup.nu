#\!/usr/bin/env nu

# Test script to check if type records exist

print "Checking if type records exist in database..."

# Check for ADDRESS type in stk_tag_type
let address_check = (nu -c "
use ./modules *
try {
    psql query 'SELECT * FROM api.stk_tag_type WHERE search_key = $'ADDRESS$'' --table
    | length
} catch {
    0
}
")

print $"ADDRESS type records: ($address_check)"

# Check for CLIENT type in stk_project_type  
let client_check = (nu -c "
use ./modules *
try {
    psql query 'SELECT * FROM api.stk_project_type WHERE search_key = $'CLIENT$'' --table
    | length
} catch {
    0
}
")

print $"CLIENT type records: ($client_check)"

# Check for TIMESHEET type in stk_event_type
let timesheet_check = (nu -c "
use ./modules *
try {
    psql query 'SELECT * FROM api.stk_event_type WHERE search_key = $'TIMESHEET$'' --table
    | length
} catch {
    0
}
")

print $"TIMESHEET type records: ($timesheet_check)"

# === Testing template pattern ===
# Template: Replace MODULE with your module name (e.g., item, bp, project)
# Template Version: 2025-01-08

# print "=== Testing MODULE template creation ==="
let template = (MODULE new $"Template($test_suffix)" --template)
assert ($template.is_template == true) "Should create as template"

# print "=== Testing MODULE regular creation ==="
let regular = (MODULE new $"Regular($test_suffix)")
assert (($regular.is_template? | default false) == false) "Should not be template"

# print "=== Testing default MODULE list excludes templates ==="
let default_list = (MODULE list | where name =~ $test_suffix)
assert ($default_list | where name =~ "Regular" | is-not-empty) "Should show regular"
assert ($default_list | where name =~ "Template" | is-empty) "Should hide templates"

# print "=== Testing MODULE list --templates ==="
let template_list = (MODULE list --templates | where name =~ $test_suffix)
assert ($template_list | where name =~ "Template" | is-not-empty) "Should show templates"
assert ($template_list | where name =~ "Regular" | is-empty) "Should hide regular"

# print "=== Testing revoked template not in --templates list ==="
let revoked_template = (MODULE new $"Revoked Template($test_suffix)" --template)
let revoked = ($revoked_template.uu | MODULE revoke)
let template_list_after = (MODULE list --templates | where name =~ $test_suffix)
assert ($template_list_after | where name =~ "Revoked Template" | is-empty) "Should not show revoked templates"

# print "=== Testing MODULE list --all ==="
let all_list = (MODULE list --all | where name =~ $test_suffix)
assert ($all_list | where name =~ "Regular" | is-not-empty) "Should show regular"
assert ($all_list | where name =~ "Template" | is-not-empty) "Should show templates"
assert ($all_list | where name =~ "Revoked Template" | is-not-empty) "Should show revoked templates with --all"

# print "=== Testing direct MODULE get on template ==="
let get_template = ($template.uu | MODULE get)
assert ($get_template.is_template == true) "Should get template directly"
use ../modules *

# to see this in action, simple `source project.nu' from a nushell session

# create new parent project
let p = project new "digital consulting erp"

# create first project line
$p.0.uu | project line new "create timesheets"

# create second project line
$p.0.uu | project line new "create support ticket"

# create to-be-revoked project line
$p.0.uu | project line new "party like it is 1984"

# show progress
$p | lines | select name lines

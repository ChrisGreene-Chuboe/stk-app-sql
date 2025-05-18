# STK Event Module
# This module provides commands for working with stk_event table

# Append text to the stk_event record_json field with the given name/topic
export def ".append event" [
    name: string       # The name/topic of the event
] {
    # Create the SQL command
    let table = "api.stk_event"
    let columns = "(name,record_json)"
    let values = $"\('($name)', jsonb_build_object\('text', '($in)'))"
    let returning = "uu"
    let sql = $"INSERT INTO ($table) ($columns) VALUES ($values) RETURNING ($returning)"
    #INSERT INTO api.stk_event (name,record_json) VALUES ('test', jsonb_build_object('text', 'this is a quick event test')) RETURNING uu

    #$sql
    psql exec $sql
    #psql exec $sql
}

# List recent events
export def "event list" [] {
    psql exec "SELECT uu, name, record_json, created, updated FROM api.stk_event ORDER BY created DESC LIMIT 10"
}

# Get a specific event by UUID
export def "event get" [
    uu: string  # The UUID of the event to retrieve
] {
    psql exec $"SELECT uu, name, record_json, created, updated FROM api.stk_event WHERE uu = '($uu)'"
}


# STK Event Module
# This module provides commands for working with stk_event table

# Append text to the stk_event record_json field with the given name/topic
export def ".append event" [
    name: string       # The name/topic of the event
] {
    # Create the SQL command
    let sql = "INSERT INTO api.stk_event (name, record_json) VALUES 
  ('" + $name + "', 
   jsonb_build_object('text', '" + $in + "')
  ) RETURNING uu;"
    
    # Pipe the SQL directly to psql via stdin
    echo $sql | run-external "psql"
}

# List recent events
export def "event list" [] {
    with-env {PSQLRC: ".psqlrc-nu"} {
        echo "SELECT uu, name, record_json, created FROM api.stk_event ORDER BY created DESC LIMIT 10" | psql
    }
}

# Get a specific event by UUID
export def "event get" [
    uu: string  # The UUID of the event to retrieve
] {
    echo $"SELECT uu, name, record_json, created FROM api.stk_event WHERE uu = '($uu)'" | run-external "psql"
}


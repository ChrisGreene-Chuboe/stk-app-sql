def "show actor" [
    --where (-w): string        # where clause
    --first (-f): int           # first clause
] {
    let where_clause = if ($where != null) {
        ["-v", $"w=($where)"]
    } else {
        []
    }

    let first_clause = if ($first != null) {
        ["-v", $"f=($first)"]
    } else {
        []
    }

    psql -Aqt ...$where_clause ...$first_clause -v t="stk_actor" -f cli/show.sql | from json
}

def "show request" [] {
    print "list request"
}

def show [] {
    print "shows all tables"
}

def "show actor" [] {
    psql -Aqt -v t="stk_actor" -f sql-templates/show-actor.sql | from json
}

def "show request" [] {
    print "list request"
}

def show [] {
    print "shows all tables"
}

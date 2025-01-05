def "show actor" [
    --where (-w): string        # where clause
    --limit (-l): int           # limit clause
] {
    #TODO: surround the --where nu command argument value with the psql w="-v w='...'" like the example below
    #TODO: inject the psql where string into the below psql command 

    #NOTE: the -v w="..." is hardcoded for example. It will soon be replaced by the above --where string
    psql -Aqt -v w=" lower(name) like 's%'" -v t="stk_actor" -f sql-templates/show.sql | from json
}

def "show request" [] {
    print "list request"
}

def show [] {
    print "shows all tables"
}

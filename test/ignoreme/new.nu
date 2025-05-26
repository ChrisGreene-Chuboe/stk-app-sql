# example for quick reference: psql -Aqt -v cols="name" -v vals="'test'"  -v t="stk_actor" -f new.sql

def "new actor" [
    --name (-n): string                 # name of record
    --search_key (-s): string           # defaults to uuid if not specified
] {

    #TODO: step:1 create comma delimited column_names string (from array)
    #TODO: step:2 create comma delimited column_values string including surrounding single quotes for text (from array)
    #TODO: step:3 create psql arguments for column_names and column_values

    # create variables to for inclusion in the below psql
    #let cols = ["-v", $"cols=($column_names)"]
    #let vals = ["-v", $"vals=($column_values)"]

    # hard coded as a quick test
    #TODO: delete this code and replace with dynamic values
    let cols = ["-v", $"cols=name,search_key"]
    let vals = ["-v", $"vals='test1','test1'"]

    psql -Aqt ...$cols ...$vals -v t="stk_actor" -f cli/new.sql | from json
}

def "new request" [] {
    print "new request"
}

def new [] {
    print "list all tables"
}

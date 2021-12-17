### What to test

#### Basic functionality (integration testing)
+ If value typed out
    + It's recognized as an abbreviation in expanded form
+ Triggered when one ends value with a symbol that would otherwise have vim expand the trigger (if it would have been typed)
    + eg, `,`, ` `, `-`, `/`
+ If an abbreviation has been expanded, do nothing (optionally test autocmd, but I don't really care about those)
    + `testing, ` triggers reminder even though I only wrote `test, `
+ Works correctly with vim-abolish (ie, prefixes are accounted for)
+ If type a multiword value, you are still reminded of the abbreviation
    + With all support that single word has
+ If an abbreviation is added/removed during the session, abbreinder acts accordingly

#### get_abbrevs_val_trigger
+ If an abbreviation is added/removed during the session, the same is done to the maps

#### getCoordinates
+ line_num, start, end are correct for single and multiword abbreviations
    + If it's the first characters in a buffer
    + If it's the first characters on a line
    + If there's multiple of the same value on the same line
        + Previously unexpanded and previously expanded
    + If the value is the first on the line
    + If the value is between two other values
    + If the value is last on the line
    + If there's multiple of the same and different values on the same line
        + `nonexpandedButPreviouslyCaughtValue1 nonexpandedButCurrentlyWorkingOnValue`


#### Known bugs
Error detected while processing InsertCharPre Autocommands for "*":
E5108: Error executing lua .../site/pack/packer/start/abbreinder/lua/abbreinder/ui.lua:15: attempt to perform arithmeti
c on local 'value_start' (a nil value)

<triggered_abbr>.
<symbol>





#### Additional functionality
+ If user backspaces while typing, that's taken into account
    + 'tex<BS>sting' still would trigger reminder about abbreviation `testing`
+ Deleting the value closes the reminder
+ User moving on the next line closes the reminder
    + Almost certainly seen it at that point, and then it's just annoying

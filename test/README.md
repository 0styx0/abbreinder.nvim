### How to test
+ Unit tests: run `make tests`
+ Integration tests:
    + `:e test/plenary/integration_manual_tests.lua`
    + `source % | lua Run_tests()`
    + Reason it's separate is because I ran into too many bugs trying to mock typing with plenary and feedkeys


### Basic functionality (integration testing)
+ If value typed out
    + It's recognized as an abbreviation in expanded form
+ Triggered when one ends value with a symbol that would otherwise have vim expand the trigger (if it would have been typed)
    + eg, `,`, ` `, `-`, `/`
+ If an abbreviation has been expanded, do nothing (optionally test autocmd, but I don't really care about those)
    + `testing, ` triggers reminder even though I only wrote `test, `
    + Potentially expand this bullet to include other areas of testing
        + Eg, for every non-expanded test, there's a corresponding yes-expanded test
            + A wrapper for tests
+ Works correctly with vim-abolish (ie, prefixes are accounted for)
+ If type a multiword value, you are still reminded of the abbreviation
    + With all support that single word has
+ If an abbreviation is added/removed during the session, abbreinder acts accordingly
+ If abbreviation of form `partSame partSameAsTrigger` or if trigger/value completely different
+ if wts -> what's

### Unit tests

#### get_abbrevs_val_trigger
+ If an abbreviation is added/removed during the session, the same is done to the maps
+ All defined abbreviations are added to the map
    + Test for regularly defined and Abolish/prefixed abbreviations
+ If multiword abbreviation, ensure the entire value is found in the main abbrev_map

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


#### Additional functionality
+ If user backspaces while typing, that's taken into account
    + 'tex<BS>sting' still would trigger reminder about abbreviation `testing`
+ Deleting the value closes the reminder
+ User moving on the next line closes the reminder
    + Almost certainly seen it at that point, and then it's just annoying




highlight default link cComment Comment

```vim
nvim_get_namespaces()                                  *nvim_get_namespaces()*
                Gets existing, non-anonymous namespaces.
                Return: dict that maps from names to namespace ids.
```



:echo "hi<" . synIDattr(synID(line("."),col("."),1),"name") . '> trans<' . synIDattr(synID(line("."),col("."),0),"name") ."> lo<" . synIDattr(synIDtrans(synID(line("."),col("."),1)),"name") . ">"<CR>

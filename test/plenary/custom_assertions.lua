local say = require('say')

local function custom_assertion_table_contains_element(state, arguments)
    local table = arguments[1]
    local element = arguments[2]

    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end
say:set_namespace('en')
say:set('assertion.contains_element.positive', 'Expected element %s in:\n%s')
say:set('assertion.contains_element.negative', 'Expected element %s to not be in:\n%s')
assert:register(
    'assertion',
    'contains_element',
    custom_assertion_table_contains_element,
    'assertion.contains_element.positive',
    'assertion.contains_element.negative'
)

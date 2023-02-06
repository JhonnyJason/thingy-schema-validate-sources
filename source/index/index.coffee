############################################################
# types Enumeration
export NUMBER = 0
export STRING = 1
export STRINGHEX = 2
export STRINGHEX32 = 3
export STRINGHEX64 = 4
export STRINGHEX128 = 5
export BOOLEAN = 6
export ARRAY = 7
export NUMBERORNULL = 8
export OBJECT = 9
export OBJECTORUNDEFINED = 10
export NONNULLOBJECT = 11

############################################################
assertionFunctions = new Array(12)

############################################################
#region hexHelpers
hexChars = "0123456789abcdefABCDEF"
hexMap = {}
hexMap[c] = true for c in hexChars

#endregion
Was
############################################################
#region all Assertion Functions
assertionFunctions[NUMBER] = (arg) ->
    if typeof arg != "number" then throw new Error("Not a number!")
    return 

assertionFunctions[STRING] = (arg) ->
    if typeof arg != "string" then throw new Error("Not a string!")
    return 

assertionFunctions[STRINGHEX] = (arg) ->
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    return

assertionFunctions[STRINGHEX32] = (arg) ->
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 32 then throw new Error("HexString length was not 32 characters!")
    return

assertionFunctions[STRINGHEX64] = (arg) ->
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 64 then throw new Error("HexString length was not 64 characters!")
    return

assertionFunctions[STRINGHEX128] = (arg) ->
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 128 then throw new Error("HexString length was not 128 characters!")
    return

assertionFunctions[BOOLEAN] = (arg) ->
    if typeof arg != "boolean" then throw new Error("Not a boolean!")
    return

assertionFunctions[ARRAY] = (arg) ->
    if !Array.isArray(arg) then throw new Error("Not an array!")
    return

assertionFunctions[NUMBERORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "number" then throw new Error("Neither a number nor null!")
    return

assertionFunctions[OBJECT] = (arg) ->
    if typeof arg != "object" then throw new Error("Not an Object!")
    return

assertionFunctions[OBJECTORUNDEFINED] = (arg) ->
    if typeof arg == "undefined" then return
    if typeof arg != "object" then throw new Error("Not an Object!")
    return

assertionFunctions[NONNULLOBJECT] = (arg) ->
    if arg == null then throw new Error("Is null!")
    if typeof arg != "object" then throw new Error("Not an Object!")
    return

#endregion

############################################################
export validate = (obj, schema) ->
    objKeys = Object.keys(obj)
    argKeys = Object.keys(schema)
    
    if objKeys.length != argKeys.length then throw new Error("Error: The Number of parameters in the obj, did not match the expected number. Expected #{argKeys.length} vs #{objKeys.length} present")
    
    for key,i in objKeys
        if key != argKeys[i] then throw new Error("Error: parameter @ index: #{i} had wrong key! expected: '#{argKeys[i]}'  detected: '#{key}'")

    for label,arg of obj
        type = schema[label]
        try assertionFunctions[type](arg)
        catch err then throw new Error("Error: unexpected format of parameter #{label} - #{err.message}")
    return

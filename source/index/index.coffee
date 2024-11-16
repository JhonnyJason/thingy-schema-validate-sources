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
export OBJECT = 8
export NONNULLOBJECT = 9

export NUMBERORNULL = 10
export STRINGORNULL = 11
export STRINGHEXORNULL = 12
export STRINGHEX32ORNULL = 13
export STRINGHEX64ORNULL = 14
export STRINGHEX128ORNULL = 15
export BOOLEANORNULL = 16
export ARRAYORNULL = 17


############################################################
assertionFunctions = new Array(18)

############################################################
#region hexHelpers
hexChars = "0123456789abcdefABCDEF"
hexMap = {}
hexMap[c] = true for c in hexChars

#endregion

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

assertionFunctions[OBJECT] = (arg) ->
    if typeof arg != "object" then throw new Error("Not an Object!")
    return

assertionFunctions[NONNULLOBJECT] = (arg) ->
    if arg == null then throw new Error("Is null!")
    if typeof arg != "object" then throw new Error("Not an Object!")
    return

assertionFunctions[NUMBERORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "number" then throw new Error("Neither a number nor null!")
    return

assertionFunctions[STRINGORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "string" then throw new Error("Not a string!")
    return 

assertionFunctions[STRINGHEXORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    return

assertionFunctions[STRINGHEX32ORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 32 then throw new Error("HexString length was not 32 characters!")
    return

assertionFunctions[STRINGHEX64ORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 64 then throw new Error("HexString length was not 64 characters!")
    return

assertionFunctions[STRINGHEX128ORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "string" then throw new Error("Not a string!")
    for c in arg when !hexMap[c]? then throw new Error("Not a HexString!")
    if arg.length != 128 then throw new Error("HexString length was not 128 characters!")
    return

assertionFunctions[BOOLEANORNULL] = (arg) ->
    if arg == null then return
    if typeof arg != "boolean" then throw new Error("Not a boolean!")
    return

assertionFunctions[ARRAYORNULL] = (arg) ->
    if arg == null then return
    if !Array.isArray(arg) then throw new Error("Not an array!")
    return

#endregion

############################################################
export validate = (obj, schema) ->
    if !schema? then throw new Error("No schema provided!")
    if !obj? then throw new Error("No Object to validate!")
    
    objKeys = Object.keys(obj)
    argKeys = Object.keys(schema)
    
    if objKeys.length != argKeys.length then throw new Error("The Number of parameters in the obj, did not match the expected number. Expected: #{argKeys.length} Present: #{objKeys.length} ")
    
    for key,i in objKeys
        if key != argKeys[i] then throw new Error("Parameter @ index: #{i} had wrong key! expected: '#{argKeys[i]}'  detected: '#{key}'")

    for label,arg of obj
        type = schema[label]
        try assertionFunctions[type](arg)
        catch err then throw new Error("Unexpected format of parameter '#{label}'! #{err.message}")
    return

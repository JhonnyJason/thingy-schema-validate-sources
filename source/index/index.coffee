############################################################
# log = console.log
# olog = (arg) -> console.log(JSON.stringify(arg, null, 4))

############################################################
#region Basic Schema Type Enumeration

############################################################
## Notice: NUMBER validation
# Due to JSON limitations NaN and (-)Infinity are invalid
# This means that NUMBER type already excludes these values
# Previously we had FINITENUMBER and NONANNUMBER 
# These types are gone now :-)

export BOOLEAN = 1
export NUMBER = 2
export ARRAY = 3
export OBJECT = 4

export STRING = 5
export STRINGEMAIL = 6 
export STRINGHEX = 7
export STRINGHEX32 = 8
export STRINGHEX64 = 9
export STRINGHEX128 = 10
export STRINGHEX256 = 11
export STRINGHEX512 = 12

export STRINGCLEAN = 13
export NONEMPTYSTRING = 14
export NONEMPTYSTRINGHEX = 15
export NONEMPTYSTRINGCLEAN = 16
export NONEMPTYARRAY = 17
export OBJECTCLEAN = 18
export NONNULLOBJECT = 19
export NONNULLOBJECTCLEAN = 20


export STRINGORNOTHING = 21
export STRINGEMAILORNOTHING = 22
export STRINGHEXORNOTHING = 23
export STRINGHEX32ORNOTHING = 24
export STRINGHEX64ORNOTHING = 25
export STRINGHEX128ORNOTHING = 26
export STRINGHEX256ORNOTHING = 27
export STRINGHEX512ORNOTHING = 28
export STRINGCLEANORNOTHING = 29
export NUMBERORNOTHING = 30
export BOOLEANORNOTHING = 31
export ARRAYORNOTHING = 32
export OBJECTORNOTHING = 33
export OBJECTCLEANORNOTHING = 34

export STRINGORNULL = 35
export STRINGEMAILORNULL = 36
export STRINGHEXORNULL = 37
export STRINGHEX32ORNULL = 38
export STRINGHEX64ORNULL = 39
export STRINGHEX128ORNULL = 40
export STRINGHEX256ORNULL = 41
export STRINGHEX512ORNULL = 42
export STRINGCLEANORNULL = 43 
export NUMBERORNULL = 44
export BOOLEANORNULL = 45
export ARRAYORNULL = 46

typeArraySize = 47

#endregion

############################################################
#region Local Variables
staticValidatorOrThrow = null
locked = false

############################################################
numericOnlyRegex = /^\d+$/
invalidEmailSmallRegex = /(\.\.|--|-\.)|\.-/

############################################################
hexChars = "0123456789abcdefABCDEF"
hexMap = new Array(103)
i = 0
while(i < hexChars.length)
    hexMap[hexChars.charCodeAt(i)] = true
    i++
# Object.freeze(hexMap) # creates minor performance penalty

############################################################
domainChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-."
domainCharMap = new Array(123)
i = 0
while(i < domainChars.length)
    domainCharMap[domainChars.charCodeAt(i)] = true
    i++
# Object.freeze(domainCharMap) # creates minor performance penalty


############################################################
# \t = \x09 Horizontal Tab -> not dirty :-) 
# \n = \x0A Line Feed -> not dirty :-)
# PAD = \x80 Padding Character -> not dirty :-)
# NEL = \x85 Next Line -> not dirty :-)

dirtyChars = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x0B\x0C\x0D\x0E\x0F" +  # C0 controls
    "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F" +  
    "\x7F" +
    "\x81\x82\x83\x84\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F" + #C1 controls
    "\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F"
# all chars > \u02ff will be cut off manually 
dirtyCharMap = new Array(160)
i = 0
while(i < dirtyChars.length)
    dirtyCharMap[dirtyChars.charCodeAt(i)] = true
    i++
# Object.freeze(dirtyCharMap) # creates minor performance penalty

#endregion

############################################################
#region Local Functions

############################################################
isDirtyObject = (obj) ->
    return if obj == null
    ## as the inputs come from an object which was originalled paref from a JSON string we assume to not fall into an infinite loop
    keys = Object.keys(obj)
    for k in keys
        if k == "__proto__" or k == "constructor" or k == "prototype"
            return true
        if typeof obj[k] == "object"
            return true if isDirtyObject(obj[k])
    return false

############################################################
createStaticStringValidator = (str) ->
    return (arg) ->
        if arg != str then return ISINVALID
        return

createThrower = (msg) ->
    return () -> throw new Error(msg)

############################################################
#region Validator Creation Helpers
getTypeValidator = (type) ->
    fun = typeValidatorFunctions[type]
    if !fun? then throw new Error("Unrecognized Schematype! (#{type})")
    return fun

############################################################
getTypeValidatorsForArray = (arr) ->
    funcs = new Array(arr.length)
    
    for el,i in arr
        switch
            when typeof el == "number" then funcs[i] = getTypeValidator(el)
            when typeof el == "string" then funcs[i] = staticValidatorOrThrow(el)
            when typeof el != "object" then throw new Error("Illegal #{typeof el}!")
            when Array.isArray(el) 
                funcs[i] = createArrayValidator(el)
            else funcs[i] = createObjectValidator(el)

    return funcs

getValidatorEntriesForObject = (obj) ->
    keys = Object.keys(obj)
    entries = []
    
    for k,i in keys
        prop = obj[k]
        if typeof prop == "number"
            entries.push([k, getTypeValidator(prop)])
            continue
        if typeof prop == "string"
            entries.push([k, staticValidatorOrThrow(prop)])
            continue
        if typeof prop != "object" then throw new Error("Illegal #{typeof prop}!")
        if Array.isArray(prop) then entries.push([k, createArrayValidator(prop)])
        else entries.push([k, createObjectValidator(prop)])

    return entries

############################################################
createArrayValidator = (arr) ->
    if arr.length ==  0 then throw new Error("[] is illegal!")
    funcs = getTypeValidatorsForArray(arr)
    # olog valEntries
    
    func = (arg) ->
        if !Array.isArray(arg) then return ISINVALID
        hits = 0
        for f,i in funcs
            el = arg[i]
            if !(el == undefined) then hits++
            err = f(el)
            if err then return err
        
        if arg.length > hits then return ISINVALID
        return

    return func

createObjectValidator = (obj) ->
    # Obj is Schema Obj like obj = { prop1:STRING, prop2:NUMBER,... }
    if obj == null then throw new Error("null is illegal!")
    valEntries = getValidatorEntriesForObject(obj)
    # olog valEntries
    if valEntries.length == 0 then throw new Error("{} is illegal!")
    
    func = (arg) ->
        # log "validating Object!"
        # olog arg
        # log "valEntries.length: #{valEntries.length}"
        if typeof arg != "object" then return ISINVALID
        if arg == null then return ISINVALID
        hits = 0
        for e in valEntries
            # olog e
            prop = arg[e[0]]
            if !(prop == undefined) then hits++
            err = e[1](prop)
            if err then return err
        
        keys = Object.keys(arg)
        # log "arg keys Length: #{keys.length} -> hits: #{hits}"
        if keys.length > hits then return ISINVALID
        # log "is valid!"
        return

    return func

#endregion

#endregion

############################################################
#region Type Validator Functions
typeValidatorFunctions = new Array(typeArraySize)

############################################################
#region Validator Functions For Basic Schema Types
typeValidatorFunctions[STRING] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    return

typeValidatorFunctions[STRINGEMAIL] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length > 320 or arg.length < 5 then return INVALIDSIZE
    if invalidEmailSmallRegex.test(arg) then return INVALIDEMAIL
    # if arg.indexOf("..") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("--") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("-.") >= 0 then return INVALIDEMAIL
    # if arg.indexOf(".-") >= 0 then return INVALIDEMAIL

    atPos = arg.indexOf("@")
    
    if atPos <= 0 or atPos > 64 or (arg.length - atPos) < 4 or 
    arg[0] == "." or arg[atPos - 1] == "." or arg[0] == "-" or 
    arg[atPos - 1] == "-" or arg[atPos + 1] == "." or 
    arg[atPos + 1] == "-" 
        return INVALIDEMAIL
    
    # if atPos <= 0 then return INVALIDEMAIL
    # if atPos > 64 then return INVALIDEMAIL
    # if arg[0] == "." or arg[atPos - 1] == "." then return INVALIDEMAIL
    # if arg[0] == "-" or arg[atPos - 1] == "-" then return INVALIDEMAIL
    # if arg[atPos + 1] == "." or arg[atPos + 1] == "-" then return INVALIDEMAIL
    
    for c,i in arg
        if !(domainCharMap[arg.charCodeAt(i)] or i == atPos or
            (i < atPos and (c == "+" or c == "_"))
            ) then return INVALIDEMAIL
    
    if arg[arg.length - 1] == "." or arg[arg.length - 1] == "-"
        return INVALIDEMAIL 

    lastPos = atPos
    dotPos = arg.indexOf(".", atPos + 1)
    if dotPos < 0 then return INVALIDEMAIL
    
    while (dotPos > 0)
        if (dotPos - lastPos) > 63 then return INVALIDEMAIL
        lastPos = dotPos
        dotPos = arg.indexOf(".", lastPos + 1)
    
    tld = arg.slice(lastPos + 1)
    if numericOnlyRegex.test(tld) then return INVALIDEMAIL
    return

typeValidatorFunctions[STRINGHEX] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX32] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 32 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX64] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 64 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX128] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 128 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX256] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 256 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX512] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 512 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[NUMBER] = (arg) ->
    if typeof arg != "number" then return NOTANUMBER
    if isNaN(arg) then return ISNAN 
    if arg == Infinity or arg == -Infinity then return ISNOTFINITE
    return

typeValidatorFunctions[BOOLEAN] = (arg) ->
    if typeof arg != "boolean" then return NOTABOOLEAN
    return

typeValidatorFunctions[ARRAY] = (arg) ->
    if !Array.isArray(arg) then return NOTANARRAY
    return

typeValidatorFunctions[OBJECT] = (arg) ->
    if typeof arg != "object" then return NOTANOBJECT
    return

typeValidatorFunctions[STRINGORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "string" then return NOTASTRING
    return

typeValidatorFunctions[STRINGEMAILORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "string" then return NOTASTRING
    
    if arg.length > 320 or arg.length < 5 then return INVALIDSIZE
    if invalidEmailSmallRegex.test(arg) then return INVALIDEMAIL
    # if arg.indexOf("..") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("--") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("-.") >= 0 then return INVALIDEMAIL
    # if arg.indexOf(".-") >= 0 then return INVALIDEMAIL

    atPos = arg.indexOf("@")
    
    if atPos <= 0 or atPos > 64 or (arg.length - atPos) < 4 or 
    arg[0] == "." or arg[atPos - 1] == "." or arg[0] == "-" or 
    arg[atPos - 1] == "-" or arg[atPos + 1] == "." or 
    arg[atPos + 1] == "-" 
        return INVALIDEMAIL
    
    # if atPos <= 0 then return INVALIDEMAIL
    # if atPos > 64 then return INVALIDEMAIL
    # if arg[0] == "." or arg[atPos - 1] == "." then return INVALIDEMAIL
    # if arg[0] == "-" or arg[atPos - 1] == "-" then return INVALIDEMAIL
    # if arg[atPos + 1] == "." or arg[atPos + 1] == "-" then return INVALIDEMAIL
    
    for c,i in arg 
        if !(domainCharMap[arg.charCodeAt(i)] or i == atPos or
            (i < atPos and (c == "+" or c == "_"))
            ) then return INVALIDEMAIL
    
    if arg[arg.length - 1] == "." or arg[arg.length - 1] == "-"
        return INVALIDEMAIL 

    lastPos = atPos
    dotPos = arg.indexOf(".", atPos + 1)
    if dotPos < 0 then return INVALIDEMAIL
    
    while (dotPos > 0)
        if (dotPos - lastPos) > 63 then return INVALIDEMAIL
        lastPos = dotPos
        dotPos = arg.indexOf(".", lastPos + 1)
    
    tld = arg.slice(lastPos + 1)
    if numericOnlyRegex.test(tld) then return INVALIDEMAIL
    return

typeValidatorFunctions[STRINGHEXORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX32ORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 32 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX64ORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 64 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX128ORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 128 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX256ORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 256 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX512ORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 512 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[NUMBERORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "number" then return NOTANUMBER
    if isNaN(arg) then return ISNAN 
    if arg == Infinity or arg == -Infinity then return ISNOTFINITE
    return

typeValidatorFunctions[BOOLEANORNOTHING] = (arg) ->
    return if arg == undefined 
    if typeof arg != "boolean" then return NOTABOOLEAN
    return

typeValidatorFunctions[ARRAYORNOTHING] = (arg) ->
    return if arg == undefined 
    if !Array.isArray(arg) then return NOTANARRAY
    return

typeValidatorFunctions[OBJECTORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "object" then return NOTANOBJECT
    return

typeValidatorFunctions[STRINGORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    return

typeValidatorFunctions[STRINGEMAILORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length > 320 or arg.length < 5 then return INVALIDSIZE
    if invalidEmailSmallRegex.test(arg) then return INVALIDEMAIL
    # if arg.indexOf("..") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("--") >= 0 then return INVALIDEMAIL
    # if arg.indexOf("-.") >= 0 then return INVALIDEMAIL
    # if arg.indexOf(".-") >= 0 then return INVALIDEMAIL

    atPos = arg.indexOf("@")
    
    if atPos <= 0 or atPos > 64 or (arg.length - atPos) < 4 or
    arg[0] == "." or arg[atPos - 1] == "." or arg[0] == "-" or 
    arg[atPos - 1] == "-" or arg[atPos + 1] == "." or 
    arg[atPos + 1] == "-"
        return INVALIDEMAIL
    
    # if atPos <= 0 then return INVALIDEMAIL
    # if atPos > 64 then return INVALIDEMAIL
    # if arg[0] == "." or arg[atPos - 1] == "." then return INVALIDEMAIL
    # if arg[0] == "-" or arg[atPos - 1] == "-" then return INVALIDEMAIL
    # if arg[atPos + 1] == "." or arg[atPos + 1] == "-" then return INVALIDEMAIL
    
    for c,i in arg 
        if !(domainCharMap[arg.charCodeAt(i)] or i == atPos or
            (i < atPos and (c == "+" or c == "_"))
            ) then return INVALIDEMAIL
    
    if arg[arg.length - 1] == "." or arg[arg.length - 1] == "-"
        return INVALIDEMAIL 

    lastPos = atPos
    dotPos = arg.indexOf(".", atPos + 1)
    if dotPos < 0 then return INVALIDEMAIL
    
    while (dotPos > 0)
        if (dotPos - lastPos) > 63 then return INVALIDEMAIL
        lastPos = dotPos
        dotPos = arg.indexOf(".", lastPos + 1)
    
    tld = arg.slice(lastPos + 1)
    if numericOnlyRegex.test(tld) then return INVALIDEMAIL
    return

typeValidatorFunctions[STRINGHEXORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX32ORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 32 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX64ORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 64 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX128ORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 128 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX256ORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 256 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[STRINGHEX512ORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    if arg.length != 512 then return INVALIDSIZE
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[NUMBERORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "number" then return NOTANUMBER
    if isNaN(arg) then return ISNAN 
    if arg == Infinity or arg == -Infinity then return ISNOTFINITE
    return

typeValidatorFunctions[BOOLEANORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "boolean" then return NOTABOOLEAN
    return

typeValidatorFunctions[ARRAYORNULL] = (arg) ->
    return if arg == null
    if !Array.isArray(arg) then return NOTANARRAY
    return

typeValidatorFunctions[NONNULLOBJECT] = (arg) ->
    if typeof arg != "object" then return NOTANOBJECT
    if arg == null then return ISNULL
    return

typeValidatorFunctions[NONEMPTYSTRING] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length == 0 then return ISEMPTYSTRING
    return

typeValidatorFunctions[NONEMPTYARRAY] = (arg) ->
    if !Array.isArray(arg) then return NOTANARRAY
    if arg.length == 0 then return ISEMPTYARRAY
    return

typeValidatorFunctions[NONEMPTYSTRINGHEX] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length == 0 then return ISEMPTYSTRING
    i = 0
    while i < arg.length
        if hexMap[arg.charCodeAt(i)] == undefined 
            return INVALIDHEX
        i++
    return

typeValidatorFunctions[NONEMPTYSTRINGCLEAN] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    if arg.length == 0 then return ISEMPTYSTRING
    i = 0
    while i < arg.length
        code = arg.charCodeAt(i)
        if code > 0x2ff or dirtyCharMap[code]
            return ISDIRTYSTRING
        i++
    return

typeValidatorFunctions[STRINGCLEAN] = (arg) ->
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        code = arg.charCodeAt(i)
        if code > 0x2ff or dirtyCharMap[code]
            return ISDIRTYSTRING
        i++
    return

typeValidatorFunctions[STRINGCLEANORNULL] = (arg) ->
    return if arg == null
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        code = arg.charCodeAt(i)
        if code > 0x2ff or dirtyCharMap[code]
            return ISDIRTYSTRING
        i++
    return

typeValidatorFunctions[STRINGCLEANORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "string" then return NOTASTRING
    i = 0
    while i < arg.length
        code = arg.charCodeAt(i)
        if code > 0x2ff or dirtyCharMap[code]
            return ISDIRTYSTRING
        i++
    return

typeValidatorFunctions[OBJECTCLEAN] = (arg) ->
    if typeof arg != "object" then return NOTANOBJECT
    if isDirtyObject(arg) then return ISDIRTYOBJECT
    return

typeValidatorFunctions[NONNULLOBJECTCLEAN] = (arg) ->
    if typeof arg != "object" then return NOTANOBJECT
    if arg == null then return ISNULL
    if isDirtyObject(arg) then return ISDIRTYOBJECT
    return

typeValidatorFunctions[OBJECTCLEANORNOTHING] = (arg) ->
    return if arg == undefined
    if typeof arg != "object" then return NOTANOBJECT
    if isDirtyObject(arg) then return ISDIRTYOBJECT
    return

#endregion

#endregion

############################################################
#region Error Codes and Messages
export NOTASTRING = 1000
export NOTANUMBER = 1001
export NOTABOOLEAN = 1002
export NOTANARRAY = 1003
export NOTANOBJECT = 1004

export INVALIDHEX = 1005
export INVALIDEMAIL = 1006
export INVALIDSIZE = 1007

export ISNAN = 1008
export ISNULL = 1009
export ISEMPTYSTRING = 1010
export ISEMPTYARRAY = 1011

export ISDIRTYSTRING = 1012
export ISDIRTYOBJECT = 1013
export ISNOTFINITE = 1014


export ISINVALID = 2222
# export THISERROR = 2223

############################################################
ErrorToMessage = Object.create(null)

ErrorToMessage[NOTASTRING] = "Not a String!"
ErrorToMessage[NOTANUMBER] = "Not a Number!"
ErrorToMessage[NOTABOOLEAN] = "Not a Boolean!"
ErrorToMessage[NOTANARRAY] = "Not an Array!"
ErrorToMessage[NOTANOBJECT] = "Not an Object!"
ErrorToMessage[INVALIDHEX] = "String is not valid hex!"
ErrorToMessage[INVALIDEMAIL] = "String is not a valid email!"
ErrorToMessage[INVALIDSIZE] = "String size mismatch!"
ErrorToMessage[ISNAN] = "Number is NaN!"
ErrorToMessage[ISNULL] = "Object is null!"
ErrorToMessage[ISEMPTYSTRING] = "String is empty!"
ErrorToMessage[ISEMPTYARRAY] = "Array is empty!"
ErrorToMessage[ISDIRTYSTRING] = "String is dirty!"
ErrorToMessage[ISDIRTYOBJECT] = "Object is dirty!"
ErrorToMessage[ISNOTFINITE] = "Number is not finite!"
ErrorToMessage[ISINVALID] = "Is invalid!"
# ErrorToMessage[THISERROR] = "This was the Error!"
#endregion

############################################################
#region API = exports

############################################################
## takes obj to be validated, schema and optional boolean staticStrings
##    a truthy staticStrings allows you to put static 
##    strings into your schema like: 
##    {userInpput: STRING, publicAccess: "onlywithexactlythisstring"}
## returns undefined if the obj is valid or the errorCode on invalid obj
export validate = (obj, schema, staticStrings) ->
    if staticStrings == true
        staticValidatorOrThrow = createStaticStringValidator
    else staticValidatorOrThrow = createThrower("Static string!")

    type = typeof schema

    if type == "number" then return getTypeValidator(schema)(obj)
    if type == "string" then return staticValidatorOrThrow(schema)(obj)
    if type != "object" then throw new Error("Illegal #{typeof schema}!")
    if Array.isArray(schema) then return createArrayValidator(schema)(obj)
    else return createObjectValidator(schema)(obj)

############################################################
## takes schema and optional boolean staticStrings
##    a truthy staticStrings allows you to put static 
##    strings into your schema like: 
##    {userInpput: STRING, publicAccess: "onlywithexactlythisstring"}
## returns the validator function
export createValidator = (schema, staticStrings) ->
    
    if staticStrings == true
        staticValidatorOrThrow = createStaticStringValidator
    else staticValidatorOrThrow = createThrower("Static string!")

    type = typeof schema

    if type == "number" then return getTypeValidator(schema)
    if type == "string" then return staticValidatorOrThrow(schema)
    if type != "object" then throw new Error("Illegal #{typeof schema}!")
    if Array.isArray(schema) then return createArrayValidator(schema)
    else return createObjectValidator(schema)

############################################################
## takes errorcode
## returns the associated errorMessage or ""
export getErrorMessage = (errorCode) ->
    msg = ErrorToMessage[errorCode]
    if typeof msg != "string" then return ""
    else return msg

############################################################
## takes a validatorFunction
##    this function cannot overwrite predefined types 
## returns the new enumeration number for the defined Type
export defineNewType = (validatorFunc) ->
    if locked then throw new Error("We are closed!")    
    newTypeId = typeValidatorFunctions.length
    if newTypeId >= 1000 then throw new Error("Exeeding type limit!")
    typeValidatorFunctions[newTypeId] = validatorFunc
    return newTypeId

############################################################
## takes errorCode and errorMessage
##     this function cannot overwrite predefined ErrorCodes
## returns the new errorCode for the defined Error
export defineNewError = (errorMessage) ->
    if locked then throw new Error("We are closed!")
    errorCode = Object.keys(ErrorToMessage).length + 1000
    if errorCode >= 2000 then throw new Error("Exeeding error code limit!")
    if typeof errorMessage != "string" then throw new Error("ErrorMessage not a String!")
    ErrorToMessage[errorCode] = errorMessage
    return errorCode

############################################################
## takes a type and validatorFunc
##     sets the specified functions as validator for the 
##     given type
export setTypeValidator = (type, valiatorFunc) ->
    if locked then throw new Error("We are closed!")
    if typeof type != "number" then throw new Error("type is not a Number!")
    if type >= typeValidatorFunctions.length or type < 1 
        throw new Error("Type does not exist!")
    
    if valiatorFunc?  and typeof valiatorFunc  != "function" 
        throw new Error("validatorFunc is not a Function!")

    if validatorFunction? then typeValidatorFunctions[type] = validatorFunc
    else typeValidatorFunctions[type] = () -> return

    return 

############################################################
## locks/freezes all internal maps no mutation after this!
export lock = ->
    locked = true
    Object.freeze(typeValidatorFunctions)
    Object.freeze(typeStringifierFunctions)
    Object.freeze(ErrorToMessage)
    return

#endregion

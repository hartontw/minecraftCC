local patterns = {}
patterns["wget"] = "^https?://[%w-_%.%?%.:/%+=&]+"
patterns["pastebin"] = "^[%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d]$"
patterns["hastebin"] = "^%l%l%l%l%l%l%l%l%l%l$"
patterns["ghostbin"] = "^[%a%d][%a%d][%a%d][%a%d][%a%d]$"
patterns["snippet"] = "^%d%d%d%d%d%d%d$"
patterns["gist"] = "/?([^/]+/?[%a%d]+)/?$"
patterns["gitlab"] = "gitlab%.com.+"
patterns["github"] = "github%.com.+"

local function getFilename( url )
    url = url:gsub( "[#?].*" , "" ):gsub( "/+$" , "" )
    return url:match( "/([^/]+)$" )
end

local function getUrl( sUrl, sName)
    -- Check if the URL is valid
    local ok, err = http.checkURL( sUrl )
    if not ok then 
        printError( err or "Invalid URL." )
        return
    end

    if sName then
        write( "Connecting to "..sName.."... " )
    end

    local response = http.get( sUrl , nil , true )
    if not response then 
        print( "No response." )
        return
    end

    local sResponse = response.readAll()
    response.close()
    return sResponse
end

local function writeFile(sFile, content, binary)
    local file = fs.open( sFile, binary and "wb" or "w" )
    if not file then 
        print("Error opening file.")
        return 
    end
    file.write( content )
    file.close()
    print( "Downloaded as " .. sFile )
    return true
end

function wget(sUrl, sFile)
    sFile = sFile or getFilename(sUrl)
    if not sFile then
        print("File name missing.")
        return
    end
   
    if fs.exists( sFile ) then
        print("File already exists")
        return
    end

    local res = getUrl(sUrl, sUrl:gsub("https?://w*%.?", ""))
    if not res then return end

    local file = writeFile(sFile, res, true)
    if not file then return end

    return true
end

local function extractId(paste, pattern)
    local code = paste:match(pattern)
    if code then return code end
    print("Invalid code.")
end

local function match(text, pattern)
    return text:match(pattern):gsub("\n", ""):gsub(" ", "")
end

local function getRawPaste(serviceUrl, serviceName)
    print( "Connecting to "..(serviceName or serviceUrl).."... " )
    local response, err = http.get(serviceUrl)
    if response then
        local headers = response.getResponseHeaders()        
        if not headers["Content-Type"] or not headers["Content-Type"]:find("^text/plain") then
            print("Not plain text.")
            return 1
        end

        print("Success.")

        local sResponse = response.readAll()
        response.close()
        return 0, sResponse
    else
        write("Failed: ")
        print(err)
        return 2
    end
end

function pastebin(paste, sFile)
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, patterns["pastebin"])
    if not sCode then return end

    if not sFile then
        local source = getUrl("https://pastebin.com/"..paste)
        sFile = source and source:match('<div class="paste_box_line1" title="([^"]+)') or sCode
    end

    if fs.exists( sFile ) then
        print( "File already exists" )
        return
    end

    -- Add a cache buster so that spam protection is re-checked
    local cacheBuster = ("%x"):format(math.random(0, 2^30))
    local res, response = getRawPaste("https://pastebin.com/raw/"..textutils.urlEncode(sCode).."?cb="..cacheBuster, "pastebin.com")
    if res == 1 then
        print( "Pastebin blocked the download due to spam protection. Please complete the captcha in a web browser: https://pastebin.com/"..textutils.urlEncode(sCode))
        return
    elseif not response then
        return
    end
    
    local file = writeFile(sFile, response)
    if not file then return end

    return true
end

function hastebin(paste, sFile)
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, patterns["hastebin"])
    if not sCode then return end

    sFile = sFile or sCode

    if fs.exists( sFile ) then
        print( "File already exists" )
        return
    end

    local res, response = getRawPaste("https://hastebin.com/raw/"..textutils.urlEncode(sCode), "hastebin.com")
    if not response then end

    local file = writeFile(sFile, response)
    if not file then return end

    return true
end

function ghostbin(paste, sFile)
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, patterns["ghostbin"])
    if not sCode then return end

    sFile = sFile or sCode

    if fs.exists( sFile ) then
        print( "File already exists" )
        return
    end

    local response = getUrl("https://ghostbin.co/paste/"..textutils.urlEncode(sCode).."/download", "ghostbin.co")
    if not response then end

    local file = writeFile(sFile, response, true)
    if not file then return end

    return true
end

function snippet(paste, sFile)
    local sCode = extractId(paste, patterns["snippet"])
    if not sCode then return end

    if not sFile then
        local source = getUrl("https://gitlab.com/snippets/"..sCode)
        sFile = match(source, '<strong class="file%-title%-name qa%-file%-title%-name">([^<]+)</strong>')
    end

    if fs.exists( sFile ) then
        print( "File already exists" )
        return
    end

    local res, response = getRawPaste("https://gitlab.com/snippets/"..sCode.."/raw", "gitlab.com/snippets")
    if not response then end
    
    local file = writeFile(sFile, response)
    if not file then return end

    return true  
end

function gist(paste, sFile)
    local sCode = extractId(paste, patterns["gist"])
    if not sCode then return end

    if sFile and fs.exists( sFile ) then
        print( "File already exists" )
        return
    end

    local source = getUrl("https://gist.github.com/"..sCode)

    if not sFile then
        sFile = match(source, '<strong class="user%-select%-contain gist%-blob%-name css%-truncate%-target">([^<]+)</strong>')
        if fs.exists( sFile ) then
            print( "File already exists" )
            return
        end
    end

    local user = match(source, '<meta name="octolytics%-dimension%-owner_login" content="([^"]+)" />')
    sCode = user.."/"..sCode

    local res, response = getRawPaste("https://gist.githubusercontent.com/"..sCode.."/raw", "gist.github.com")
    if not response then end
    
    local file = writeFile(sFile, response)
    if not file then return end

    return true
end

function gitlab(paste, sFile)
    local sCode = extractId(paste:gsub("/blob/", "/raw/"), patterns["gitlab"])
    if not sCode then return end

    sFile = sFile or getFilename(sCode)
    if not sFile then
        print("File name missing.")
        return
    end
   
    if fs.exists( sFile ) then
        print("File already exists")
        return
    end

    local res, response = getRawPaste("https://"..sCode, "gitlab.com")
    if not response then end

    local file = writeFile(sFile, response)
    if not file then return end

    return true
end

function github(paste, sFile)
    sFile = sFile or getFilename(paste)
    if not sFile then
        print("File name missing.")
        return
    end
   
    if fs.exists( sFile ) then
        print("File already exists")
        return
    end

    local sCode = extractId(paste, patterns["github"])
    if not sCode then return end

    sCode = sCode:gsub("github.com", "https://raw.githubusercontent.com"):gsub("blob/", "")

    local res, response = getRawPaste(sCode, "github.com")
    if not response then end

    local file = writeFile(sFile, response)
    if not file then return end

    return true
end

function auto(paste, sFile)
    local services = {"gitlab", "github", "wget", "hastebin", "snippet", "pastebin", "ghostbin", "gist"}
    for _, key in ipairs(services) do
        local sCode = paste:match(patterns[key])
        if sCode then
            return getfenv()[key](sCode, sFile)
        end
    end
    print("Unkwnown code")
end
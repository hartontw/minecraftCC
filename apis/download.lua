local services = {}

local function getUrl( sUrl, sName)
    -- Check if the URL is valid
    local ok, err = http.checkURL( sUrl )
    if not ok then 
        printError( err or "Invalid URL." )
        return
    end

    write( "Connecting to "..(sName or sUrl).."... " )

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
    local getFilename = function( url )
        url = url:gsub( "[#?].*" , "" ):gsub( "/+$" , "" )
        return url:match( "/([^/]+)$" )
    end

    sFile = sFile or getFilename(sUrl)
    if not sFile then
        print("File name missing.")
        return
    end
   
    if fs.exists( sFile ) then
        print("File already exists")
        return
    end

    local res = getUrl(sUrl)
    if not res then return end

    local file = writeFile(sFile, res, true)
    if not file then return end

    return true
end

local function extractId(paste, patterns)
    for i = 1, #patterns do
        local code = paste:match(patterns[i])
        if code then return code end
    end
    print("Invalid code.")
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
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, services.pastebin.patterns)
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
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, services.pastebin.patterns)
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
    local sCode = paste:match("^([%a%d]+)$") or extractId(paste, service.ghostbin.patterns)
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

function githubgist(paste, sFile)

end

function auto(paste, sFile)
    for name, service in pairs(services) do
        for i, pattern in ipairs(service.patterns) do
            local sCode = paste:match(pattern)
            if sCode then
                return service.method(sCode, sFile)
            end
        end
    end
    return wget(paste, sFile)
end

services["pastebin"] = {
    method=pastebin,
    patterns={"^[%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d]$", "pastebin.com/([%a%d]+)$", "pastebin.com/raw/([%a%d]+)$"}
}
services["hastebin"] = {
    method=hastebin,
    patterns={"^%l%l%l%l%l%l%l%l%l%l$", "hastebin.com/(%l+)", "hastebin.com/raw/(%l+)"}
}
services["ghostbin"] = {
    method=ghostbin,
    patterns={"^[%a%d][%a%d][%a%d][%a%d][%a%d]$", "ghostbin.co/paste/([%a%d]+)/?$", "ghostbin.co/paste/([%a%d]+)/download/?$", "ghostbin.co/([%a%d]+)/?$", "ghostbin.co/paste/([%a%d]+)/raw/?$"}
}
services["githubgist"] = {
    method=githubgist,
    patterns={"[^/]+/?[^/]+/?$", "gist.github.com/[^/]/[^/]/?$"}
}
function RC4(key, text)
    -- RC4
    -- @zhuangzebo
    -- https://github.com/zebozhuang/RC4
    
    local KSA = function(key)
        local key_len = string.len(key)
        local S = {}
        local key_byte = {}
    
        for i = 0, 255 do
            S[i] = i
        end
    
        for i = 1, key_len do
            key_byte[i-1] = string.byte(key, i, i)
        end
    
        local j = 0
        for i = 0, 255 do
            j = (j + S[i] + key_byte[i % key_len]) % 256
            S[i], S[j] = S[j], S[i]
        end
        return S
    end
    
    local PRGA = function(S, text_len)
        local i = 0
        local j = 0
        local K = {}
    
        for n = 1, text_len do
    
            i = (i + 1) % 256
            j = (j + S[i]) % 256
    
            S[i], S[j] = S[j], S[i]
            K[n] = S[(S[i] + S[j]) % 256]
        end
        return K
    end
    
    local output = function(S, text)
        local len = string.len(text)
        local c = nil
        local res = {}
        for i = 1, len do
            c = string.byte(text, i, i)
            res[i] = string.char(bit.bxor(S[i], c))
        end
        return table.concat(res)
    end
    
    return output(PRGA(KSA(key), string.len(text)), text)
end

function AES(key, text)

end
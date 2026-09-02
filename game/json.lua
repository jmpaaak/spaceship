-- Minimal, dependency-free JSON decoder used to load gear data
-- (docs/feedback/INBOX.md item 13: "부품 데이터를 별도 config로 외부화").
-- LOVE ships no JSON module, and pulling in a third-party library would
-- violate the "no external dependency" simplicity of this repo, so this
-- is a small hand-rolled recursive-descent decoder. It intentionally only
-- supports the subset of JSON the gear data files need (objects, arrays,
-- strings, numbers, booleans, null) — no encoder, no comments, no NaN/Inf.
local M = {}

local function skipWhitespace(s, i)
    local _, stop = s:find("^[ \t\r\n]*", i)
    return stop + 1
end

local decodeValue

local function decodeError(s, i, message)
    error(string.format("json: %s at position %d near '%s'", message, i, s:sub(i, i + 20)))
end

local function decodeString(s, i)
    -- s:sub(i,i) is the opening quote.
    local j = i + 1
    local out = {}
    while true do
        local c = s:sub(j, j)
        if c == "" then
            decodeError(s, j, "unterminated string")
        elseif c == '"' then
            return table.concat(out), j + 1
        elseif c == "\\" then
            local esc = s:sub(j + 1, j + 1)
            local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
            if map[esc] then
                out[#out + 1] = map[esc]
                j = j + 2
            elseif esc == "u" then
                local hex = s:sub(j + 2, j + 5)
                local code = tonumber(hex, 16)
                if not code then decodeError(s, j, "invalid \\u escape") end
                -- Only handle the common BMP/ASCII range used by our data
                -- (gear names/icons don't need surrogate pairs).
                if code < 0x80 then
                    out[#out + 1] = string.char(code)
                else
                    out[#out + 1] = utf8 and utf8.char(code) or "?"
                end
                j = j + 6
            else
                decodeError(s, j, "invalid escape")
            end
        else
            out[#out + 1] = c
            j = j + 1
        end
    end
end

local function decodeNumber(s, i)
    local _, stop, numStr = s:find("^(%-?%d+%.?%d*[eE]?[%+%-]?%d*)", i)
    if not stop then decodeError(s, i, "invalid number") end
    local value = tonumber(numStr)
    if not value then decodeError(s, i, "invalid number") end
    return value, stop + 1
end

local function decodeArray(s, i)
    local out = {}
    i = skipWhitespace(s, i + 1)
    if s:sub(i, i) == "]" then return out, i + 1 end
    while true do
        local value
        value, i = decodeValue(s, i)
        out[#out + 1] = value
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = skipWhitespace(s, i + 1)
        elseif c == "]" then
            return out, i + 1
        else
            decodeError(s, i, "expected ',' or ']'")
        end
    end
end

local function decodeObject(s, i)
    local out = {}
    i = skipWhitespace(s, i + 1)
    if s:sub(i, i) == "}" then return out, i + 1 end
    while true do
        if s:sub(i, i) ~= '"' then decodeError(s, i, "expected string key") end
        local key
        key, i = decodeString(s, i)
        i = skipWhitespace(s, i)
        if s:sub(i, i) ~= ":" then decodeError(s, i, "expected ':'") end
        i = skipWhitespace(s, i + 1)
        local value
        value, i = decodeValue(s, i)
        out[key] = value
        i = skipWhitespace(s, i)
        local c = s:sub(i, i)
        if c == "," then
            i = skipWhitespace(s, i + 1)
        elseif c == "}" then
            return out, i + 1
        else
            decodeError(s, i, "expected ',' or '}'")
        end
    end
end

decodeValue = function(s, i)
    i = skipWhitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then
        return decodeString(s, i)
    elseif c == "{" then
        return decodeObject(s, i)
    elseif c == "[" then
        return decodeArray(s, i)
    elseif c == "t" and s:sub(i, i + 3) == "true" then
        return true, i + 4
    elseif c == "f" and s:sub(i, i + 4) == "false" then
        return false, i + 5
    elseif c == "n" and s:sub(i, i + 3) == "null" then
        return nil, i + 4
    elseif c:match("[%-%d]") then
        return decodeNumber(s, i)
    else
        decodeError(s, i, "unexpected character")
    end
end

-- M.decode(str) -> value. Raises a Lua error (use pcall) on malformed JSON.
function M.decode(s)
    if type(s) ~= "string" then error("json.decode expects a string") end
    local i = skipWhitespace(s, 1)
    if i > #s then decodeError(s, i, "empty input") end
    local value, stop = decodeValue(s, i)
    stop = skipWhitespace(s, stop)
    if stop <= #s then decodeError(s, stop, "trailing data after JSON value") end
    return value
end

return M

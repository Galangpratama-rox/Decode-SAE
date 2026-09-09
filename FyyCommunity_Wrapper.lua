--[[
================================================================================
  FYY COMMUNITY — BYPASS WRAPPER
  File  : FyyCommunity_Wrapper.lua
  Repo  : https://github.com/Galangpratama-rox/Decode-SAE

  CARA PAKAI (simpan ini di auto-execute executor):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/FyyCommunity_Wrapper.lua"))()

  HOW IT WORKS:
    1. Wrapper ini hook fungsi 'request' di executor SEBELUM script asli jalan
    2. Semua request ke fyycommunity.com di-intercept → return fake response
    3. Script asli didownload dari CDN FyyCommunity (selalu versi terbaru)
    4. Script asli dijalankan — bypass sudah aktif → keyless otomatis
    5. Saat rejoin/hop server, wrapper ini auto-execute lagi → bypass aktif lagi
================================================================================
--]]

-- ============================================================
-- BAGIAN 1: SETUP FAKE RESPONSE
-- ============================================================
local ge = (getgenv and getgenv()) or _G
local hs_ok, hs = pcall(function() return game:GetService("HttpService") end)

local function jsonEncode(t)
    if hs_ok and hs then
        local ok, r = pcall(function() return hs:JSONEncode(t) end)
        if ok then return r end
    end
    -- fallback manual JSON
    local function enc(v)
        local tv = type(v)
        if tv == "string" then return '"' .. v:gsub('"', '\\"') .. '"'
        elseif tv == "number" then return tostring(v)
        elseif tv == "boolean" then return tostring(v)
        elseif tv == "table" then
            local parts = {}
            for k, val in pairs(v) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. enc(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return "null"
    end
    return enc(t)
end

local function makeResp(body_table)
    return { StatusCode = 200, Status = 200, Body = jsonEncode(body_table) }
end

local function fakeResponse(url)
    local u = tostring(url or ""):lower()
    local sid  = "bypass-" .. tostring(math.random(1000000, 9999999))
    local stok = "bypass-tok-" .. tostring(math.random(1000000, 9999999))
    local chal = string.rep("61", 32)
    local cid  = "bypass-chal-" .. tostring(math.random(100000, 999999))

    -- /api/v1/loader/access-mode → keyless (public_maintenance)
    if u:find("access%-mode") or u:find("loader/access") then
        return makeResp({ status = "ok", data = { mode = "public_maintenance" } })
    end
    -- /api/v1/check/challenge
    if u:find("check/challenge") then
        return makeResp({ status = "ok", transportKey = chal, challengeId = cid })
    end
    -- /api/v1/check/maintenance
    if u:find("check/maintenance") then
        return makeResp({
            status = "ok",
            session = {
                sessionId            = sid,
                sessionToken         = stok,
                nextHeartbeatSeconds = 999999,
                accessTier           = "premium",
                licenseType          = "premium",
            },
            continuityCredential = "bypass-continuity",
            accessTier           = "premium",
            licenseType          = "premium",
        })
    end
    -- /api/v1/check/heartbeat
    if u:find("heartbeat") then
        return makeResp({ status = "ok", state = "active" })
    end
    -- /api/v1/check (generic license validate)
    if u:find("/api/v1/check") then
        return makeResp({
            status = "ok",
            session = {
                sessionId            = sid,
                sessionToken         = stok,
                nextHeartbeatSeconds = 999999,
                accessTier           = "premium",
                licenseType          = "premium",
            },
            continuityCredential = "bypass-continuity",
        })
    end
    -- endpoint lain dari fyycommunity → ok generic
    return makeResp({ status = "ok" })
end

-- ============================================================
-- BAGIAN 2: BUAT fakeReq (wrapper request yang intercept)
-- ============================================================
-- Simpan referensi ke request asli untuk non-fyycommunity calls
local origRequest = rawget(ge, "request")
    or rawget(ge, "http_request")
    or rawget(ge, "httprequest")
    or nil

local function fakeReq(opts)
    local url = ""
    if type(opts) == "table" then
        url = tostring(opts.Url or opts.url or "")
    else
        url = tostring(opts or "")
    end

    -- Intercept hanya fyycommunity.com
    if url:find("fyycommunity%.com") or url:find("104%-20") then
        warn("[FyyWrapper] Intercepted: " .. url)
        return fakeResponse(url)
    end

    -- Non-fyycommunity: pakai request asli
    if type(origRequest) == "function" then
        return origRequest(opts)
    end
    -- Fallback: game:HttpGet untuk GET request
    if type(opts) == "table" and (not opts.Method or opts.Method == "GET") then
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and body then
            return { StatusCode = 200, Status = 200, Body = body }
        end
    end
    return { StatusCode = 0, Status = 0, Body = "" }
end

-- ============================================================
-- BAGIAN 3: INJECT fakeReq ke semua env paths
-- ============================================================
-- rawset ke getgenv()
rawset(ge, "__FyyFakeReq", fakeReq)
rawset(ge, "request", fakeReq)
if rawget(ge, "http_request")  then rawset(ge, "http_request",  fakeReq) end
if rawget(ge, "httprequest")   then rawset(ge, "httprequest",   fakeReq) end

-- hookfunction: intercept di level object fungsi (Synapse/Wave/Delta support)
if type(hookfunction) == "function" then
    if type(origRequest) == "function" then
        pcall(function() hookfunction(origRequest, fakeReq) end)
        warn("[FyyWrapper] hookfunction applied to original request")
    end
end

-- syn.request
pcall(function()
    local syn = rawget(ge, "syn")
    if type(syn) == "table" and type(rawget(syn, "request")) == "function" then
        if type(hookfunction) == "function" then
            hookfunction(rawget(syn, "request"), fakeReq)
        else
            syn.request = fakeReq
        end
    end
end)

-- Persistent __newindex: cegah siapapun override request setelah ini
pcall(function()
    if type(getrawmetatable) ~= "function" then return end
    local mt = getrawmetatable(ge)
    if not mt then return end
    local origNI = rawget(mt, "__newindex")
    local function blockOverride(t, k, v)
        if k == "request" or k == "http_request" or k == "httprequest" then
            local cur = rawget((getgenv and getgenv()) or _G, "__FyyFakeReq")
            if cur and v ~= cur then
                rawset(t, k, cur)
                warn("[FyyWrapper] Blocked override of: " .. tostring(k))
                return
            end
        end
        if type(origNI) == "function" then return origNI(t, k, v) end
        rawset(t, k, v)
    end
    if type(setrawmetatable) == "function" then
        rawset(mt, "__newindex", blockOverride)
        warn("[FyyWrapper] Persistent __newindex hook aktif")
    end
end)

-- Simpan key file dengan format valid (FYY- prefix)
pcall(function()
    local wf  = rawget(ge, "writefile")  or rawget(ge, "writeFile")
    local mf  = rawget(ge, "makefolder") or rawget(ge, "makeFolder")
    local isf = rawget(ge, "isfolder")   or rawget(ge, "isFolder")
    if wf then
        if mf then
            pcall(function()
                if not (isf and isf("FyyCommunity")) then mf("FyyCommunity") end
            end)
        end
        pcall(wf, "FyyCommunity/license.key", "FYY-BYPASS-KEYLESS")
    end
end)

warn("[FyyWrapper] Bypass aktif — siap jalankan script asli")

-- ============================================================
-- BAGIAN 4: DOWNLOAD DAN JALANKAN SCRIPT ASLI (VERSI TERBARU)
-- ============================================================
-- Script asli selalu diambil dari CDN FyyCommunity
-- Setiap update dari mereka langsung ter-apply otomatis
local FYY_CDN_URL = "https://FyyCommunity.com"

local ok, result = pcall(function()
    warn("[FyyWrapper] Downloading script asli dari: " .. FYY_CDN_URL)
    local src = game:HttpGet(FYY_CDN_URL, true)
    if not src or #src < 100 then
        error("Download gagal atau konten terlalu pendek: " .. tostring(#(src or "")))
    end
    warn("[FyyWrapper] Download sukses (" .. #src .. " bytes) — menjalankan...")
    loadstring(src)()
end)

if not ok then
    warn("[FyyWrapper] ERROR: " .. tostring(result))
    -- Notifikasi error ke player
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "FyyWrapper ❌",
            Text     = "Gagal load script asli. Cek console.",
            Duration = 8,
        })
    end)
end

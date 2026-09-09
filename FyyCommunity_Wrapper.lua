--[[
================================================================================
  FYY COMMUNITY — BYPASS WRAPPER
  File  : FyyCommunity_Wrapper.lua
  Repo  : https://github.com/Galangpratama-rox/Decode-SAE

  CARA PAKAI (simpan di auto-execute executor):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/FyyCommunity_Wrapper.lua"))()

  HOW IT WORKS:
    1. Tunggu game fully loaded (cegah crash saat rejoin)
    2. Hook request sebelum script asli jalan
    3. Download script asli dari FyyCommunity CDN (selalu versi terbaru)
    4. Jalankan — bypass aktif → keyless otomatis
================================================================================
--]]

-- ============================================================
-- BAGIAN 0: TUNGGU GAME LOADED (anti-crash saat rejoin)
-- ============================================================
local function waitForGame()
    -- Tunggu sampai karakter spawn dan game tidak loading
    local ok = pcall(function()
        if not game:IsLoaded() then
            game.Loaded:Wait()
        end
    end)
    -- Extra delay untuk pastikan semua service ready
    task.wait(2)
    -- Tunggu LocalPlayer ready
    pcall(function()
        local Players = game:GetService("Players")
        if not Players.LocalPlayer then
            Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        end
        -- Tunggu karakter
        local lp = Players.LocalPlayer
        if lp and not lp.Character then
            lp.CharacterAdded:Wait()
        end
    end)
    task.wait(1)
end

waitForGame()
warn("[FyyWrapper] Game loaded — memulai bypass...")

-- ============================================================
-- BAGIAN 1: SETUP FAKE RESPONSE
-- ============================================================
local ge = (getgenv and getgenv()) or _G
local hs_ok, hs = pcall(function() return game:GetService("HttpService") end)

local function jsonEncode(t)
    if hs_ok and hs then
        local ok, r = pcall(function() return hs:JSONEncode(t) end)
        if ok and r then return r end
    end
    local function enc(v)
        local tv = type(v)
        if tv == "string"  then return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
        elseif tv == "number"  then return tostring(v)
        elseif tv == "boolean" then return tostring(v)
        elseif tv == "table"   then
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

    -- /api/v1/loader/access-mode → keyless
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
    -- /api/v1/check (generic)
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
    -- Semua endpoint fyycommunity lainnya
    return makeResp({ status = "ok" })
end

-- ============================================================
-- BAGIAN 2: BUAT fakeReq
-- ============================================================
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

    if url:find("fyycommunity%.com") or url:find("104%-20") then
        warn("[FyyWrapper] Intercepted: " .. url)
        return fakeResponse(url)
    end

    if type(origRequest) == "function" then
        return origRequest(opts)
    end
    if type(opts) == "table" and (not opts.Method or opts.Method == "GET") then
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok and body then return { StatusCode = 200, Status = 200, Body = body } end
    end
    return { StatusCode = 0, Status = 0, Body = "" }
end

-- ============================================================
-- BAGIAN 3: INJECT fakeReq
-- ============================================================
rawset(ge, "__FyyFakeReq", fakeReq)
rawset(ge, "request",      fakeReq)
if rawget(ge, "http_request") then rawset(ge, "http_request",  fakeReq) end
if rawget(ge, "httprequest")  then rawset(ge, "httprequest",   fakeReq) end

-- hookfunction: dibungkus pcall ketat agar tidak crash executor
pcall(function()
    if type(hookfunction) ~= "function" then return end
    if type(origRequest) == "function" and origRequest ~= fakeReq then
        local hok, herr = pcall(hookfunction, origRequest, fakeReq)
        if hok then
            warn("[FyyWrapper] hookfunction OK")
        else
            warn("[FyyWrapper] hookfunction skip: " .. tostring(herr))
        end
    end
end)

-- syn.request
pcall(function()
    local syn = rawget(ge, "syn")
    if type(syn) ~= "table" then return end
    local sr = rawget(syn, "request")
    if type(sr) ~= "function" then return end
    if type(hookfunction) == "function" then
        pcall(hookfunction, sr, fakeReq)
    else
        rawset(syn, "request", fakeReq)
    end
end)

-- Persistent __newindex
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
                warn("[FyyWrapper] Override blocked: " .. tostring(k))
                return
            end
        end
        if type(origNI) == "function" then return origNI(t, k, v) end
        rawset(t, k, v)
    end
    if type(setrawmetatable) == "function" then
        pcall(function() rawset(mt, "__newindex", blockOverride) end)
        warn("[FyyWrapper] __newindex hook aktif")
    end
end)

-- Simpan key file dengan prefix FYY- (format valid)
pcall(function()
    local wf  = rawget(ge, "writefile")  or rawget(ge, "writeFile")
    local mf  = rawget(ge, "makefolder") or rawget(ge, "makeFolder")
    local isf = rawget(ge, "isfolder")   or rawget(ge, "isFolder")
    if not wf then return end
    pcall(function()
        if mf and not (isf and isf("FyyCommunity")) then mf("FyyCommunity") end
    end)
    pcall(wf, "FyyCommunity/license.key", "FYY-BYPASS-KEYLESS")
end)

warn("[FyyWrapper] Semua bypass aktif — mendownload script asli...")

-- ============================================================
-- BAGIAN 4: DOWNLOAD DAN JALANKAN SCRIPT ASLI
-- ============================================================
local FYY_CDN_URL = "https://FyyCommunity.com"

-- Retry logic: coba max 3x kalau download gagal
local src = nil
local downloadErr = nil
for attempt = 1, 3 do
    local ok, result = pcall(function()
        return game:HttpGet(FYY_CDN_URL, true)
    end)
    if ok and result and #result > 100 then
        src = result
        warn("[FyyWrapper] Download sukses attempt " .. attempt .. " (" .. #src .. " bytes)")
        break
    else
        downloadErr = tostring(result)
        warn("[FyyWrapper] Download attempt " .. attempt .. " gagal: " .. downloadErr)
        if attempt < 3 then task.wait(2) end
    end
end

if not src then
    warn("[FyyWrapper] Semua download attempt gagal: " .. tostring(downloadErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "FyyWrapper ❌",
            Text     = "Gagal download script. Cek koneksi.",
            Duration = 8,
        })
    end)
    return
end

-- Jalankan script asli dalam pcall agar error tidak crash executor
local runOk, runErr = pcall(function()
    loadstring(src)()
end)

if not runOk then
    warn("[FyyWrapper] Script asli error: " .. tostring(runErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "FyyWrapper ⚠️",
            Text     = "Script error — lihat console.",
            Duration = 6,
        })
    end)
end

--[[
================================================================================
  FYY COMMUNITY — BYPASS WRAPPER
  File  : FyyCommunity_Wrapper.lua
  Repo  : https://github.com/Galangpratama-rox/Decode-SAE

  CARA PAKAI (simpan di auto-execute executor):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/FyyCommunity_Wrapper.lua"))()
================================================================================
--]]

-- ============================================================
-- BAGIAN 0: TUNGGU GAME LOADED (anti-crash saat rejoin)
-- ============================================================
pcall(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
end)
task.wait(2)
pcall(function()
    local lp = game:GetService("Players").LocalPlayer
    if lp and not lp.Character then lp.CharacterAdded:Wait() end
end)
task.wait(0.5)
warn("[FyyWrapper] Game loaded — memulai bypass...")

-- ============================================================
-- BAGIAN 1: JSON ENCODER
-- ============================================================
local ge = (getgenv and getgenv()) or _G
local _hs
pcall(function() _hs = game:GetService("HttpService") end)

local function J(t)
    if _hs then
        local ok, r = pcall(function() return _hs:JSONEncode(t) end)
        if ok and r then return r end
    end
    local function enc(v)
        local tv = type(v)
        if tv == "string"  then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"')..'"'
        elseif tv == "number"  then return tostring(v)
        elseif tv == "boolean" then return tostring(v)
        elseif tv == "table"   then
            local p={}
            for k,val in pairs(v) do
                table.insert(p,'"'..tostring(k)..'":'..enc(val))
            end
            return "{"..table.concat(p,",").."}"
        end
        return "null"
    end
    return enc(t)
end

local function R(body)
    return {StatusCode=200, Status=200, Body=J(body)}
end

-- ============================================================
-- BAGIAN 2: FAKE RESPONSE PER ENDPOINT
-- ============================================================
local function fakeResponse(url, opts, origFn)
    local u = tostring(url or ""):lower()
    local sid  = "bp-"..tostring(math.random(1e6,9e6))
    local stok = "bt-"..tostring(math.random(1e6,9e6))
    local sess = {
        sessionId=sid, sessionToken=stok,
        nextHeartbeatSeconds=999999,
        accessTier="premium", licenseType="premium"
    }

    if u:find("access%-mode") or u:find("loader/access") then
        return R({status="ok", data={mode="public_maintenance"}})
    end
    if u:find("check/challenge") then
        return R({status="ok", transportKey=string.rep("61",32),
                  challengeId="bp-chal-"..tostring(math.random(1e5,9e5))})
    end
    if u:find("check/maintenance") then
        return R({status="ok", session=sess,
                  continuityCredential="bypass-continuity",
                  accessTier="premium", licenseType="premium"})
    end
    if u:find("heartbeat") then
        return R({status="ok", state="active"})
    end
    if u:find("/api/v1/check") then
        return R({status="ok", session=sess, continuityCredential="bypass-continuity"})
    end

    -- runtime/resolve: response-nya adalah script Lua langsung (bukan JSON)
    -- Harus pakai request asli agar runtime berhasil didownload dari CDN
    if u:find("runtime/resolve") or u:find("script%-distribution") then
        warn("[FyyWrapper] Letting runtime/resolve through to real CDN...")
        if type(origFn)=="function" then
            local ok, res = pcall(origFn, opts)
            if ok then return res end
        end
        -- Fallback: coba HttpGet langsung ke CDN
        return nil
    end

    return R({status="ok"})
end

-- ============================================================
-- BAGIAN 3: BUAT fakeReq & INJECT — TANPA hookfunction/getrawmetatable
-- (kedua fungsi itu penyebab crash di beberapa executor)
-- ============================================================
local origReq = rawget(ge,"request") or rawget(ge,"http_request")
             or rawget(ge,"httprequest") or nil

local function fakeReq(opts)
    local url = type(opts)=="table" and tostring(opts.Url or opts.url or "") or tostring(opts or "")
    if url:find("fyycommunity%.com") or url:find("104%-20") then
        warn("[FyyWrapper] Intercepted: "..url)
        local resp = fakeResponse(url, opts, origReq)
        if resp ~= nil then return resp end
        -- resp==nil berarti endpoint ini harus diteruskan ke CDN asli
    end
    -- Non-fyycommunity ATAU runtime/resolve yang perlu CDN asli
    if type(origReq)=="function" then return origReq(opts) end
    -- Fallback GET via game:HttpGet
    if type(opts)~="table" or not opts.Method or opts.Method=="GET" then
        local ok,body = pcall(function() return game:HttpGet(url,true) end)
        if ok and body then return {StatusCode=200,Status=200,Body=body} end
    end
    return {StatusCode=0,Status=0,Body=""}
end

-- Inject via rawset ke getgenv() — cara paling aman
rawset(ge, "__FyyFakeReq", fakeReq)
rawset(ge, "request",      fakeReq)
if rawget(ge,"http_request") ~= nil then rawset(ge,"http_request", fakeReq) end
if rawget(ge,"httprequest")  ~= nil then rawset(ge,"httprequest",  fakeReq) end

-- syn.request — rawset saja, tanpa hookfunction
pcall(function()
    local syn = rawget(ge,"syn")
    if type(syn)=="table" then rawset(syn,"request",fakeReq) end
end)

-- fluxus.request
pcall(function()
    local fl = rawget(ge,"fluxus")
    if type(fl)=="table" then rawset(fl,"request",fakeReq) end
end)

-- Simpan key file (prefix FYY- agar format valid di payload)
pcall(function()
    local wf  = rawget(ge,"writefile")  or rawget(ge,"writeFile")
    local mf  = rawget(ge,"makefolder") or rawget(ge,"makeFolder")
    local isf = rawget(ge,"isfolder")   or rawget(ge,"isFolder")
    if not wf then return end
    pcall(function()
        if mf and not(isf and isf("FyyCommunity")) then mf("FyyCommunity") end
    end)
    pcall(wf,"FyyCommunity/license.key","FYY-BYPASS-KEYLESS")
end)

warn("[FyyWrapper] Bypass aktif — download script asli...")

-- ============================================================
-- BAGIAN 4: DOWNLOAD & JALANKAN SCRIPT ASLI (versi terbaru)
-- ============================================================
local FYY_URL = "https://FyyCommunity.com"
local src, dlErr

for i = 1, 3 do
    local ok, res = pcall(function() return game:HttpGet(FYY_URL, true) end)
    if ok and type(res)=="string" and #res > 100 then
        src = res
        warn("[FyyWrapper] Download OK attempt "..i.." ("..#src.." bytes)")
        break
    end
    dlErr = tostring(res)
    warn("[FyyWrapper] Attempt "..i.." gagal: "..dlErr)
    if i < 3 then task.wait(2) end
end

if not src then
    warn("[FyyWrapper] Download gagal semua attempt.")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification",{
            Title="FyyWrapper ❌", Text="Gagal download. Cek koneksi.", Duration=8
        })
    end)
    return
end

local runOk, runErr = pcall(loadstring(src))
if not runOk then
    warn("[FyyWrapper] Script error: "..tostring(runErr))
end

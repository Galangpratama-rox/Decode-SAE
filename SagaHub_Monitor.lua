--[[
================================================================================
  SAGAHUB MONITOR
  File  : SagaHub_Monitor.lua
  Repo  : https://github.com/Galangpratama-rox/Decode-SAE

  CARA PAKAI:
    Jalankan setelah SagaHub_OneFile sudah load (tunggu ~5 detik):

    task.wait(5)
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/SagaHub_Monitor.lua"))()

    Atau tambahkan di auto-execute setelah SagaHub:
    loadstring(game:HttpGet("...SagaHub_OneFile.lua"))()
    task.wait(6)
    loadstring(game:HttpGet("...SagaHub_Monitor.lua"))()

  CONFIG:
    Ganti MONITOR_ENDPOINT dengan URL website kamu.
    Format POST JSON, cocok untuk Express/FastAPI/Flask endpoint.
================================================================================
--]]

-- ============================================================
-- CONFIG — ganti ini dengan URL website kamu
-- ============================================================
local MONITOR_ENDPOINT = "https://backend-monitoring-sae-production-a7b9.up.railway.app/api/monitor"
local MONITOR_INTERVAL = 30  -- kirim data setiap N detik
local MONITOR_KEY      = "sagahub-secret-key"  -- harus sama dengan MONITOR_KEY di .env

-- ============================================================
-- SETUP
-- ============================================================
local ge       = getgenv and getgenv() or _G
local Players  = game:GetService("Players")
local lp       = Players.LocalPlayer
local hs       = game:GetService("HttpService")
local rs       = game:GetService("RunService")

if not lp then
    warn("[SagaMonitor] LocalPlayer tidak ada, abort")
    return
end

-- Cek apakah SagaHub sudah load
local handoff = rawget(ge, "__FYY_ACCESS_HANDOFF")
    or _G["__FYY_ACCESS_HANDOFF"]
    or (type(shared) == "table" and shared["__FYY_ACCESS_HANDOFF"])

-- Ambil request function — pakai HttpService:RequestAsync langsung
-- Ini TIDAK bisa di-intercept oleh fakeReq karena bukan dari getgenv()
local function doRequest(url, method, headers, body)
    local hs2 = game:GetService("HttpService")
    -- Coba HttpService:RequestAsync (tidak semua executor support)
    local ok1, res1 = pcall(function()
        return hs2:RequestAsync({
            Url     = url,
            Method  = method or "POST",
            Headers = headers or {},
            Body    = body or "",
        })
    end)
    if ok1 and res1 and (res1.StatusCode or 0) > 0 then
        return res1
    end

    -- Fallback: cari request function yang bukan fakeReq
    local ge2 = (getgenv and getgenv()) or _G
    local fakeRef = rawget(ge2, "__FyyFakeReq")
    local reqFns = {
        rawget(ge2, "__FyyTrueRequest"),
        rawget(ge2, "__FyyOrigRequest"),
    }
    -- Cek semua nama request
    for _, name in ipairs({"request","http_request","httprequest","syn"}) do
        local fn = rawget(ge2, name)
        if type(fn) == "function" and fn ~= fakeRef then
            table.insert(reqFns, fn)
        elseif type(fn) == "table" and type(rawget(fn, "request")) == "function" then
            table.insert(reqFns, rawget(fn, "request"))
        end
    end

    for _, fn in ipairs(reqFns) do
        if type(fn) == "function" and fn ~= fakeRef then
            local ok2, res2 = pcall(fn, {
                Url     = url,
                Method  = method or "POST",
                Headers = headers or {},
                Body    = body or "",
            })
            if ok2 and res2 and type(res2) == "table" and (res2.StatusCode or 0) > 0 then
                return res2
            end
        end
    end

    return nil
end

warn("[SagaMonitor] Request method siap")

-- ============================================================
-- DATA COLLECTOR — kumpulkan semua info dari game
-- ============================================================
local function getPlayerStats()
    local stats = {}
    pcall(function()
        local char = lp.Character
        -- Basic player info
        stats.username    = lp.Name
        stats.displayName = lp.DisplayName
        stats.userId      = lp.UserId
        stats.placeId     = game.PlaceId
        stats.jobId       = game.JobId
        stats.serverTime  = os.time()

        -- Ping / latency (kalau tersedia)
        pcall(function()
            stats.ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value)
        end)

        -- Player count di server ini
        stats.playerCount = #Players:GetPlayers()

        -- Leaderboard / stats dari ReplicatedStorage atau leaderstats
        pcall(function()
            local ls = lp:FindFirstChild("leaderstats")
            if ls then
                stats.leaderstats = {}
                for _, v in ipairs(ls:GetChildren()) do
                    stats.leaderstats[v.Name] = tostring(v.Value)
                end
            end
        end)

        -- SAE specific: coba ambil dari DataModel atau PlayerData
        pcall(function()
            local rs_game = game:GetService("ReplicatedStorage")
            -- Steal An Egg biasanya punya PlayerData di ReplicatedStorage
            local pdata = rs_game:FindFirstChild("PlayerData")
                       or rs_game:FindFirstChild("Data")
                       or rs_game:FindFirstChild("GameData")
            if pdata then
                local mydata = pdata:FindFirstChild(tostring(lp.UserId))
                           or pdata:FindFirstChild(lp.Name)
                if mydata then
                    stats.gameData = {}
                    for _, v in ipairs(mydata:GetDescendants()) do
                        if v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("StringValue") or v:IsA("BoolValue") then
                            stats.gameData[v.Name] = tostring(v.Value)
                        end
                    end
                end
            end
        end)

        -- Egg count dari leaderstats (SAE specific)
        pcall(function()
            local ls = lp:FindFirstChild("leaderstats")
            if ls then
                local eggs = ls:FindFirstChild("Eggs") or ls:FindFirstChild("EggCount") or ls:FindFirstChild("Hatched")
                local pets  = ls:FindFirstChild("Pets") or ls:FindFirstChild("PetCount")
                local coins = ls:FindFirstChild("Coins") or ls:FindFirstChild("Gold") or ls:FindFirstChild("Currency")
                if eggs  then stats.eggs  = tonumber(eggs.Value)  end
                if pets  then stats.pets  = tonumber(pets.Value)  end
                if coins then stats.coins = tonumber(coins.Value) end
            end
        end)

        -- SagaHub runtime stats (dari __FYY_ACCESS_HANDOFF session)
        pcall(function()
            if handoff and type(handoff.session) == "table" then
                stats.session = {
                    sessionId  = handoff.session.sessionId,
                    accessTier = handoff.session.accessTier,
                }
            end
        end)

        -- Character position
        pcall(function()
            local char2 = lp.Character
            if char2 then
                local hrp = char2:FindFirstChild("HumanoidRootPart")
                if hrp then
                    stats.position = {
                        x = math.floor(hrp.Position.X),
                        y = math.floor(hrp.Position.Y),
                        z = math.floor(hrp.Position.Z),
                    }
                end
            end
        end)
    end)
    return stats
end

-- ============================================================
-- SEND — kirim data ke endpoint monitoring
-- ============================================================
local function sendMonitorData()
    local data = getPlayerStats()
    data._key  = MONITOR_KEY
    data._type = "monitor"
    data._ts   = os.time()

    local ok, encoded = pcall(function()
        return hs:JSONEncode(data)
    end)
    if not ok or not encoded then
        warn("[SagaMonitor] JSON encode gagal: " .. tostring(encoded))
        return false
    end

    local req_ok, resp = pcall(function()
        return doRequest(
            MONITOR_ENDPOINT,
            "POST",
            {
                ["Content-Type"]  = "application/json",
                ["X-Monitor-Key"] = MONITOR_KEY,
            },
            encoded
        )
    end)

    if req_ok and resp and type(resp) == "table" then
        local sc = resp.StatusCode or resp.Status or 0
        if sc >= 200 and sc < 300 then
            return true
        else
            warn("[SagaMonitor] Server error: " .. tostring(sc))
            return false
        end
    else
        warn("[SagaMonitor] Request gagal: " .. tostring(resp))
        return false
    end
end

-- ============================================================
-- MAIN LOOP — kirim data setiap MONITOR_INTERVAL detik
-- ============================================================

-- Kirim langsung saat pertama jalan
task.spawn(function()
    task.wait(2)  -- tunggu sebentar setelah load

    local success = sendMonitorData()
    if success then
        warn("[SagaMonitor] ✅ Data pertama terkirim ke " .. MONITOR_ENDPOINT)
    else
        warn("[SagaMonitor] ❌ Gagal kirim data pertama")
    end

    -- Loop interval
    while true do
        task.wait(MONITOR_INTERVAL)

        -- Stop kalau player sudah tidak di game
        if not lp or not lp.Parent then
            warn("[SagaMonitor] Player left, monitor stop")
            break
        end

        pcall(sendMonitorData)
    end
end)

warn("[SagaMonitor] Monitor aktif — interval: " .. MONITOR_INTERVAL .. "s")
warn("[SagaMonitor] Endpoint: " .. MONITOR_ENDPOINT)

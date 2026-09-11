--[[
================================================================================
  SAGAHUB MONITOR  v2.1
  File  : SagaHub_Monitor.lua
  Repo  : https://github.com/Galangpratama-rox/Decode-SAE

  CARA PAKAI:
    loadstring(game:HttpGet("...SagaHub_OneFile.lua"))()
    task.wait(6)
    loadstring(game:HttpGet("...SagaHub_Monitor.lua"))()

  CONFIG:
    Ganti MONITOR_ENDPOINT & MONITOR_KEY agar cocok dengan .env backend.

  DATA YANG DIKIRIM:
    - Basic: username, userId, placeId, ping, position, leaderstats
    - Plot snapshot: income, speed, capacity, plotLevel, treadmillLevel
    - placedEggs: array egg yang ditanam (name, rarity, ratePerSecond, weightKg, mutations)
    - activePets: jumlah pet aktif
    - backpackEggCount / backpackPetCount
    - latestDeposit: egg terakhir yang di-deposit
================================================================================
--]]

-- ============================================================
-- CONFIG
-- ============================================================
local MONITOR_ENDPOINT = "https://backend-monitoring-sae-production-a7b9.up.railway.app/api/monitor"
local MONITOR_INTERVAL = 30   -- kirim setiap N detik
local MONITOR_KEY      = "sagahub-secret-key"

-- ============================================================
-- SETUP
-- ============================================================
local ge      = (getgenv and getgenv()) or _G
local Players = game:GetService("Players")
local lp      = Players.LocalPlayer
local hs      = game:GetService("HttpService")

if not lp then
    warn("[SagaMonitor] LocalPlayer tidak ada, abort")
    return
end

local handoff = rawget(ge, "__FYY_ACCESS_HANDOFF")
    or (type(shared) == "table" and shared["__FYY_ACCESS_HANDOFF"])

-- ============================================================
-- REQUEST HELPER
-- ============================================================
local function doRequest(url, method, headers, body)
    local hs2 = game:GetService("HttpService")
    local ok1, res1 = pcall(function()
        return hs2:RequestAsync({
            Url = url, Method = method or "POST",
            Headers = headers or {}, Body = body or "",
        })
    end)
    if ok1 and res1 and (res1.StatusCode or 0) > 0 then return res1 end

    local ge2    = (getgenv and getgenv()) or _G
    local fakeRef = rawget(ge2, "__FyyFakeReq")
    local reqFns = {
        rawget(ge2, "__FyyTrueRequest"),
        rawget(ge2, "__FyyOrigRequest"),
    }
    for _, name in ipairs({"request","http_request","httprequest"}) do
        local fn = rawget(ge2, name)
        if type(fn) == "function" and fn ~= fakeRef then
            table.insert(reqFns, fn)
        elseif type(fn) == "table" and type(rawget(fn,"request")) == "function" then
            table.insert(reqFns, rawget(fn,"request"))
        end
    end
    for _, fn in ipairs(reqFns) do
        if type(fn) == "function" and fn ~= fakeRef then
            local ok2, res2 = pcall(fn, {
                Url = url, Method = method or "POST",
                Headers = headers or {}, Body = body or "",
            })
            if ok2 and res2 and type(res2) == "table" and (res2.StatusCode or 0) > 0 then
                return res2
            end
        end
    end
    return nil
end

warn("[SagaMonitor] Request helper siap")

-- ============================================================
-- HELPER: safe number
-- ============================================================
local function safeNum(v)
    local n = tonumber(v)
    return n or 0
end

-- ============================================================
-- EGG / PLOT DATA COLLECTOR
-- Path sudah diverifikasi dari debug output:
-- - AssetRoster.ReadSnapshot(userId) → Records per egg
-- - EggState.FetchEggRecord(uid) → detail per egg
-- - PlotState.ResolveLocalSlot() + ResolveFolder() → plot data
-- ============================================================

local function getEggAndPlotData(stats)
    local rs2 = game:GetService("ReplicatedStorage")

    -- Require modules — semua dibungkus pcall agar tidak crash
    local ok1, EggState    = pcall(require, rs2.Client.EggState)
    local ok2, AssetRoster = pcall(require, rs2.Client.AssetRoster)
    local ok3, PlotState   = pcall(require, rs2.Client.PlotState)
    if not ok1 or not ok2 or not ok3 then return end

    -- ── Placed eggs dari AssetRoster.ReadSnapshot ─────────────────
    pcall(function()
        local snap = AssetRoster.ReadSnapshot(lp.UserId)
        if type(snap) ~= "table" then return end

        -- Cari snapshot milik player ini
        local mySnap = nil
        for _, s in ipairs(snap) do
            if type(s) == "table" and s.OwnerUserId == lp.UserId then
                mySnap = s
                break
            end
        end
        if not mySnap or type(mySnap.Records) ~= "table" then return end

        local placedEggs = {}
        for uid, rec in pairs(mySnap.Records) do
            if type(rec) == "table" then
                local item = rec.ItemData or {}
                -- Mutations: bisa table array
                local muts = {}
                if type(item.Mutations) == "table" then
                    for _, m in ipairs(item.Mutations) do
                        table.insert(muts, tostring(m))
                    end
                end
                table.insert(placedEggs, {
                    uid           = tostring(uid),
                    name          = tostring(item.Category or "Unknown"),
                    moneyPerSecond= safeNum(rec.MoneyPerSecond),
                    scale         = safeNum(item.Scale or 1),
                    baseMutation  = tostring(item.BaseMutation or ""),
                    mutations     = muts,
                    gender        = tostring(item.Gender or ""),
                    personality   = tostring(item.Personality or ""),
                })
            end
        end

        -- Sort by moneyPerSecond descending
        table.sort(placedEggs, function(a, b)
            return a.moneyPerSecond > b.moneyPerSecond
        end)

        if #placedEggs > 0 then
            stats.placedEggs = placedEggs
            stats.placedEggCount = #placedEggs
        end
    end)

    -- ── Plot snapshot dari PlotState ───────────────────────────────
    pcall(function()
        local slotNum = PlotState.ResolveLocalSlot()
        if type(slotNum) ~= "number" then return end

        local folder = PlotState.ResolveFolder(slotNum)
        if not folder then return end

        -- folder = "Plots" (Folder), slot = Model di dalamnya
        local plotModel = nil
        if typeof(folder) == "Instance" then
            plotModel = folder:FindFirstChild(tostring(slotNum))
        end

        local plotLevel = 0
        if plotModel then
            -- BaseUpgradeLevel ada di attribute
            local lvl = plotModel:GetAttribute("BaseUpgradeLevel")
            if lvl then plotLevel = safeNum(lvl) end
        end

        -- Income dari leaderstats (sudah ada di stats.leaderstats)
        local income = 0
        if stats.leaderstats then
            income = safeNum(stats.leaderstats["Money/s"] or 0)
        end

        stats.plotSnapshot = {
            slotNumber     = slotNum,
            plotLevel      = plotLevel,
            placedEggCount = stats.placedEggCount or 0,
            income         = income,
        }
    end)

    -- ── Per-egg detail via FetchEggRecord (ambil dari PlacedEggRenders) ──
    -- Hanya enrichment tambahan — skip kalau sudah ada placedEggs
    pcall(function()
        if stats.placedEggs and #stats.placedEggs > 0 then return end

        -- Fallback: baca dari PlacedEggRenders di workspace
        local myId = tostring(lp.UserId)
        local ws = game:GetService("Workspace")
        local renders = ws:FindFirstChild("PlacedEggRenders")
        if not renders then return end

        local eggs = {}
        for _, model in ipairs(renders:GetChildren()) do
            if model.Name:sub(1, #myId) == myId then
                local uid = model.Name:sub(#myId + 2)
                local ok, rec = pcall(function()
                    return EggState.FetchEggRecord(uid)
                end)
                if ok and type(rec) == "table" then
                    local muts = {}
                    if type(rec.Mutations) == "table" then
                        for _, m in ipairs(rec.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end
                    local placedAt = 0
                    if type(rec.Placement) == "table" then
                        placedAt = safeNum(rec.Placement.PlacedAt)
                    end
                    table.insert(eggs, {
                        uid          = uid,
                        name         = tostring(rec.AssetCategory or "Unknown"),
                        scale        = safeNum(rec.AssetScale or 1),
                        baseMutation = tostring(rec.BaseMutation or ""),
                        mutations    = muts,
                        placedAt     = placedAt,
                    })
                end
            end
        end
        if #eggs > 0 then
            stats.placedEggs     = eggs
            stats.placedEggCount = #eggs
        end
    end)
end

-- ============================================================
-- ============================================================
-- MAIN DATA COLLECTOR
-- ============================================================
local function getPlayerStats()
    local stats = {}

    pcall(function()
        -- ── Basic info ───────────────────────────────────────────────
        stats.username    = lp.Name
        stats.displayName = lp.DisplayName
        stats.userId      = lp.UserId
        stats.placeId     = game.PlaceId
        stats.jobId       = game.JobId
        stats.serverTime  = os.time()
        stats.playerCount = #Players:GetPlayers()

        -- ── Ping ─────────────────────────────────────────────────────
        pcall(function()
            stats.ping = math.floor(
                game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value
            )
        end)

        -- ── Leaderstats ───────────────────────────────────────────────
        pcall(function()
            local ls = lp:FindFirstChild("leaderstats")
            if ls then
                stats.leaderstats = {}
                for _, v in ipairs(ls:GetChildren()) do
                    stats.leaderstats[v.Name] = tostring(v.Value)
                end
            end
        end)

        -- ── Character position ────────────────────────────────────────
        pcall(function()
            local char = lp.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    stats.position = {
                        x = math.floor(hrp.Position.X),
                        y = math.floor(hrp.Position.Y),
                        z = math.floor(hrp.Position.Z),
                    }
                end
            end
        end)

        -- ── Session info ─────────────────────────────────────────────
        pcall(function()
            if handoff and type(handoff.session) == "table" then
                stats.session = {
                    sessionId  = handoff.session.sessionId,
                    accessTier = handoff.session.accessTier,
                }
            end
        end)
    end)

    -- ── Egg & Plot data ───────────────────────────────────────────────
    getEggAndPlotData(stats)

    return stats
end

-- ============================================================
-- SEND
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
            MONITOR_ENDPOINT, "POST",
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
-- MAIN LOOP
-- ============================================================
task.spawn(function()
    task.wait(2)

    local success = sendMonitorData()
    if success then
        warn("[SagaMonitor] ✅ Data pertama terkirim ke " .. MONITOR_ENDPOINT)
    else
        warn("[SagaMonitor] ❌ Gagal kirim data pertama")
    end

    while true do
        task.wait(MONITOR_INTERVAL)
        if not lp or not lp.Parent then
            warn("[SagaMonitor] Player left, monitor stop")
            break
        end
        pcall(sendMonitorData)
    end
end)

warn("[SagaMonitor] Monitor v2.1 aktif — interval: " .. MONITOR_INTERVAL .. "s")
warn("[SagaMonitor] Endpoint: " .. MONITOR_ENDPOINT)

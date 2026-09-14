--[[
================================================================================
  SAGAHUB MONITOR  v2.3
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
local MONITOR_INTERVAL = 45   -- kirim setiap N detik (dinaikkan untuk performa)
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
    -- Pakai HttpService:RequestAsync langsung (tidak bisa di-intercept fakeReq)
    local hs2 = game:GetService("HttpService")
    local ok, res = pcall(function()
        return hs2:RequestAsync({
            Url = url, Method = method or "POST",
            Headers = headers or {}, Body = body or "",
        })
    end)
    if ok and res and (res.StatusCode or 0) > 0 then return res end
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
-- EGG / PLOT DATA COLLECTOR  v2.3
-- Strategy:
--   1. PRIMARY: baca __FYY_LAST_WEBHOOK_PAYLOAD yang di-intercept
--      dari Discord webhook runtime — data 100% akurat (nama, rarity,
--      weightKg, ratePerSecond) sama persis dengan yang dikirim ke Discord
--   2. FALLBACK: PlacedEggRenders + FetchEggRecord + Assets.Directory
--      (nama & rarity akurat, weightKg/$/s adalah base value bukan live)
--   3. PETS: AssetRoster.ReadSnapshot() — strict filter OwnerUserId
-- ============================================================

-- ============================================================
-- MODULE CACHE — require sekali saat load, pakai terus
-- ============================================================
local _EggState    = nil
local _AssetRoster = nil
local _PlotState   = nil
local _Assets      = nil
local _Mutations   = nil
local _Dir         = nil  -- Assets.Directory cache

-- Pets cache untuk skip-interval optimization
local _lastPetsData    = nil
local _petsSkipCounter = 0

-- Mutation EarningsScalar cache — hindari pcall Mutations.Get per egg
local _mutCache = {}
local function getMutScalar(mutName)
    if not mutName or mutName == "" or mutName == "nil" then return 1.0 end
    if _mutCache[mutName] then return _mutCache[mutName] end
    if _Mutations and type(_Mutations.Get) == "function" then
        local ok, cfg = pcall(_Mutations.Get, mutName)
        local scalar = (ok and type(cfg) == "table") and (cfg.EarningsScalar or 1.0) or 1.0
        _mutCache[mutName] = scalar
        return scalar
    end
    return 1.0
end

-- __FyyCommunityStealAnEgg cache
local _saeCache = nil
local function getSAE()
    if _saeCache then return _saeCache end
    local ge2 = (getgenv and getgenv()) or _G
    local sae = rawget(ge2, "__FyyCommunityStealAnEgg")
    if type(sae) == "table" then _saeCache = sae end
    return sae
end

do
    local rs2 = game:GetService("ReplicatedStorage")
    local function tryRequire(path)
        local ok, m = pcall(require, path)
        return ok and m or nil
    end
    _EggState    = tryRequire(rs2.Client.EggState)
    _AssetRoster = tryRequire(rs2.Client.AssetRoster)
    _PlotState   = tryRequire(rs2.Client.PlotState)
    _Assets      = tryRequire(rs2.Data.Assets)
    _Mutations   = tryRequire(rs2.Shared.Modules.Mutations)
    if _Assets and type(_Assets.Directory) == "table" then
        _Dir = _Assets.Directory
    end
end

local function getEggAndPlotData(stats)
    local ok1 = _EggState ~= nil
    local ok2 = _AssetRoster ~= nil
    local ok3 = _PlotState ~= nil
    local ok4 = _Assets ~= nil
    local ok5 = _Mutations ~= nil
    local EggState    = _EggState
    local AssetRoster = _AssetRoster
    local PlotState   = _PlotState
    local Assets      = _Assets
    local Mutations   = _Mutations

    -- ── PRIMARY: EggState.FetchEggRecord (live, setiap interval) ──
    -- Ini real-time — tidak perlu tunggu webhook Discord
    -- Webhook intercept tetap berjalan sebagai bonus kalau ada steal event
    if not ok1 then return end

    -- ── Live egg data: ReadOwnedEggs + FetchEggRecord + weightUtil ──
    -- weightUtil.WeightKg(rec) = berat aktual include growth
    -- weightUtil.SellPrice(rec) = nilai jual telur saat netas (ini yang ditampilkan)
    pcall(function()
        if not ok1 then return end

        local sae = getSAE()
        if type(sae) ~= "table" then return end

        local weightUtil = sae.eggRuntime and sae.eggRuntime.weightUtil
        if type(weightUtil) ~= "table" then return end

        -- Pakai _Dir cache (sudah di-init di load time)
        local dir = _Dir

        -- ReadOwnedEggs: sudah filter per player
        local okR, owned = pcall(EggState.ReadOwnedEggs)
        if not okR or type(owned) ~= "table" then return end

        local myEntry = nil
        for _, entry in ipairs(owned) do
            if type(entry) == "table"
                and type(entry.OwnerUserId) == "number"
                and entry.OwnerUserId == lp.UserId then
                myEntry = entry
                break
            end
        end
        if not myEntry or type(myEntry.Records) ~= "table" then return end

        local plotEggs = {}
        for uid in pairs(myEntry.Records) do
            local okF, rec = pcall(EggState.FetchEggRecord, uid)
            if not okF or type(rec) ~= "table" then
                rec = sae.eggRuntime.records and sae.eggRuntime.records[uid]
            end
            if type(rec) == "table" then
                local category = tostring(rec.AssetCategory or "Unknown")
                if category ~= "Unknown" then
                    -- WeightKg aktual (include growth)
                    local ok_w, weightKg = pcall(weightUtil.WeightKg, rec)
                    weightKg = (ok_w and type(weightKg) == "number" and weightKg > 0)
                        and weightKg or 0

                    -- SellPrice = nilai jual telur saat netas
                    local ok_s, sellPrice = pcall(weightUtil.SellPrice, rec)
                    sellPrice = (ok_s and type(sellPrice) == "number")
                        and sellPrice or 0

                    -- Fallback weight dari Assets.Directory
                    if weightKg <= 0 then
                        local dirE = dir and dir[category]
                        local baseW = dirE and dirE.Egg and safeNum(dirE.Egg.WeightKg or 0) or 0
                        local scale = safeNum(rec.AssetScale or 1)
                        weightKg = baseW * scale
                    end

                    -- 1x dirEntry lookup
                    local dirEntry   = dir and dir[category]
                    local eggData    = (dirEntry and type(dirEntry.Egg) == "table") and dirEntry.Egg or {}
                    local rarityData = (dirEntry and type(dirEntry.Rarity) == "table") and dirEntry.Rarity or {}

                    local displayName = tostring(eggData.DisplayName or category .. " Egg")
                    local rarity      = tostring(rarityData._id or rarityData.DisplayName or "Unknown")

                    -- Mutations list (untuk display)
                    local muts = {}
                    if type(rec.Mutations) == "table" then
                        for _, m in ipairs(rec.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end

                    -- EarningsScalar via cache (tidak ada pcall overhead per egg)
                    local baseMut = tostring(rec.BaseMutation or "")
                    local earningsScalar = getMutScalar(baseMut)
                    -- Cek Mutations array kalau ada scalar lebih tinggi
                    for _, m in ipairs(muts) do
                        local s = getMutScalar(m)
                        if s > earningsScalar then earningsScalar = s end
                    end

                    -- rate = SellPrice * 3/200 / 1.2 * EarningsScalar
                    local ratePerSec = math.floor(sellPrice * 3 / 200 / 1.2 * earningsScalar)

                    if weightKg > 0 then
                        table.insert(plotEggs, {
                            name          = displayName,
                            rarity        = rarity,
                            weightKg      = math.floor(weightKg * 100) / 100,
                            ratePerSecond = ratePerSec,
                            mutations     = muts,
                        })
                    end
                end
            end
        end

        -- Sort by ratePerSecond descending
        table.sort(plotEggs, function(a, b)
            return a.ratePerSecond > b.ratePerSecond
        end)

        if #plotEggs > 0 then
            stats.plotEggs     = plotEggs
            stats.plotEggCount = #plotEggs
        end
    end)


    -- ── Pets dari AssetRoster.ReadSnapshot ────────────────────────
    -- ReadSnapshot berat (scan semua player) — jalankan setiap 3x interval
    pcall(function()
        if not ok2 then return end
        -- Skip counter: hanya update pets setiap 3 kali interval (~135 detik)
        if not _petsSkipCounter then _petsSkipCounter = 0 end
        _petsSkipCounter = _petsSkipCounter + 1
        if _petsSkipCounter < 3 then
            -- Pakai data pets terakhir kalau ada
            if _lastPetsData then
                stats.pets     = _lastPetsData
                stats.petCount = #_lastPetsData
            end
            return
        end
        _petsSkipCounter = 0
        local snap = AssetRoster.ReadSnapshot()
        if type(snap) ~= "table" then return end

        local mySnap = nil
        for _, s in ipairs(snap) do
            -- Strict: OwnerUserId harus exact match number, bukan string prefix
            if type(s) == "table"
                and type(s.OwnerUserId) == "number"
                and s.OwnerUserId == lp.UserId then
                mySnap = s
                break
            end
        end
        if not mySnap then return end

        local records = mySnap.Records
        if type(records) ~= "table" then return end

        local pets = {}
        for uid, rec in pairs(records) do
            if type(rec) == "table" then
                -- Double-check: setiap record harus milik player ini
                if rec.OwnerUserId and rec.OwnerUserId ~= lp.UserId then
                    -- skip record milik orang lain
                else
                    local item = rec.ItemData or {}
                    local muts = {}
                    if type(item.Mutations) == "table" then
                        for _, m in ipairs(item.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end
                    local petRate = safeNum(rec.MoneyPerSecond)
                    if petRate > 0 then
                        table.insert(pets, {
                            name          = tostring(item.Category or "Unknown"),
                            ratePerSecond = petRate,
                            mutations     = muts,
                        })
                    end
                end
            end
        end
        table.sort(pets, function(a, b) return a.ratePerSecond > b.ratePerSecond end)
        if #pets > 0 then
            stats.pets     = pets
            stats.petCount = #pets
            _lastPetsData  = pets  -- cache untuk skip intervals
        end
    end)

    -- ── Plot snapshot dari PlotState ───────────────────────────────
    pcall(function()
        if not ok3 then return end
        local slotNum = PlotState.ResolveLocalSlot()
        if type(slotNum) ~= "number" then return end

        local folder = PlotState.ResolveFolder(slotNum)
        local plotLevel = 0
        if typeof(folder) == "Instance" then
            local plotModel = folder:FindFirstChild(tostring(slotNum))
            if plotModel then
                local lvl = plotModel:GetAttribute("BaseUpgradeLevel")
                if lvl then plotLevel = safeNum(lvl) end
            end
        end

        local income = 0
        if stats.leaderstats then
            income = safeNum(stats.leaderstats["Money/s"] or 0)
        end

        stats.plotSnapshot = {
            slotNumber    = slotNum,
            plotLevel     = plotLevel,
            plotEggCount  = stats.plotEggCount or 0,
            petCount      = stats.petCount or 0,
            income        = income,
        }
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

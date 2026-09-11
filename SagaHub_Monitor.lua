--[[
================================================================================
  SAGAHUB MONITOR  v2.2
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
-- EGG / PLOT DATA COLLECTOR  v2.2
-- Path diverifikasi dari debug live:
--   workspace.PlacedEggRenders  → model {userId}_{uid} = egg di plot
--   EggState.FetchEggRecord(uid) → AssetCategory, AssetScale, Mutations
--   RS.Data.Assets.Directory[category] → EarningRate, Rarity, Egg.WeightKg, Egg.DisplayName
--   AssetRoster.ReadSnapshot() → pets (bukan eggs), disimpan di stats.pets
--   PlotState.ResolveLocalSlot() + ResolveFolder() → plot level
-- ============================================================

local function getEggAndPlotData(stats)
    local rs2 = game:GetService("ReplicatedStorage")

    local ok1, EggState    = pcall(require, rs2.Client.EggState)
    local ok2, AssetRoster = pcall(require, rs2.Client.AssetRoster)
    local ok3, PlotState   = pcall(require, rs2.Client.PlotState)
    local ok4, Assets      = pcall(require, rs2.Data.Assets)
    if not ok1 then return end

    -- ── Plot Eggs dari PlacedEggRenders + FetchEggRecord + Assets.Directory ──
    pcall(function()
        local myId   = tostring(lp.UserId)
        local myPrefix = myId .. "_"   -- exact prefix: "11624556573_"
        local ws     = game:GetService("Workspace")
        local renders = ws:FindFirstChild("PlacedEggRenders")
        if not renders then return end

        -- Cache Assets.Directory agar tidak require ulang tiap egg
        local dir = (ok4 and type(Assets) == "table" and type(Assets.Directory) == "table")
            and Assets.Directory or nil

        local plotEggs = {}
        for _, model in ipairs(renders:GetChildren()) do
            -- Exact match: nama harus mulai dengan "{userId}_"
            if model.Name:sub(1, #myPrefix) == myPrefix then
                local uid = model.Name:sub(#myPrefix + 1)
                local okR, rec = pcall(function()
                    return EggState.FetchEggRecord(uid)
                end)
                if okR and type(rec) == "table" then
                    local category = tostring(rec.AssetCategory or "Unknown")

                    -- Lookup di Assets.Directory untuk nama, rarity, weightKg, earningRate
                    local dirEntry  = dir and dir[category]
                    local eggData   = (dirEntry and type(dirEntry.Egg) == "table") and dirEntry.Egg or {}
                    local rarityData= (dirEntry and type(dirEntry.Rarity) == "table") and dirEntry.Rarity or {}

                    local displayName   = tostring(eggData.DisplayName or category .. " Egg")
                    local weightKg      = safeNum(eggData.WeightKg or 0)
                    local earningRate   = safeNum(dirEntry and dirEntry.EarningRate or 0)
                    local rarity        = tostring(rarityData._id or rarityData.DisplayName or "Unknown")
                    local rarityNumber  = safeNum(rarityData.RarityNumber or 0)

                    -- Mutations
                    local muts = {}
                    if type(rec.Mutations) == "table" then
                        for _, m in ipairs(rec.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end

                    -- Scale dari FetchEggRecord (ukuran visual, bukan berat)
                    local scale = safeNum(rec.AssetScale or 1)

                    -- Berat real = WeightKg * Scale (sama seperti yang ditampilkan webhook)
                    local actualWeightKg = weightKg * scale

                    -- PlacedAt dari Placement
                    local placedAt = 0
                    if type(rec.Placement) == "table" then
                        placedAt = safeNum(rec.Placement.PlacedAt)
                    end

                    table.insert(plotEggs, {
                        uid           = uid,
                        name          = displayName,
                        category      = category,
                        rarity        = rarity,
                        rarityNumber  = rarityNumber,
                        ratePerSecond = earningRate,
                        weightKg      = math.floor(actualWeightKg * 100) / 100,
                        scale         = scale,
                        mutations     = muts,
                        baseMutation  = tostring(rec.BaseMutation or ""),
                        hasParasite   = rec.HasParasite == true,
                        placedAt      = placedAt,
                    })
                end
            end
        end

        -- Sort by ratePerSecond descending
        table.sort(plotEggs, function(a, b)
            return a.ratePerSecond > b.ratePerSecond
        end)

        if #plotEggs > 0 then
            stats.plotEggs      = plotEggs
            stats.plotEggCount  = #plotEggs
            warn("[SagaMonitor] ✅ plotEggs collected: " .. #plotEggs)
        else
            warn("[SagaMonitor] ⚠️ plotEggs: 0 eggs found in PlacedEggRenders")
        end
    end)

    -- ── Pets dari AssetRoster.ReadSnapshot ────────────────────────
    -- (ini adalah pets yang di-equip/di-pen, bukan eggs)
    -- ReadSnapshot() return semua player di server — HARUS filter ketat
    pcall(function()
        if not ok2 then return end
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
                    table.insert(pets, {
                        uid            = tostring(uid),
                        name           = tostring(item.Category or "Unknown"),
                        moneyPerSecond = safeNum(rec.MoneyPerSecond),
                        ratePerSecond  = safeNum(rec.MoneyPerSecond),
                        scale          = safeNum(item.Scale or 1),
                        baseMutation   = tostring(item.BaseMutation or ""),
                        mutations      = muts,
                        gender         = tostring(item.Gender or ""),
                        personality    = tostring(item.Personality or ""),
                    })
                end
            end
        end
        table.sort(pets, function(a, b) return a.ratePerSecond > b.ratePerSecond end)
        if #pets > 0 then
            stats.pets     = pets
            stats.petCount = #pets
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

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
-- EGG / PLOT DATA COLLECTOR  v2.3
-- Strategy:
--   1. PRIMARY: baca __FYY_LAST_WEBHOOK_PAYLOAD yang di-intercept
--      dari Discord webhook runtime — data 100% akurat (nama, rarity,
--      weightKg, ratePerSecond) sama persis dengan yang dikirim ke Discord
--   2. FALLBACK: PlacedEggRenders + FetchEggRecord + Assets.Directory
--      (nama & rarity akurat, weightKg/$/s adalah base value bukan live)
--   3. PETS: AssetRoster.ReadSnapshot() — strict filter OwnerUserId
-- ============================================================

-- Parse plot eggs dari webhook payload yang sudah di-intercept di OneFile
-- Format components v2: components[1].components[5] = Plot Eggs
--                       components[1].components[6] = Active Pets
--                       components[1].components[3].components[2] = Plot Summary
local function parseWebhookPayload(payload)
    if type(payload) ~= "table" then return nil end

    local result = {}

    -- Navigasi ke components[1].components
    local c1 = type(payload.components) == "table" and payload.components[1]
    if not c1 or type(c1.components) ~= "table" then return nil end
    local inner = c1.components

    -- Helper: ambil content dari component by index
    local function getContent(idx)
        local c = inner[idx]
        if c and type(c.content) == "string" then return c.content end
        return nil
    end

    -- Helper: parse number string seperti "1.07B", "35.2M", "98.32B"
    local function parseNum(s)
        if not s then return 0 end
        s = s:gsub(",", ""):gsub("%s", "")
        local num = tonumber(s:match("^([%d%.]+)")) or 0
        local suf = s:match("[KMBTkmbt]$")
        if suf then suf = suf:upper() end
        if suf == "K" then return num * 1e3
        elseif suf == "M" then return num * 1e6
        elseif suf == "B" then return num * 1e9
        elseif suf == "T" then return num * 1e12
        end
        return num
    end

    -- ── Plot Eggs (component index 5) ─────────────────────────────
    -- Format: "• **Name** · Rarity · **Kg Kg** · **$Rate/s** · Mutation"
    -- atau:   "• **Name** · Rarity · **Kg Kg** · **$Rate/s**"
    local plotEggsContent = getContent(5)
    if plotEggsContent then
        local eggs = {}
        for line in plotEggsContent:gmatch("[^\n]+") do
            -- Strip markdown bold
            line = line:gsub("%*%*", "")
            -- Pattern: "• Name · Rarity · Weight Kg · $Rate/s" dengan optional mutation
            local name, rarity, weight, rate = line:match(
                "^[•%*%-]%s*(.-)%s*·%s*(.-)%s*·%s*([%d%.,]+)%s*Kg%s*·%s*%$([%d%.]+[KMBT]?)/s"
            )
            if name and rarity and weight and rate then
                -- Ambil mutations (sisa setelah $/s)
                local rest = line:match("/s%s*·?%s*(.+)$") or ""
                local muts = {}
                for m in rest:gmatch("[^/,·]+") do
                    local mt = m:match("^%s*(.-)%s*$")
                    if mt and #mt > 0 then table.insert(muts, mt) end
                end
                table.insert(eggs, {
                    name          = name,
                    rarity        = rarity,
                    weightKg      = tonumber(weight:gsub(",","")) or 0,
                    ratePerSecond = parseNum(rate),
                    mutations     = muts,
                })
            end
        end
        if #eggs > 0 then result.plotEggs = eggs end
    end

    -- ── Active Pets (component index 6) ───────────────────────────
    -- Format: "• **Name** · Rarity · **$Rate/s** · Mutation"
    -- atau:   "• **Name ×N** · Rarity · **$Rate/s**"
    local petsContent = getContent(6)
    if petsContent then
        local pets = {}
        for line in petsContent:gmatch("[^\n]+") do
            line = line:gsub("%*%*", "")
            -- Coba match dengan ×N (grouped)
            local name, rarity, rate = line:match(
                "^[•%*%-]%s*(.-)%s*·%s*(.-)%s*·%s*%$([%d%.]+[KMBT]?)/s"
            )
            if name and rarity and rate then
                local rest = line:match("/s%s*·?%s*(.+)$") or ""
                local muts = {}
                for m in rest:gmatch("[^/,·]+") do
                    local mt = m:match("^%s*(.-)%s*$")
                    if mt and #mt > 0 then table.insert(muts, mt) end
                end
                table.insert(pets, {
                    name          = name,
                    rarity        = rarity,
                    ratePerSecond = parseNum(rate),
                    moneyPerSecond= parseNum(rate),
                    mutations     = muts,
                })
            end
        end
        if #pets > 0 then result.pets = pets end
    end

    -- ── Plot Summary (component[3].components[2]) ──────────────────
    local c3 = inner[3]
    if type(c3) == "table" and type(c3.components) == "table" then
        local summaryContent = type(c3.components[2]) == "table"
            and c3.components[2].content or nil
        if summaryContent then
            summaryContent = summaryContent:gsub("%*%*","")
            local income  = summaryContent:match("Income%s*·%s*%$([%d%.]+[KMBT]?)/s")
            local speed   = summaryContent:match("Speed%s*·%s*([%d%.]+[KMBT]?)")
            local placed  = summaryContent:match("Placed eggs%s*·%s*(%d+)")
            local capacity= summaryContent:match("Placed eggs%s*·%s*%d+/(%d+)")
            local active  = summaryContent:match("Active pets%s*·%s*(%d+)")
            result.plotSnapshot = {
                income         = parseNum(income or "0"),
                speed          = parseNum(speed or "0"),
                placedEggCount = tonumber(placed) or 0,
                capacity       = tonumber(capacity) or 0,
                activePetCount = tonumber(active) or 0,
                plotEggCount   = result.plotEggs and #result.plotEggs or 0,
                petCount       = result.pets and #result.pets or 0,
            }
        end
    end

    return (result.plotEggs or result.pets) and result or nil
end

-- ============================================================
-- MODULE CACHE — require sekali, pakai terus
-- ============================================================
local _rs2        = game:GetService("ReplicatedStorage")
local _EggState   = nil
local _AssetRoster= nil
local _PlotState  = nil
local _Assets     = nil
local _Mutations  = nil
local _Dir        = nil  -- Assets.Directory cache

local function _initModules()
    if not _EggState then
        local ok, m = pcall(require, _rs2.Client.EggState)
        if ok then _EggState = m end
    end
    if not _AssetRoster then
        local ok, m = pcall(require, _rs2.Client.AssetRoster)
        if ok then _AssetRoster = m end
    end
    if not _PlotState then
        local ok, m = pcall(require, _rs2.Client.PlotState)
        if ok then _PlotState = m end
    end
    if not _Assets then
        local ok, m = pcall(require, _rs2.Data.Assets)
        if ok then
            _Assets = m
            if type(m) == "table" and type(m.Directory) == "table" then
                _Dir = m.Directory
            end
        end
    end
    if not _Mutations then
        local ok, m = pcall(require, _rs2.Shared.Modules.Mutations)
        if ok then _Mutations = m end
    end
end

-- Init sekali saat monitor load
_initModules()

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

    -- ── Webhook sebagai bonus update (kalau fresh < 2 menit) ─────
    pcall(function()
        local ge2 = (getgenv and getgenv()) or _G
        local payload = rawget(ge2, "__FYY_LAST_WEBHOOK_PAYLOAD")
        local ts      = rawget(ge2, "__FYY_LAST_WEBHOOK_TS") or 0
        -- Hanya pakai webhook kalau fresh (< 2 menit) — bukan primary
        if not payload or (os.time() - ts) > 120 then return end

        local parsed = parseWebhookPayload(payload)
        if not parsed then return end
        if parsed.plotSnapshot then
            stats.webhookSnapshot = parsed.plotSnapshot
        end
    end)

    -- ── Live egg data: ReadOwnedEggs + FetchEggRecord + weightUtil ──
    -- weightUtil.WeightKg(rec) = berat aktual include growth
    -- weightUtil.SellPrice(rec) = nilai jual telur saat netas (ini yang ditampilkan)
    pcall(function()
        if not ok1 then return end

        local ge2 = (getgenv and getgenv()) or _G
        local sae = rawget(ge2, "__FyyCommunityStealAnEgg")
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

                    -- Data display dari Assets.Directory
                    local dirEntry   = dir and dir[category]
                    local eggData    = (dirEntry and type(dirEntry.Egg) == "table") and dirEntry.Egg or {}
                    local rarityData = (dirEntry and type(dirEntry.Rarity) == "table") and dirEntry.Rarity or {}

                    local displayName  = tostring(eggData.DisplayName or category .. " Egg")
                    local rarity       = tostring(rarityData._id or rarityData.DisplayName or "Unknown")
                    local rarityNumber = safeNum(rarityData.RarityNumber or 0)

                    -- Mutations
                    local muts = {}
                    if type(rec.Mutations) == "table" then
                        for _, m in ipairs(rec.Mutations) do
                            table.insert(muts, tostring(m))
                        end
                    end

                    -- ratePerSecond = SellPrice * 3/200 / 1.2 * EarningsScalar
                    -- SellPrice*3/200 menghasilkan rate dengan Silver(1.2x) implicit
                    -- Jadi perlu dibagi 1.2 dulu (base), lalu kali EarningsScalar mutation
                    local baseRate = sellPrice * 3 / 200 / 1.2

                    -- Ambil EarningsScalar dari mutation
                    local earningsScalar = 1.0
                    if ok5 and type(Mutations) == "table" and type(Mutations.Get) == "function" then
                        -- BaseMutation dari rec
                        local baseMut = tostring(rec.BaseMutation or "")
                        if baseMut ~= "" and baseMut ~= "nil" then
                            local okM, mutCfg = pcall(Mutations.Get, baseMut)
                            if okM and type(mutCfg) == "table" then
                                earningsScalar = safeNum(mutCfg.EarningsScalar or 1.0)
                            end
                        end
                        -- Cek juga Mutations array
                        if type(rec.Mutations) == "table" then
                            for _, m in ipairs(rec.Mutations) do
                                local okM2, mutCfg2 = pcall(Mutations.Get, tostring(m))
                                if okM2 and type(mutCfg2) == "table" and safeNum(mutCfg2.EarningsScalar) > earningsScalar then
                                    earningsScalar = safeNum(mutCfg2.EarningsScalar)
                                end
                            end
                        end
                    end

                    local ratePerSec = math.floor(baseRate * earningsScalar)

                    if weightKg > 0 then
                        table.insert(plotEggs, {
                            uid           = uid,
                            name          = displayName,
                            category      = category,
                            rarity        = rarity,
                            rarityNumber  = rarityNumber,
                            weightKg      = math.floor(weightKg * 100) / 100,
                            sellPrice     = math.floor(sellPrice),
                            ratePerSecond = ratePerSec,
                            mutations     = muts,
                            hasParasite   = rec.HasParasite == true,
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
            warn("[SagaMonitor] plotEggs: " .. #plotEggs)
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

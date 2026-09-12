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

local function getEggAndPlotData(stats)
    local rs2 = game:GetService("ReplicatedStorage")

    local ok1, EggState    = pcall(require, rs2.Client.EggState)
    local ok2, AssetRoster = pcall(require, rs2.Client.AssetRoster)
    local ok3, PlotState   = pcall(require, rs2.Client.PlotState)
    local ok4, Assets      = pcall(require, rs2.Data.Assets)

    -- ── PRIMARY: baca dari webhook payload yang di-intercept ──────
    pcall(function()
        local ge2 = (getgenv and getgenv()) or _G
        local payload = rawget(ge2, "__FYY_LAST_WEBHOOK_PAYLOAD")
        local ts      = rawget(ge2, "__FYY_LAST_WEBHOOK_TS") or 0
        if not payload or (os.time() - ts) > 300 then return end

        local parsed = parseWebhookPayload(payload)
        if not parsed then return end

        if parsed.plotEggs and #parsed.plotEggs > 0 then
            stats.plotEggs     = parsed.plotEggs
            stats.plotEggCount = #parsed.plotEggs
            warn("[SagaMonitor] ✅ plotEggs dari webhook: " .. #parsed.plotEggs)
        end
        if parsed.pets and #parsed.pets > 0 then
            stats.pets     = parsed.pets
            stats.petCount = #parsed.pets
        end
        if parsed.plotSnapshot then
            stats.plotSnapshot = parsed.plotSnapshot
        end
    end)
    if not ok1 then return end

    -- ── FALLBACK: PlacedEggRenders + FetchEggRecord + Assets.Directory ──
    -- Hanya jalan kalau webhook intercept belum ada data
    pcall(function()
        if stats.plotEggs and #stats.plotEggs > 0 then return end
        if not ok1 then return end

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

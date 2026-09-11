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
-- Membaca data plot & egg langsung dari Roblox Instance tree
-- sesuai dengan arsitektur SAE (Steal An Egg, PlaceId 10563114921)
-- ============================================================

-- Coba baca plot snapshot dari WebhookRuntime (kalau ada)
local function getPlotSnapshotFromRuntime()
    -- Runtime FyyCommunity expose collectDashboardSnapshot via handoff
    if not handoff then return nil end
    local snapshot = nil
    pcall(function()
        local rt = rawget(ge, "__FYY_WEBHOOK_RUNTIME")
            or (handoff and handoff.webhookRuntime)
            or (handoff and handoff.runtime)
        if rt and type(rt.collectDashboardSnapshot) == "function" then
            snapshot = rt:collectDashboardSnapshot()
        elseif rt and type(rt.getStats) == "function" then
            snapshot = rt:getStats()
        end
    end)
    return snapshot
end

-- Coba baca placed eggs dari SAE EggState/EggInventory remote
local function getPlacedEggsFromRemote()
    local eggs = {}
    pcall(function()
        local rs2 = game:GetService("ReplicatedStorage")

        -- SAE menyimpan egg inventory via RemoteFunction "EggInventory"
        -- dengan method "Get" atau via folder Remotes
        local remotes = rs2:FindFirstChild("Remotes")
            or rs2:FindFirstChild("Remote")
            or rs2:FindFirstChild("Events")

        local eggInvRemote = nil
        if remotes then
            eggInvRemote = remotes:FindFirstChild("EggInventory")
                or remotes:FindFirstChild("GetEggInventory")
                or remotes:FindFirstChild("ReadEggInventory")
        end

        if eggInvRemote and eggInvRemote:IsA("RemoteFunction") then
            local ok, result = pcall(function()
                return eggInvRemote:InvokeServer("Get")
            end)
            if ok and type(result) == "table" then
                for _, egg in ipairs(result) do
                    if type(egg) == "table" then
                        table.insert(eggs, {
                            name          = tostring(egg.name or egg.item or egg.uid or "Unknown"),
                            category      = tostring(egg.category or egg.AssetCategory or ""),
                            rarity        = tostring(egg.rarity or "Unknown"),
                            rarityRank    = safeNum(egg.rarityRank),
                            ratePerSecond = safeNum(egg.ratePerSecond),
                            weightKg      = safeNum(egg.weightKg),
                            scale         = safeNum(egg.scale or egg.AssetScale),
                            mutations     = egg.mutations or {},
                            baseMutation  = tostring(egg.baseMutation or egg.BaseMutation or ""),
                            placed        = egg.placed == true,
                            areaId        = tostring(egg.areaId or egg.AreaId or ""),
                        })
                    end
                end
            end
        end
    end)
    return eggs
end

-- Baca plot state dari workspace Bases/PlotState
local function getPlotStateFromWorkspace()
    local plotData = {}
    pcall(function()
        -- SAE workspace structure: workspace.Areas atau workspace.Bases
        local ws = game:GetService("Workspace")

        -- Cari Bases folder (tempat plot berada)
        local bases = ws:FindFirstChild("Bases")
            or ws:FindFirstChild("Plots")
            or ws:FindFirstChild("PlayerPlots")

        if not bases then return end

        -- Cari plot yang dimiliki player ini
        local myPlot = nil
        for _, plot in ipairs(bases:GetChildren()) do
            -- Plot ownership biasanya via StringValue "Owner" atau attribute
            local ownerVal = plot:FindFirstChild("Owner")
                or plot:FindFirstChild("OwnerUserId")
                or plot:FindFirstChild("PlayerId")
            if ownerVal then
                local ownerId = tonumber(ownerVal.Value)
                if ownerId == lp.UserId then
                    myPlot = plot
                    break
                end
            end
            -- Fallback: cek nama plot == nama player
            if plot.Name == lp.Name then
                myPlot = plot
                break
            end
        end

        if not myPlot then return end

        -- Baca PlotState (NumberValue / IntValue children)
        local plotState = myPlot:FindFirstChild("PlotState")
            or myPlot:FindFirstChild("Stats")
            or myPlot

        if plotState then
            local fieldMap = {
                plotLevel        = {"plotLevel", "PlotLevel", "Level"},
                plotMaxLevel     = {"plotMaxLevel", "PlotMaxLevel", "MaxLevel"},
                treadmillLevel   = {"treadmillLevel", "TreadmillLevel"},
                treadmillMaxLevel= {"treadmillMaxLevel", "TreadmillMaxLevel"},
                income           = {"income", "Income", "IncomePerSecond", "LiveRatePerSecond"},
                speed            = {"speed", "Speed", "WalkSpeed"},
                capacity         = {"capacity", "Capacity", "EggCapacity"},
                placedEggCount   = {"placedEggs", "PlacedEggs", "EggsPlaced", "placedEggCount"},
                activePetCount   = {"activePets", "ActivePets", "PetsActive", "activePetCount"},
                backpackEggCount = {"backpackEggCount", "BackpackEggs", "StorageEggs"},
                backpackPetCount = {"backpackPetCount", "BackpackPets"},
            }
            for key, names in pairs(fieldMap) do
                for _, n in ipairs(names) do
                    local child = plotState:FindFirstChild(n)
                    if child and (child:IsA("NumberValue") or child:IsA("IntValue")) then
                        plotData[key] = child.Value
                        break
                    end
                end
            end
        end

        -- Baca placed eggs di dalam plot (folder Eggs atau EggSlots)
        local eggsFolder = myPlot:FindFirstChild("Eggs")
            or myPlot:FindFirstChild("EggSlots")
            or myPlot:FindFirstChild("PlacedEggs")

        if eggsFolder then
            plotData.placedEggList = {}
            for _, eggObj in ipairs(eggsFolder:GetChildren()) do
                local eggEntry = {
                    name         = eggObj.Name,
                    rarity       = "Unknown",
                    ratePerSecond = 0,
                    weightKg     = 0,
                    mutations    = {},
                }
                -- Baca attribute atau child values
                pcall(function()
                    local rarityV = eggObj:FindFirstChild("Rarity") or eggObj:FindFirstChild("rarity")
                    if rarityV then eggEntry.rarity = tostring(rarityV.Value) end

                    local rateV = eggObj:FindFirstChild("LiveRatePerSecond")
                        or eggObj:FindFirstChild("ratePerSecond")
                        or eggObj:FindFirstChild("Income")
                    if rateV then eggEntry.ratePerSecond = safeNum(rateV.Value) end

                    local weightV = eggObj:FindFirstChild("WeightKg")
                        or eggObj:FindFirstChild("weightKg")
                    if weightV then eggEntry.weightKg = safeNum(weightV.Value) end

                    local catV = eggObj:FindFirstChild("Category")
                        or eggObj:FindFirstChild("AssetCategory")
                    if catV then eggEntry.category = tostring(catV.Value) end

                    local scaleV = eggObj:FindFirstChild("AssetScale")
                        or eggObj:FindFirstChild("Scale")
                    if scaleV then eggEntry.scale = safeNum(scaleV.Value) end

                    -- Mutations
                    local mutFolder = eggObj:FindFirstChild("Mutations")
                    if mutFolder then
                        for _, m in ipairs(mutFolder:GetChildren()) do
                            table.insert(eggEntry.mutations, m.Name)
                        end
                    end
                end)
                table.insert(plotData.placedEggList, eggEntry)
            end
        end
    end)
    return plotData
end

-- Baca dari EggWorld/AreaEggs (field eggs saat ini)
local function getFieldEggs()
    local fieldEggs = {}
    pcall(function()
        local ws = game:GetService("Workspace")
        local eggWorld = ws:FindFirstChild("EggWorld")
            or ws:FindFirstChild("AreaEggs")
            or ws:FindFirstChild("Field")

        if not eggWorld then return end

        for _, area in ipairs(eggWorld:GetChildren()) do
            for _, eggObj in ipairs(area:GetChildren()) do
                local entry = { area = area.Name, name = eggObj.Name }
                pcall(function()
                    local rV = eggObj:FindFirstChild("Rarity") or eggObj:FindFirstChild("rarity")
                    if rV then entry.rarity = tostring(rV.Value) end
                    local wV = eggObj:FindFirstChild("WeightKg") or eggObj:FindFirstChild("weightKg")
                    if wV then entry.weightKg = safeNum(wV.Value) end
                    local iV = eggObj:FindFirstChild("LiveRatePerSecond") or eggObj:FindFirstChild("ratePerSecond")
                    if iV then entry.ratePerSecond = safeNum(iV.Value) end
                end)
                table.insert(fieldEggs, entry)
            end
        end
    end)
    return fieldEggs
end

-- ============================================================
-- DEBUG HELPER — jalankan sekali untuk lihat struktur workspace
-- Hapus atau comment setelah dapat info yang dibutuhkan
-- ============================================================
local function debugSAEStructure()
    warn("[SagaDebug] === MULAI SCAN STRUKTUR SAE ===")

    -- 1. Scan workspace top-level
    pcall(function()
        local ws = game:GetService("Workspace")
        local names = {}
        for _, c in ipairs(ws:GetChildren()) do
            table.insert(names, c.Name .. "(" .. c.ClassName .. ")")
        end
        warn("[SagaDebug] Workspace children: " .. table.concat(names, ", "))
    end)

    -- 2. Scan ReplicatedStorage top-level
    pcall(function()
        local rs2 = game:GetService("ReplicatedStorage")
        local names = {}
        for _, c in ipairs(rs2:GetChildren()) do
            table.insert(names, c.Name .. "(" .. c.ClassName .. ")")
        end
        warn("[SagaDebug] ReplicatedStorage children: " .. table.concat(names, ", "))
    end)

    -- 3. Cari folder Remotes / Remote
    pcall(function()
        local rs2 = game:GetService("ReplicatedStorage")
        for _, name in ipairs({"Remotes","Remote","Events","Functions","Network"}) do
            local f = rs2:FindFirstChild(name)
            if f then
                local sub = {}
                for _, c in ipairs(f:GetChildren()) do
                    table.insert(sub, c.Name .. "(" .. c.ClassName .. ")")
                end
                warn("[SagaDebug] " .. name .. ": " .. table.concat(sub, ", "))
            end
        end
    end)

    -- 4. Cari leaderstats dan semua child player
    pcall(function()
        local childNames = {}
        for _, c in ipairs(lp:GetChildren()) do
            table.insert(childNames, c.Name .. "(" .. c.ClassName .. ")")
        end
        warn("[SagaDebug] LocalPlayer children: " .. table.concat(childNames, ", "))
    end)

    -- 5. Cari Bases/Plots di workspace
    pcall(function()
        local ws = game:GetService("Workspace")
        for _, folderName in ipairs({"Bases","Plots","PlayerPlots","Areas","Map","World","EggWorld"}) do
            local f = ws:FindFirstChild(folderName)
            if f then
                local sub = {}
                for _, c in ipairs(f:GetChildren()) do
                    table.insert(sub, c.Name)
                end
                warn("[SagaDebug] Workspace." .. folderName .. " (" .. #sub .. " items): " .. table.concat(sub, ", "):sub(1, 200))
            end
        end
    end)

    -- 6. Cari plot milik player
    pcall(function()
        local ws = game:GetService("Workspace")
        local function searchForPlot(parent, depth)
            if depth > 3 then return end
            for _, obj in ipairs(parent:GetChildren()) do
                -- Cek apakah ada Owner/OwnerUserId child
                local ownerV = obj:FindFirstChild("Owner") or obj:FindFirstChild("OwnerUserId")
                if ownerV and tostring(ownerV.Value) == tostring(lp.UserId) then
                    warn("[SagaDebug] PLOT DITEMUKAN: " .. obj:GetFullName())
                    -- Dump children plot
                    local plotChildren = {}
                    for _, pc in ipairs(obj:GetChildren()) do
                        table.insert(plotChildren, pc.Name .. "(" .. pc.ClassName .. ")")
                    end
                    warn("[SagaDebug] Plot children: " .. table.concat(plotChildren, ", "))
                end
                searchForPlot(obj, depth + 1)
            end
        end
        searchForPlot(ws, 0)
    end)

    -- 7. Cek __FYY_ACCESS_HANDOFF
    pcall(function()
        local ge2 = (getgenv and getgenv()) or _G
        local ho = rawget(ge2, "__FYY_ACCESS_HANDOFF")
        if ho then
            warn("[SagaDebug] Handoff keys: " .. table.concat((function()
                local k = {}
                for key in pairs(ho) do table.insert(k, tostring(key)) end
                return k
            end)(), ", "))
        else
            warn("[SagaDebug] Handoff: nil")
        end
    end)

    warn("[SagaDebug] === SCAN SELESAI ===")
end

-- Jalankan debug 3 detik setelah load
task.delay(3, debugSAEStructure)
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

        -- ── Session info (SagaHub handoff) ────────────────────────────
        pcall(function()
            if handoff and type(handoff.session) == "table" then
                stats.session = {
                    sessionId  = handoff.session.sessionId,
                    accessTier = handoff.session.accessTier,
                }
            end
        end)

        -- ── ReplicatedStorage PlayerData (generic gameData) ───────────
        pcall(function()
            local rs2 = game:GetService("ReplicatedStorage")
            local pdata = rs2:FindFirstChild("PlayerData")
                or rs2:FindFirstChild("Data")
                or rs2:FindFirstChild("GameData")
            if pdata then
                local mydata = pdata:FindFirstChild(tostring(lp.UserId))
                    or pdata:FindFirstChild(lp.Name)
                if mydata then
                    stats.gameData = {}
                    for _, v in ipairs(mydata:GetDescendants()) do
                        if v:IsA("NumberValue") or v:IsA("IntValue")
                            or v:IsA("StringValue") or v:IsA("BoolValue") then
                            stats.gameData[v.Name] = tostring(v.Value)
                        end
                    end
                end
            end
        end)
    end)

    -- ── Plot & Egg snapshot ───────────────────────────────────────────
    -- Coba dari WebhookRuntime dulu (paling lengkap)
    local rtSnapshot = getPlotSnapshotFromRuntime()
    if rtSnapshot and type(rtSnapshot) == "table" then
        stats.plotSnapshot = {
            income           = safeNum(rtSnapshot.income or rtSnapshot.incomePerSecond),
            incomeDisplay    = tostring(rtSnapshot.incomeDisplay or ""),
            speed            = safeNum(rtSnapshot.speed),
            capacity         = safeNum(rtSnapshot.capacity),
            plotLevel        = safeNum(rtSnapshot.plotLevel),
            plotMaxLevel     = safeNum(rtSnapshot.plotMaxLevel),
            treadmillLevel   = safeNum(rtSnapshot.treadmillLevel),
            treadmillMaxLevel= safeNum(rtSnapshot.treadmillMaxLevel),
            placedEggCount   = safeNum(rtSnapshot.placedEggs or rtSnapshot.placedEggCount),
            activePetCount   = safeNum(rtSnapshot.activePets or rtSnapshot.activePetCount),
            backpackEggCount = safeNum(rtSnapshot.backpackEggCount),
            backpackPetCount = safeNum(rtSnapshot.backpackPetCount),
        }
        -- latestDeposit dari snapshot
        if type(rtSnapshot.latestDeposit) == "table" then
            local d = rtSnapshot.latestDeposit
            stats.latestDeposit = {
                name          = tostring(d.name or d.item or ""),
                rarity        = tostring(d.rarity or ""),
                ratePerSecond = safeNum(d.ratePerSecond),
                weightKg      = safeNum(d.weightKg),
                areaId        = tostring(d.areaId or ""),
                mutations     = d.mutations or {},
                depositedAt   = safeNum(d.depositedAt),
            }
        end
        -- placedEggs list dari snapshot
        if type(rtSnapshot.placedEggs) == "table" then
            stats.placedEggs = {}
            for _, egg in ipairs(rtSnapshot.placedEggs) do
                if type(egg) == "table" then
                    table.insert(stats.placedEggs, {
                        name          = tostring(egg.name or egg.item or egg.uid or ""),
                        category      = tostring(egg.category or ""),
                        rarity        = tostring(egg.rarity or "Unknown"),
                        rarityRank    = safeNum(egg.rarityRank),
                        ratePerSecond = safeNum(egg.ratePerSecond),
                        weightKg      = safeNum(egg.weightKg),
                        scale         = safeNum(egg.scale or egg.AssetScale),
                        mutations     = type(egg.mutations) == "table" and egg.mutations or {},
                        baseMutation  = tostring(egg.baseMutation or ""),
                        areaId        = tostring(egg.areaId or ""),
                        placed        = egg.placed == true,
                    })
                end
            end
        end
    else
        -- Fallback: baca langsung dari workspace
        local wsPlot = getPlotStateFromWorkspace()
        if wsPlot and next(wsPlot) then
            stats.plotSnapshot = {
                income           = safeNum(wsPlot.income),
                speed            = safeNum(wsPlot.speed),
                capacity         = safeNum(wsPlot.capacity),
                plotLevel        = safeNum(wsPlot.plotLevel),
                plotMaxLevel     = safeNum(wsPlot.plotMaxLevel),
                treadmillLevel   = safeNum(wsPlot.treadmillLevel),
                treadmillMaxLevel= safeNum(wsPlot.treadmillMaxLevel),
                placedEggCount   = safeNum(wsPlot.placedEggCount),
                activePetCount   = safeNum(wsPlot.activePetCount),
                backpackEggCount = safeNum(wsPlot.backpackEggCount),
                backpackPetCount = safeNum(wsPlot.backpackPetCount),
            }
            if type(wsPlot.placedEggList) == "table" then
                stats.placedEggs = wsPlot.placedEggList
            end
        end

        -- Juga coba remote EggInventory
        local remoteEggs = getPlacedEggsFromRemote()
        if #remoteEggs > 0 and not stats.placedEggs then
            stats.placedEggs = remoteEggs
        end
    end

    -- ── Field eggs saat ini ───────────────────────────────────────────
    local fe = getFieldEggs()
    if #fe > 0 then
        stats.fieldEggs = fe
    end

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

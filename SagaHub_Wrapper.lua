--[[
================================================================================
  SAGAHUB WRAPPER
  Repo: https://github.com/Galangpratama-rox/Decode-SAE

  Auto-execute di executor (satu script untuk semua):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/SagaHub_Wrapper.lua"))()

  Yang dilakukan:
    1. Load SagaHub_OneFile (bypass + runtime)
    2. Tunggu runtime fully loaded
    3. Load SagaHub_Monitor (kirim data ke website monitoring)
================================================================================
--]]

local RAW = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/"

-- Tunggu game loaded
pcall(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
end)
task.wait(1)

-- 1. Load SagaHub OneFile (bypass + runtime)
local ok1, err1 = pcall(function()
    local src = game:HttpGet(RAW .. "SagaHub_OneFile.lua", true)
    loadstring(src)()
end)

if not ok1 then
    warn("[SagaHub] OneFile gagal: " .. tostring(err1))
    return
end

warn("[SagaHub] OneFile loaded — tunggu runtime...")
task.wait(6)

-- 2. Load Monitor
local ok2, err2 = pcall(function()
    local src = game:HttpGet(RAW .. "SagaHub_Monitor.lua", true)
    loadstring(src)()
end)

if not ok2 then
    warn("[SagaHub] Monitor gagal: " .. tostring(err2))
end

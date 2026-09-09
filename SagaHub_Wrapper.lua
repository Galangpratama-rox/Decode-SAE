--[[
================================================================================
  FYY COMMUNITY — WRAPPER
  Repo: https://github.com/Galangpratama-rox/Decode-SAE

  Auto-execute di executor:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/FyyCommunity_Wrapper.lua"))()

  KENAPA WRAPPER INI ADA:
    Script asli FyyCommunity CDN tidak bisa di-bypass dari luar karena
    mereka validate session di server. Wrapper ini menjalankan OneFile
    yang sudah embed semua bypass — keyless tanpa perlu key.
================================================================================
--]]

-- Tunggu game loaded dulu (anti-crash saat rejoin)
pcall(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
end)
task.wait(1.5)
pcall(function()
    local lp = game:GetService("Players").LocalPlayer
    if lp and not lp.Character then lp.CharacterAdded:Wait() end
end)
task.wait(0.5)

warn("[FyyWrapper] Memuat FyyCommunity OneFile...")

-- Jalankan OneFile yang sudah di-patch (keyless + bypass lengkap)
local ONEFILE_URL = "https://raw.githubusercontent.com/Galangpratama-rox/Decode-SAE/refs/heads/main/SagaHub_OneFile.lua"

local src, dlErr
for i = 1, 3 do
    local ok, res = pcall(function() return game:HttpGet(ONEFILE_URL, true) end)
    if ok and type(res) == "string" and #res > 1000 then
        src = res
        warn("[FyyWrapper] Download OK ("..#src.." bytes)")
        break
    end
    dlErr = tostring(res)
    warn("[FyyWrapper] Attempt "..i.." gagal: "..dlErr)
    if i < 3 then task.wait(2) end
end

if not src then
    warn("[FyyWrapper] Gagal download OneFile: "..tostring(dlErr))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "FyyWrapper ❌",
            Text  = "Gagal download. Cek koneksi.",
            Duration = 8,
        })
    end)
    return
end

local ok, err = pcall(loadstring(src))
if not ok then
    warn("[FyyWrapper] Error: "..tostring(err))
end

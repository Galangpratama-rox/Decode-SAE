--[[
================================================================================
  FYY COMMUNITY — ONEFILE STANDALONE EXECUTOR SCRIPT
  File  : source/FyyCommunity_OneFile.lua
================================================================================
  ✨ CARA PAKAI: BUKA FILE INI DI EXECUTOR (Solara / Script-Ware / dll)
                → LANGSUNG KLIK EXECUTE / INJECT.
  ✨ TIDAK BUTUH FOLDER / FILE LAIN APAPUN. SEMUA MODULE SUDAH INLINE.

  KANDUNGAN (100% inline di satu file):
   • 4 XOR Decoders       : i839AqOk, I7XobYa, Ns7EkuS, qu8xeC
   • Tny516 mini-VM       : PUSH(99) / CONCAT(164) / NOP(247)
   • p9smPy8V             : 32 library name keys
   • eX7N4                : 132 method/field keys
   • KkykK2E              : Method invoker (pengganti obj:method(a))
   • EnvBootstrap         : 4-level closure + executor detect + anti-debug
   • ⭐ PAYLOAD UTUH      : fyy_source_semi_deobfuscated.lua (1 baris 84KB)
================================================================================
--]]


-- ============================================================
-- [SECTION 1/5] FOUR XOR STRING DECODERS + Tny516 mini-VM
-- ============================================================

local FyyDecoders = {}
local _schar,_sbyte,_ssub,_srep,_tcat = string.char,string.byte,string.sub,string.rep,table.concat
local _tonumber, _pcall = tonumber, pcall

local function make_charset_decoder(_KEY_CHARS, _KH_EXPECTED, _M0, _L_MOD, _Q_MUL, _Q_SUB)
    local _KEY = ""
    for i = 1, #_KEY_CHARS do _KEY = _KEY .. _schar(_KEY_CHARS[i]) end
    local _KH = 0
    for _ki = 1, #_KEY do _KH = (_KH * 31 + _sbyte(_KEY, _ki)) % 65537 end
    local _C = {}
    for _yi = 1, #_KEY do _C[_ssub(_KEY, _yi, _yi)] = _yi end
    local _cache = {}
    return function(_E, ...)
        if _cache[_E] then return _cache[_E] end
        local _d, _m, _l, _i, _max = {}, _M0, 1, 1, #_E - 3
        while _i <= _max do
            local _c1, _c2 = _ssub(_E, _i, _i), _ssub(_E, _i + 1, _i + 1)
            local _P = _C[_c1] or 1
            local _O = _C[_c2] or 1
            local _K = (_P - 1) * 77 + (_O - 1)
            local _Q = (_K - _l * _L_MOD) % 256
            local _b = (_Q * _Q_MUL - _m - _Q_SUB) % 256
            _d[#_d + 1] = _schar(_b)
            _m, _l, _i = _b, _l + 1, _i + 4
        end
        local _r = _tcat(_d)
        _cache[_E] = _r
        return _r
    end
end

-- i839AqOk (_KH=19661, _m=11)
FyyDecoders.i839AqOk = make_charset_decoder({53,98,79,122,91,119,101,37,35,106,95,57,48,69,108,70,50,51,67,118,126,58,114,49,78,61,55,68,81,100,112,124,89,99,90,83,111,45,103,36,59,97,38,76,121,117,105,62,75,86,80,52,46,82,72,88,113,110,54,47,77,93,42,109,96,33,65,120,94,116,63,66,44,60,85,84,71},19661,11,11,197,97)

-- I7XobYa (_KH=10217, _m=49)
FyyDecoders.I7XobYa = make_charset_decoder({47,107,86,67,81,35,62,83,118,45,69,72,95,37,33,110,59,116,89,82,79,38,94,88,56,126,66,46,58,60,42,64,48,91,71,106,108,53,124,102,117,87,73,103,109,104,77,68,105,49,98,43,121,119,63,54,61,111,74,70,50,57,120,115,51,96,85,36,112,122,100,80,52,114,97,55,113},10217,49,49,219,102)

-- Ns7EkuS (_KH=33491, _m=6)
FyyDecoders.Ns7EkuS = make_charset_decoder({60,122,112,42,98,46,118,104,95,113,81,38,88,117,70,36,77,63,33,87,126,44,54,62,105,102,72,79,78,124,67,71,61,49,99,52,68,66,35,83,76,58,101,109,45,114,119,107,91,74,121,75,47,59,116,48,56,85,82,96,84,50,90,89,51,37,110,111,69,97,73,106,120,43,80,93,108},33491,6,6,223,88)

-- qu8xeC (HEX polynomial XOR)
do
    local _qu8_cache = {}
    local _a = {123, 41, 16, 21}
    local _s = 41
    local function _K(_i)
        local _x = (_i + _s) % 251
        local r, xp = 0, 1
        for _j = 1, 4 do
            r = (r + _a[_j] * xp) % 251
            xp = (xp * _x) % 251
        end
        return r % 256
    end
    FyyDecoders.qu8xeC = function(_E, ...)
        if _qu8_cache[_E] then return _qu8_cache[_E] end
        local _t, _n = {}, 0
        for _k = 1, #_E, 2 do
            _n = _n + 1
            local _b = _tonumber(_ssub(_E, _k, _k + 1), 16) or 0
            _t[_n] = _schar((_b - _K(_n - 1) + 768) % 256)
        end
        local _r = _tcat(_t)
        _qu8_cache[_E] = _r
        return _r
    end
end

-- Tny516 mini-VM: PUSH[99] / CONCAT[164] / NOP[247]
do
    local _fns = {FyyDecoders.i839AqOk,FyyDecoders.I7XobYa,FyyDecoders.Ns7EkuS,FyyDecoders.qu8xeC}
    local _ops = {}
    _ops[99] = function(_s, _n, _v)
        if _n >= 1 and _n <= 4 then _s[#_s + 1] = _fns[_n](_v) end
    end
    _ops[164] = function(_s)
        if #_s >= 2 then
            local _b = _s[#_s]; _s[#_s] = nil
            local _a = _s[#_s]; _s[#_s] = nil
            _s[#_s + 1] = _a .. _b
        end
    end
    _ops[247] = function(_s) end
    FyyDecoders.Tny516 = function(_p)
        local _s = {}
        for _i = 1, #_p do
            local instr = _p[_i]
            local op = instr[1]
            local _h = _ops[op]
            if _h then _h(_s, instr[2], instr[3]) end
        end
        return _s[#_s] or ""
    end
end

FyyDecoders.KkykK2E = function(_o, _k, ...) return _o[_k](_o, ...) end


-- ============================================================
-- [SECTION 2/5] LIBRARY KEY TABLES (p9smPy8V + eX7N4)
-- ============================================================

local FyyTables = {}

FyyTables.p9smPy8V = {
    [1] = "game",
    [2] = "Color3",
    [3] = "string",
    [4] = "type",
    [5] = "tonumber",
    [6] = "getgenv",
    [7] = "rawget",
    [8] = "identifyexecutor",
    [9] = "pcall",
    [10] = "ipairs",
    [11] = "tostring",
    [12] = "math",
    [13] = "bit32",
    [14] = "table",
    [15] = "task",
    [16] = "os",
    [17] = "typeof",
    [18] = "Instance",
    [19] = "pairs",
    [20] = "TweenInfo",
    [21] = "Enum",
    [22] = "syn",
    [23] = "UDim2",
    [24] = "Vector2",
    [25] = "UDim",
    [26] = "ColorSequence",
    [27] = "NumberSequence",
    [28] = "setclipboard",
    [29] = "loadstring",
    [30] = "xpcall",
    [31] = "debug",
    [32] = "warn",
}

local eX7N4 = {}
FyyTables.eX7N4 = eX7N4

eX7N4[1] = "fromRGB"
eX7N4[2] = "format"
eX7N4[3] = "byte"
eX7N4[4] = "char"
eX7N4[5] = "request"
eX7N4[6] = "floor"
eX7N4[7] = "bxor"
eX7N4[8] = "lshift"
eX7N4[9] = "rshift"
eX7N4[10] = "create"
eX7N4[11] = "ceil"
eX7N4[12] = "min"
eX7N4[13] = "concat"
eX7N4[14] = "rep"
eX7N4[15] = "LocalPlayer"
eX7N4[16] = "UserId"
eX7N4[17] = "JSONEncode"
eX7N4[18] = "StatusCode"
eX7N4[19] = "Status"
eX7N4[20] = "Body"
eX7N4[21] = "JSONDecode"
eX7N4[22] = "code"
eX7N4[23] = "error"
eX7N4[24] = "GameId"
eX7N4[25] = "spawn"
eX7N4[26] = "HttpGet"
eX7N4[27] = "clock"
eX7N4[28] = "wait"
eX7N4[29] = "PlaceId"
eX7N4[30] = "Name"
eX7N4[31] = "new"
eX7N4[32] = "Parent"
eX7N4[33] = "Quad"
eX7N4[34] = "EasingStyle"
eX7N4[35] = "Out"
eX7N4[36] = "EasingDirection"
eX7N4[37] = "Destroy"
eX7N4[38] = "Sibling"
eX7N4[39] = "ZIndexBehavior"
eX7N4[40] = "protect_gui"
eX7N4[41] = "fromScale"
eX7N4[42] = "Backdrop"
eX7N4[43] = "fromOffset"
eX7N4[44] = "Surface"
eX7N4[45] = "Border"
eX7N4[46] = "Accent"
eX7N4[47] = "Text"
eX7N4[48] = "Fit"
eX7N4[49] = "ScaleType"
eX7N4[50] = "GothamBold"
eX7N4[51] = "Font"
eX7N4[52] = "Left"
eX7N4[53] = "TextXAlignment"
eX7N4[54] = "GothamMedium"
eX7N4[55] = "upper"
eX7N4[56] = "Muted"
eX7N4[57] = "SurfaceHigh"
eX7N4[58] = "Horizontal"
eX7N4[59] = "FillDirection"
eX7N4[60] = "Center"
eX7N4[61] = "HorizontalAlignment"
eX7N4[62] = "VerticalAlignment"
eX7N4[63] = "LayoutOrder"
eX7N4[64] = "SortOrder"
eX7N4[65] = "AccentHigh"
eX7N4[66] = "X"
eX7N4[67] = "AutomaticSize"
eX7N4[68] = "TextYAlignment"
eX7N4[69] = "Gotham"
eX7N4[70] = "Top"
eX7N4[71] = "Faint"
eX7N4[72] = "MouseEnter"
eX7N4[73] = "Active"
eX7N4[74] = "MouseLeave"
eX7N4[75] = "AtEnd"
eX7N4[76] = "TextTruncate"
eX7N4[77] = "Sine"
eX7N4[78] = "Visible"
eX7N4[79] = "TextColor3"
eX7N4[80] = "clamp"
eX7N4[81] = "Back"
eX7N4[82] = "TextTransparency"
eX7N4[83] = "InputBegan"
eX7N4[84] = "UserInputType"
eX7N4[85] = "MouseButton1"
eX7N4[86] = "Touch"
eX7N4[87] = "Position"
eX7N4[88] = "InputChanged"
eX7N4[89] = "MouseMovement"
eX7N4[90] = "Y"
eX7N4[91] = "InputEnded"
eX7N4[92] = "Quart"
eX7N4[93] = "In"
eX7N4[94] = "Enabled"
eX7N4[95] = "Error"
eX7N4[96] = "BackgroundColor3"
eX7N4[97] = "delay"
eX7N4[98] = "Success"
eX7N4[99] = "setclipboard"
eX7N4[100] = "MouseButton1Click"
eX7N4[101] = "transportKey"
eX7N4[102] = "sessionId"
eX7N4[103] = "sessionToken"
eX7N4[104] = "challengeId"
eX7N4[105] = "state"
eX7N4[106] = "session"
eX7N4[107] = "continuityCredential"
eX7N4[108] = "accessTier"
eX7N4[109] = "licenseType"
eX7N4[110] = "nextHeartbeatSeconds"
eX7N4[111] = "__FYY_ACCESS_HANDOFF"
eX7N4[112] = "traceback"
eX7N4[113] = "TextEditable"
eX7N4[114] = "defer"
eX7N4[115] = "CaptureFocus"
eX7N4[116] = "status"
eX7N4[117] = "FocusLost"
eX7N4[118] = "data"
eX7N4[119] = "mode"
eX7N4[120] = "GetService"
eX7N4[121] = "gsub"
eX7N4[122] = "find"
eX7N4[123] = "lower"
eX7N4[124] = "match"
eX7N4[125] = "GenerateGUID"
eX7N4[126] = "GetClientId"
eX7N4[127] = "GetProductInfo"
eX7N4[128] = "Create"
eX7N4[129] = "Play"
eX7N4[130] = "FindFirstChild"
eX7N4[131] = "Connect"
eX7N4[132] = "sub"

function FyyTables.build_hH45k3O(_G_env)
    local _env = _G_env or (getgenv and getgenv()) or getfenv() or _G
    local hH45k3O = {}
    for idx, lib_name in pairs(FyyTables.p9smPy8V) do
        local ok, val = pcall(function() return _env[lib_name] end)
        if ok and val ~= nil then hH45k3O[lib_name] = val end
    end
    return hH45k3O
end


-- ============================================================
-- [SECTION 3/5] ENVIRONMENT BOOTSTRAP (4 closure wrapper)
-- ============================================================

local EnvBootstrap = {}

function EnvBootstrap.get_root_env()
    local ok, fe = pcall(function() return getfenv() end)
    if ok and fe then return fe end
    local ok2, gg = pcall(function() return getgenv() end)
    if ok2 and gg then return gg end
    return _G
end

function EnvBootstrap.wrap4levels(payload_fn)
    return function(Vj0r0XiN, ...)
        return (function(env2, ...)
            return (function(env3, ...)
                return (function(empty_env, ...)
                    return payload_fn(empty_env or {}, Vj0r0XiN, env2, env3, ...)
                end)({})
            end)({})
        end)(Vj0r0XiN, nil,nil,nil,nil,nil,nil,nil,nil,nil,nil)
    end
end

function EnvBootstrap.detect_executor(hH45k3O)
    local _rawget = hH45k3O.rawget or rawget
    local ok_gg, ge = pcall(function() return getgenv and getgenv() end)
    local env = ok_gg and ge or {}
    if hH45k3O.identifyexecutor then
        local ok, n = pcall(hH45k3O.identifyexecutor)
        if ok and n and type(n) == "string" and #n > 0 then return n end
    end
    if env.SOLARA_LOADED or _rawget(env, "SOLARA_LOADED") then return "Solara" end
    if env.is_xeno then return "Xeno" end
    if env.syn then return "Synapse" end
    local ok3, re = pcall(function() return getrenv and getrenv() end)
    if ok3 and type(re) == "table" and _rawget(re, "solara") then return "Solara" end
    return "Unknown"
end


-- ============================================================
-- [SECTION 4/5] INISIALISASI + INJECT MODULE GLOBAL KE ENV
-- ============================================================

local root_env    = EnvBootstrap.get_root_env()
local hH45k3O     = FyyTables.build_hH45k3O(root_env)
local p9smPy8V    = FyyTables.p9smPy8V
local eX7N4       = FyyTables.eX7N4
local KkykK2E     = FyyDecoders.KkykK2E
local i839AqOk    = FyyDecoders.i839AqOk
local I7XobYa     = FyyDecoders.I7XobYa
local Ns7EkuS     = FyyDecoders.Ns7EkuS
local qu8xeC      = FyyDecoders.qu8xeC
local Tny516      = FyyDecoders.Tny516
local executor    = EnvBootstrap.detect_executor(hH45k3O)

-- Inject semua module ini ke environment global (supaya PAYLOAD bisa menemukannya
-- meskipun source-nya masih refer nama-nama random Tu669bhFa index)
do
    root_env.hH45k3O  = hH45k3O
    root_env.p9smPy8V = p9smPy8V
    root_env.eX7N4    = eX7N4
    root_env.KkykK2E  = KkykK2E
    root_env.i839AqOk = i839AqOk
    root_env.I7XobYa  = I7XobYa
    root_env.Ns7EkuS  = Ns7EkuS
    root_env.qu8xeC   = qu8xeC
    root_env.Tny516   = Tny516
    root_env.__FyyOneFile = true
end


-- ============================================================
-- [SECTION 5/5] EXECUTE PAYLOAD (semi_deobfuscated.lua 84KB)
-- ============================================================

local __FYY_PAYLOAD_SRC = 
[======[
return(function(Vj0r0XiN,...) do local _sc=string.char local m4x8OT=Vj0r0XiN local _ty=m4x8OT["type"]local _pc=m4x8OT["pcall"]local _rg0=m4x8OT["rawget"] if not _ty or not _pc or not _rg0 then return end local _d=m4x8OT["debug"] if _d then local _rg=m4x8OT["rawget"] local VOI7GE=(_rg and _rg(_d,"gethook"))or _d["gethook"] if _ty(VOI7GE)=="function" then local ZEJy6,o51MKf=_pc(VOI7GE) if ZEJy6 and o51MKf~=nil then return end end end local _gr=m4x8OT["getrawmetatable"] local _ie=m4x8OT["isexecutorclosure"]or m4x8OT["isourclosure"] local _g0=m4x8OT["game"] if _ty(_gr)=="function"and _ty(_ie)=="function"and _g0 then local ZEJy6,y7I5fF42=_pc(_gr,_g0) if ZEJy6 and _ty(y7I5fF42)=="table" then local c6ggdc4l=_rg0(y7I5fF42,"__index") local r43EMA97b=_rg0(y7I5fF42,"__namecall") local _oi,_vi=_pc(_ie,c6ggdc4l) local _on,_vn=_pc(_ie,r43EMA97b) if(_oi and _vi)or(_on and _vn)then return end end end end local i839AqOk do local _KEY="5bOz[w".."e%#j_90ElF23Cv~:r1N=7DQdp|YcZSo-g$;a&Lyui"..">KVP4.RHXqn6/M]*m`!Ax^t?B,<UTG" local _C={} for _yi=1,#_KEY,1 do _C[_KEY:sub(_yi,_yi)]=_yi end local _KH=0 do local _ks=_KEY for _ki=1,#_ks do _KH=(_KH*31+_ks:byte(_ki))%65537 end end local _cache={} local _u=string.char function i839AqOk(_E,...) if _cache[_E]then return _cache[_E]end if(typeof~=_u(110,105,108)and typeof or type)(game)~=_u(73,110,115,116,97,110,99,101)then return string.rep("\0",#_E)end if _KH~=19661 then return string.rep("\0",10)end local _d={} local _m=11 local _l=1 local _i=1 while _i<=#_E-3 do local _c1=string.sub(_E,_i,_i) local _c2=string.sub(_E,_i+1,_i+1) local _P=_C[_c1]or 1 local _O=_C[_c2]or 1 local _K=(_P-1)*77+(_O-1) local _Q=(_K-_l*11)%256 local _b=(_Q*197-_m-97)%256 _d[#_d+1]=_u(_b) _m=_b _l=_l+1 _i=_i+4 end local _r=table.concat(_d) _cache[_E]=_r return _r end end local I7XobYa do local _KEY="/kVCQ#>S".."v-EH_%!n;tYRO&^X8~B.:<*@0[Gjl5|fuWIgmhMDi1b+".."yw?6=oJF29xs3`U$pzdP4ra7q" local _C={} for _yi=1,#_KEY,1 do _C[_KEY:sub(_yi,_yi)]=_yi end local _KH=0 do local _ks=_KEY for _ki=1,#_ks do _KH=(_KH*31+_ks:byte(_ki))%65537 end end local _cache={} local _u=string.char function I7XobYa(_E,...) if _cache[_E]then return _cache[_E]end if(typeof~=_u(110,105,108)and typeof or type)(game)~=_u(73,110,115,116,97,110,99,101)then return string.rep("\0",#_E)end if _KH~=10217 then return string.rep("\0",10)end local _d={} local _m=49 local _l=1 local _i=1 while _i<=#_E-3 do local _c1=string.sub(_E,_i,_i) local _c2=string.sub(_E,_i+1,_i+1) local _P=_C[_c1]or 1 local _O=_C[_c2]or 1 local _K=(_P-1)*77+(_O-1) local _Q=(_K-_l*49)%256 local _b=(_Q*219-_m-102)%256 _d[#_d+1]=_u(_b) _m=_b _l=_l+1 _i=_i+4 end local _r=table.concat(_d) _cache[_E]=_r return _r end end local Ns7EkuS do local _KEY="<zp*b.vh_qQ&XuF$M?!W~,".."6>ifHON|CG=1c4DB#SL"..":em-rwk[JyK/;t08UR`T2ZY3%noEaIjx+P]l" local _C={} for _yi=1,#_KEY,1 do _C[_KEY:sub(_yi,_yi)]=_yi end local _KH=0 do local _ks=_KEY for _ki=1,#_ks do _KH=(_KH*31+_ks:byte(_ki))%65537 end end local _cache={} local _u=string.char function Ns7EkuS(_E,...) if _cache[_E]then return _cache[_E]end if(typeof~=_u(110,105,108)and typeof or type)(game)~=_u(73,110,115,116,97,110,99,101)then return string.rep("\0",#_E)end if _KH~=33491 then return string.rep("\0",10)end local _d={} local _m=6 local _l=1 local _i=1 while _i<=#_E-3 do local _c1=string.sub(_E,_i,_i) local _c2=string.sub(_E,_i+1,_i+1) local _P=_C[_c1]or 1 local _O=_C[_c2]or 1 local _K=(_P-1)*77+(_O-1) local _Q=(_K-_l*6)%256 local _b=(_Q*223-_m-88)%256 _d[#_d+1]=_u(_b) _m=_b _l=_l+1 _i=_i+4 end local _r=table.concat(_d) _cache[_E]=_r return _r end end local qu8xeC do local _a={123,41,16,21} local _s=41 local _ch={} local function _K(_i) local _x=(_i+_s)%251 local _r=0 local _xp=1 for _j=1,#_a do _r=(_r+_a[_j]*_xp)%251 _xp=(_xp*_x)%251 end return _r%256 end function qu8xeC(_E,...) if _ch[_E]then return _ch[_E]end if(typeof~="nil"and typeof or type)(game)~="Instance"then return string.rep("\0",#_E)end local _t={} local _n=0 for _k=1,#_E,2 do _n=_n+1 local _b=tonumber(_E:sub(_k,_k+1),16)or 0 _t[_n]=string.char((_b-_K(_n-1)+768)%256)end local _r=table.concat(_t) _ch[_E]=_r return _r end end if "GetService|UserInputService|CoreGui|LocalPlayer|Destroy"~="GetService|UserInputService|CoreGui|LocalPlayer|Destroy" then return end if "GetService|UserInputService|CoreGui|LocalPlayer|Destroy"~="GetService|UserInputService|CoreGui|LocalPlayer|Destroy" then return end if "GetService|UserInputService|CoreGui|LocalPlayer|Destroy"~="GetService|UserInputService|CoreGui|LocalPlayer|Destroy" then return end if "GetService|UserInputService|CoreGui|LocalPlayer|Destroy"~="GetService|UserInputService|CoreGui|LocalPlayer|Destroy" then return end return(function(hH45k3O,bji0b1,cil1q,Xo4rHi,Qe7F090oL,Xx7vdSeb,HeYDU56,KNjg6,wcCZ8wj,C3YyJ,x8A2WuOrt,...) do local Q5H0ZeF6V,ZD0GXHl1H=pcall(function() local _a="FYY" local _b="FYY" return _a==_b and type(pcall)=="function" and string.byte("ÿ")==255 end) if not Q5H0ZeF6V or not ZD0GXHl1H then return end end if not hH45k3O["game"] or (hH45k3O["tonumber"](hH45k3O["game"]["PlaceId"]) or 0) <= 0 then return end local h9Icxco=(typeof~="nil"and typeof or type) if h9Icxco(1337)~="number" then return end if type("")~=h9Icxco("") then return end local Ua9FG1Y5,iPA3gWZ=hH45k3O["pcall"]( function() return hH45k3O["game"]["GetService"]( hH45k3O["game"],"CoreGui") end) if not Ua9FG1Y5 or not iPA3gWZ then return end do local h4JBGYuE=table.concat({"rGWY8","FB0kF"}) end local z3i6I72s=(typeof~="nil"and typeof or type) if z3i6I72s(hH45k3O["game"])~="Instance" then return end do local Z5RRsV65=(9 > 0 and "ss3Jo" or "wx125") if (select("#")==1) then Z5RRsV65=nil end end local PGmS3Vu0 hH45k3O["pcall"]( function() PGmS3Vu0=hH45k3O["game"]["GetService"]( hH45k3O["game"],"Players" )["LocalPlayer"] end) if not PGmS3Vu0 then return end if (string.byte("Z")==90) then local w072TREL=string.rep("S074p",5) end local qgVoZS4,eSeQ3C hH45k3O["pcall"]( function() local _g=hH45k3O["game"] local _uid=_g["GetService"](_g,"Players")["LocalPlayer"]["UserId"] local _pid=_g["PlaceId"] qgVoZS4=bit32.bxor(math.abs(math.floor(_uid)),math.abs(math.floor(_pid))) local _uid2=_g["GetService"](_g,"Players")["LocalPlayer"]["UserId"] local _pid2=_g["PlaceId"] eSeQ3C=bit32.bxor(math.abs(math.floor(_uid2)),math.abs(math.floor(_pid2))) end) if type(qgVoZS4)~="number"or type(eSeQ3C)~="number"or qgVoZS4~=eSeQ3C then return end if not hH45k3O["game"] or (hH45k3O["tonumber"](hH45k3O["game"]["GameId"]) or 0) <= 0 then return end local QyOJd15x,k8gvNZb=hH45k3O["pcall"]( function() return hH45k3O["game"]["GetService"]( hH45k3O["game"],"UserInputService") end) if not QyOJd15x or not k8gvNZb then return end do local vSWrX7vC=type(v5pKnj)..tostring(920) if (2570-2570-1)>0 then vSWrX7vC=nil end end local vOZm1 hH45k3O["pcall"]( function() vOZm1=hH45k3O["game"]["GetService"]( hH45k3O["game"],"Players" )["LocalPlayer"]["UserId"] end) if type(vOZm1)~="number"or vOZm1<=0 then return end local Jo15Y,Nx12C=hH45k3O["pcall"]( function() return hH45k3O["game"]["GetService"]( hH45k3O["game"],"RunService") end) if not Jo15Y or not Nx12C then return end if (select("#",20,46)==2) then local nl11NMt1R=string.rep("U2Ecw",5) end local p9smPy8V={}
p9smPy8V[1]="game"
p9smPy8V[2]="Color3"
p9smPy8V[3]="string"
p9smPy8V[4]="type"
p9smPy8V[5]="tonumber"
p9smPy8V[6]="getgenv"
p9smPy8V[7]="rawget"
p9smPy8V[8]="identifyexecutor"
p9smPy8V[9]="pcall"
p9smPy8V[10]="ipairs"
p9smPy8V[11]="tostring"
p9smPy8V[12]="math"
p9smPy8V[13]="bit32"
p9smPy8V[14]="table"
p9smPy8V[15]="task"
p9smPy8V[16]="os"
p9smPy8V[17]="typeof"
p9smPy8V[18]="Instance"
p9smPy8V[19]="pairs"
p9smPy8V[20]="TweenInfo"
p9smPy8V[21]="Enum"
p9smPy8V[22]="syn"
p9smPy8V[23]="UDim2"
p9smPy8V[24]="Vector2"
p9smPy8V[25]="UDim"
p9smPy8V[26]="ColorSequence"
p9smPy8V[27]="NumberSequence"
p9smPy8V[28]="setclipboard"
p9smPy8V[29]="loadstring"
p9smPy8V[30]="xpcall"
p9smPy8V[31]="debug"
p9smPy8V[32]="warn"
local eX7N4={}
eX7N4[1]="fromRGB"
eX7N4[2]="format"
eX7N4[3]="byte"
eX7N4[4]="char"
eX7N4[5]="request"
eX7N4[6]="floor"
eX7N4[7]="bxor"
eX7N4[8]="lshift"
eX7N4[9]="rshift"
eX7N4[10]="create"
eX7N4[11]="ceil"
eX7N4[12]="min"
eX7N4[13]="concat"
eX7N4[14]="rep"
eX7N4[15]="LocalPlayer"
eX7N4[16]="UserId"
eX7N4[17]="JSONEncode"
eX7N4[18]="StatusCode"
eX7N4[19]="Status"
eX7N4[20]="Body"
eX7N4[21]="JSONDecode"
eX7N4[22]="code"
eX7N4[23]="error"
eX7N4[24]="GameId"
eX7N4[25]="spawn"
eX7N4[26]="HttpGet"
eX7N4[27]="clock"
eX7N4[28]="wait"
eX7N4[29]="PlaceId"
eX7N4[30]="Name"
eX7N4[31]="new"
eX7N4[32]="Parent"
eX7N4[33]="Quad"
eX7N4[34]="EasingStyle"
eX7N4[35]="Out"
eX7N4[36]="EasingDirection"
eX7N4[37]="Destroy"
eX7N4[38]="Sibling"
eX7N4[39]="ZIndexBehavior"
eX7N4[40]="protect_gui"
eX7N4[41]="fromScale"
eX7N4[42]="Backdrop"
eX7N4[43]="fromOffset"
eX7N4[44]="Surface"
eX7N4[45]="Border"
eX7N4[46]="Accent"
eX7N4[47]="Text"
eX7N4[48]="Fit"
eX7N4[49]="ScaleType"
eX7N4[50]="GothamBold"
eX7N4[51]="Font"
eX7N4[52]="Left"
eX7N4[53]="TextXAlignment"
eX7N4[54]="GothamMedium"
eX7N4[55]="upper"
eX7N4[56]="Muted"
eX7N4[57]="SurfaceHigh"
eX7N4[58]="Horizontal"
eX7N4[59]="FillDirection"
eX7N4[60]="Center"
eX7N4[61]="HorizontalAlignment"
eX7N4[62]="VerticalAlignment"
eX7N4[63]="LayoutOrder"
eX7N4[64]="SortOrder"
eX7N4[65]="AccentHigh"
eX7N4[66]="X"
eX7N4[67]="AutomaticSize"
eX7N4[68]="TextYAlignment"
eX7N4[69]="Gotham"
eX7N4[70]="Top"
eX7N4[71]="Faint"
eX7N4[72]="MouseEnter"
eX7N4[73]="Active"
eX7N4[74]="MouseLeave"
eX7N4[75]="AtEnd"
eX7N4[76]="TextTruncate"
eX7N4[77]="Sine"
eX7N4[78]="Visible"
eX7N4[79]="TextColor3"
eX7N4[80]="clamp"
eX7N4[81]="Back"
eX7N4[82]="TextTransparency"
eX7N4[83]="InputBegan"
eX7N4[84]="UserInputType"
eX7N4[85]="MouseButton1"
eX7N4[86]="Touch"
eX7N4[87]="Position"
eX7N4[88]="InputChanged"
eX7N4[89]="MouseMovement"
eX7N4[90]="Y"
eX7N4[91]="InputEnded"
eX7N4[92]="Quart"
eX7N4[93]="In"
eX7N4[94]="Enabled"
eX7N4[95]="Error"
eX7N4[96]="BackgroundColor3"
eX7N4[97]="delay"
eX7N4[98]="Success"
eX7N4[99]="setclipboard"
eX7N4[100]="MouseButton1Click"
eX7N4[101]="transportKey"
eX7N4[102]="sessionId"
eX7N4[103]="sessionToken"
eX7N4[104]="challengeId"
eX7N4[105]="state"
eX7N4[106]="session"
eX7N4[107]="continuityCredential"
eX7N4[108]="accessTier"
eX7N4[109]="licenseType"
eX7N4[110]="nextHeartbeatSeconds"
eX7N4[111]="__FYY_ACCESS_HANDOFF"
eX7N4[112]="traceback"
eX7N4[113]="TextEditable"
eX7N4[114]="defer"
eX7N4[115]="CaptureFocus"
eX7N4[116]="status"
eX7N4[117]="FocusLost"
eX7N4[118]="data"
eX7N4[119]="mode"
eX7N4[120]="GetService"
eX7N4[121]="gsub"
eX7N4[122]="find"
eX7N4[123]="lower"
eX7N4[124]="match"
eX7N4[125]="GenerateGUID"
eX7N4[126]="GetClientId"
eX7N4[127]="GetProductInfo"
eX7N4[128]="Create"
eX7N4[129]="Play"
eX7N4[130]="FindFirstChild"
eX7N4[131]="Connect"
eX7N4[132]="sub"
local KkykK2E=function(_o,_k,...)return _o[_k](_o,...)end local bljY6f9Xt={} bljY6f9Xt[8418]=Ns7EkuS bljY6f9Xt[2691]=I7XobYa bljY6f9Xt[2006]=i839AqOk bljY6f9Xt[5807]=qu8xeC local i839AqOk=bljY6f9Xt[2006] local I7XobYa=bljY6f9Xt[2691] local Ns7EkuS=bljY6f9Xt[8418] local qu8xeC=bljY6f9Xt[5807] local Tny516 do local _fns={i839AqOk,I7XobYa,Ns7EkuS,qu8xeC} local _ops={} _ops[99]=function(_s,_n,_v) _s[#_s+1]=_fns[_n](_v) end _ops[164]=function(_s) local _b=_s[#_s] _s[#_s]=nil local _a=_s[#_s] _s[#_s]=nil _s[#_s+1]=_a.._b end _ops[247]=function(_s) end function Tny516(_p) local _s={} for _,_i in ipairs(_p) do local _h=_ops[_i[1]] if _h then _h(_s,_i[2],_i[3]) end end return _s[#_s] end end return(function(Tu669bhFa) Tu669bhFa[(200-20)] = KkykK2E(hH45k3O["game"],"GetService","Twee".."nSer".."vice") Tu669bhFa[(-588579-(-588768))] = KkykK2E(hH45k3O["game"],"GetService","Core".."Gui") Tu669bhFa[(0xD7)] = KkykK2E(hH45k3O["game"],"GetService","UserInpu".."tService") Tu669bhFa[(-361316-(-361538))] = KkykK2E(hH45k3O["game"],"GetService","Pla".."yer".."s") Tu669bhFa[(0xE7)] = KkykK2E(hH45k3O["game"],"GetService","HttpService") Tu669bhFa[(0xFA)] = KkykK2E(hH45k3O["game"],"GetService","Marketpla".."ceService") Tu669bhFa[(133*2)] = KkykK2E(hH45k3O["game"],"GetService","RbxAnalyticsService") Tu669bhFa[(0x124)] = ("FyyCom".."munity".."Loader") Tu669bhFa[(363-58)] = "2.2.0" Tu669bhFa[(-860680-(-861001))] = (1) Tu669bhFa[(0x15A)] = ("https://".."fyycommu".."nity.com") Tu669bhFa[(195+164)] = "https://discord.gg/pH3u8bBZsJ" Tu669bhFa[(-144956-(-145328))] = "https://fyycommunity.com/free" Tu669bhFa[(110+289)] = ("FyyC".."ommu".."nity") Tu669bhFa[(270+140)] = Tu669bhFa[(491-92)] .. ("/lic".."ense"..".key") Tu669bhFa[(0x1A8)] = true Tu669bhFa[(-318830-(-319272))] = ("9e5e1d5bb0".."314168b68d".."8514de9b99".."b465e55e19") Tu669bhFa[(0x1CD)] = { [5750914919] = "FyyFishCENC.lua", [6739698191] = ("FyyV".."DENC"..".lua"), [10563114921] = ("FyyStealAn".."EggENC.lua"), } Tu669bhFa[(268+218)] = { ["Backdrop"] = hH45k3O["Color3"]["fromRGB"]((1*5), (0x7), (5*2)), ["Surface"] = hH45k3O["Color3"]["fromRGB"]((33-16), (20+1), (0x1B)), ["SurfaceHigh"] = hH45k3O["Color3"]["fromRGB"]((-589853-(-589877)), (0x1D), (69-32)), ["Border"] = hH45k3O["Color3"]["fromRGB"]((0x30), (-688509-(-688565)), (66+2)), ["Text"] = hH45k3O["Color3"]["fromRGB"]((-661678-(-661921)), (-522216-(-522462)), (125*2)), ["Muted"] = hH45k3O["Color3"]["fromRGB"]((-651252-(-651398)), (0x9C), (85*2)), ["Faint"] = hH45k3O["Color3"]["fromRGB"]((13*7), (79+22), (-642586-(-642702))), ["Accent"] = hH45k3O["Color3"]["fromRGB"]((25*5), (-963219-(-963320)), (179+76)), ["AccentHigh"] = hH45k3O["Color3"]["fromRGB"]((83*2), (167-19), (-623304-(-623559))), ["Success"] = hH45k3O["Color3"]["fromRGB"]((-555394-(-555461)), (152+55), (-608718-(-608857))), ["Error"] = hH45k3O["Color3"]["fromRGB"]((63+176), (-738438-(-738530)), (0x69)), } Tu669bhFa[(0x5AB)]=function(EhpV4b5) return (EhpV4b5["gsub"](EhpV4b5,".",function(Ft5OP2e8) return hH45k3O["string"]["format"]("%02x", hH45k3O["string"]["byte"](Ft5OP2e8)) end)) end Tu669bhFa[(-387962-(-389427))]=function(EhpV4b5) if hH45k3O["type"](EhpV4b5) ~= "string" or #EhpV4b5 % (1*2) ~= (0) or EhpV4b5["find"](EhpV4b5,"[^%d".."a-fA".."-F]") then return nil end return (EhpV4b5["gsub"](EhpV4b5,"..",function(W9Eax) return hH45k3O["string"]["char"](hH45k3O["tonumber"](W9Eax, (0x10))) end)) end Tu669bhFa[(744*2)]=function(Z05yW) return(function(i7C3e) i7C3e[(2148-33)] = (hH45k3O["getgenv"] and hH45k3O["getgenv"]()) or _G i7C3e[(2177-38)] = hH45k3O["rawget"](i7C3e[(705*3)], Z05yW) if hH45k3O["type"](i7C3e[(0x85B)]) == "function" then return i7C3e[(713*3)] end i7C3e[(869+1270)] = hH45k3O["rawget"](_G, Z05yW) return hH45k3O["type"](i7C3e[(2148-9)]) == "function") and i7C3e[(713*3)] or nil end)({}) end Tu669bhFa[(0x5DB)]=function() return(function(NuW67) NuW67[(0x86D)] = (hH45k3O["getgenv"] and hH45k3O["getgenv"]()) or _G NuW67[(0x882)] = hH45k3O["rawget"](NuW67[(2199-42)], "syn") return hH45k3O["rawget"](NuW67[(719*3)], "request") or hH45k3O["rawget"](NuW67[(0x86D)], ("http".."_req".."uest") or (hH45k3O["type"](NuW67[(1089*2)]) == "table" and NuW67[(1089*2)]["request"]) end)({}) end Tu669bhFa[(0x5EF)]=function() return(function(v1tI6X) v1tI6X[(1200+992)] = hH45k3O["identifyexecutor"] or getexecutorname if hH45k3O["type"](v1tI6X[(-671166-(-673358))]) == "function" then v1tI6X[(0x89F)], v1tI6X[(137+2098)] = hH45k3O["pcall"](v1tI6X[(750+1442)]) if v1tI6X[(2223-16)] and hH45k3O["type"](v1tI6X[(-886690-(-888925))]) == "string") and v1tI6X[(2240-5)] ~= "" then return v1tI6X[(745*3)] end end v1tI6X[(0x8CE)] = (hH45k3O["getgenv"] and hH45k3O["getgenv"]()) or _G for V5J6oh, SvVZ1Dh in hH45k3O["ipairs"]({ ("identify".."executor"), ("getexecu".."torname") }) do v1tI6X[(2328-54)] = hH45k3O["rawget"](v1tI6X[(1127*2)], SvVZ1Dh) if hH45k3O["type"](v1tI6X[(1137*2)]) == "function") then v1tI6X[(2150+146)], v1tI6X[(1369+952)] = hH45k3O["pcall"](v1tI6X[(2303-29)]) if v1tI6X[(-406542-(-408838))] and hH45k3O["type"](v1tI6X[(-177294-(-179615))]) == "string" and v1tI6X[(1717+604)] ~= "" then return v1tI6X[(211*11)] end end end if hH45k3O["rawget"](v1tI6X[(-568550-(-570804))], ("XENO".."_LOA".."DED") or hH45k3O["rawget"](v1tI6X[(0x8CE)], "is_xeno") then return "Xeno" end if hH45k3O["rawget"](v1tI6X[(2308-54)], "SOLARA_LOADED") or hH45k3O["rawget"](v1tI6X[(1127*2)], ("is_".."sol".."ara") then return "Solara" end return "Unknown" end)({}) end Tu669bhFa[(1042+495)]=function() return(function(lmd2Oi) lmd2Oi[(2435-91)] = KkykK2E(Tu669bhFa[(134+1385)](),"lower") return KkykK2E(lmd2Oi[(0x928)],"find","xeno") ~= nil or KkykK2E(lmd2Oi[(-134271-(-136615))],"find","solara") ~= nil end)({}) end Tu669bhFa[(1405+150)]=function(EhpV4b5) EhpV4b5 = KkykK2E(KkykK2E(hH45k3O["tostring"](EhpV4b5 or ""),"upper"),"gsub","%s+","") if #EhpV4b5 > (-252886-(-253014)) or not (EhpV4b5["match"](EhpV4b5,"^FYY%-") or EhpV4b5["match"](EhpV4b5,"^TRIAL%-")) then return nil end return EhpV4b5 end Tu669bhFa[(1234+334)]=function() return(function(Esb4K3Yc5) Esb4K3Yc5[(0x93E)] = Tu669bhFa[(274+1214)]("readfile") if not Esb4K3Yc5[(1183*2)] then return nil end Esb4K3Yc5[(475*5)] = Tu669bhFa[(1442+46)]("isfile") if Esb4K3Yc5[(-781703-(-784078))] then Esb4K3Yc5[(0x956)], Esb4K3Yc5[(2135+284)] = hH45k3O["pcall"](Esb4K3Yc5[(2378-3)], Tu669bhFa[(205*2)]) if not Esb4K3Yc5[(-562313-(-564703))] or not Esb4K3Yc5[(0x973)] then return nil end end Esb4K3Yc5[(2488-47)], Esb4K3Yc5[(1228*2)] = hH45k3O["pcall"](Esb4K3Yc5[(-896789-(-899155))], Tu669bhFa[(-275687-(-276097))]) return Esb4K3Yc5[(-318054-(-320495))] and Tu669bhFa[(311*5)](Esb4K3Yc5[(1228*2)]) or nil end)({}) end Tu669bhFa[(-862234-(-863825))]=function(EhpV4b5) return(function(Z6KQpY) Z6KQpY[(1240*2)] = Tu669bhFa[(0x5D0)](("write".."file") if not Z6KQpY[(2527-47)] then return false end Z6KQpY[(0x9B8)] = Tu669bhFa[(552+936)]("makefolder") Z6KQpY[(883+1630)] = Tu669bhFa[(0x5D0)]("isfolder") if Z6KQpY[(0x9D1)] then Z6KQpY[(847*3)], Z6KQpY[(853*3)] = hH45k3O["pcall"](Z6KQpY[(359*7)], Tu669bhFa[(452-53)]) if not Z6KQpY[(2606-65)] then return false end if not Z6KQpY[(2029+530)] and (not Z6KQpY[(2535-47)] or not hH45k3O["pcall"](Z6KQpY[(0x9B8)], Tu669bhFa[(428-29)])) then return false end elseif Z6KQpY[(1244*2)] then hH45k3O["pcall"](Z6KQpY[(2246+242)], Tu669bhFa[(0x18F)]) end return hH45k3O["pcall"](Z6KQpY[(2484-4)], Tu669bhFa[(301+109)], EhpV4b5) end)({}) end Tu669bhFa[(1622-6)]=function() return(function(xQACaW2RI) xQACaW2RI[(0xA16)] = Tu669bhFa[(-299957-(-301445))]("delfile") or Tu669bhFa[(1515-27)](("delet".."efile") xQACaW2RI[(2691-94)] = Tu669bhFa[(744*2)]("isfile") if xQACaW2RI[(0xA25)] then xQACaW2RI[(-991562-(-994174))], xQACaW2RI[(-356447-(-359068))] = hH45k3O["pcall"](xQACaW2RI[(0xA25)], Tu669bhFa[(0x19A)]) if xQACaW2RI[(2345+267)] and not xQACaW2RI[(-494419-(-497040))] then return true end end if xQACaW2RI[(2592-10)] then xQACaW2RI[(-832122-(-834765))] = hH45k3O["pcall"](xQACaW2RI[(-814578-(-817160))], Tu669bhFa[(205*2)]) if xQACaW2RI[(2716-73)] then return true end end xQACaW2RI[(-891091-(-893748))] = Tu669bhFa[(744*2)](("write".."file") if xQACaW2RI[(-802431-(-805088))] then hH45k3O["pcall"](xQACaW2RI[(-263827-(-266484))], Tu669bhFa[(0x19A)], "") return true end return false end)({}) end Tu669bhFa[(171*3)] = 4294967296 Tu669bhFa[(813*2)]=function(EhpV4b5, jOpz6sdU) return(function(LN5naNSZt) LN5naNSZt[(621+2057)], LN5naNSZt[(901*3)], LN5naNSZt[(1355*2)], LN5naNSZt[(2734-4)] = hH45k3O["string"]["byte"](EhpV4b5, jOpz6sdU, jOpz6sdU + (1+2)) return LN5naNSZt[(1339*2)] + (LN5naNSZt[(0xA8F)] * (0x100)) + (LN5naNSZt[(2196+514)] * (47921+17615)) + (LN5naNSZt[(2818-88)] * 16777216) end)({}) end Tu669bhFa[(1223+420)]=function(EhpV4b5) return(function(Xz81RjT) EhpV4b5 = EhpV4b5 % Tu669bhFa[(366+147)] Xz81RjT[(-359623-(-362370))] = EhpV4b5 % (301-45) Xz81RjT[(-844666-(-847424))] = hH45k3O["math"]["floor"](EhpV4b5 / (319-63)) % (98+158) Xz81RjT[(2848-65)] = hH45k3O["math"]["floor"](EhpV4b5 / (0x10000)) % (0x100) Xz81RjT[(2812-20)] = hH45k3O["math"]["floor"](EhpV4b5 / 16777216) % (331-75) return hH45k3O["string"]["char"](Xz81RjT[(129+2618)], Xz81RjT[(2807-49)], Xz81RjT[(0xADF)], Xz81RjT[(2839-47)]) end)({}) end Tu669bhFa[(555-23)] = hH45k3O["bit32"] if not Tu669bhFa[(549-17)] then Tu669bhFa[(266*2)] = { ["band"] = function(Fq0v3tnp, hvSGYXM5F) return(function(psUU7Fj0) psUU7Fj0[(536+2274)] = (0); psUU7Fj0[(943*3)] = (1) for V5J6oh = (0), (26+5) do if Fq0v3tnp % (-347872-(-347874)) == (1) and hvSGYXM5F % (1*2) == (1) then psUU7Fj0[(1405*2)] = psUU7Fj0[(0xAFA)] + psUU7Fj0[(2879-50)] end Fq0v3tnp = hH45k3O["math"]["floor"](Fq0v3tnp / (1*2)); hvSGYXM5F = hH45k3O["math"]["floor"](hvSGYXM5F / (1*2)); psUU7Fj0[(0xB0D)] = psUU7Fj0[(943*3)] * (-346438-(-346440)) end return psUU7Fj0[(2899-89)] end)({}) end, ["bxor"] = function(Fq0v3tnp, hvSGYXM5F) return(function(vy7NqE) vy7NqE[(1626+1229)] = (0); vy7NqE[(2950-68)] = (1) for V5J6oh = (0), (0x1F) do vy7NqE[(0xB52)] = Fq0v3tnp % (0x2); vy7NqE[(2740+180)] = hvSGYXM5F % (-808310-(-808312)) if vy7NqE[(2967-69)] ~= vy7NqE[(-266675-(-269595))] then vy7NqE[(946+1909)] = vy7NqE[(571*5)] + vy7NqE[(1441*2)] end Fq0v3tnp = hH45k3O["math"]["floor"](Fq0v3tnp / (2+0)); hvSGYXM5F = hH45k3O["math"]["floor"](hvSGYXM5F / (-616552-(-616554))); vy7NqE[(2965-83)] = vy7NqE[(2944-62)] * (-531296-(-531298)) end return vy7NqE[(0xB27)] end)({}) end, ["lshift"] = function(Fq0v3tnp, hvSGYXM5F) return (Fq0v3tnp * ((1*2) ^ hvSGYXM5F)) % Tu669bhFa[(571-58)] end, ["rshift"] = function(Fq0v3tnp, hvSGYXM5F) return hH45k3O["math"]["floor"]((Fq0v3tnp % Tu669bhFa[(-457620-(-458133))]) / ((0x2) ^ hvSGYXM5F)) end, } end Tu669bhFa[(832*2)]=function(ZU6tmq5V, RBj8TNTO, F4470xK) return(function(RYRSU2s3) RYRSU2s3[(0xB7C)] = (0) for V5J6oh = (1), (30+2) do ZU6tmq5V = (ZU6tmq5V + Tu669bhFa[(0x214)]["bxor"]((Tu669bhFa[(-639903-(-640435))]["lshift"](RBj8TNTO, (0x4)) + F4470xK[(1)]) % Tu669bhFa[(-589188-(-589701))], (RBj8TNTO + RYRSU2s3[(2971-31)]) % Tu669bhFa[(-639587-(-640100))], Tu669bhFa[(247+285)]["rshift"](RBj8TNTO, (-271704-(-271709))) + F4470xK[(1*2)])) % Tu669bhFa[(65+448)] RYRSU2s3[(2959-19)] = (RYRSU2s3[(2988-48)] + 2654435769) % Tu669bhFa[(0x201)] RBj8TNTO = (RBj8TNTO + Tu669bhFa[(581-49)]["bxor"]((Tu669bhFa[(-209672-(-210204))]["lshift"](ZU6tmq5V, (4+0)) + F4470xK[(-879639-(-879642))]) % Tu669bhFa[(-354061-(-354574))], (ZU6tmq5V + RYRSU2s3[(254+2686)]) % Tu669bhFa[(540-27)], Tu669bhFa[(0x214)]["rshift"](ZU6tmq5V, (0x5)) + F4470xK[(1+3)])) % Tu669bhFa[(595-82)] end return ZU6tmq5V, RBj8TNTO end)({}) end Tu669bhFa[(0x68B)]=function(EhpV4b5, zW4YHi4, grCDhS5s) return(function(BN3MVgC4d) BN3MVgC4d[(0xB92)] = { Tu669bhFa[(1304+322)](grCDhS5s, (1)), Tu669bhFa[(1559+67)](grCDhS5s, (1*5)), Tu669bhFa[(-857890-(-859516))](grCDhS5s, (0x9)), Tu669bhFa[(135+1491)](grCDhS5s, (11+2)) } BN3MVgC4d[(0xB9C)], BN3MVgC4d[(3076-85)] = Tu669bhFa[(0x65A)](zW4YHi4, (1)), Tu669bhFa[(813*2)](zW4YHi4, (7-2)) BN3MVgC4d[(3107-98)] = hH45k3O["table"]["create"](hH45k3O["math"]["ceil"](#EhpV4b5 / (4*2))) for jOpz6sdU = (1), #EhpV4b5, (4*2) do BN3MVgC4d[(2812+216)] = hH45k3O["math"]["floor"]((jOpz6sdU - (1)) / (4*2)) BN3MVgC4d[(3063-28)], BN3MVgC4d[(0xBF1)] = Tu669bhFa[(0x680)](BN3MVgC4d[(0xB9C)], (BN3MVgC4d[(-870222-(-873213))] + BN3MVgC4d[(0xBD4)]) % Tu669bhFa[(-549787-(-550300))], BN3MVgC4d[(1481*2)]) BN3MVgC4d[(456+2614)] = Tu669bhFa[(1690-47)](BN3MVgC4d[(0xBDB)]) .. Tu669bhFa[(1716-73)](BN3MVgC4d[(1019*3)]) BN3MVgC4d[(3099-5)] = hH45k3O["table"]["create"](hH45k3O["math"]["min"]((0x8), #EhpV4b5 - jOpz6sdU + (1))) for C00Yc5 = (1), hH45k3O["math"]["min"]((1+7), #EhpV4b5 - jOpz6sdU + (1)) do BN3MVgC4d[(1547*2)][C00Yc5] = hH45k3O["string"]["char"](Tu669bhFa[(-687319-(-687851))]["bxor"](hH45k3O["string"]["byte"](EhpV4b5, jOpz6sdU + C00Yc5 - (1)), hH45k3O["string"]["byte"](BN3MVgC4d[(1535*2)], C00Yc5))) end BN3MVgC4d[(3098-89)][#BN3MVgC4d[(0xBC1)] + (1)] = hH45k3O["table"]["concat"](BN3MVgC4d[(1547*2)]) end return hH45k3O["table"]["concat"](BN3MVgC4d[(0xBC1)]) end)({}) end Tu669bhFa[(0x692)]=function(EhpV4b5, grCDhS5s) return(function(ctnL4O) ctnL4O[(2773+348)] = { Tu669bhFa[(-505125-(-506751))](grCDhS5s, (1)), Tu669bhFa[(813*2)](grCDhS5s, (9-4)), Tu669bhFa[(-306440-(-308066))](grCDhS5s, (-569433-(-569442))), Tu669bhFa[(301+1325)](grCDhS5s, (1*13)) } ctnL4O[(3164-17)] = Tu669bhFa[(-528973-(-530616))](#EhpV4b5) .. Tu669bhFa[(-430976-(-432619))]((0)) .. EhpV4b5 ctnL4O[(-335219-(-338374))] = (#ctnL4O[(3154-7)] % (0x8) == (0)) and (0) or ((0x8) - #ctnL4O[(0xC4B)] % (4+4)) ctnL4O[(2420+727)] = ctnL4O[(-225808-(-228955))] .. hH45k3O["string"]["rep"]("", ctnL4O[(-719486-(-722641))]) ctnL4O[(3222-59)], ctnL4O[(1591*2)] = (0), (0) for jOpz6sdU = (1), #ctnL4O[(2052+1095)], (11-3) do ctnL4O[(780+2383)] = Tu669bhFa[(0x214)]["bxor"](ctnL4O[(3215-52)], Tu669bhFa[(1077+549)](ctnL4O[(1049*3)], jOpz6sdU)) ctnL4O[(-765058-(-768240))] = Tu669bhFa[(620-88)]["bxor"](ctnL4O[(1591*2)], Tu669bhFa[(0x65A)](ctnL4O[(0xC4B)], jOpz6sdU + (-381234-(-381238)))) ctnL4O[(-750968-(-754131))], ctnL4O[(3012+170)] = Tu669bhFa[(-537611-(-539275))](ctnL4O[(3196-33)], ctnL4O[(0xC6E)], ctnL4O[(-863570-(-866691))]) end return Tu669bhFa[(833+810)](ctnL4O[(3254-91)]) .. Tu669bhFa[(1666-23)](ctnL4O[(3241-59)]) end)({}) end Tu669bhFa[(0x6A2)]=function() return Tu669bhFa[(293*5)](KkykK2E(KkykK2E(KkykK2E(Tu669bhFa[(-551669-(-551900))],"GenerateGUID",false),"gsub","-",""),"sub",1,1+15)) end Tu669bhFa[(1761-45)]=function() return(function(nkf8X) nkf8X[(3217-23)], nkf8X[(1006+2203)] = hH45k3O["pcall"](function() return KkykK2E(Tu669bhFa[(0x10A)],"GetClientId") end) if nkf8X[(0xC7A)] and hH45k3O["type"](nkf8X[(0xC89)]) == "string" and #nkf8X[(1613+1596)] > (0) then return nkf8X[(-194809-(-198018))] end return ("unkno".."wn-cl".."ient-") .. hH45k3O["tostring"](Tu669bhFa[(-712290-(-712512))]["LocalPlayer"] and Tu669bhFa[(310-88)]["LocalPlayer"]["UserId"] or (0)) end)({}) end Tu669bhFa[(0x6C5)]=function(twlSSG618, usZBMM0o, Jqx81q, vrddPH78) return(function(VhFmpV53O) VhFmpV53O[(0xC96)] = Tu669bhFa[(0x5DB)]() if not VhFmpV53O[(3232-10)] then return (0), nil end VhFmpV53O[(463*7)] = nil VhFmpV53O[(628+2639)] = { ["Accept"] = vrddPH78 or ("application".."/json, text".."/plain, */*"), [("User-".."Agent")] = ("FyyCo".."mmuni".."tyLoa".."der/") .. Tu669bhFa[(251+54)], } if Jqx81q ~= nil then if hH45k3O["type"](Jqx81q) == "string" then VhFmpV53O[(1916+1325)] = Jqx81q VhFmpV53O[(0xCC3)]["Content-Type")] = vrddPH78 or ("text/".."plain") else VhFmpV53O[(-489163-(-492449))], VhFmpV53O[(-121585-(-124897))] = hH45k3O["pcall"](Tu669bhFa[(77*3)]["JSONEncode"], Tu669bhFa[(183+48)], Jqx81q) if not VhFmpV53O[(0xCD6)] then return (0), nil end VhFmpV53O[(3324-83)] = VhFmpV53O[(0xCF0)] VhFmpV53O[(1333+1934)][("Cont".."ent-".."Type")] = "application/json" end end VhFmpV53O[(-731107-(-734427))] = nil VhFmpV53O[(3374-26)] = hH45k3O["pcall"](function() VhFmpV53O[(0xCF8)] = VhFmpV53O[(0xC96)]({ ["Url"] = Tu669bhFa[(173*2)] .. twlSSG618, ["Method"] = usZBMM0o or "GET", ["Headers"] = VhFmpV53O[(0xCC3)], ["Body"] = VhFmpV53O[(463*7)], }) end) if not VhFmpV53O[(1674*2)] or hH45k3O["type"](VhFmpV53O[(1149+2171)]) ~= "table") then return (0), nil end VhFmpV53O[(1683*2)] = hH45k3O["tonumber"](VhFmpV53O[(1660*2)]["StatusCode"] or VhFmpV53O[(3420-100)]["Status"] or (0)) or (0) return VhFmpV53O[(1683*2)], VhFmpV53O[(0xCF8)]["Body"] end)({}) end Tu669bhFa[(0x6CC)]=function(twlSSG618, usZBMM0o, Jqx81q) return(function(aT1G53Jfv) aT1G53Jfv[(3367+23)], aT1G53Jfv[(0xD4F)] = Tu669bhFa[(1516+217)](twlSSG618, usZBMM0o, Jqx81q, ("appl".."icat".."ion/".."json")) aT1G53Jfv[(-272325-(-275760))] = nil if hH45k3O["type"](aT1G53Jfv[(-210372-(-213779))]) == "string" then aT1G53Jfv[(3447-3)], aT1G53Jfv[(3468-7)] = hH45k3O["pcall"](Tu669bhFa[(77*3)]["JSONDecode"], Tu669bhFa[(0xE7)], aT1G53Jfv[(0xD4F)]) if aT1G53Jfv[(1848+1596)] and hH45k3O["type"](aT1G53Jfv[(3498-37)]) == "table" then aT1G53Jfv[(3286+149)] = aT1G53Jfv[(3447+14)] end end if aT1G53Jfv[(399+2991)] < (0xC8) or aT1G53Jfv[(3393-3)] >= (-234991-(-235291)) then return nil, aT1G53Jfv[(1145*3)] and hH45k3O["tostring"](aT1G53Jfv[(0xD6B)]["code"] or aT1G53Jfv[(989+2446)]["error"] or "REQUEST_FAILED") or ("REQUEST".."_FAILED"), aT1G53Jfv[(0xD3E)] end return aT1G53Jfv[(-776948-(-780383))], nil, aT1G53Jfv[(1662+1728)] end)({}) end Tu669bhFa[(1830-71)]=function() return(function(Q9o2QRzf) Q9o2QRzf[(0xD96)] = hH45k3O["game"]["GameId"] Q9o2QRzf[(0xDA8)] = Tu669bhFa[(-556266-(-556727))][Q9o2QRzf[(3491-13)]] if not Q9o2QRzf[(0xDA8)] then return nil, ("Unsuppo".."rted Ga".."me ID: ") .. hH45k3O["tostring"](Q9o2QRzf[(-895288-(-898766))]) end Q9o2QRzf[(0xDC1)] = Tu669bhFa[(1571-72)]() Q9o2QRzf[(0xE2A)]=function(O3y6z, J9cAhRJ) return(function(SAe6Tb) SAe6Tb[(594+3057)], SAe6Tb[(3733-74)] = false, nil hH45k3O["task"]["spawn"](function() return(function(Xy134) if Q9o2QRzf[(1021+2500)] then Xy134[(0xE74)], Xy134[(1864*2)] = hH45k3O["pcall"](Q9o2QRzf[(253+3268)], { ["Url"] = O3y6z, ["Method"] = "GET", ["Timeout"] = J9cAhRJ }) if Xy134[(3720-20)] and hH45k3O["type"](Xy134[(3798-70)]) == "table" and (Xy134[(-694487-(-698215))]["StatusCode"] == (0xC8) or Xy134[(-476592-(-480320))]["Status"] == (-672099-(-672299))) and hH45k3O["type"](Xy134[(0xE90)]["Body"]) == "string" then SAe6Tb[(0xE4B)] = Xy134[(3762-34)]["Body"] end end if not SAe6Tb[(-495146-(-498805))] then Xy134[(0xE9C)], Xy134[(-317289-(-321043))] = hH45k3O["pcall"](hH45k3O["game"]["HttpGet"], hH45k3O["game"], O3y6z) if Xy134[(3813-73)] and hH45k3O["type"](Xy134[(3069+685)]) == "string" then SAe6Tb[(3705-46)] = Xy134[(1877*2)] end end SAe6Tb[(3661-10)] = true end)({}) end) SAe6Tb[(2560+1119)] = hH45k3O["os"]["clock"]() + J9cAhRJ while not SAe6Tb[(3680-29)] and hH45k3O["os"]["clock"]() < SAe6Tb[(3684-5)] do hH45k3O["task"]["wait"](0.05) end return hH45k3O["type"](SAe6Tb[(0xE4B)]) == "string" and #SAe6Tb[(-894343-(-898002))] > (0x40) and SAe6Tb[(1969+1690)] or nil end)({}) end Q9o2QRzf[(0xDD7)] = hH45k3O["string"]["format"](("https://104-20".."7-92-246.sslip"..".io/scripts/%s"), Q9o2QRzf[(1748*2)]) Q9o2QRzf[(2917+655)] = Q9o2QRzf[(1813*2)](Q9o2QRzf[(1224+2319)], (-514569-(-514581))) if Q9o2QRzf[(208+3364)] then return Q9o2QRzf[(3595-23)], nil end Q9o2QRzf[(0xDFB)] = hH45k3O["string"]["format"](("https://raw.githubu".."sercontent.com/FyyW".."annaFly/FyyLuaColle".."ction/%s/scripts/%s"), Tu669bhFa[(204+238)], Q9o2QRzf[(1748*2)]) Q9o2QRzf[(0xDF4)] = Q9o2QRzf[(1813*2)](Q9o2QRzf[(0xDFB)], (6*2)) if Q9o2QRzf[(-872444-(-876016))] then return Q9o2QRzf[(-123822-(-127394))], nil end Q9o2QRzf[(3639-35)] = hH45k3O["string"]["format"]("https://fyycommunity.com/cdn/scripts/%s"), Q9o2QRzf[(1748*2)]) Q9o2QRzf[(-255350-(-258922))] = Q9o2QRzf[(1813*2)](Q9o2QRzf[(2966+638)], (15-3)) if Q9o2QRzf[(-162521-(-166093))] then return Q9o2QRzf[(0xDF4)], nil end return nil, ("Failed to do".."wnload game ".."runtime from".." all deliver".."y routes") end)({}) end Tu669bhFa[(258+291)] = { ["INVALID_KEY"] = true, ["EXPIRED"] = true, ["KEY_EXPIRED"] = true, ["LICENSE_EXPIRED"] = true, ["KEY_REVOKED"] = true, ["LICENSE_NOT_ACTIVE"] = true, ["HWID_MISMATCH"] = true, ["HWID_BLACKLISTED"] = true, ["BLACKLISTED"] = true, ["REDEEM_REQUIRED"] = true, } Tu669bhFa[(1853-82)]=function(x2mM6X) return(function(b6bc08r) b6bc08r[(3+3775)] = { ["INVALID_KEY"] = ("The license key you ".."entered is invalid."), ["EXPIRED"] = ("Your licens".."e has expir".."ed. Please ".."renew to co".."ntinue."), ["KEY_EXPIRED"] = ("Your license ".."has expired. ".."Please renew ".."to continue."), ["LICENSE_EXPIRED"] = ("Your license has ".."expired. Please r".."enew to continue."), ["KEY_REVOKED"] = ("Your lic".."ense has".." been re".."voked."), ["LICENSE_NOT_ACTIVE"] = ("This licens".."e is no lon".."ger active.".." Enter anot".."her key."), ["HWID_MISMATCH"] = ("This key is bound to".." another device. Res".."et HWID on Discord."), ["HWID_BLACKLISTED"] = ("This device is blocked f".."rom using Fyy Community."), ["BLACKLISTED"] = ("This li".."cense h".."as been".." blackl".."isted."), ["REDEEM_REQUIRED"] = ("Redeem this key ".."in Discord, then".." enter it again."), ["MAX_HWID_RESETS"] = ("Maximum HWID ".."resets reache".."d for this bi".."lling cycle."), ["MAINTENANCE_UNAVAILABLE"] = ("Public main".."tenance acc".."ess is temp".."orarily una".."vailable."), ["DISTRIBUTION_OFFLINE"] = ("Script distribution serve".."r is temporarily offline."), ["DISTRIBUTION_UNAVAILABLE"] = ("Script distributi".."on server is temp".."orarily offline."), ["REQUEST_FAILED"] = ("Fyy Community ".."could not be r".."eached. Please".." try again."), ["AUDIT_FAILED"] = "License verification is temporarily unavailable.", ["INTERNAL_ERROR"] = ("License verifica".."tion is temporar".."ily unavailable."), } return b6bc08r[(0xEC2)][hH45k3O["tostring"](x2mM6X)] or "Authorization failed. Please try again.") end)({}) end Tu669bhFa[(-927604-(-929388))]=function() return(function(oM9XxE23) oM9XxE23[(0xED4)], oM9XxE23[(2643+1172)] = hH45k3O["pcall"](function() return KkykK2E(Tu669bhFa[(246+4)],"GetProductInfo",hH45k3O["game"]["PlaceId"]) end) if oM9XxE23[(0xED4)] and hH45k3O["type"](oM9XxE23[(-613838-(-617653))]) == "table" and hH45k3O["type"](oM9XxE23[(-584551-(-588366))]["Name"]) == "string" and oM9XxE23[(-625783-(-629598))]["Name"] ~= "" then return oM9XxE23[(763*5)]["Name"] end oM9XxE23[(1915*2)] = { [5750914919] = "Fisch", [6739698191] = ("Viol".."ence".." Dis".."tric".."t"), [10563114921] = ("Steal ".."An Egg"), } return oM9XxE23[(1915*2)][hH45k3O["game"]["GameId"]] or ("Robl".."ox E".."xper".."ienc".."e") end)({}) end Tu669bhFa[(567+1225)]=function() return(function(qe9fatwy) for V5J6oh, o6RGhZ4y9 in hH45k3O["ipairs"]({ "gethui", ("get_hid".."den_gui"), ("gethid".."dengui") }) do qe9fatwy[(0xF0C)] = Tu669bhFa[(-840008-(-841496))](o6RGhZ4y9) if hH45k3O["type"](qe9fatwy[(1926*2)]) == "function" then qe9fatwy[(553*7)], qe9fatwy[(0xF27)] = hH45k3O["pcall"](qe9fatwy[(3440+412)]) if qe9fatwy[(0xF1F)] and hH45k3O["typeof"](qe9fatwy[(1293*3)]) == "Instance" then return qe9fatwy[(-336858-(-340737))] end end end return Tu669bhFa[(287-98)] end)({}) end Tu669bhFa[(0x70F)]=function(S2tB8, CP0KF066) return(function(upMV5) upMV5[(3974-66)] = hH45k3O["Instance"]["new"](S2tB8) for F4470xK, EhpV4b5 in hH45k3O["pairs"](CP0KF066) do if F4470xK ~= "Parent") then upMV5[(0xF44)][F4470xK] = EhpV4b5 end end upMV5[(1954*2)]["Parent"] = CP0KF066["Parent"] return upMV5[(-955922-(-959830))] end)({}) end Tu669bhFa[(0x729)]=function(gm9l3, LZV28WXZ, nN8wvzl, fvrlr51sS, hHXf0086G) return(function(nsa17Aj) nsa17Aj[(-870127-(-874059))] = KkykK2E(Tu669bhFa[(-770543-(-770723))],"Create",gm9l3,hH45k3O["TweenInfo"]["new"](LZV28WXZ, fvrlr51sS or hH45k3O["Enum"]["EasingStyle"]["Quad"], hHXf0086G or hH45k3O["Enum"]["EasingDirection"]["Out"]),nN8wvzl) KkykK2E(nsa17Aj[(0xF5C)],"Play") return nsa17Aj[(3965-33)] end)({}) end Tu669bhFa[(40+516)] = Tu669bhFa[(1466+326)]() for V5J6oh, jjW9M3j4T in hH45k3O["ipairs"]({ Tu669bhFa[(278*2)], Tu669bhFa[(20+169)] }) do Tu669bhFa[(-964214-(-964788))] = jjW9M3j4T and jjW9M3j4T["FindFirstChild"](jjW9M3j4T,Tu669bhFa[(375-83)]) if Tu669bhFa[(-367395-(-367969))] then hH45k3O["pcall"](Tu669bhFa[(287*2)]["Destroy"], Tu669bhFa[(-946806-(-947380))]) end end Tu669bhFa[(688-86)] = Tu669bhFa[(-759006-(-760813))]("ScreenGui"), { ["Name"] = Tu669bhFa[(146*2)], ["IgnoreGuiInset"] = true, ["ResetOnSpawn"] = false, ["DisplayOrder"] = (-563916-(-663916)), ["ZIndexBehavior"] = hH45k3O["Enum"]["ZIndexBehavior"]["Sibling"], ["Parent"] = Tu669bhFa[(100+456)], }) hH45k3O["pcall"](function() if hH45k3O["syn"] and hH45k3O["syn"]["protect_gui"] then hH45k3O["syn"]["protect_gui"](Tu669bhFa[(93+509)]) end end) Tu669bhFa[(209*3)] = Tu669bhFa[(0x70F)]("Frame", { ["Name"] = "Backdrop", ["Size"] = hH45k3O["UDim2"]["fromScale"]((1), (1)), ["BackgroundColor3"] = Tu669bhFa[(25+461)]["Backdrop"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(-425254-(-425856))], }) Tu669bhFa[(0x28D)], Tu669bhFa[(341*2)] = (400-20), (-765118-(-765368)) Tu669bhFa[(524+175)] = Tu669bhFa[(564+1243)]("Frame", { ["Name"] = "Card", ["Active"] = true, ["AnchorPoint"] = hH45k3O["Vector2"]["new"](0.5, 0.5), ["Position"] = hH45k3O["UDim2"]["new"](0.5, (0), 0.5, (6+4)), ["Size"] = hH45k3O["UDim2"]["fromOffset"](Tu669bhFa[(0x28D)], Tu669bhFa[(0x2AA)]), ["BackgroundColor3"] = Tu669bhFa[(419+67)]["Surface"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(0x273)], }) Tu669bhFa[(664+1143)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (7*2)), ["Parent"] = Tu669bhFa[(713-14)] }) Tu669bhFa[(1905-98)](("UIGr".."adie".."nt"), { ["Color"] = hH45k3O["ColorSequence"]["new"]({ ColorSequenceKeypoint["new"]((0), hH45k3O["Color3"]["fromRGB"]((-708491-(-708513)), (0x1A), (59-25))), ColorSequenceKeypoint["new"]((1), Tu669bhFa[(242+244)]["Surface"]), }), ["Rotation"] = (36+54), ["Parent"] = Tu669bhFa[(771-72)], }) Tu669bhFa[(363*2)] = Tu669bhFa[(0x70F)]("UIStroke", { ["Color"] = Tu669bhFa[(2+484)]["Border"], ["Thickness"] = (1), ["Transparency"] = (1), ["Parent"] = Tu669bhFa[(0x2BB)] }) Tu669bhFa[(377*2)] = Tu669bhFa[(-221301-(-223108))]("UIScale"), { ["Scale"] = 0.96, ["Parent"] = Tu669bhFa[(233*3)] }) Tu669bhFa[(0x304)] = Tu669bhFa[(62+1745)]("Frame"), { ["Name"] = ("Top".."Acc".."ent"), ["AnchorPoint"] = hH45k3O["Vector2"]["new"](0.5, (0)), ["Position"] = hH45k3O["UDim2"]["fromScale"](0.5, (0)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(20*2), (0), (1+1)), ["BackgroundColor3"] = Tu669bhFa[(110+376)]["Accent"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(233*3)], }) Tu669bhFa[(0x70F)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((1), (0)), ["Parent"] = Tu669bhFa[(0x304)] }) Tu669bhFa[(0x70F)](("UIGr".."adie".."nt"), { ["Transparency"] = hH45k3O["NumberSequence"]["new"]({ NumberSequenceKeypoint["new"]((0), (1)), NumberSequenceKeypoint["new"](0.18, 0.15), NumberSequenceKeypoint["new"](0.82, 0.15), NumberSequenceKeypoint["new"]((1), (1)), }), ["Parent"] = Tu669bhFa[(0x304)], }) Tu669bhFa[(-973035-(-973834))] = Tu669bhFa[(-319930-(-321737))]("Frame", { ["Name"] = "Mark", ["Position"] = hH45k3O["UDim2"]["fromOffset"]((16+2), (-664274-(-664292))), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((52-24), (0x1C)), ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(0x2BB)] }) Tu669bhFa[(864-55)] = Tu669bhFa[(139*13)]("ImageLabel"), { ["Name"] = "Logo", ["AnchorPoint"] = hH45k3O["Vector2"]["new"](0.5, 0.5), ["Position"] = hH45k3O["UDim2"]["fromScale"](0.5, 0.5), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((11*2), (13+9)), ["BackgroundTransparency"] = (1), ["Image"] = ("rbxasseti".."d://90892".."630150011"), ["ImageColor3"] = Tu669bhFa[(84+402)]["Text"], ["ImageTransparency"] = (1), ["ScaleType"] = hH45k3O["Enum"]["ScaleType"]["Fit"], ["Parent"] = Tu669bhFa[(879-80)], }) Tu669bhFa[(0x338)] = Tu669bhFa[(-295755-(-297562))]("TextLabel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((12+42), (0x11)), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((96+74), (31-15)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = ("Fyy Com".."munity"), ["TextColor3"] = Tu669bhFa[(243*2)]["Text"], ["TextSize"] = (0xD), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["Parent"] = Tu669bhFa[(767-68)], }) Tu669bhFa[(277*3)] = Tu669bhFa[(-878823-(-880630))](("TextL".."abel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((-907401-(-907455)), (9+25)), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((105*2), (0xD)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["GothamMedium"], ["Text"] = hH45k3O["string"]["upper"](Tu669bhFa[(1789-5)]()) .. " RUNTIME", ["TextColor3"] = Tu669bhFa[(557-71)]["Muted"], ["TextSize"] = (13-5), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["Parent"] = Tu669bhFa[(0x2BB)], }) Tu669bhFa[(707+149)] = Tu669bhFa[(0x70F)]("Frame", { ["Name"] = ("Sta".."teP".."ill"), ["AnchorPoint"] = hH45k3O["Vector2"]["new"]((1), (0)), ["Position"] = hH45k3O["UDim2"]["new"]((1), -(28-10), (0), (34-14)), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((87+19), (40-16)), ["BackgroundColor3"] = Tu669bhFa[(-606627-(-607113))]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(428+271)], }) Tu669bhFa[(1907-100)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (10-2)), ["Parent"] = Tu669bhFa[(879-23)] }) Tu669bhFa[(911-48)] = Tu669bhFa[(0x70F)]("Frame", { ["Name"] = "Content", ["AnchorPoint"] = hH45k3O["Vector2"]["new"](0.5, 0.5), ["Position"] = hH45k3O["UDim2"]["fromScale"](0.5, 0.5), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(6+2), (1), (0)), ["BackgroundTransparency"] = (1), ["Parent"] = Tu669bhFa[(428*2)], }) Tu669bhFa[(905-31)] = Tu669bhFa[(-151584-(-153391))](("UILi".."stLa".."yout"), { ["FillDirection"] = hH45k3O["Enum"]["FillDirection"]["Horizontal"], ["HorizontalAlignment"] = hH45k3O["Enum"]["HorizontalAlignment"]["Center"], ["VerticalAlignment"] = hH45k3O["Enum"]["VerticalAlignment"]["Center"], ["Padding"] = hH45k3O["UDim"]["new"]((0), (3*2)), ["SortOrder"] = hH45k3O["Enum"]["SortOrder"]["LayoutOrder"], ["Parent"] = Tu669bhFa[(-118238-(-119101))], }) Tu669bhFa[(179*5)] = Tu669bhFa[(0x70F)]("Frame", { ["Name"] = "Dot", ["Size"] = hH45k3O["UDim2"]["fromOffset"]((1*5), (1*5)), ["BackgroundColor3"] = Tu669bhFa[(243*2)]["AccentHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["LayoutOrder"] = (1), ["Parent"] = Tu669bhFa[(-338433-(-339296))], }) Tu669bhFa[(139*13)]("UICorner"), { ["CornerRadius"] = hH45k3O["UDim"]["new"]((1), (0)), ["Parent"] = Tu669bhFa[(0x37F)] }) Tu669bhFa[(458*2)] = Tu669bhFa[(0x70F)](("Tex".."tLa".."bel"), { ["Name"] = "Text", ["AutomaticSize"] = hH45k3O["Enum"]["AutomaticSize"]["X"], ["Size"] = hH45k3O["UDim2"]["fromScale"]((0), (1)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = "CHECKING", ["TextColor3"] = Tu669bhFa[(521-35)]["AccentHigh"], ["TextSize"] = (4*2), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Center"], ["TextYAlignment"] = hH45k3O["Enum"]["TextYAlignment"]["Center"], ["LayoutOrder"] = (-160604-(-160606)), ["Parent"] = Tu669bhFa[(928-65)], }) Tu669bhFa[(-701802-(-702728))] = Tu669bhFa[(1710+97)](("Tex".."tLa".."bel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((0x12), (0x44)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(44-8), (0), (-314155-(-314175))), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = ("Initializing".." runtime..."), ["TextColor3"] = Tu669bhFa[(549-63)]["Text"], ["TextSize"] = (12+3), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["Parent"] = Tu669bhFa[(-293498-(-294197))], }) Tu669bhFa[(0x3AA)] = Tu669bhFa[(139*13)](("Tex".."tLa".."bel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((9*2), (0x60)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(1+35), (0), (18*2)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["Gotham"], ["Text"] = ("Keyless access granted â¢ Fre".."e Premium features unlocked\nCo".."nnecting to online session..."), ["TextColor3"] = Tu669bhFa[(243*2)]["Muted"], ["TextSize"] = (0xB), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["TextYAlignment"] = hH45k3O["Enum"]["TextYAlignment"]["Top"], ["Visible"] = false, ["Parent"] = Tu669bhFa[(0x2BB)], }) Tu669bhFa[(479*2)] = Tu669bhFa[(139*13)]("Frame", { ["Name"] = "InputRow", ["Position"] = hH45k3O["UDim2"]["fromOffset"]((13+5), (142-46)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(52-16), (0), (8+26)), ["BackgroundTransparency"] = (1), ["Visible"] = false, ["Parent"] = Tu669bhFa[(788-89)], }) Tu669bhFa[(490*2)] = Tu669bhFa[(1566+241)]("TextBox"), { ["Name"] = ("Lice".."nseK".."ey"), ["Position"] = hH45k3O["UDim2"]["fromOffset"]((0), (0)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(34+58), (1), (0)), ["BackgroundColor3"] = Tu669bhFa[(580-94)]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["ClearTextOnFocus"] = false, ["Font"] = hH45k3O["Enum"]["Font"]["GothamMedium"], ["PlaceholderText"] = ("FYY-."..".. or".." TRIA".."L-..."), ["PlaceholderColor3"] = Tu669bhFa[(79+407)]["Faint"], ["Text"] = "", ["TextColor3"] = Tu669bhFa[(523-37)]["Text"], ["TextSize"] = (17-7), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["Parent"] = Tu669bhFa[(-995329-(-996287))], }) Tu669bhFa[(1897-90)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (15-7)), ["Parent"] = Tu669bhFa[(1051-71)] }) Tu669bhFa[(-394525-(-396332))]("UIPadding"), { ["PaddingLeft"] = hH45k3O["UDim"]["new"]((0), (-688148-(-688159))), ["PaddingRight"] = hH45k3O["UDim"]["new"]((0), (20-9)), ["Parent"] = Tu669bhFa[(0x3D4)] }) Tu669bhFa[(331*3)] = Tu669bhFa[(1905-98)]("UIStroke", { ["Color"] = Tu669bhFa[(243*2)]["Border"], ["Thickness"] = (1), ["Transparency"] = (1), ["Parent"] = Tu669bhFa[(0x3D4)], }) Tu669bhFa[(-239544-(-240566))] = Tu669bhFa[(1893-86)](("TextB".."utton"), { ["Name"] = "Validate", ["AnchorPoint"] = hH45k3O["Vector2"]["new"]((1), (0)), ["Position"] = hH45k3O["UDim2"]["new"]((1), (0), (0), (0)), ["Size"] = hH45k3O["UDim2"]["fromOffset"]((42*2), (0x22)), ["BackgroundColor3"] = Tu669bhFa[(243*2)]["Accent"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["AutoButtonColor"] = false, ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = "CONTINUE", ["TextColor3"] = Tu669bhFa[(-461502-(-461988))]["Text"], ["TextSize"] = (-588193-(-588202)), ["TextTransparency"] = (1), ["Parent"] = Tu669bhFa[(479*2)], }) Tu669bhFa[(193+1614)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (4*2)), ["Parent"] = Tu669bhFa[(0x3FE)] }) KkykK2E(Tu669bhFa[(1096-74)]["MouseEnter"],"Connect",function() if Tu669bhFa[(511*2)]["Active"] then Tu669bhFa[(611*3)](Tu669bhFa[(682+340)], 0.16, { ["BackgroundColor3"] = Tu669bhFa[(0x1E6)]["AccentHigh"] }) end end) KkykK2E(Tu669bhFa[(1043-21)]["MouseLeave"],"Connect",function() if Tu669bhFa[(-615549-(-616571))]["Active"] then Tu669bhFa[(611*3)](Tu669bhFa[(-288555-(-289577))], 0.16, { ["BackgroundColor3"] = Tu669bhFa[(461+25)]["Accent"] }) end end) Tu669bhFa[(864+177)] = Tu669bhFa[(-797146-(-798953))]("Frame", { ["Name"] = ("Actio".."nsRow"), ["Position"] = hH45k3O["UDim2"]["fromOffset"]((9*2), (0x8A)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(55-19), (0), (0x1E)), ["BackgroundTransparency"] = (1), ["Visible"] = false, ["Parent"] = Tu669bhFa[(0x2BB)], }) Tu669bhFa[(530+518)] = Tu669bhFa[(139*13)](("TextB".."utton"), { ["Name"] = "GetKey", ["Position"] = hH45k3O["UDim2"]["fromOffset"]((0), (0)), ["Size"] = hH45k3O["UDim2"]["new"](0.5, -(1*5), (1), (0)), ["BackgroundColor3"] = Tu669bhFa[(-208008-(-208494))]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["AutoButtonColor"] = false, ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = ("GET FR".."EE KEY"), ["TextColor3"] = Tu669bhFa[(497-11)]["Text"], ["TextSize"] = (0x8), ["TextTransparency"] = (1), ["Parent"] = Tu669bhFa[(1120-79)], }) Tu669bhFa[(544+1263)]("UICorner"), { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (4*2)), ["Parent"] = Tu669bhFa[(524*2)] }) Tu669bhFa[(1101-30)] = Tu669bhFa[(618+1189)]("UIStroke", { ["Color"] = Tu669bhFa[(309+177)]["Border"], ["Thickness"] = (1), ["Transparency"] = (1), ["Parent"] = Tu669bhFa[(-144013-(-145061))], }) Tu669bhFa[(541*2)] = Tu669bhFa[(-123349-(-125156))](("Text".."Butt".."on"), { ["Name"] = ("Disc".."ordA".."ctio".."n"), ["AnchorPoint"] = hH45k3O["Vector2"]["new"]((1), (0)), ["Position"] = hH45k3O["UDim2"]["new"]((1), (0), (0), (0)), ["Size"] = hH45k3O["UDim2"]["new"](0.5, -(1*5), (1), (0)), ["BackgroundColor3"] = Tu669bhFa[(0x1E6)]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["AutoButtonColor"] = false, ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = ("JOIN".." DIS".."CORD"), ["TextColor3"] = Tu669bhFa[(192+294)]["Text"], ["TextSize"] = (0x8), ["TextTransparency"] = (1), ["Parent"] = Tu669bhFa[(0x411)], }) Tu669bhFa[(1868-61)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (4*2)), ["Parent"] = Tu669bhFa[(1155-73)] }) Tu669bhFa[(0x443)] = Tu669bhFa[(275+1532)]("UIStroke"), { ["Color"] = Tu669bhFa[(510-24)]["Border"], ["Thickness"] = (1), ["Transparency"] = (1), ["Parent"] = Tu669bhFa[(374+708)], }) for V5J6oh, Cb2LBC in hH45k3O["ipairs"]({ Tu669bhFa[(-595613-(-596661))], Tu669bhFa[(194+888)] }) do KkykK2E(Cb2LBC["MouseEnter"],"Connect",function() Tu669bhFa[(1105+728)](Cb2LBC, 0.16, { ["BackgroundColor3"] = hH45k3O["Color3"]["fromRGB"]((16*2), (22+16), (48+0)) }) end) KkykK2E(Cb2LBC["MouseLeave"],"Connect",function() Tu669bhFa[(-227573-(-229406))](Cb2LBC, 0.16, { ["BackgroundColor3"] = Tu669bhFa[(539-53)]["SurfaceHigh"] }) end) end Tu669bhFa[(1115-7)] = Tu669bhFa[(-592289-(-594096))]("TextLabel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((9*2), (-724440-(-724620))), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(-985393-(-985429)), (0), (8*2)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["GothamMedium"], ["Text"] = ("Connecti".."ng secur".."ely..."), ["TextColor3"] = Tu669bhFa[(-711929-(-712415))]["Muted"], ["TextSize"] = (8+1), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["TextTruncate"] = hH45k3O["Enum"]["TextTruncate"]["AtEnd"], ["Parent"] = Tu669bhFa[(247+452)], }) Tu669bhFa[(391+728)] = Tu669bhFa[(139*13)]("Frame", { ["Name"] = ("Progres".."sTrack"), ["Position"] = hH45k3O["UDim2"]["fromOffset"]((3+15), (101+105)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(-955160-(-955196)), (0), (0x4)), ["BackgroundColor3"] = Tu669bhFa[(0x1E6)]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(233*3)], }) Tu669bhFa[(1872-65)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((1), (0)), ["Parent"] = Tu669bhFa[(-179198-(-180317))] }) Tu669bhFa[(574*2)] = Tu669bhFa[(139*13)]("Frame", { ["Name"] = "Progress", ["Size"] = hH45k3O["UDim2"]["fromScale"]((0), (1)), ["BackgroundColor3"] = Tu669bhFa[(243*2)]["Accent"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["Parent"] = Tu669bhFa[(0x45F)], }) Tu669bhFa[(-954790-(-956597))]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((1), (0)), ["Parent"] = Tu669bhFa[(574*2)] }) Tu669bhFa[(0x70F)](("UIGr".."adie".."nt"), { ["Color"] = hH45k3O["ColorSequence"]["new"]({ ColorSequenceKeypoint["new"]((0), Tu669bhFa[(-338959-(-339445))]["Accent"]), ColorSequenceKeypoint["new"]((1), Tu669bhFa[(243*2)]["AccentHigh"]), }), ["Parent"] = Tu669bhFa[(178+970)], }) Tu669bhFa[(729+447)] = Tu669bhFa[(1468+339)](("TextB".."utton"), { ["Name"] = "DiscordFull", ["Position"] = hH45k3O["UDim2"]["fromOffset"]((9*2), (105+75)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(0x24), (0), (17*2)), ["BackgroundColor3"] = Tu669bhFa[(391+95)]["SurfaceHigh"], ["BackgroundTransparency"] = (1), ["BorderSizePixel"] = (0), ["AutoButtonColor"] = false, ["Font"] = hH45k3O["Enum"]["Font"]["GothamBold"], ["Text"] = ("JOIN ".."DISCO".."RD CO".."MMUNI".."TY"), ["TextColor3"] = Tu669bhFa[(11+475)]["Text"], ["TextSize"] = (11-2), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Center"], ["TextYAlignment"] = hH45k3O["Enum"]["TextYAlignment"]["Center"], ["Visible"] = false, ["Parent"] = Tu669bhFa[(730-31)], }) Tu669bhFa[(0x70F)]("UICorner", { ["CornerRadius"] = hH45k3O["UDim"]["new"]((0), (11-3)), ["Parent"] = Tu669bhFa[(0x498)] }) Tu669bhFa[(-238954-(-240141))] = Tu669bhFa[(0x70F)]("UIStroke", { ["Color"] = Tu669bhFa[(0x1E6)]["Border"], ["Thickness"] = (1), ["Transparency"] = (1), ["Parent"] = Tu669bhFa[(-851654-(-852830))], }) KkykK2E(Tu669bhFa[(1233-57)]["MouseEnter"],"Connect",function() Tu669bhFa[(611*3)](Tu669bhFa[(-689166-(-690342))], 0.16, { ["BackgroundColor3"] = hH45k3O["Color3"]["fromRGB"]((31+1), (0x26), (58-10)) }) Tu669bhFa[(1901-68)](Tu669bhFa[(0x4A3)], 0.16, { ["Color"] = Tu669bhFa[(309+177)]["Accent"], ["Transparency"] = 0.3 }) end) KkykK2E(Tu669bhFa[(-698482-(-699658))]["MouseLeave"],"Connect",function() Tu669bhFa[(1444+389)](Tu669bhFa[(1199-23)], 0.16, { ["BackgroundColor3"] = Tu669bhFa[(243*2)]["SurfaceHigh"] }) Tu669bhFa[(1900-67)](Tu669bhFa[(-603987-(-605174))], 0.16, { ["Color"] = Tu669bhFa[(581-95)]["Border"], ["Transparency"] = 0.5 }) end) Tu669bhFa[(0x4AC)] = Tu669bhFa[(-606131-(-607938))](("TextL".."abel"), { ["Position"] = hH45k3O["UDim2"]["fromOffset"]((-795742-(-795760)), (113*2)), ["Size"] = hH45k3O["UDim2"]["new"]((1), -(18*2), (0), (6*2)), ["BackgroundTransparency"] = (1), ["Font"] = hH45k3O["Enum"]["Font"]["Gotham"], ["Text"] = ("Fyy Communit".."y  â¢  Secu".."re Runtime"), ["TextColor3"] = Tu669bhFa[(-347215-(-347701))]["Faint"], ["TextSize"] = (-221135-(-221143)), ["TextTransparency"] = (1), ["TextXAlignment"] = hH45k3O["Enum"]["TextXAlignment"]["Left"], ["Parent"] = Tu669bhFa[(47+652)], }) Tu669bhFa[(-619175-(-620400))] = (0) Tu669bhFa[(871+377)] = true Tu669bhFa[(1262-2)] = false Tu669bhFa[(531+749)] = nil Tu669bhFa[(1326-25)] = nil Tu669bhFa[(1331-19)] = nil Tu669bhFa[(0x535)] = "licensed" Tu669bhFa[(271*5)] = nil Tu669bhFa[(-608396-(-609763))] = nil Tu669bhFa[(-764400-(-766254))]=function() return(function(R5jjl44) Tu669bhFa[(1274-49)] = Tu669bhFa[(0x4C9)] + (1) R5jjl44[(0xF6F)] = Tu669bhFa[(1258-33)] hH45k3O["task"]["spawn"](function() while Tu669bhFa[(0x4E0)] and R5jjl44[(3377+574)] == Tu669bhFa[(245*5)] do Tu669bhFa[(611*3)](Tu669bhFa[(179*5)], 0.55, { ["BackgroundTransparency"] = 0.72 }, hH45k3O["Enum"]["EasingStyle"]["Sine"]) hH45k3O["task"]["wait"](0.55) Tu669bhFa[(1791+42)](Tu669bhFa[(179*5)], 0.55, { ["BackgroundTransparency"] = (0) }, hH45k3O["Enum"]["EasingStyle"]["Sine"]) hH45k3O["task"]["wait"](0.55) end end) end)({}) end Tu669bhFa[(-420623-(-422489))]=function() return Tu669bhFa[(1398-65)] == ("public_ma".."intenance") and Tu669bhFa[(469*2)]["Visible"] and Tu669bhFa[(-868458-(-869396))] or Tu669bhFa[(-184810-(-185918))] end Tu669bhFa[(379*5)]=function(eoBA1, W0211wjXQ) return(function(pFiKP8ijP) pFiKP8ijP[(4009-35)] = Tu669bhFa[(1687+179)]() pFiKP8ijP[(2620+1354)]["Text"] = hH45k3O["tostring"](eoBA1 or "") if W0211wjXQ then pFiKP8ijP[(3675+299)]["TextColor3"] = W0211wjXQ end end)({}) end Tu669bhFa[(0x781)]=function(YIfm7z, x98oLjn) YIfm7z = hH45k3O["math"]["clamp"](YIfm7z, (0), (1)) if x98oLjn then Tu669bhFa[(-318803-(-320698))](x98oLjn) end Tu669bhFa[(1846-13)](Tu669bhFa[(438+710)], 0.32, { ["Size"] = hH45k3O["UDim2"]["fromScale"](YIfm7z, (1)) }) end Tu669bhFa[(0x79B)]=function() Tu669bhFa[(1579+254)](Tu669bhFa[(-999071-(-999698))], 0.22, { ["BackgroundTransparency"] = 0.36 }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) Tu669bhFa[(1901-68)](Tu669bhFa[(739-40)], 0.28, { ["Position"] = hH45k3O["UDim2"]["fromScale"](0.5, 0.5), ["BackgroundTransparency"] = (0) }) Tu669bhFa[(26+1807)](Tu669bhFa[(-995678-(-996432))], 0.42, { ["Scale"] = (1) }, hH45k3O["Enum"]["EasingStyle"]["Back"]) Tu669bhFa[(-373503-(-375336))](Tu669bhFa[(331+395)], 0.28, { ["Transparency"] = 0.42 }) Tu669bhFa[(611*3)](Tu669bhFa[(548+224)], 0.3, { ["BackgroundTransparency"] = (0) }) Tu669bhFa[(0x729)](Tu669bhFa[(-133087-(-133943))], 0.28, { ["BackgroundTransparency"] = (0) }) Tu669bhFa[(0x729)](Tu669bhFa[(0x45F)], 0.28, { ["BackgroundTransparency"] = (0) }) Tu669bhFa[(0x729)](Tu669bhFa[(520+628)], 0.28, { ["BackgroundTransparency"] = (0) }) for V5J6oh, nWpO6 in hH45k3O["ipairs"]({ Tu669bhFa[(908-84)], Tu669bhFa[(0x33F)], Tu669bhFa[(0x394)], Tu669bhFa[(939-13)], Tu669bhFa[(-110955-(-112063))], Tu669bhFa[(317+879)] }) do if nWpO6 and nWpO6["TextTransparency"] ~= nil then Tu669bhFa[(1861-28)](nWpO6, 0.25, { ["TextTransparency"] = (0) }) end end Tu669bhFa[(161+1672)](Tu669bhFa[(884-75)], 0.25, { ["ImageTransparency"] = (0) }) Tu669bhFa[(611*3)](Tu669bhFa[(179*5)], 0.25, { ["BackgroundTransparency"] = (0) }) Tu669bhFa[(927*2)]() end Tu669bhFa[(-255027-(-256420))] = false Tu669bhFa[(627+783)] = nil Tu669bhFa[(287*5)] = nil KkykK2E(Tu669bhFa[(-340548-(-341247))]["InputBegan"],"Connect",function(uD1PYZ5gP) if uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["MouseButton1"] or uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["Touch"] then Tu669bhFa[(0x571)] = true Tu669bhFa[(-147133-(-148543))] = uD1PYZ5gP["Position"] Tu669bhFa[(287*5)] = Tu669bhFa[(-813156-(-813855))]["Position"] end end) KkykK2E(Tu669bhFa[(43*5)]["InputChanged"],"Connect",function(uD1PYZ5gP) return(function(ZG0SKPL) if Tu669bhFa[(227+1166)] and (uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["MouseMovement"] or uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["Touch"]) then ZG0SKPL[(529+3470)] = uD1PYZ5gP["Position"] - Tu669bhFa[(-579991-(-581401))] Tu669bhFa[(798-99)]["Position"] = Tu669bhFa[(762+673)] + hH45k3O["UDim2"]["fromOffset"](ZG0SKPL[(1333*3)]["X"], ZG0SKPL[(0xF9F)]["Y"]) end end)({}) end) KkykK2E(Tu669bhFa[(0xD7)]["InputEnded"],"Connect",function(uD1PYZ5gP) if uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["MouseButton1"] or uD1PYZ5gP["UserInputType"] == hH45k3O["Enum"]["UserInputType"]["Touch"] then Tu669bhFa[(1490-97)] = false end end) Tu669bhFa[(1345+618)]=function() if not Tu669bhFa[(0x4E0)] then return end Tu669bhFa[(0x4E0)] = false Tu669bhFa[(245*5)] = Tu669bhFa[(1318-93)] + (1) Tu669bhFa[(1843-10)](Tu669bhFa[(-449357-(-450111))], 0.2, { ["Scale"] = 0.965 }, hH45k3O["Enum"]["EasingStyle"]["Quart"], hH45k3O["Enum"]["EasingDirection"]["In"]) Tu669bhFa[(1858-25)](Tu669bhFa[(-790141-(-790840))], 0.22, { ["Position"] = hH45k3O["UDim2"]["new"](0.5, (0), 0.5, -(-187872-(-187880))), ["BackgroundTransparency"] = (1) }, hH45k3O["Enum"]["EasingStyle"]["Quart"], hH45k3O["Enum"]["EasingDirection"]["In"]) Tu669bhFa[(1769+64)](Tu669bhFa[(641-14)], 0.28, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(-552725-(-554558))](Tu669bhFa[(389+337)], 0.2, { ["Transparency"] = (1) }) Tu669bhFa[(1835-2)](Tu669bhFa[(811-39)], 0.2, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(1925-92)](Tu669bhFa[(411+445)], 0.2, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(0x729)](Tu669bhFa[(105+790)], 0.2, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(1895-62)](Tu669bhFa[(373*3)], 0.2, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(1540+293)](Tu669bhFa[(989+159)], 0.2, { ["BackgroundTransparency"] = (1) }) Tu669bhFa[(611*3)](Tu669bhFa[(490*2)], 0.2, { ["BackgroundTransparency"] = (1), ["TextTransparency"] = (1) }) Tu669bhFa[(611*3)](Tu669bhFa[(1082-89)], 0.2, { ["Transparency"] = (1) }) Tu669bhFa[(-768880-(-770713))](Tu669bhFa[(511*2)], 0.2, { ["BackgroundTransparency"] = (1), ["TextTransparency"] = (1) }) Tu669bhFa[(-169403-(-171236))](Tu669bhFa[(524*2)], 0.2, { ["BackgroundTransparency"] = (1), ["TextTransparency"] = (1) }) Tu669bhFa[(611*3)](Tu669bhFa[(357*3)], 0.2, { ["Transparency"] = (1) }) Tu669bhFa[(0x729)](Tu669bhFa[(0x43A)], 0.2, { ["BackgroundTransparency"] = (1), ["TextTransparency"] = (1) }) Tu669bhFa[(1803+30)](Tu669bhFa[(1119-28)], 0.2, { ["Transparency"] = (1) }) Tu669bhFa[(-341693-(-343526))](Tu669bhFa[(1256-80)], 0.2, { ["BackgroundTransparency"] = (1), ["TextTransparency"] = (1) }) Tu669bhFa[(1050+783)](Tu669bhFa[(1234-47)], 0.2, { ["Transparency"] = (1) }) for V5J6oh, nWpO6 in hH45k3O["ipairs"]({ Tu669bhFa[(170+654)], Tu669bhFa[(0x33F)], Tu669bhFa[(0x394)], Tu669bhFa[(975-49)], Tu669bhFa[(0x454)], Tu669bhFa[(0x3AA)], Tu669bhFa[(676+520)] }) do if nWpO6 and nWpO6["TextTransparency"] ~= nil then Tu669bhFa[(-348979-(-350812))](nWpO6, 0.15, { ["TextTransparency"] = (1) }) end end Tu669bhFa[(611*3)](Tu669bhFa[(301+508)], 0.15, { ["ImageTransparency"] = (1) }) hH45k3O["task"]["wait"](0.3) if Tu669bhFa[(694-92)] then Tu669bhFa[(-659810-(-660412))]["Enabled"] = false hH45k3O["pcall"](Tu669bhFa[(0x25A)]["Destroy"], Tu669bhFa[(244+358)]) end end Tu669bhFa[(-462214-(-464194))]=function(eoBA1, twE2Oo, raoi5vR) return(function(W0S1n9Dn) Tu669bhFa[(31+1194)] = Tu669bhFa[(1280-55)] + (1) W0S1n9Dn[(-771302-(-775322))] = Tu669bhFa[(0x4C9)] Tu669bhFa[(0x39E)]["Text"] = twE2Oo or "Launch interrupted") Tu669bhFa[(1269+626)](eoBA1 or ("Autho".."rizat".."ion f".."ailed"), Tu669bhFa[(551-65)]["Error"]) Tu669bhFa[(102+814)]["Text"] = raoi5vR and "CRASHED" or "FAILED" Tu669bhFa[(0x394)]["TextColor3"] = Tu669bhFa[(-771641-(-772127))]["Error"] Tu669bhFa[(0x37F)]["BackgroundColor3"] = Tu669bhFa[(243*2)]["Error"] Tu669bhFa[(-749345-(-750117))]["BackgroundColor3"] = Tu669bhFa[(439+47)]["Error"] Tu669bhFa[(1191-43)]["BackgroundColor3"] = Tu669bhFa[(3+483)]["Error"] if raoi5vR then Tu669bhFa[(1397-30)] = hH45k3O["tostring"](eoBA1) Tu669bhFa[(541*2)]["Text"] = "REPORT ISSUE" Tu669bhFa[(541*2)]["TextColor3"] = Tu669bhFa[(-475388-(-475874))]["Text"] Tu669bhFa[(-597818-(-598840))]["Text"] = "FAILED" Tu669bhFa[(611*3)](Tu669bhFa[(1115-93)], 0.2, { ["BackgroundColor3"] = Tu669bhFa[(575-89)]["Error"] }) elseif Tu669bhFa[(341+992)] == "licensed" then Tu669bhFa[(-373119-(-374141))]["Text"] = "INVALID" Tu669bhFa[(0x729)](Tu669bhFa[(0x3FE)], 0.2, { ["BackgroundColor3"] = Tu669bhFa[(243*2)]["Error"] }) Tu669bhFa[(524*2)]["Active"] = true Tu669bhFa[(541*2)]["Active"] = true Tu669bhFa[(-321087-(-322920))](Tu669bhFa[(1023+25)], 0.2, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(1641+192)](Tu669bhFa[(-561405-(-562487))], 0.2, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) end Tu669bhFa[(-190049-(-191882))](Tu669bhFa[(377*2)], 0.12, { ["Scale"] = 1.015 }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) hH45k3O["task"]["delay"](0.12, function() if Tu669bhFa[(624*2)] and W0S1n9Dn[(4048-28)] == Tu669bhFa[(359+866)] then Tu669bhFa[(653+1180)](Tu669bhFa[(377*2)], 0.18, { ["Scale"] = (1) }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) end end) hH45k3O["task"]["spawn"](function() for tA7Ia1 = (8-3), (1), -(1) do if not Tu669bhFa[(-271172-(-272420))] or W0S1n9Dn[(-761519-(-765539))] ~= Tu669bhFa[(1258-33)] then return end Tu669bhFa[(-971734-(-972930))]["Text"] = hH45k3O["string"]["format"](("Closing automatically in %d second%".."s â¢ Click Discord to copy invite"), tA7Ia1, tA7Ia1 == (1) and "") or "s") hH45k3O["task"]["wait"]((1)) end if Tu669bhFa[(1338-90)] and W0S1n9Dn[(2010*2)] == Tu669bhFa[(1315-90)] then Tu669bhFa[(99+1864)]() end end) end)({}) end Tu669bhFa[(999*2)]=function() Tu669bhFa[(0x781)]((1), ("Opening".." your e".."xperien".."ce...")) Tu669bhFa[(1004-78)]["Text"] = Tu669bhFa[(1378-45)] == "licensed" and ("Welcom".."e back") or ("You\'".."re a".."ll s".."et") Tu669bhFa[(-812957-(-814852))](("Runtime l".."oaded suc".."cessfully"), Tu669bhFa[(562-76)]["Success"]) Tu669bhFa[(928-12)]["Text"] = "READY" Tu669bhFa[(217+699)]["TextColor3"] = Tu669bhFa[(0x1E6)]["Success"] Tu669bhFa[(179*5)]["BackgroundColor3"] = Tu669bhFa[(243*2)]["Success"] Tu669bhFa[(168+604)]["BackgroundColor3"] = Tu669bhFa[(292+194)]["Success"] Tu669bhFa[(-766246-(-767394))]["BackgroundColor3"] = Tu669bhFa[(-815017-(-815503))]["Success"] if Tu669bhFa[(-484140-(-485162))]["Visible"] then Tu669bhFa[(1031-9)]["Text"] = "READY" Tu669bhFa[(-941837-(-943670))](Tu669bhFa[(511*2)], 0.2, { ["BackgroundColor3"] = Tu669bhFa[(518-32)]["Success"] }) end Tu669bhFa[(1887-54)](Tu669bhFa[(200+554)], 0.16, { ["Scale"] = 1.015 }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) hH45k3O["task"]["wait"](0.65) Tu669bhFa[(1996-33)]() end Tu669bhFa[(0x7E3)]=function() Tu669bhFa[(1190+143)] = "public_maintenance" Tu669bhFa[(1015-99)]["Text"] = "KEYLESS" Tu669bhFa[(967-51)]["TextColor3"] = Tu669bhFa[(268+218)]["Success"] Tu669bhFa[(859+36)]["BackgroundColor3"] = Tu669bhFa[(-709036-(-709522))]["Success"] Tu669bhFa[(0x39E)]["Text"] = "Keyless Access Active" Tu669bhFa[(479*2)]["Visible"] = false Tu669bhFa[(0x411)]["Visible"] = false Tu669bhFa[(554*2)]["Visible"] = false Tu669bhFa[(914+24)]["Visible"] = true Tu669bhFa[(654+284)]["Text"] = "Keyless access granted â¢ Free Premium features unlocked\nConnecting to online session..." Tu669bhFa[(180+758)]["TextColor3"] = Tu669bhFa[(0x1E6)]["Muted"] Tu669bhFa[(1530+303)](Tu669bhFa[(0x3AA)], 0.25, { ["TextTransparency"] = (0) }) Tu669bhFa[(672+447)]["Position"] = hH45k3O["UDim2"]["fromOffset"]((-220590-(-220608)), (80*2)) Tu669bhFa[(588*2)]["Visible"] = true Tu669bhFa[(-310386-(-311562))]["Text"] = ("JOIN ".."DISCO".."RD CO".."MMUNI".."TY") Tu669bhFa[(1184-8)]["TextColor3"] = Tu669bhFa[(-822267-(-822753))]["Text"] Tu669bhFa[(1864-31)](Tu669bhFa[(620+556)], 0.25, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(1872-39)](Tu669bhFa[(-897810-(-898997))], 0.25, { ["Transparency"] = 0.5 }) end Tu669bhFa[(2053-15)]=function(qU4yC) Tu669bhFa[(0x535)] = "licensed" Tu669bhFa[(890+26)]["Text"] = ("KEY ".."REQU".."IRED") Tu669bhFa[(0x394)]["TextColor3"] = Tu669bhFa[(500-14)]["AccentHigh"] Tu669bhFa[(0x37F)]["BackgroundColor3"] = Tu669bhFa[(243*2)]["AccentHigh"] Tu669bhFa[(-474506-(-475432))]["Text"] = ("Enter".." your".." lice".."nse k".."ey") Tu669bhFa[(429+509)]["Visible"] = false Tu669bhFa[(1165-57)]["Visible"] = true Tu669bhFa[(0x498)]["Visible"] = false Tu669bhFa[(0x45F)]["Position"] = hH45k3O["UDim2"]["fromOffset"]((24-6), (249-43)) Tu669bhFa[(1176-68)]["Text"] = qU4yC or ("Enter y".."our key".." to con".."tinue") Tu669bhFa[(1150-42)]["TextColor3"] = qU4yC and Tu669bhFa[(243*2)]["Error"] or Tu669bhFa[(63+423)]["Muted"] Tu669bhFa[(479*2)]["Visible"] = true Tu669bhFa[(55+986)]["Visible"] = true Tu669bhFa[(-206849-(-207871))]["Active"] = true Tu669bhFa[(0x418)]["Active"] = true Tu669bhFa[(541*2)]["Active"] = true Tu669bhFa[(407+615)]["Text"] = "CONTINUE" Tu669bhFa[(1059-37)]["BackgroundColor3"] = Tu669bhFa[(0x1E6)]["Accent"] Tu669bhFa[(1931-98)](Tu669bhFa[(117+863)], 0.25, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(932+901)](Tu669bhFa[(-405118-(-406111))], 0.25, { ["Transparency"] = 0.5 }) Tu669bhFa[(611*3)](Tu669bhFa[(1047-25)], 0.25, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(1002+831)](Tu669bhFa[(0x418)], 0.25, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(0x729)](Tu669bhFa[(357*3)], 0.25, { ["Transparency"] = 0.5 }) Tu669bhFa[(0x729)](Tu669bhFa[(-380714-(-381796))], 0.25, { ["BackgroundTransparency"] = (0), ["TextTransparency"] = (0) }) Tu669bhFa[(-693539-(-695372))](Tu669bhFa[(919+172)], 0.25, { ["Transparency"] = 0.5 }) end Tu669bhFa[(321+1729)]=function(O3y6z, nWpO6) hH45k3O["pcall"](function() if hH45k3O["type"](hH45k3O["getgenv"] and hH45k3O["getgenv"]()["setclipboard"]) == "function" then hH45k3O["getgenv"]()["setclipboard"](O3y6z) elseif hH45k3O["type"](hH45k3O["setclipboard"]) == "function" then hH45k3O["setclipboard"](O3y6z) end end) Tu669bhFa[(1940-45)](nWpO6 .. (" copied to ".."clipboard!"), Tu669bhFa[(0x1E6)]["Success"]) hH45k3O["task"]["delay"](1.5, function() if not Tu669bhFa[(801+459)] and Tu669bhFa[(-501874-(-503122))] then Tu669bhFa[(-409829-(-411724))](("Enter your ke".."y to continue"), Tu669bhFa[(243*2)]["Muted"]) end end) end KkykK2E(Tu669bhFa[(524*2)]["MouseButton1Click"],"Connect",function() if not Tu669bhFa[(-210164-(-211424))] then Tu669bhFa[(2093-43)](Tu669bhFa[(346+26)], "Free key link") end end) KkykK2E(Tu669bhFa[(541*2)]["MouseButton1Click"],"Connect",function() if Tu669bhFa[(-859297-(-860664))] then Tu669bhFa[(2103-53)](Tu669bhFa[(-245246-(-246613))] .. ("\nDis".."cord"..": ") .. Tu669bhFa[(69+290)], "Error trace") else Tu669bhFa[(0x802)](Tu669bhFa[(423-64)], ("Disc".."ord ".."invi".."te l".."ink") end end) KkykK2E(Tu669bhFa[(588*2)]["MouseButton1Click"],"Connect",function() Tu669bhFa[(2089-39)](Tu669bhFa[(405-46)], "Discord invite link") end) Tu669bhFa[(0x80C)]=function(v5pKnj, iChmNk5) return(function(JSvyO7j2z) if not Tu669bhFa[(640*2)] then return nil, ("INVA".."LID_".."SESS".."ION") end if not Tu669bhFa[(1190+111)] or not Tu669bhFa[(-671507-(-672819))] then return nil, ("CONTIN".."UITY_M".."ISSING") end JSvyO7j2z[(311*13)], JSvyO7j2z[(2035*2)] = Tu669bhFa[(1816-76)](("/api/v1/check/hea".."rtbeat/challenge"), "POST") if not JSvyO7j2z[(0xFCB)] then return nil, JSvyO7j2z[(2035*2)] or ("NETWO".."RK_OU".."TAGE") end JSvyO7j2z[(4173-96)] = Tu669bhFa[(293*5)](JSvyO7j2z[(4056-13)]["transportKey"]) if not JSvyO7j2z[(1359*3)] or #JSvyO7j2z[(1359*3)] ~= (17+15) then return nil, ("CHALLENGE".."_INVALID") end JSvyO7j2z[(3291+793)] = Tu669bhFa[(1717-19)]() JSvyO7j2z[(2050*2)] = KkykK2E(Tu669bhFa[(87+144)],"JSONEncode",{ ["sessionId"] = Tu669bhFa[(640*2)]["sessionId"], ["sessionToken"] = Tu669bhFa[(640*2)]["sessionToken"], ["sequence"] = v5pKnj, ["clientState"] = iChmNk5 or "running", ["licenseKey"] = Tu669bhFa[(734+567)], ["hwid"] = Tu669bhFa[(1055+257)], ["robloxUsername"] = Tu669bhFa[(-760549-(-760771))]["LocalPlayer"] and Tu669bhFa[(166+56)]["LocalPlayer"]["Name"] or "Unknown", }) JSvyO7j2z[(0x1020)] = Tu669bhFa[(0x68B)](JSvyO7j2z[(951+3149)], JSvyO7j2z[(2042*2)], KkykK2E(JSvyO7j2z[(767+3310)],"sub",1,0x10)) JSvyO7j2z[(2789+1358)] = Tu669bhFa[(529+1153)](JSvyO7j2z[(2042*2)] .. JSvyO7j2z[(154+3974)], KkykK2E(JSvyO7j2z[(274+3803)],"sub",20-3,10+22)) JSvyO7j2z[(492+3683)], JSvyO7j2z[(-162339-(-166526))] = Tu669bhFa[(1744-11)](("/api/v".."1/chec".."k/hear".."tbeat"), "POST", { ["challengeId"] = JSvyO7j2z[(4077-34)]["challengeId"], ["nonce"] = Tu669bhFa[(1518-67)](JSvyO7j2z[(3919+165)]), ["data"] = Tu669bhFa[(0x5AB)](JSvyO7j2z[(4138-10)]), ["tag"] = Tu669bhFa[(-966644-(-968095))](JSvyO7j2z[(0x1033)]), }, ("applicat".."ion/json")) JSvyO7j2z[(4066+130)]=nil if hH45k3O["type"](JSvyO7j2z[(0x105B)]) == "string" then hH45k3O["pcall"](function() JSvyO7j2z[(2098*2)] = KkykK2E(Tu669bhFa[(313-82)],"JSONDecode",JSvyO7j2z[(-148984-(-153171))]) end) end if hH45k3O["type"](JSvyO7j2z[(0x1064)]) == "table") and hH45k3O["type"](JSvyO7j2z[(-224413-(-228609))]["state"]) == "string" and (JSvyO7j2z[(0x104F)] == (100*2) or JSvyO7j2z[(3273+902)] == (330+71) or JSvyO7j2z[(2214+1961)] == (287+116)) then if JSvyO7j2z[(2098*2)]["state"] ~= "active") and JSvyO7j2z[(2098*2)]["state"] ~= ("upda".."te_a".."vail".."able") then Tu669bhFa[(640*2)] = nil end return JSvyO7j2z[(4217-21)], nil end return nil, ("TRANSIENT_HEAR".."TBEAT_FAILURE") end)({}) end Tu669bhFa[(415*5)]=function(J9ho2, S508M8) return(function(Ha21Tv0v8) Ha21Tv0v8[(4000+224)] = Tu669bhFa[(892*2)]() Ha21Tv0v8[(-964887-(-969123))] = Tu669bhFa[(42+1291)] == "public_maintenance" if hH45k3O["type"](J9ho2) ~= "table") or hH45k3O["type"](J9ho2["session"]) ~= "table" then Tu669bhFa[(990*2)](("A verified server sess".."ion is required before".." loading the runtime."), ("Sess".."ion ".."Unav".."aila".."ble"), false) return end Tu669bhFa[(163+1117)] = J9ho2["session"] Tu669bhFa[(1401-100)] = J9ho2["continuityCredential"] or S508M8 Tu669bhFa[(-795802-(-797114))] = Tu669bhFa[(858*2)]() if hH45k3O["type"](Tu669bhFa[(-648141-(-649421))]["sessionId"]) ~= "string" or hH45k3O["type"](Tu669bhFa[(0x500)]["sessionToken"]) ~= "string" or hH45k3O["type"](Tu669bhFa[(536+765)]) ~= "string" or Tu669bhFa[(1315-14)] == "" or hH45k3O["type"](Tu669bhFa[(0x520)]) ~= "string") or Tu669bhFa[(-392542-(-393854))] == "" then Tu669bhFa[(880+400)], Tu669bhFa[(0x515)], Tu669bhFa[(972+340)] = nil, nil, nil Tu669bhFa[(990*2)](("The server r".."eturned an i".."ncomplete au".."thorization ".."session."), ("Sess".."ion ".."Inva".."lid"), false) return end Ha21Tv0v8[(377+3879)] = Ha21Tv0v8[(-254070-(-258306))] and "premium" or (J9ho2["accessTier"] or (J9ho2["licenseType"] == "premium") and "premium" or "free") Ha21Tv0v8[(4289-16)] = hH45k3O["tonumber"](Tu669bhFa[(1344-64)]["nextHeartbeatSeconds"]) or (Ha21Tv0v8[(0x108C)] and (60*2) or (Ha21Tv0v8[(2128*2)] == "premium" and (46+14) or (46-16))) Ha21Tv0v8[(3707+585)] = { ["sessionId"] = Tu669bhFa[(-380713-(-381993))]["sessionId"], ["protocolVersion"] = (1), ["accessMode"] = Tu669bhFa[(1414-81)], ["accessTier"] = Ha21Tv0v8[(4321-65)], ["licenseType"] = Ha21Tv0v8[(1205+3051)], ["nextHeartbeatSeconds"] = Ha21Tv0v8[(-193470-(-197743))], } Tu669bhFa[(1989-68)](0.65, ("Prepa".."ring ".."game ".."runti".."me...")) Ha21Tv0v8[(4309-6)], Ha21Tv0v8[(-925162-(-929477))] = Tu669bhFa[(-278592-(-280351))]() if not Ha21Tv0v8[(331*13)] then if Tu669bhFa[(1113+167)] and Tu669bhFa[(1345-65)]["sessionId"] and Tu669bhFa[(1307-27)]["sessionToken"] then Ha21Tv0v8[(4370-46)], Ha21Tv0v8[(1380+2970)] = Tu669bhFa[(1756-23)](("/api/v1/scr".."ipt-distrib".."ution/runti".."me/resolve"), "POST", { ["sessionId"] = Tu669bhFa[(0x500)]["sessionId"], ["sessionToken"] = Tu669bhFa[(0x500)]["sessionToken"], ["gameId"] = hH45k3O["tostring"](hH45k3O["game"]["GameId"]), }, "text/plain") if Ha21Tv0v8[(-510240-(-514564))] == (-189702-(-189902)) and hH45k3O["type"](Ha21Tv0v8[(-529894-(-534244))]) == "string" and #Ha21Tv0v8[(0x10FE)] > (-515415-(-515479)) then Ha21Tv0v8[(331*13)] = Ha21Tv0v8[(3528+822)] end end end if not Ha21Tv0v8[(0x10CF)] then Tu669bhFa[(-961016-(-962996))](Ha21Tv0v8[(2050+2265)] or "Script distribution temporarily unavailable"), ("Dist".."ribu".."tion".." Off".."line"), false) return end Tu669bhFa[(1931-10)](0.92, "Executing ") .. Ha21Tv0v8[(0x1080)] .. "...") Ha21Tv0v8[(4393-29)], Ha21Tv0v8[(264+4127)] = hH45k3O["loadstring"](Ha21Tv0v8[(4344-41)], ("@Fyy".."Comm".."unit".."y") if not Ha21Tv0v8[(4368-4)] then Tu669bhFa[(2066-86)](("Comp".."ilat".."ion ".."fail".."ed: ") .. hH45k3O["tostring"](Ha21Tv0v8[(-709124-(-713515))]), ("Synta".."x / C".."ompil".."e Err".."or"), true) return end Ha21Tv0v8[(0x1132)] = { ["session"] = Ha21Tv0v8[(0x10C4)], ["heartbeat"] = Tu669bhFa[(-137908-(-139968))], } hH45k3O["pcall"](function() if hH45k3O["type"](hH45k3O["getgenv"]) == "function" and hH45k3O["type"](hH45k3O["getgenv"]()) == "table" then hH45k3O["getgenv"]()["__FYY_ACCESS_HANDOFF"] = Ha21Tv0v8[(4461-59)] end end) hH45k3O["pcall"](function() _G["__FYY_ACCESS_HANDOFF"] = Ha21Tv0v8[(2201*2)] end) hH45k3O["pcall"](function() if hH45k3O["type"](shared) == "table" then shared["__FYY_ACCESS_HANDOFF"] = Ha21Tv0v8[(1172+3230)] end end) Ha21Tv0v8[(0x114F)], Ha21Tv0v8[(2227*2)], Ha21Tv0v8[(4572-96)] = false, false, nil hH45k3O["task"]["spawn"](function() Ha21Tv0v8[(-215260-(-219714))], Ha21Tv0v8[(0x117C)] = hH45k3O["xpcall"](Ha21Tv0v8[(0x110C)], hH45k3O["debug"]["traceback"]) Ha21Tv0v8[(4469-38)] = true end) Ha21Tv0v8[(0x1185)] = hH45k3O["os"]["clock"]() + (-408890-(-408935)) while not Ha21Tv0v8[(-450505-(-454936))] and hH45k3O["os"]["clock"]() < Ha21Tv0v8[(1495*3)] do hH45k3O["task"]["wait"](0.05) end if not Ha21Tv0v8[(0x114F)] then Tu669bhFa[(990*2)]("The game runtime did not finish starting in time. Please execute again."), "Runtime Startup Timeout"), true) return end if not Ha21Tv0v8[(-577885-(-582339))] or hH45k3O["type"](Ha21Tv0v8[(4563-87)]) ~= "table" then hH45k3O["pcall"](function() if hH45k3O["getgenv"] then hH45k3O["getgenv"]()["__FYY_ACCESS_HANDOFF"] = nil end end) _G["__FYY_ACCESS_HANDOFF"] = nil hH45k3O["pcall"](function() if hH45k3O["type"](shared) == "table" then shared["__FYY_ACCESS_HANDOFF"] = nil end end) Ha21Tv0v8[(2256*2)] = Ha21Tv0v8[(-110058-(-114512))] and "Runtime returned before creating the menu.") or hH45k3O["tostring"](Ha21Tv0v8[(4550-74)]) hH45k3O["warn"](("[FyyCo".."mmunit".."y] Run".."time e".."rror:\n") .. Ha21Tv0v8[(-472590-(-477102))]) Tu669bhFa[(990*2)](Ha21Tv0v8[(2767+1745)], "Runtime Error"), true) return end Tu669bhFa[(2087-89)]() end)({}) end Tu669bhFa[(0x834)]=function(Ra8c3) return(function(Hp23Ur3) if Tu669bhFa[(-230436-(-231696))] then return end Tu669bhFa[(0x4EC)] = true Hp23Ur3[(1034+3496)] = Tu669bhFa[(-313240-(-314956))]() Tu669bhFa[(787+193)]["TextEditable"] = false Tu669bhFa[(490*2)]["Text"] = Ra8c3 Tu669bhFa[(985+848)](Tu669bhFa[(1039-59)], 0.18, { ["BackgroundColor3"] = hH45k3O["Color3"]["fromRGB"]((0x14), (12*2), (18+13)) }) Tu669bhFa[(511*2)]["Active"] = false Tu669bhFa[(-166611-(-167633))]["Text"] = ("VERIF".."YING") Tu669bhFa[(-364058-(-365891))](Tu669bhFa[(0x3FE)], 0.18, { ["BackgroundColor3"] = Tu669bhFa[(515-29)]["AccentHigh"] }) Tu669bhFa[(126+922)]["Active"] = false Tu669bhFa[(1138-56)]["Active"] = false Tu669bhFa[(-649823-(-651656))](Tu669bhFa[(524*2)], 0.18, { ["BackgroundTransparency"] = 0.5, ["TextTransparency"] = 0.4 }) Tu669bhFa[(576+1257)](Tu669bhFa[(-588734-(-589816))], 0.18, { ["BackgroundTransparency"] = 0.5, ["TextTransparency"] = 0.4 }) Tu669bhFa[(1018-92)]["Text"] = ("Verif".."ying ".."Licen".."se") Tu669bhFa[(458*2)]["Text"] = ("AUTH".."ORIZ".."ING") Tu669bhFa[(458*2)]["TextColor3"] = Tu669bhFa[(556-70)]["Text"] Tu669bhFa[(179*5)]["BackgroundColor3"] = Tu669bhFa[(243*2)]["AccentHigh"] Tu669bhFa[(0x781)](0.20, "Connecting to Fyy Cloud...") Hp23Ur3[(633+3912)], Hp23Ur3[(4225+333)] = Tu669bhFa[(870*2)]("/api/v1/check/challenge"), "GET") if not Hp23Ur3[(4605-60)] or not Hp23Ur3[(1515*3)]["transportKey"] then Tu669bhFa[(-899543-(-900803))] = false Tu669bhFa[(1019*2)](Tu669bhFa[(0x6EB)](Hp23Ur3[(2279*2)] or "REQUEST_FAILED"))) Tu669bhFa[(490*2)]["Text"] = "" Tu669bhFa[(1043-63)]["TextEditable"] = true Tu669bhFa[(1012-32)]["BackgroundColor3"] = Tu669bhFa[(278+208)]["SurfaceHigh"] hH45k3O["task"]["defer"](function() hH45k3O["pcall"](Tu669bhFa[(-967273-(-968253))]["CaptureFocus"], Tu669bhFa[(-773893-(-774873))]) end) return end Tu669bhFa[(1098+823)](0.40, "Verifying license entitlement...") Hp23Ur3[(635+3947)] = Tu669bhFa[(293*5)](Hp23Ur3[(4156+389)]["transportKey"]) if hH45k3O["type"](Hp23Ur3[(-424673-(-429255))]) ~= "string") or #Hp23Ur3[(4647-65)] ~= (-554778-(-554810)) then Tu669bhFa[(1266-6)] = false Tu669bhFa[(-467698-(-469736))](("The secure ch".."allenge was i".."nvalid. Pleas".."e try again.") Tu669bhFa[(1033-53)]["Text"] = "" Tu669bhFa[(1047-67)]["TextEditable"] = true Tu669bhFa[(100+880)]["BackgroundColor3"] = Tu669bhFa[(546-60)]["SurfaceHigh"] return end Hp23Ur3[(4646-49)] = Tu669bhFa[(0x6A2)]() Hp23Ur3[(2303*2)] = KkykK2E(Tu669bhFa[(82+149)],"JSONEncode",{ ["licenseKey"] = Ra8c3, ["hwid"] = Hp23Ur3[(0x11B2)], ["robloxUsername"] = Tu669bhFa[(-701057-(-701279))]["LocalPlayer"] and Tu669bhFa[(177+45)]["LocalPlayer"]["Name"] or "Unknown", }) Hp23Ur3[(3084+1530)] = Tu669bhFa[(0x68B)](Hp23Ur3[(-717433-(-722039))], Hp23Ur3[(-777603-(-782200))], KkykK2E(Hp23Ur3[(2291*2)],"sub",1,5+11)) Hp23Ur3[(2857+1768)] = Tu669bhFa[(190+1492)](Hp23Ur3[(0x11F5)] .. Hp23Ur3[(0x1206)], KkykK2E(Hp23Ur3[(2291*2)],"sub",26-9,-913352-(-913384))) Hp23Ur3[(-661714-(-666354))], Hp23Ur3[(0x1230)] = Tu669bhFa[(-716940-(-718680))](("/api/v1".."/check"), "POST"), { ["challengeId"] = Hp23Ur3[(1515*3)]["challengeId"], ["nonce"] = Tu669bhFa[(-513122-(-514573))](Hp23Ur3[(1298+3299)]), ["data"] = Tu669bhFa[(0x5AB)](Hp23Ur3[(2307*2)]), ["tag"] = Tu669bhFa[(822+629)](Hp23Ur3[(925*5)]), }) if Hp23Ur3[(-290402-(-295042))] and Hp23Ur3[(2320*2)]["status"] == "ok" and Hp23Ur3[(240+4400)]["session"] then Tu669bhFa[(-698359-(-699950))](Ra8c3) Tu669bhFa[(-163891-(-165812))](0.55, ("License verified â¢".." Entitlement granted")) Tu669bhFa[(0x81B)](Hp23Ur3[(-183111-(-187751))], Ra8c3) else Tu669bhFa[(-977099-(-978359))] = false Hp23Ur3[(4718-36)] = Hp23Ur3[(2320*2)] and Hp23Ur3[(0x1220)]["code"] or Hp23Ur3[(-719727-(-724383))] or "REQUEST_FAILED") if Tu669bhFa[(614-65)][Hp23Ur3[(-458820-(-463502))]] then Tu669bhFa[(808*2)]() end Hp23Ur3[(0x1253)] = Tu669bhFa[(0x6EB)](Hp23Ur3[(2341*2)]) Tu669bhFa[(-259724-(-261762))](Hp23Ur3[(4776-85)]) Tu669bhFa[(490*2)]["Text"] = "" Tu669bhFa[(490*2)]["TextEditable"] = true Tu669bhFa[(1062-82)]["BackgroundColor3"] = Tu669bhFa[(-959469-(-959955))]["SurfaceHigh"] hH45k3O["task"]["defer"](function() hH45k3O["pcall"](Tu669bhFa[(1001-21)]["CaptureFocus"], Tu669bhFa[(85+895)]) end) Tu669bhFa[(871+962)](Tu669bhFa[(377*2)], 0.12, { ["Scale"] = 1.015 }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) hH45k3O["task"]["delay"](0.12, function() if Tu669bhFa[(380+868)] then Tu669bhFa[(0x729)](Tu669bhFa[(0x2F2)], 0.18, { ["Scale"] = (1) }, hH45k3O["Enum"]["EasingStyle"]["Quad"]) end end) end end)({}) end KkykK2E(Tu669bhFa[(21+1001)]["MouseButton1Click"],"Connect",function() return(function(v6MMRK1HL) v6MMRK1HL[(673*7)] = Tu669bhFa[(311*5)](Tu669bhFa[(0x3D4)]["Text"]) if v6MMRK1HL[(4726-15)] then Tu669bhFa[(0x834)](v6MMRK1HL[(4717-6)]) else Tu669bhFa[(554*2)]["Text"] = ("Enter ".."a vali".."d FYY ".."or TRI".."AL key") Tu669bhFa[(1189-81)]["TextColor3"] = Tu669bhFa[(243*2)]["Error"] hH45k3O["task"]["delay"](1.5, function() if not Tu669bhFa[(630*2)] and Tu669bhFa[(-845895-(-847143))] then Tu669bhFa[(1187-79)]["Text"] = "Enter your key to continue" Tu669bhFa[(113+995)]["TextColor3"] = Tu669bhFa[(243*2)]["Muted"] end end) end end)({}) end) KkykK2E(Tu669bhFa[(-547278-(-548258))]["FocusLost"],"Connect",function(lFQF8EY34) return(function(v04sG) if lFQF8EY34 then v04sG[(-450914-(-455640))] = Tu669bhFa[(0x613)](Tu669bhFa[(490*2)]["Text"]) if v04sG[(4809-83)] then Tu669bhFa[(0x834)](v04sG[(2363*2)]) end end end)({}) end) Tu669bhFa[(1081+866)]() hH45k3O["task"]["spawn"](function() return(function(n9D0A3Vw) n9D0A3Vw[(4817-62)] = hH45k3O["os"]["clock"]() if Tu669bhFa[(1614-77)]() then n9D0A3Vw[(-935535-(-940299))] = Tu669bhFa[(1559-40)]() hH45k3O["task"]["wait"](0.3) Tu669bhFa[(1957-36)](0.15, ("Checkin".."g execu".."tor com".."patibil".."ity...")) hH45k3O["task"]["wait"](0.5) Tu669bhFa[(-490294-(-492274))](hH45k3O["string"]["format"](("%s is not supported. Please ".."use a supported executor (De".."lta, Codex, Hydrogen, etc)."), n9D0A3Vw[(0x129C)]), ("Unsup".."porte".."d Exe".."cutor"), false) return end Tu669bhFa[(0x781)](0.12, ("Queryi".."ng acc".."ess mo".."de...")) n9D0A3Vw[(955*5)], n9D0A3Vw[(0x12B0)] = Tu669bhFa[(870*2)]("/api/v1/loader/access-mode"), "GET") n9D0A3Vw[(4870-69)] = n9D0A3Vw[(955*5)] and n9D0A3Vw[(955*5)]["data"] and n9D0A3Vw[(-581223-(-585998))]["data"]["mode"] or nil if n9D0A3Vw[(0x12C1)] ~= ("publi".."c_mai".."ntena".."nce") and n9D0A3Vw[(-838382-(-843183))] ~= "licensed" then Tu669bhFa[(-247780-(-249760))](Tu669bhFa[(1453+318)](n9D0A3Vw[(0x12B0)] or ("REQUE".."ST_FA".."ILED")), ("Connecti".."on Unava".."ilable"), false) return end Tu669bhFa[(-282699-(-284032))] = n9D0A3Vw[(-427403-(-432204))] if Tu669bhFa[(-578406-(-579739))] == ("publi".."c_mai".."ntena".."nce") then Tu669bhFa[(2022-3)]() Tu669bhFa[(-336446-(-338367))](0.30, ("Connect".."ing to ".."keyless".." sessio".."n...")) hH45k3O["task"]["wait"](0.35) n9D0A3Vw[(965*5)], n9D0A3Vw[(4860-18)] = Tu669bhFa[(-880196-(-881936))](("/api/".."v1/ch".."eck/c".."halle".."nge"), "GET") if not n9D0A3Vw[(0x12D9)] or not n9D0A3Vw[(0x12D9)]["transportKey"] then Tu669bhFa[(990*2)](Tu669bhFa[(-680894-(-682665))](n9D0A3Vw[(2421*2)] or "REQUEST_FAILED")), ("Keyless Sessio".."n Unavailable"), false) return end n9D0A3Vw[(-262400-(-267269))] = Tu669bhFa[(0x5B9)](n9D0A3Vw[(0x12D9)]["transportKey"]) if hH45k3O["type"](n9D0A3Vw[(-847414-(-852283))]) ~= "string" or #n9D0A3Vw[(1623*3)] ~= (16*2) then Tu669bhFa[(1988-8)](("The sec".."ure cha".."llenge ".."was inv".."alid."), ("Keyless Sess".."ion Invalid"), false) return end n9D0A3Vw[(4943-50)] = Tu669bhFa[(0x6A2)]() n9D0A3Vw[(0x1338)] = KkykK2E(Tu669bhFa[(-258830-(-259061))],"JSONEncode",{ ["hwid"] = Tu669bhFa[(970+746)](), ["robloxUsername"] = Tu669bhFa[(131+91)]["LocalPlayer"] and Tu669bhFa[(253-31)]["LocalPlayer"]["Name"] or "Unknown"), }) n9D0A3Vw[(1645*3)] = Tu669bhFa[(335*5)](n9D0A3Vw[(2460*2)], n9D0A3Vw[(1281+3612)], KkykK2E(n9D0A3Vw[(0x1305)],"sub",1,8*2)) n9D0A3Vw[(4977-22)] = Tu669bhFa[(1778-96)](n9D0A3Vw[(658+4235)] .. n9D0A3Vw[(5016-81)], KkykK2E(n9D0A3Vw[(-297772-(-302641))],"sub",10+7,-552043-(-552075))) n9D0A3Vw[(-524315-(-529288))], n9D0A3Vw[(5026-40)] = Tu669bhFa[(1749-9)](("/api/v1".."/check/".."mainten".."ance"), "POST", { ["challengeId"] = n9D0A3Vw[(965*5)]["challengeId"], ["nonce"] = Tu669bhFa[(1522-71)](n9D0A3Vw[(-639493-(-644386))]), ["data"] = Tu669bhFa[(0x5AB)](n9D0A3Vw[(4209+726)]), ["tag"] = Tu669bhFa[(-107923-(-109374))](n9D0A3Vw[(0x135B)]), }) if not n9D0A3Vw[(1974+2999)] or n9D0A3Vw[(138+4835)]["status"] ~= "ok" or hH45k3O["type"](n9D0A3Vw[(1834+3139)]["session"]) ~= "table" then Tu669bhFa[(-221769-(-223749))](Tu669bhFa[(1774-3)](n9D0A3Vw[(5046-60)] or ("MAINTENA".."NCE_UNAV".."AILABLE")), "Keyless Session Unavailable"), false) return end n9D0A3Vw[(1525+3470)] = hH45k3O["os"]["clock"]() - n9D0A3Vw[(-314570-(-319325))] if n9D0A3Vw[(1665*3)] < Tu669bhFa[(351-30)] then hH45k3O["task"]["wait"](Tu669bhFa[(107*3)] - n9D0A3Vw[(1665*3)]) end Tu669bhFa[(-577740-(-579815))](n9D0A3Vw[(5043-70)], n9D0A3Vw[(-332850-(-337823))]["continuityCredential"]) else Tu669bhFa[(2120-82)]() n9D0A3Vw[(-896854-(-901877))] = Tu669bhFa[(212*2)] and Tu669bhFa[(-576706-(-578274))]() or nil if n9D0A3Vw[(1661+3362)] then Tu669bhFa[(-296880-(-297988))]["Text"] = ("Validat".."ing sav".."ed lice".."nse key".."...") hH45k3O["task"]["wait"](0.5) Tu669bhFa[(-400124-(-402224))](n9D0A3Vw[(2681+2342)]) else Tu669bhFa[(1981-60)]((0), ("Enter ".."your k".."ey to ".."contin".."ue")) end end end)({}) end) end)({}) end)(Vj0r0XiN,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,...) end)((getfenv and getfenv()or _G),...)
]======]


local __FYY_PAYLOAD_FN, __FYY_LOAD_ERR = loadstring(__FYY_PAYLOAD_SRC, "FyyCommunity_Payload")
if not __FYY_PAYLOAD_FN then
    local StarterGui = game:GetService("StarterGui")
    pcall(function() StarterGui:SetCore("SendNotification", {Title="FyyCommunity ERROR", Text="Payload: "..tostring(__FYY_LOAD_ERR), Duration=6}) end)
    error("[FyyCommunity OneFile] Payload loadstring FAILED: " .. tostring(__FYY_LOAD_ERR))
end

-- Payload sudah memiliki outer closure (function(Vj0r0XiN,...)) sendiri.
-- Cukup panggil langsung dengan root_env sebagai argumen pertama (= Vj0r0XiN).
setfenv(__FYY_PAYLOAD_FN, root_env)
local _ok, _ret = pcall(__FYY_PAYLOAD_FN, root_env)
if _ok then
    local StarterGui = game:GetService("StarterGui")
    pcall(function() StarterGui:SetCore("SendNotification", {Title="FyyCommunity ✅", Text="Executor: "..executor, Duration=5}) end)
    return _ret
else
    local StarterGui = game:GetService("StarterGui")
    pcall(function() StarterGui:SetCore("SendNotification", {Title="FyyCommunity ❌", Text="Payload failed — lihat console", Duration=6}) end)
    error("[FyyCommunity OneFile] Payload EXEC FAILED: " .. tostring(_ret))
end
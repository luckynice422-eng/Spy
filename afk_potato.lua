-- ==============================================================================
-- Anti-AFK + Potato + ตัวช่วยให้ลื่น (ใช้ได้ทุกเกม) — เปิด/ปิดได้ตลอดจาก UI
-- ทุกอย่างที่เปลี่ยนกราฟิก ปิดแล้วคืนค่าเดิม | ค่าตั้งบันทึกอัตโนมัติ

-- ===== ตั้งค่า Anti-AFK (ปรับในโค้ดได้) =====
local AFK_MIN, AFK_MAX = 45, 75   -- ส่ง input จำลองทุก 45–75 วินาที (สุ่มช่วงให้ไม่เป๊ะเหมือนเครื่อง)
-- ===== ตั้งค่า Auto Ultimate =====
-- วิธีสั่งอัลติ:
--   "remote" (ค่าเริ่มต้น) = ยิงรีโมทที่ดักได้จริงจากเกม: ReplicatedStorage.GameEvents.UseUltimateEvent:FireServer(<ยูนิตของเรา>)
--                            ยิงให้ทุกยูนิตของเราที่วางในด่าน ทุก ULT_INTERVAL วินาที (อัลติยังไม่พร้อม เกมจะไม่รับเอง)
--   "button" = กดปุ่มอัลติบนจอ + ปุ่มที่สอนไว้ (ถ้าไม่เจอปุ่มเลย และ ULT_REMOTE_FALLBACK = true จะยิงรีโมทแทน)
--   "both"   = ทำทั้งสองอย่าง (ยิงรีโมท + กดปุ่มบนจอ/ปุ่มที่สอนไว้)
local ULT_MODE = "remote"
local ULT_UI_INTERVAL = 0.3            -- เช็ก/กดทุกกี่วินาทีในโหมดปุ่มบนจอ (ต่ำสุด 0.2)
local ULT_PRESS_WHILE_COOLDOWN = true  -- true = กดซ้ำเรื่อยๆ แม้ปุ่มดูเหมือนยังคูลดาวน์ (ซ่อน / Interactable=false / ขนาด 0) เกมจะไม่รับเองถ้ายังไม่พร้อม พอคูลดาวน์เสร็จก็ออกสกิลทันที
                                       -- false = กดเฉพาะตอนปุ่ม "พร้อม" (เสี่ยง: ถ้าเกมไม่คืนสถานะปุ่มหลังคูลดาวน์ จะกดครั้งเดียวแล้วหยุด)
local ULT_METHOD = "auto"              -- วิธีกด: "auto" (สัญญาณปุ่มก่อน ไม่ได้ค่อยคลิกจริง) | "signal" | "click"
local ULT_EXTRA_NAMES = {}             -- ชื่อปุ่มที่อยากให้กดเพิ่ม (ชื่อตรงตัว) เช่น {"SkillButton1"} ดูชื่อได้จาก AfkPotato.ListButtons()
-- โหมด "button": ถ้าไม่พบปุ่มอัลติบนจอเลย ใช้รีโมท UseUltimateEvent ยิงให้ยูนิตของเราแทน
local ULT_REMOTE_FALLBACK = true
-- สอนปุ่ม: กดปุ่ม "สอนปุ่ม" ในกล่อง แล้วแตะปุ่มสกิลในเกมจริง 1 ครั้ง (แตะได้หลายปุ่ม) สคริปต์จะจดไว้แล้วกดให้เองทุกครั้งที่ปุ่มนั้นกดได้
local TEACH_SECONDS = 30            -- โหมดสอนเปิดกี่วินาทีแล้วปิดเอง
-- ===== ตั้งค่า Auto Retry (จบด่านแล้วเล่นซ้ำ) =====
local RETRY_COOLDOWN = 5               -- เว้นกี่วินาทีระหว่างการสั่งเล่นซ้ำแต่ละครั้ง (กันยิงรัว)
local RETRY_MAX = 0                    -- เล่นซ้ำสูงสุดกี่รอบแล้วหยุด (0 = ไม่จำกัด) เผื่อเกมกินตั๋ว/เงินทุกครั้งที่เล่นซ้ำ
local RETRY_EXTRA_NAMES = {}           -- ชื่อปุ่ม "เล่นซ้ำ" เพิ่มเอง (ตรงตัว) กรณีเกมใช้ชื่ออื่น ดูชื่อจาก AfkPotato.ListButtons()
local ULT_INTERVAL = 1                 -- ยิงรีโมทอัลติทุกกี่วินาที (ต่อยูนิต, ต่ำสุด 0.5)
-- ===================================
-- ===========================================
-- ==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local G = (getgenv and getgenv()) or _G

-- รันซ้ำได้: ปิดตัวเก่าก่อน (คืนกราฟิก + ตัดการเชื่อมต่อ)
if G.AfkPotato and G.AfkPotato.Shutdown then pcall(G.AfkPotato.Shutdown) end

local App = { antiAfk = true, potato = false, afkCount = 0, lastAfk = nil, afkMethod = "-", fpsCap = 0,
              render3dOff = false, hidePlayers = false, autoUlt = false, autoRetry = false, closed = false, taught = {} }

-- ล็อก FPS: ใช้ setfpscap ของ executor (สคริปต์ปกติของ Roblox ตั้งเพดาน FPS เองไม่ได้)
-- 0 = ไม่ล็อก (ไม่แตะค่าของเกม), 999 = ไม่จำกัด
local FPS_OPTIONS = { 0, 15, 30, 45, 60, 90, 120, 999 }
local hasFpsCap = type(setfpscap) == "function"
local function fpsLabel(v)
    if v == 0 then return "ปิด" elseif v == 999 then return "ไม่จำกัด" end
    return tostring(v)
end
local function validFps(v)
    for _, o in ipairs(FPS_OPTIONS) do if o == v then return true end end
    return false
end
local conns = {}
local function track(c) conns[#conns + 1] = c return c end

-- ------------------------------------------------------------------------------
-- Auto Save Config: บันทึกค่าตั้งลงไฟล์ของ executor อัตโนมัติ และโหลดกลับตอนรันครั้งถัดไป
-- เก็บ: Anti-AFK เปิด/ปิด, Potato เปิด/ปิด, ย่อกล่องหรือไม่, ตำแหน่งกล่อง (ใช้ร่วมกันทุกเกม)
-- ถ้า executor ไม่มี writefile/readfile จะข้ามไปเงียบๆ (สคริปต์ทำงานปกติ แค่ไม่จำค่า)
-- ------------------------------------------------------------------------------
-- CONFIG BEGIN
local CONFIG_FILE = "AfkPotato_Config.json"
local hasFs = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
local Prefs = { collapsed = false, posX = nil, posY = nil }
local Config = {
    status = hasFs and "ยังไม่มีไฟล์ (สร้างตอนเปลี่ยนค่า)" or "ไม่รองรับ (executor ไม่มี writefile)",
    token = 0, closed = false, getCollapsed = nil, getPos = nil,
}

local function asBool(v, default) if type(v) == "boolean" then return v end return default end
local function asNum(v) if type(v) == "number" and v == v and v > -1e6 and v < 1e6 then return v end return nil end

-- กันกล่องหลุดจอ (เช่น เคยบันทึกไว้ตอนจอใหญ่ แล้วรันบนจอเล็กกว่า)
function Config.clampPos(x, y, vp)
    return math.clamp(x, 0, math.max(0, vp.X - 120)), math.clamp(y, 0, math.max(0, vp.Y - 60))
end

function Config.load()
    if not hasFs then return end
    local okExists, exists = pcall(isfile, CONFIG_FILE)
    if not (okExists and exists) then return end
    local okRead, raw = pcall(readfile, CONFIG_FILE)
    if not okRead or type(raw) ~= "string" then Config.status = "อ่านไฟล์ไม่ได้ ใช้ค่าเริ่มต้น" return end
    local okJson, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not okJson or type(data) ~= "table" then Config.status = "ไฟล์เสีย ใช้ค่าเริ่มต้น (จะเขียนทับใหม่)" return end
    -- ตรวจชนิดข้อมูลทีละช่อง: ช่องไหนผิดชนิดก็ข้ามช่องนั้น ใช้ค่าเริ่มต้นของช่องนั้น
    App.antiAfk = asBool(data.antiAfk, App.antiAfk)
    if validFps(data.fpsCap) then App.fpsCap = data.fpsCap end
    App.potato = asBool(data.potato, App.potato)
    App.render3dOff = asBool(data.render3dOff, App.render3dOff)
    App.hidePlayers = asBool(data.hidePlayers, App.hidePlayers)
    App.autoUlt = asBool(data.autoUlt, App.autoUlt)
    App.autoRetry = asBool(data.autoRetry, App.autoRetry)
    if type(data.taught) == "string" then   -- ปุ่มที่สอนไว้ (เก็บเป็นข้อความคั่นด้วย |)
        local list = {}
        for path in data.taught:gmatch("[^|]+") do
            if #path <= 150 and #list < 40 then list[#list + 1] = path end
        end
        App.taught = list
    end
    Prefs.collapsed = asBool(data.collapsed, Prefs.collapsed)
    Prefs.posX, Prefs.posY = asNum(data.posX), asNum(data.posY)
    Config.status = "โหลดค่าที่บันทึกไว้แล้ว"
end

function Config.write()
    if not hasFs or Config.closed then return end
    local pos = Config.getPos and Config.getPos()
    local data = {
        v = 1,
        antiAfk = App.antiAfk,
        potato = App.potato,
        fpsCap = App.fpsCap,
        render3dOff = App.render3dOff,
        hidePlayers = App.hidePlayers,
        autoUlt = App.autoUlt,
        autoRetry = App.autoRetry,
        taught = table.concat(App.taught, "|"),
        collapsed = Config.getCollapsed and Config.getCollapsed() or Prefs.collapsed,
        posX = pos and pos.X or Prefs.posX,
        posY = pos and pos.Y or Prefs.posY,
    }
    local ok = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
    Config.status = ok and ("บันทึกแล้ว " .. os.date("%H:%M:%S")) or "บันทึกไม่สำเร็จ"
end

-- ใช้กับการลากกล่อง (เกิดถี่ๆ): รอให้นิ่ง 0.6 วินาทีแล้วเขียนครั้งเดียว ไม่เขียนทุกพิกเซล
function Config.scheduleSave()
    if not hasFs then return end
    Config.token += 1
    local mine = Config.token
    task.delay(0.6, function()
        if mine == Config.token then Config.write() end
    end)
end

-- ลบไฟล์ค่าตั้ง (รันครั้งหน้าจะเริ่มจากค่าเริ่มต้น) เรียกด้วย AfkPotato.ResetConfig()
function Config.reset()
    if type(delfile) == "function" and hasFs then pcall(delfile, CONFIG_FILE) end
    Config.status = "ลบไฟล์ค่าตั้งแล้ว"
end
-- CONFIG END
Config.load()

-- ------------------------------------------------------------------------------
-- Anti-AFK แบบ "กดจำลองเหมือนคนกดเอง"
--   - ทุก 45–75 วินาที (สุ่ม) ถ้าช่วงนั้นคุณไม่ได้กดอะไรเอง จะส่ง input จำลอง 2 แบบ:
--       คลิกขวาผ่าน VirtualUser + ขยับเมาส์ 1 พิกเซลแล้วกลับที่เดิมผ่าน VirtualInputManager
--     ไม่ใช้คลิกซ้าย เพราะคลิกซ้ายอาจไปโดนปุ่มในเกมหรือเมนูของ Roblox
--   - สำรอง: ถ้า Roblox แจ้งว่าไม่ได้ขยับ (Idled) ก็ส่งทันที
--   - ระหว่างที่คุณเล่นเองอยู่ (มี input จริง) จะไม่ส่ง ไม่กวนการเล่น
-- ------------------------------------------------------------------------------
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = nil
pcall(function() VirtualInputManager = game:GetService("VirtualInputManager") end)
local lastRealInput = os.clock()
local simulating = false

track(UserInputService.InputBegan:Connect(function()
    if not simulating then lastRealInput = os.clock() end
end))

local function simulateInput(reason)
    simulating = true
    local methods = {}
    if pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end) then methods[#methods + 1] = "คลิกขวา" end
    if VirtualInputManager then
        if pcall(function()
            local cam = Workspace.CurrentCamera
            local vp = (cam and cam.ViewportSize) or Vector2.new(800, 600)
            local x, y = math.floor(vp.X / 2), math.floor(vp.Y / 2)
            VirtualInputManager:SendMouseMoveEvent(x + 1, y, game)
            VirtualInputManager:SendMouseMoveEvent(x, y, game)
        end) then methods[#methods + 1] = "ขยับเมาส์" end
    end
    simulating = false
    App.afkCount += 1
    App.lastAfk = os.clock()
    App.afkMethod = (#methods > 0 and table.concat(methods, "+") or "ไม่สำเร็จ") .. " (" .. reason .. ")"
end

task.spawn(function()
    while not App.closed do
        task.wait(AFK_MIN + math.random() * (AFK_MAX - AFK_MIN))
        if App.closed then break end
        if App.antiAfk and os.clock() - lastRealInput >= AFK_MIN - 1 then
            simulateInput("ตามรอบ")
        end
    end
end)

track(LocalPlayer.Idled:Connect(function()
    if App.antiAfk and not App.closed then simulateInput("Roblox แจ้ง idle") end
end))

-- ------------------------------------------------------------------------------
-- Auto Ultimate (Anime Mysterious): กดอัลติทันทีที่กดได้
--
-- โหมดหลัก = กดปุ่มอัลติบนจอ (เหมือนนิ้วกดเอง ไม่ต้องรู้ยูนิต ไม่ต้องหา hitbox):
--   - หาปุ่มใน PlayerGui ที่ชื่อ/ข้อความ (หรือกรอบแม่ 2 ชั้น) มีคำว่า Ult / Ultimate
--     ไม่นับคำที่มี ult ปนอยู่ เช่น Result, Difficulty, Default, Multiplier
--     และข้ามปุ่มที่เกี่ยวกับ shop/buy/store/sell/upgrade/summon/claim ฯลฯ กันกดผิดปุ่ม
--   - ปุ่มโผล่ใหม่ (เช่นวางยูนิต) จะถูกจับทันทีผ่าน DescendantAdded + สแกนซ้ำทุก 3 วินาที
--   - สกิลที่มีอยู่แล้วแค่คูลดาวน์ (ไม่ได้ถูกสร้างใหม่) ก็ต้องกดซ้ำได้: ค่าเริ่มต้น ULT_PRESS_WHILE_COOLDOWN = true
--     คือกดทุกรอบ (ทุก ULT_UI_INTERVAL วินาที) ไม่รอให้ปุ่ม "โผล่ใหม่/พร้อม" เกมเป็นคนปฏิเสธเองตอนยังคูลดาวน์
--     พอคูลดาวน์เสร็จ การกดรอบถัดไปจะออกสกิลทันที (ไม่ผูกกับสถานะซ่อน/Interactable ที่เกมอาจไม่คืนค่า)
--   - การกดแบบสัญญาณจำลองการคลิกเต็มรูป: Down -> Up -> Click -> Activated ครบทุกสัญญาณที่เกมผูกไว้ (เกมจะผูกตรรกะกับตัวไหนก็ถึง)
--     การคลิกจริงด้วยพิกัดใช้เฉพาะตอนปุ่มมองเห็นและไม่มีสัญญาณให้กดตรงๆ
--   - ลูปมี pcall คุม: ถ้าเกิดข้อผิดพลาดชั่วคราว ลูปไม่ตาย แสดงข้อความในกล่องแล้วทำงานต่อ
-- สำรอง = รีโมท (เฉพาะตอนไม่พบปุ่มอัลติบนจอเลย): ReplicatedStorage.GameEvents.UseUltimateEvent:FireServer(<ยูนิต>)
--   ยิงให้ทุกยูนิตของเรา (OwnerID ตรงกับ UserId) ไม่ยิงศัตรู/ของคนอื่น
-- ------------------------------------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
ULT_UI_INTERVAL = math.max(0.2, tonumber(ULT_UI_INTERVAL) or 0.3)
ULT_INTERVAL = math.max(0.5, tonumber(ULT_INTERVAL) or 1)
ULT_MODE = tostring(ULT_MODE or "remote"):lower()
if ULT_MODE ~= "remote" and ULT_MODE ~= "button" and ULT_MODE ~= "both" then ULT_MODE = "remote" end
local Ult = { fired = 0, status = "ปิดอยู่", remoteStatus = "-", how = "-", remote = nil, folder = nil, lastSearch = -math.huge, lastRemote = -math.huge }

-- ---------- จับชื่อปุ่ม ----------
local ULT_EXCLUDE = { "shop", "buy", "store", "purchase", "robux", "gamepass", "sell", "upgrade",
                      "reroll", "summon", "claim", "index", "trait", "unlock", "equip" }
local function matchesUlt(str)
    if type(str) ~= "string" or str == "" then return false end
    if str:lower():find("ultimate", 1, true) then return true end
    return str:find("%f[%u]Ult") ~= nil          -- Ult / UltBtn / UnitUlt
        or str:find("^ult") ~= nil                 -- ult_button
        or str:find("[^%a]ult") ~= nil             -- btn_ult / my ult
        or str:find("%f[%a]ULT%f[%A]") ~= nil      -- ULT ทั้งคำ
end
local function matchesExcluded(str)
    if type(str) ~= "string" then return false end
    local low = str:lower()
    for _, w in ipairs(ULT_EXCLUDE) do
        if low:find(w, 1, true) then return true end
    end
    return false
end
local function safeIsA(o, cls)
    local ok, r = pcall(function() return o:IsA(cls) end)
    return ok and r == true
end
-- ปุ่มที่สอนไว้ (Teach): จับคู่ด้วย "เส้นทางจาก ScreenGui ถึงปุ่ม" โดยแปลงเลขในชื่อเป็น #
-- เช่น HUD/Units/Card3/Skill -> HUD/Units/Card#/Skill  ทำให้ช่องที่ 1..6 ถูกกดเหมือนกัน
-- แต่ปุ่มชื่อกลางๆ (เช่น Button) ที่อยู่คนละที่จะไม่ถูกกดไปด้วย
local Taught = { set = {}, names = {} }
local function normName(n) return (tostring(n):gsub("%d+", "#")) end
local function normPath(obj)
    local parts, o = {}, obj
    while o do
        parts[#parts + 1] = normName(o.Name)
        if safeIsA(o, "LayerCollector") then break end
        o = o.Parent
        if o and o.ClassName == "PlayerGui" then break end
    end
    local out = {}
    for i = #parts, 1, -1 do out[#out + 1] = parts[i] end
    return table.concat(out, "/")
end
local function rememberTaught(path)
    Taught.set[path] = true
    Taught.names[path:match("([^/]*)$")] = true
end
for _, path in ipairs(App.taught) do rememberTaught(path) end
local function isTaught(b)
    return Taught.names[normName(b.Name)] == true and Taught.set[normPath(b)] == true
end

local function ultButtonOk(b)
    for _, n in ipairs(ULT_EXTRA_NAMES) do
        if b.Name == n then return true end
    end
    if isTaught(b) then return true end
    local names = { b.Name }
    if safeIsA(b, "TextButton") then
        local okT, text = pcall(function() return b.Text end)
        if okT and type(text) == "string" then names[#names + 1] = text end
    end
    local p = b.Parent
    for _ = 1, 2 do                                -- กรอบแม่ 2 ชั้น (ไม่รวม ScreenGui)
        if not p or safeIsA(p, "LayerCollector") then break end
        names[#names + 1] = p.Name
        p = p.Parent
    end
    local hit = false
    for _, n in ipairs(names) do
        if matchesExcluded(n) then return false end
        if matchesUlt(n) then hit = true end
    end
    return hit
end

-- ---------- ปุ่ม "กดได้" ----------
local function isShown(b)
    local o = b
    while o do
        local ok, visible = pcall(function()
            if safeIsA(o, "GuiObject") then return o.Visible end
            if safeIsA(o, "LayerCollector") then return o.Enabled end
            return true
        end)
        if ok and visible == false then return false end
        o = o.Parent
    end
    local okS, size = pcall(function() return b.AbsoluteSize end)
    if okS and size and (size.X <= 0 or size.Y <= 0) then return false end
    local okI, interactable = pcall(function() return b.Interactable end)
    if okI and interactable == false then return false end
    return true
end

-- ---------- เก็บรายการปุ่มอัลติ (จับทันทีตอนโผล่ + สแกนซ้ำทุก 3 วินาที) ----------
local UltUI = { set = {}, hooked = false, lastScan = -math.huge }
local function playerGui() return LocalPlayer:FindFirstChild("PlayerGui") end
local function isGuiButton(d) return safeIsA(d, "GuiButton") end
local function ultScan()
    local gui = playerGui()
    if not gui then return end
    if not UltUI.hooked then
        UltUI.hooked = true
        track(gui.DescendantAdded:Connect(function(d)
            if isGuiButton(d) and ultButtonOk(d) then UltUI.set[d] = true end
        end))
    end
    if os.clock() - UltUI.lastScan >= 3 then
        UltUI.lastScan = os.clock()
        for _, d in ipairs(gui:GetDescendants()) do
            local okD, hit = pcall(function() return isGuiButton(d) and ultButtonOk(d) end)
            if okD and hit then UltUI.set[d] = true end
        end
    end
end
-- คืน (จำนวนปุ่มอัลติที่รู้จักทั้งหมด, รายการที่ "พร้อม" ตอนนี้, รายการทั้งหมดที่ยังอยู่)
local function ultButtons()
    local gui = playerGui()
    local known, shown, all = 0, {}, {}
    for b in pairs(UltUI.set) do
        -- ปุ่มที่อ่านค่าแล้ว error (instance แปลก/ถูกทำลายกลางคัน) ถือว่าหาย ไม่ปล่อยให้ทำทั้งรอบล้ม
        local okB, keep, visible = pcall(function()
            local alive = gui and b:IsDescendantOf(gui)
            if not alive or not ultButtonOk(b) then return false end
            return true, isShown(b)
        end)
        if not okB or not keep then
            UltUI.set[b] = nil
            UltUI.lastScan = -math.huge   -- ปุ่มหาย/ถูกแทนที่ (เช่นเกมสร้างใหม่ตอนคูลดาวน์) -> สแกนหาตัวใหม่รอบถัดไปทันที ไม่รอ 3 วินาที
        else
            known += 1
            all[#all + 1] = b
            if visible then shown[#shown + 1] = b end
        end
    end
    return known, shown, all
end

-- ---------- กดปุ่ม ----------
-- จำลองการคลิกจริงของ Roblox: MouseButton1Down -> MouseButton1Up -> MouseButton1Click -> Activated
-- ยิงทุกสัญญาณที่มีการผูกไว้ (เกมจะผูกตรรกะสกิลกับตัวไหนก็ถูกเรียก และแอนิเมชันปุ่มที่ผูก Down/Up ก็จบครบคู่ ไม่ค้างในสภาพถูกกด)
-- สกิลมีคูลดาวน์ กดซ้ำหลายสัญญาณไม่เกิดผลซ้ำ | visible = ปุ่มมองเห็นอยู่ไหม (คลิกจริงด้วยพิกัดทำได้เฉพาะตอนมองเห็น)
local CLICK_EVENTS = { "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "Activated" }
local EVENT_SHORT = { MouseButton1Down = "Down", MouseButton1Up = "Up", MouseButton1Click = "Click", Activated = "Activated" }
local function pressButton(b, visible)
    if visible == nil then visible = true end
    if ULT_METHOD == "auto" or ULT_METHOD == "signal" then
        if type(getconnections) == "function" then
            local used = {}
            for _, ev in ipairs(CLICK_EVENTS) do
                local ok, conns = pcall(function() return getconnections(b[ev]) end)
                if ok and type(conns) == "table" and #conns > 0 then
                    for _, c in ipairs(conns) do pcall(function() c:Fire() end) end
                    used[#used + 1] = EVENT_SHORT[ev]
                end
            end
            if #used > 0 then return "สัญญาณ " .. table.concat(used, "+") end
        elseif type(firesignal) == "function" then
            local anyOk = false
            for _, ev in ipairs(CLICK_EVENTS) do
                if pcall(function() firesignal(b[ev]) end) then anyOk = true end
            end
            if anyOk then return "firesignal" end
        end
    end
    if visible and (ULT_METHOD == "auto" or ULT_METHOD == "click") and VirtualInputManager then
        local ok = pcall(function()
            local pos, size, inset = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
            local x = pos.X + size.X / 2 + inset.X
            local y = pos.Y + size.Y / 2 + inset.Y
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        if ok then return "คลิกกลางปุ่ม" end
    end
    return nil
end

-- ---------- สอนปุ่ม: แตะปุ่มสกิลในเกม 1 ครั้ง สคริปต์จดไว้แล้วกดให้เอง ----------
-- จับ 2 ทาง: (1) ฟังสัญญาณ Activated/MouseButton1Click ของทุกปุ่มบนจอ (ไม่ต้องคำนวณพิกัด)
--            (2) ถ้าแตะแล้วไม่มีปุ่มไหนส่งสัญญาณ ใช้ตำแหน่งที่แตะหาปุ่มที่ทับจุดนั้น (เลือกปุ่มที่เล็กที่สุด)
-- กันพลาด: ไม่จดปุ่มที่ดูเป็นร้านค้า/ซื้อขาย/ออก/ตั้งค่า (กดรัวทุก 0.3 วิจะอันตราย)
local TEACH_REJECT = { "shop", "buy", "store", "purchase", "robux", "gamepass", "sell", "leave", "exit", "quit",
                       "close", "setting", "menu", "lobby", "teleport", "home", "rejoin", "reset", "retreat", "surrender" }
local Teach = { active = false, token = 0, endAt = 0, conns = {}, hooked = {}, last = "-", capturedAt = -1 }

local function teachRecord(obj)
    local path = normPath(obj)
    if path:find('[|"\\]') then Teach.last = "ข้าม (ชื่อมีอักขระพิเศษ): " .. path return end
    local tail = (path:match("([^/]*/[^/]*)$") or path):lower()   -- ดูแค่ 2 ชั้นท้าย กันชื่อกรอบไกลๆ ทำให้ปฏิเสธผิด
    for _, w in ipairs(TEACH_REJECT) do
        if tail:find(w, 1, true) then Teach.last = "ข้าม (ดูเป็นปุ่มร้านค้า/ออก/ตั้งค่า): " .. path return end
    end
    if Taught.set[path] then Teach.last = "มีอยู่แล้ว: " .. path return end
    if #App.taught >= 40 then Teach.last = "สอนเต็ม 40 ปุ่ม (ล้างด้วย AfkPotato.ForgetButtons())" return end
    rememberTaught(path)
    App.taught[#App.taught + 1] = path
    UltUI.set[obj] = true      -- เริ่มกดได้ทันที ไม่ต้องรอสแกน
    UltUI.lastScan = -math.huge  -- สั่งสแกนใหม่รอบถัดไปทันที ให้ช่องข้างเคียง (Card#) ถูกจับพร้อมกัน ไม่ต้องรอ 3 วินาที
    Config.write()
    Teach.last = "สอนแล้ว: " .. path
end

local function teachHookButton(b)
    if Teach.hooked[b] then return end
    Teach.hooked[b] = true
    local function onFire()
        if not Teach.active then return end
        Teach.capturedAt = os.clock()
        teachRecord(b)
    end
    for _, ev in ipairs({ "Activated", "MouseButton1Click" }) do
        local ok, conn = pcall(function() return b[ev]:Connect(onFire) end)
        if ok and conn then Teach.conns[#Teach.conns + 1] = conn end
    end
end

local function inRect(o, x, y)
    local ok, r = pcall(function()
        local p, sz = o.AbsolutePosition, o.AbsoluteSize
        return x >= p.X and x <= p.X + sz.X and y >= p.Y and y <= p.Y + sz.Y
    end)
    return ok and r == true
end
local function teachHitTest(pos)
    local gui = playerGui()
    if not gui then return end
    local okI, inset = pcall(function() return GuiService:GetGuiInset() end)
    local iy = (okI and inset and inset.Y) or 0
    local pts = { { pos.X, pos.Y }, { pos.X, pos.Y - iy } }   -- พิกัดสัมผัสอาจรวม/ไม่รวมแถบบน ลองทั้งสองแบบ
    local best, bestArea
    for _, d in ipairs(gui:GetDescendants()) do
        if isGuiButton(d) and isShown(d) then
            for _, pt in ipairs(pts) do
                if inRect(d, pt[1], pt[2]) then
                    local area = d.AbsoluteSize.X * d.AbsoluteSize.Y
                    if not best or area < bestArea then best, bestArea = d, area end
                    break
                end
            end
        end
    end
    if best then teachRecord(best) else Teach.last = "ไม่พบปุ่มตรงจุดที่แตะ (อาจไม่ใช่ปุ่มมาตรฐาน)" end
end

local function teachStop()
    Teach.active = false
    for _, c in ipairs(Teach.conns) do pcall(function() c:Disconnect() end) end
    Teach.conns, Teach.hooked = {}, {}
end

local function teachStart()
    if Teach.active then return end
    local gui = playerGui()
    if not gui then Teach.last = "ไม่พบ PlayerGui" return end
    Teach.active = true
    Teach.token += 1
    local mine = Teach.token
    Teach.endAt = os.clock() + TEACH_SECONDS
    Teach.capturedAt = -1
    Teach.last = "แตะปุ่มสกิลในเกมได้เลย"
    for _, d in ipairs(gui:GetDescendants()) do
        if isGuiButton(d) then teachHookButton(d) end
    end
    Teach.conns[#Teach.conns + 1] = gui.DescendantAdded:Connect(function(d)
        if Teach.active and isGuiButton(d) then teachHookButton(d) end
    end)
    Teach.conns[#Teach.conns + 1] = UserInputService.InputBegan:Connect(function(input)
        if not Teach.active then return end
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        local tapAt, pos = os.clock(), input.Position
        task.delay(0.3, function()    -- รอให้สัญญาณของปุ่มทำงานก่อน ถ้าไม่มีปุ่มไหนจับได้ค่อยใช้ตำแหน่ง
            if Teach.active and Teach.token == mine and Teach.capturedAt < tapAt then teachHitTest(pos) end
        end)
    end)
    task.delay(TEACH_SECONDS, function()
        if Teach.active and Teach.token == mine then teachStop() end
    end)
end

local function forgetButtons()
    App.taught = {}
    Taught.set, Taught.names = {}, {}
    UltUI.set = {}
    Config.write()
    Teach.last = "ล้างปุ่มที่สอนไว้แล้ว"
end

-- ---------- สำรอง: รีโมท ----------
local function ultRemote()
    if Ult.remote then
        local ok, inside = pcall(function() return Ult.remote:IsDescendantOf(ReplicatedStorage) end)
        if ok and inside then return Ult.remote end
    end
    local ev = ReplicatedStorage:FindFirstChild("GameEvents")
    Ult.remote = ev and ev:FindFirstChild("UseUltimateEvent") or nil
    return Ult.remote
end

-- โฟลเดอร์ยูนิตผู้เล่น: ลองแมพในล็อกก่อน ไม่เจอค่อยค้นชื่อ PlayerFolder ทั้งแมพ (ทุก 5 วิ)
local function ultFolder()
    local f = Ult.folder
    if f then
        local ok, inside = pcall(function() return f:IsDescendantOf(Workspace) end)
        if ok and inside then return f end
    end
    Ult.folder = nil
    local known = Workspace:FindFirstChild("CursedAcademy")
    known = known and known:FindFirstChild("PlayerFolder")
    if known then Ult.folder = known return known end
    if os.clock() - Ult.lastSearch < 5 then return nil end
    Ult.lastSearch = os.clock()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == "PlayerFolder" then Ult.folder = d return d end
    end
    return nil
end

-- ยูนิตของเรา: OwnerID ตรงกับ UserId
-- ไม่มีตัวไหนตรงแต่ทุกยูนิตเจ้าของเดียวกัน (เล่นคนเดียว) ถือเป็นของเรา
-- หลายเจ้าของและไม่มีของเรา -> ไม่ยิง (ไม่ยิงใส่ยูนิตของคนอื่น)
local function ultUnits(folder)
    local all, owners, ownerCount = {}, {}, 0
    for _, c in ipairs(folder:GetChildren()) do
        if c.Name == "BaseHitbox" then
            all[#all + 1] = c
            local oid = tostring(c:GetAttribute("OwnerID"))
            if not owners[oid] then owners[oid] = true ownerCount += 1 end
        end
    end
    if #all == 0 then return {}, "ไม่มียูนิตในสนาม" end
    local mine = {}
    for _, c in ipairs(all) do
        if tonumber(c:GetAttribute("OwnerID")) == LocalPlayer.UserId then mine[#mine + 1] = c end
    end
    if #mine > 0 then return mine end
    if ownerCount <= 1 then return all end
    return {}, "ไม่มียูนิตที่ OwnerID ตรงกับเรา (มี " .. ownerCount .. " เจ้าของ)"
end

local function remoteRound()
    local r = ultRemote()
    if not r then
        Ult.remoteStatus = "ไม่พบรีโมท (ไม่ใช่เกมนี้/ยังอยู่ล็อบบี้)"
        return
    end
    local folder = ultFolder()
    if not folder then
        Ult.remoteStatus = "หา PlayerFolder ไม่เจอ (ยังไม่เข้าด่าน?)"
        return
    end
    local units, why = ultUnits(folder)
    if #units == 0 then
        Ult.remoteStatus = why or "ไม่มียูนิต"
        return
    end
    local names, okCount = {}, 0
    for i, u in ipairs(units) do
        if not App.autoUlt or App.closed then break end -- กดปิดกลางรอบ: หยุดทันที
        if pcall(function() r:FireServer(u) end) then
            okCount += 1
            Ult.fired += 1
        end
        names[#names + 1] = tostring(u:GetAttribute("DisplayName") or u:GetAttribute("UnitId") or "?")
        if i < #units then task.wait(math.min(0.15, ULT_INTERVAL / #units)) end
    end
    Ult.remoteStatus = string.format("ยิง %d ยูนิต: %s", okCount, table.concat(names, ", "))
end

-- ---------- ลูปหลัก ----------
-- ตื่นทุก ULT_UI_INTERVAL วินาทีเสมอ (ปุ่มโผล่ใหม่ถูกจับทันทีแล้ว ลูปต้องไม่หลับนานจนกดช้า)
-- โหมดรีโมทสำรองถูกจำกัดให้ยิงไม่เกิน 1 รอบต่อ ULT_INTERVAL วินาที ไม่ยิงถี่ตามลูป
-- ultStep คืนค่า "รอกี่วินาที" ; ลูปครอบด้วย pcall กันข้อผิดพลาดชั่วคราวทำให้ลูปตายแล้วหยุดกดถาวร
local function remoteDue()
    -- ยิงรีโมทไม่เกิน 1 รอบต่อ ULT_INTERVAL วินาที (ลูปตื่นทุก ULT_UI_INTERVAL แต่รีโมทไม่ยิงถี่ตามลูป)
    if os.clock() - Ult.lastRemote >= ULT_INTERVAL - 0.001 then
        Ult.lastRemote = os.clock()
        remoteRound()
    end
end
local function ultStep()
    local roundStart = os.clock()
    local nextWait = ULT_UI_INTERVAL
    if App.autoUlt and ULT_MODE == "remote" then
        remoteDue()
        Ult.status = "โหมดรีโมท: " .. Ult.remoteStatus
        return math.min(ULT_UI_INTERVAL, math.max(0.05, ULT_INTERVAL - (os.clock() - Ult.lastRemote)))
    end
    if App.autoUlt and ULT_MODE == "both" then remoteDue() end
    if App.autoUlt then
        ultScan()
        local known, shown, all = ultButtons()
        if known > 0 then
            local targets = ULT_PRESS_WHILE_COOLDOWN and all or shown
            if #targets == 0 then
                Ult.status = string.format("โหมดปุ่มบนจอ: รอปุ่มอัลติขึ้น (%d ปุ่มซ่อนอยู่)", known)
            else
                local visible = {}
                for _, b in ipairs(shown) do visible[b] = true end
                local pressed = 0
                for _, b in ipairs(targets) do
                    if not App.autoUlt or App.closed then break end
                    local how = pressButton(b, visible[b] == true)   -- จุดเสี่ยงทุกจุดในฟังก์ชันนี้มี pcall อยู่ข้างในแล้ว
                    if how then
                        pressed += 1
                        Ult.fired += 1
                        Ult.how = how
                        Ult.lastPress = os.clock()
                    end
                end
                if pressed > 0 then
                    Ult.status = string.format("โหมดปุ่มบนจอ: กด %d ปุ่ม (%s) | พร้อม %d ซ่อน/คูลดาวน์ %d", pressed, Ult.how, #shown, known - #shown)
                        .. (ULT_MODE == "both" and (" | รีโมท: " .. Ult.remoteStatus) or "")
                elseif #shown == 0 then
                    Ult.status = string.format("โหมดปุ่มบนจอ: ปุ่มซ่อน/คูลดาวน์ทั้งหมด (%d) และไม่มีสัญญาณให้กดตรงๆ รอปุ่มขึ้น", known)
                else
                    Ult.status = "โหมดปุ่มบนจอ: เจอปุ่มแต่กดไม่สำเร็จ (executor ไม่มี getconnections/คลิกจำลอง)"
                end
            end
            nextWait = math.max(0.05, ULT_UI_INTERVAL - (os.clock() - roundStart))
            if ULT_MODE == "both" then   -- ตื่นให้ตรงรอบยิงรีโมทด้วย (ไม่งั้นรอบรีโมทเพี้ยนเป็น 1.2 วิ ตามจังหวะ 0.3 วิของลูป)
                nextWait = math.min(nextWait, math.max(0.05, ULT_INTERVAL - (os.clock() - Ult.lastRemote)))
            end
        elseif ULT_MODE == "both" then
            Ult.status = "รีโมท: " .. Ult.remoteStatus .. " | ไม่พบปุ่มอัลติบนจอ"
            nextWait = math.min(ULT_UI_INTERVAL, math.max(0.05, ULT_INTERVAL - (os.clock() - Ult.lastRemote)))
        elseif ULT_REMOTE_FALLBACK then
            remoteDue()
            Ult.status = "โหมดรีโมท (ไม่พบปุ่มอัลติบนจอ): " .. Ult.remoteStatus
            nextWait = math.min(ULT_UI_INTERVAL, math.max(0.05, ULT_INTERVAL - (os.clock() - Ult.lastRemote)))
        else
            Ult.status = "ไม่พบปุ่มอัลติบนจอ (พิมพ์ AfkPotato.ListButtons() ดูปุ่มทั้งหมด)"
        end
    else
        Ult.status = "ปิดอยู่"
    end
    return nextWait
end
task.spawn(function()
    while not App.closed do
        local ok, res = pcall(ultStep)
        local waitFor = ULT_UI_INTERVAL
        if ok then
            waitFor = res or waitFor
        else
            Ult.status = "ผิดพลาดในลูปอัลติ (ทำงานต่อ): " .. tostring(res)
            warn("[AfkPotato] ลูปอัลติผิดพลาด (ทำงานต่อ): " .. tostring(res))
            waitFor = 1
        end
        task.wait(waitFor)
    end
end)

-- ------------------------------------------------------------------------------
-- Auto Retry: จบด่านแล้วสั่งเล่นซ้ำให้เอง
-- ยืนยันจากล็อก: ReplicatedStorage.GameEvents.RetryGameRequest:FireServer()  (ไม่มีค่าที่ส่ง)
-- ตัวบอกว่า "ด่านจบแล้ว" = มีปุ่ม Retry / Replay / Play Again โผล่บนจอ (ไม่ยิงรีโมทมั่วระหว่างด่านที่กำลังเล่น)
--   ปุ่มโผล่ -> ยิงรีโมท RetryGameRequest ทันที
--   ถ้าผ่านไป RETRY_COOLDOWN วินาทีแล้วปุ่มยังอยู่ (รีโมทไม่ได้ผล) -> สลับไปกดปุ่มบนจอ แล้วสลับกลับไปรีโมทสลับกันไป
--   เกมที่ไม่มีรีโมทนี้ -> กดปุ่มบนจออย่างเดียว | ตั้ง RETRY_MAX ได้ถ้ากลัวเกมกินตั๋วทุกครั้งที่เล่นซ้ำ
-- ------------------------------------------------------------------------------
RETRY_COOLDOWN = math.max(2, tonumber(RETRY_COOLDOWN) or 5)
RETRY_MAX = math.max(0, math.floor(tonumber(RETRY_MAX) or 0))
local RetryUI = { set = {}, hooked = false, lastScan = -math.huge }
local Retry = { runs = 0, attempt = 0, lastFire = -math.huge, status = "ปิดอยู่" }

local function matchesRetry(str)
    if type(str) ~= "string" or str == "" then return false end
    local c = str:lower():gsub("[^%a]", "")      -- ตัดช่องว่าง/ขีด/เลข: "Play Again", "try_again" -> playagain / tryagain
    return c:find("retry", 1, true) ~= nil or c:find("replay", 1, true) ~= nil
        or c:find("playagain", 1, true) ~= nil or c:find("tryagain", 1, true) ~= nil
end
local function retryButtonOk(b)
    for _, n in ipairs(RETRY_EXTRA_NAMES) do
        if b.Name == n then return true end
    end
    local names = { b.Name }
    if safeIsA(b, "TextButton") then
        local okT, text = pcall(function() return b.Text end)
        if okT and type(text) == "string" then names[#names + 1] = text end
    end
    local hit = false
    for _, n in ipairs(names) do
        if matchesExcluded(n) then return false end
        if matchesRetry(n) then hit = true end
    end
    return hit
end
local function retryScan()
    local gui = playerGui()
    if not gui then return end
    if not RetryUI.hooked then
        RetryUI.hooked = true
        track(gui.DescendantAdded:Connect(function(d)
            if isGuiButton(d) and retryButtonOk(d) then RetryUI.set[d] = true end
        end))
    end
    if os.clock() - RetryUI.lastScan >= 3 then
        RetryUI.lastScan = os.clock()
        for _, d in ipairs(gui:GetDescendants()) do
            local okD, hit = pcall(function() return isGuiButton(d) and retryButtonOk(d) end)
            if okD and hit then RetryUI.set[d] = true end
        end
    end
end
local function retryShown()
    local gui = playerGui()
    local shown = {}
    for b in pairs(RetryUI.set) do
        local okB, keep, visible = pcall(function()
            local alive = gui and b:IsDescendantOf(gui)
            if not alive or not retryButtonOk(b) then return false end
            return true, isShown(b)
        end)
        if not okB or not keep then
            RetryUI.set[b] = nil
            RetryUI.lastScan = -math.huge
        elseif visible then
            shown[#shown + 1] = b
        end
    end
    return shown
end
local function retryRemote()
    local ev = ReplicatedStorage:FindFirstChild("GameEvents")
    return ev and ev:FindFirstChild("RetryGameRequest") or nil
end

local function retryStep()
    do
        if App.autoRetry then
            retryScan()
            local shown = retryShown()
            if #shown == 0 then
                Retry.attempt = 0   -- ยังไม่จบด่าน (หรือเล่นซ้ำสำเร็จแล้ว): เริ่มนับรอบใหม่
                Retry.status = string.format("รอด่านจบ (เล่นซ้ำแล้ว %d รอบ)", Retry.runs)
            elseif RETRY_MAX > 0 and Retry.runs >= RETRY_MAX and Retry.attempt == 0 then
                Retry.status = string.format("ครบ %d รอบที่ตั้งไว้แล้ว (หยุดเล่นซ้ำ)", RETRY_MAX)
            elseif os.clock() - Retry.lastFire >= RETRY_COOLDOWN then
                Retry.attempt += 1
                if Retry.attempt == 1 then Retry.runs += 1 end
                Retry.lastFire = os.clock()
                local r, how = retryRemote(), nil
                if r and Retry.attempt % 2 == 1 then
                    if pcall(function() r:FireServer() end) then how = "รีโมท RetryGameRequest" end
                end
                if not how then
                    for _, b in ipairs(shown) do
                        local m = pressButton(b)
                        if m then how = "กดปุ่มบนจอ (" .. m .. ")" break end
                    end
                end
                if not how and r then
                    if pcall(function() r:FireServer() end) then how = "รีโมท RetryGameRequest" end
                end
                Retry.status = how and string.format("ด่านจบ: เล่นซ้ำรอบที่ %d ด้วย %s", Retry.runs, how)
                    or "เจอปุ่มเล่นซ้ำแต่สั่งไม่สำเร็จ (ไม่มีรีโมท/คลิกจำลอง)"
            end
        else
            Retry.status = "ปิดอยู่"
        end
    end
end
task.spawn(function()
    while not App.closed do
        local ok, err = pcall(retryStep)
        if not ok then
            Retry.status = "ผิดพลาดในลูปเล่นซ้ำ (ทำงานต่อ): " .. tostring(err)
            warn("[AfkPotato] ลูปเล่นซ้ำผิดพลาด (ทำงานต่อ): " .. tostring(err))
        end
        task.wait(0.5)
    end
end)

-- วินิจฉัยปุ่มอัลติ/ปุ่มที่สอนไว้ ตอนที่มันไม่กดซ้ำ: พิมพ์ AfkPotato.UltDebug() ตอนคูลดาวน์เสร็จแล้ว (ผลคัดลอกลงคลิปบอร์ดเอง)
-- บอกต่อปุ่ม: ซ่อนที่ชั้นไหน, Interactable/Active, ขนาด, ข้อความ, และจำนวนสัญญาณที่เกมผูกไว้ (Down/Up/Click/Activated)
local function ultDebug()
    ultScan()
    local known, shown, all = ultButtons()
    local out = { "== ULT DEBUG | PlaceId " .. tostring(game.PlaceId) .. " ==" }
    out[#out + 1] = string.format("รู้จัก %d ปุ่ม | พร้อม %d | ซ่อน/คูลดาวน์ %d | กดไปแล้ว %d ครั้ง | วิธีล่าสุด: %s | กดล่าสุด: %s",
        known, #shown, known - #shown, Ult.fired, tostring(Ult.how),
        Ult.lastPress and (math.floor(os.clock() - Ult.lastPress) .. " วิก่อน") or "ยังไม่เคย")
    out[#out + 1] = string.format("ตั้งค่า: ULT_PRESS_WHILE_COOLDOWN=%s ULT_METHOD=%s ULT_UI_INTERVAL=%s | getconnections=%s firesignal=%s คลิกจำลอง=%s | สถานะ: %s",
        tostring(ULT_PRESS_WHILE_COOLDOWN), tostring(ULT_METHOD), tostring(ULT_UI_INTERVAL),
        tostring(type(getconnections) == "function"), tostring(type(firesignal) == "function"), tostring(VirtualInputManager ~= nil), tostring(Ult.status))
    -- ข้อมูลรีโมท (ใช้ในโหมด remote/both และเป็นทางสำรองของ button)
    local okR, r = pcall(ultRemote)
    out[#out + 1] = string.format("โหมด: %s | รีโมท: %s | ยิงทุก %s วิ | สถานะรีโมทล่าสุด: %s", ULT_MODE,
        (okR and r) and (r:GetFullName() .. " [" .. r.ClassName .. "]") or "ไม่พบ (อยู่ล็อบบี้/คนละเกม?)", tostring(ULT_INTERVAL), tostring(Ult.remoteStatus))
    local okF, folder = pcall(ultFolder)
    if okF and folder then
        local okU, units, why = pcall(ultUnits, folder)
        if okU and #units > 0 then
            local names = {}
            for i, u in ipairs(units) do
                if i > 10 then names[#names + 1] = "…" break end
                local okN, n = pcall(function() return tostring(u:GetAttribute("DisplayName") or u:GetAttribute("UnitId") or "?") end)
                names[#names + 1] = okN and n or "?"
            end
            out[#out + 1] = string.format("ยูนิตของเราที่จะยิงอัลติให้ (%d): %s | โฟลเดอร์: %s", #units, table.concat(names, ", "), folder:GetFullName())
        else
            out[#out + 1] = "ยูนิตของเรา: " .. tostring(okU and why or "อ่านไม่ได้") .. " | โฟลเดอร์: " .. folder:GetFullName()
        end
    else
        out[#out + 1] = "ยูนิตของเรา: หา PlayerFolder ไม่เจอ (ยังไม่เข้าด่าน?)"
    end
    local shownSet = {}
    for _, b in ipairs(shown) do shownSet[b] = true end
    for i, b in ipairs(all) do
        if i > 20 then out[#out + 1] = "…ตัดที่ 20 ปุ่ม" break end
        local path = b:GetFullName():gsub("^.-PlayerGui%.", "")
        local hiddenAt = "-"
        local o = b
        while o do
            local ok, v = pcall(function()
                if safeIsA(o, "GuiObject") then return o.Visible end
                if safeIsA(o, "LayerCollector") then return o.Enabled end
                return true
            end)
            if ok and v == false then hiddenAt = o.Name break end
            o = o.Parent
        end
        local function prop(name)
            local ok, v = pcall(function() return b[name] end)
            return ok and tostring(v) or "?"
        end
        local conns = {}
        if type(getconnections) == "function" then
            for _, ev in ipairs(CLICK_EVENTS) do
                local ok, c = pcall(function() return getconnections(b[ev]) end)
                conns[#conns + 1] = EVENT_SHORT[ev] .. "=" .. ((ok and type(c) == "table") and tostring(#c) or "?")
            end
        else
            conns[1] = "ไม่มี getconnections"
        end
        local txt = "-"
        if safeIsA(b, "TextButton") then
            local ok, t = pcall(function() return b.Text end)
            if ok and type(t) == "string" and t ~= "" then txt = string.format("%q", t:sub(1, 24)) end
        end
        out[#out + 1] = string.format("- %s | %s | ซ่อนที่: %s | Interactable=%s Active=%s | ขนาด=%s | ข้อความ=%s | สัญญาณ: %s",
            path, shownSet[b] and "พร้อม" or "ไม่พร้อม", hiddenAt, prop("Interactable"), prop("Active"), prop("AbsoluteSize"), txt, table.concat(conns, " "))
    end
    local text = table.concat(out, "\n")
    print(text)
    if setclipboard then
        setclipboard(text)
        print("[AfkPotato] คัดลอกผลวินิจฉัยลงคลิปบอร์ดแล้ว วางในแชทได้เลย")
    end
    return text
end

-- แสดงปุ่มทั้งหมดบนจอ (ไว้ดูชื่อปุ่มจริง แล้วเติมใน ULT_EXTRA_NAMES) คัดลอกลงคลิปบอร์ดให้เอง
local function listButtons()
    local gui = playerGui()
    local out = { "== ปุ่มบนจอ (PlayerGui) | PlaceId " .. tostring(game.PlaceId) .. " | ★ = ปุ่มอัลติ  ↻ = ปุ่มเล่นซ้ำ ==" }
    if not gui then
        out[#out + 1] = "(ไม่พบ PlayerGui)"
    else
        local n = 0
        for _, d in ipairs(gui:GetDescendants()) do
            if isGuiButton(d) then
                n += 1
                if n > 250 then out[#out + 1] = "…ตัดที่ 250 ปุ่ม" break end
                local path = d:GetFullName():gsub("^.-PlayerGui%.", "")
                local txt = ""
                if safeIsA(d, "TextButton") then
                    local okT, t = pcall(function() return d.Text end)
                    if okT and type(t) == "string" and t ~= "" then txt = ' "' .. t:sub(1, 30) .. '"' end
                end
                out[#out + 1] = string.format("%s%s [%s]%s | %s", (ultButtonOk(d) and "★ " or "") .. (retryButtonOk(d) and "↻ " or ""), path, d.ClassName, txt,
                    isShown(d) and "เห็น" or "ซ่อน")
            end
        end
        if n == 0 then out[#out + 1] = "(ไม่พบปุ่มเลย)" end
    end
    local text = table.concat(out, "\n")
    print(text)
    if setclipboard then
        setclipboard(text)
        print("[AfkPotato] คัดลอกรายการปุ่มลงคลิปบอร์ดแล้ว วางในแชทได้เลย")
    end
    return text
end

-- รวมแล้ว: ถ้า auto_ultimate.lua ตัวแยกรันอยู่ ให้หยุด กันยิงซ้อน 2 ตัว
if G.AutoUlt and type(G.AutoUlt.Stop) == "function" then pcall(G.AutoUlt.Stop) end

-- ------------------------------------------------------------------------------
-- ปิดภาพ 3D: หยุดวาดโลก 3 มิติ (เหลือแค่ UI) ช่วยเรื่องแบต/ความร้อน/FPS มากที่สุดตอน AFK
-- ------------------------------------------------------------------------------
local render3dSupported = true
local function set3dOff(off)
    App.render3dOff = off
    local ok = pcall(function() RunService:Set3dRenderingEnabled(not off) end)
    if not ok then render3dSupported = false end
end

-- ------------------------------------------------------------------------------
-- ซ่อนผู้เล่นอื่น: ไม่วาดตัวละครคนอื่น (เห็นแค่ในเครื่องเรา ไม่มีผลกับคนอื่น) ช่วยในเซิร์ฟคนเยอะ
-- ใช้ LocalTransparencyModifier ซึ่งเป็นค่าฝั่งเครื่องเราล้วนๆ ปิดแล้วตั้งกลับเป็น 0
-- ------------------------------------------------------------------------------
local hideConns = {}
local function hideable(d) return d:IsA("BasePart") or d:IsA("Decal") end
local function setCharHidden(char, hide)
    for _, d in ipairs(char:GetDescendants()) do
        if hideable(d) then pcall(function() d.LocalTransparencyModifier = hide and 1 or 0 end) end
    end
end
local function hookPlayer(p)
    if p == LocalPlayer then return end
    local function onChar(char)
        setCharHidden(char, true)
        hideConns[#hideConns + 1] = char.DescendantAdded:Connect(function(d)
            if App.hidePlayers and hideable(d) then pcall(function() d.LocalTransparencyModifier = 1 end) end
        end)
    end
    if p.Character then onChar(p.Character) end
    hideConns[#hideConns + 1] = p.CharacterAdded:Connect(onChar)
end
local function setHidePlayers(on)
    App.hidePlayers = on
    for _, c in ipairs(hideConns) do pcall(function() c:Disconnect() end) end
    hideConns = {}
    if on then
        for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
        hideConns[#hideConns + 1] = Players.PlayerAdded:Connect(hookPlayer)
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then setCharHidden(p.Character, false) end
        end
    end
end

-- ------------------------------------------------------------------------------
-- Potato Graphics: จดค่าเดิมไว้ก่อนเปลี่ยนทุกครั้ง ปิดแล้วคืนค่าเดิม
-- ------------------------------------------------------------------------------
local saved = setmetatable({}, { __mode = "k" }) -- [Instance] = { prop = ค่าเดิม }
local lightingSaved = nil
local qualitySaved = nil

local function remember(inst, prop, newValue)
    local ok, current = pcall(function() return inst[prop] end)
    if not ok then return end
    local rec = saved[inst]
    if not rec then rec = {} saved[inst] = rec end
    if rec[prop] == nil then rec[prop] = current end -- จดครั้งแรกเท่านั้น (ค่าดั้งเดิมจริง)
    pcall(function() inst[prop] = newValue end)
end

local EFFECT_CLASSES = {
    ParticleEmitter = true, Trail = true, Beam = true, Smoke = true,
    Fire = true, Sparkles = true, Explosion = false,
}
local POST_CLASSES = {
    BloomEffect = true, BlurEffect = true, SunRaysEffect = true,
    DepthOfFieldEffect = true, ColorCorrectionEffect = true,
}

local function potatoify(inst)
    if inst:IsA("BasePart") then
        remember(inst, "Material", Enum.Material.SmoothPlastic)
        remember(inst, "Reflectance", 0)
        remember(inst, "CastShadow", false)
        if inst:IsA("MeshPart") then remember(inst, "TextureID", "") end -- ถอดลายบนโมเดล ลดหน่วยความจำกราฟิก
    elseif inst:IsA("SpecialMesh") then
        remember(inst, "TextureId", "")
    elseif inst:IsA("Atmosphere") then
        remember(inst, "Density", 0)
        remember(inst, "Haze", 0)
        remember(inst, "Glare", 0)
    elseif inst:IsA("Clouds") then
        remember(inst, "Enabled", false)
    elseif inst:IsA("Sky") then
        remember(inst, "CelestialBodiesShown", false)
        remember(inst, "StarCount", 0)
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        remember(inst, "Transparency", 1)
    elseif EFFECT_CLASSES[inst.ClassName] then
        remember(inst, "Enabled", false)
    elseif POST_CLASSES[inst.ClassName] then
        remember(inst, "Enabled", false)
    elseif inst:IsA("SurfaceAppearance") then
        -- SurfaceAppearance เปลี่ยนค่าไม่ได้จากสคริปต์ ข้าม
    end
end

local potatoAddedConn = nil
local potatoBusy = false

local function applyPotato()
    if potatoBusy then return end
    potatoBusy = true
    if not lightingSaved then
        lightingSaved = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        }
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)
    pcall(function()
        local r = settings().Rendering
        if qualitySaved == nil then qualitySaved = r.QualityLevel end
        r.QualityLevel = Enum.QualityLevel.Level01
    end)
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        remember(terrain, "WaterWaveSize", 0)
        remember(terrain, "WaterWaveSpeed", 0)
        remember(terrain, "WaterReflectance", 0)
        remember(terrain, "Decoration", false)
    end
    for _, inst in ipairs(Lighting:GetDescendants()) do potatoify(inst) end

    -- ทำทีละชุด กันเกมค้างในแมพใหญ่ (หมื่นชิ้นขึ้นไป)
    local list = Workspace:GetDescendants()
    for i, inst in ipairs(list) do
        if not App.potato then break end -- ผู้ใช้กดปิดระหว่างทำ
        potatoify(inst)
        if i % 1500 == 0 then task.wait() end
    end

    if App.potato and not potatoAddedConn then
        potatoAddedConn = Workspace.DescendantAdded:Connect(function(inst)
            if App.potato then potatoify(inst) end
        end)
    end
    potatoBusy = false
end

local function restorePotato()
    if potatoAddedConn then potatoAddedConn:Disconnect() potatoAddedConn = nil end
    if lightingSaved then
        pcall(function()
            for k, v in pairs(lightingSaved) do Lighting[k] = v end
        end)
        lightingSaved = nil
    end
    if qualitySaved ~= nil then
        pcall(function() settings().Rendering.QualityLevel = qualitySaved end)
        qualitySaved = nil
    end
    local n = 0
    for inst, rec in pairs(saved) do
        for prop, v in pairs(rec) do
            pcall(function() inst[prop] = v end)
        end
        saved[inst] = nil
        n += 1
        if n % 1500 == 0 then task.wait() end
    end
end

local fpsOriginal = nil   -- เพดานก่อนสคริปต์นี้แตะ (คืนค่าตอนปิด/ตอน Shutdown)
local fpsTouched = false
local function applyFpsCap()
    if not hasFpsCap then return end
    if App.fpsCap == 0 then
        -- ปิดล็อก: คืนค่าเดิมเฉพาะเมื่อเราเคยเปลี่ยนไปแล้ว (ไม่ไปทับค่าที่สคริปต์อื่นตั้งไว้ตอนเริ่ม)
        if fpsTouched then
            pcall(setfpscap, fpsOriginal or 60)
            fpsTouched = false
        end
        return
    end
    if not fpsTouched then
        local ok, cur = pcall(function() return getfpscap and getfpscap() end)
        fpsOriginal = (ok and type(cur) == "number" and cur > 0) and cur or 60
        fpsTouched = true
    end
    pcall(setfpscap, App.fpsCap)
end

local function setPotato(on)
    App.potato = on
    if on then
        task.spawn(applyPotato)
    else
        task.spawn(function()
            while potatoBusy do task.wait() end -- รอให้รอบที่กำลังทำหยุดก่อน ค่อยคืนค่า
            restorePotato()
        end)
    end
end

-- ------------------------------------------------------------------------------
-- UI: ลากย้ายได้ ย่อได้ แสดง FPS / Ping / จำนวนครั้งที่กัน AFK
-- ------------------------------------------------------------------------------
local guiParent
do
    local okHui, hui = pcall(function() return gethui and gethui() end)
    if okHui and hui then guiParent = hui else
        local okCore, core = pcall(function() return game:GetService("CoreGui") end)
        guiParent = (okCore and core) or LocalPlayer:WaitForChild("PlayerGui")
    end
end
local oldGui = guiParent:FindFirstChild("AfkPotatoUI")
if oldGui then oldGui:Destroy() end

local Screen = Instance.new("ScreenGui")
Screen.Name = "AfkPotatoUI"
Screen.ResetOnSpawn = false
Screen.DisplayOrder = 999
Screen.Parent = guiParent

local function corner(o, r) local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r or 8) c.Parent = o end

local Frame = Instance.new("Frame")
local viewport = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 600)
local startX, startY = Config.clampPos(Prefs.posX or 20, Prefs.posY or 120, viewport)
Frame.Size = UDim2.fromOffset(240, 368)
Frame.Position = UDim2.fromOffset(startX, startY)
Frame.BackgroundColor3 = Color3.fromRGB(15, 19, 26)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Parent = Screen
corner(Frame, 10)
local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(56, 126, 245) stroke.Thickness = 1.2 stroke.Parent = Frame

local Title = Instance.new("TextButton")
Title.Size = UDim2.new(1, -40, 0, 30)
Title.Position = UDim2.fromOffset(10, 0)
Title.BackgroundTransparency = 1
Title.AutoButtonColor = false
Title.Text = "🥔 Anti-AFK + Potato"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Color3.fromRGB(240, 244, 250)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Frame

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.fromOffset(24, 22)
MinBtn.Position = UDim2.new(1, -32, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(26, 34, 48)
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.TextColor3 = Color3.fromRGB(240, 244, 250)
MinBtn.Parent = Frame
corner(MinBtn, 6)

do -- ลากที่หัวข้อ
    local dragging, startPos, startInput = false, nil, nil
    track(Title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, startPos, startInput = true, Frame.Position, input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    Config.scheduleSave()
                end
            end)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - startInput
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, -20, 1, -38)
Body.Position = UDim2.fromOffset(10, 32)
Body.BackgroundTransparency = 1
Body.Parent = Frame

local function makeToggle(y, label, getState, setState, rightPad)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(1, -(rightPad or 0), 0, 26)
    Btn.Position = UDim2.fromOffset(0, y)
    Btn.BackgroundColor3 = Color3.fromRGB(22, 29, 41)
    Btn.AutoButtonColor = false
    Btn.Text = ""
    Btn.Parent = Body
    corner(Btn, 8)
    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -60, 1, 0)
    Lbl.Position = UDim2.fromOffset(10, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.GothamMedium
    Lbl.TextSize = 12
    Lbl.TextColor3 = Color3.fromRGB(240, 244, 250)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Text = label
    Lbl.Parent = Btn
    local Sw = Instance.new("Frame")
    Sw.Size = UDim2.fromOffset(38, 20)
    Sw.Position = UDim2.new(1, -48, 0.5, -10)
    Sw.Parent = Btn
    corner(Sw, 10)
    local Knob = Instance.new("Frame")
    Knob.Size = UDim2.fromOffset(16, 16)
    Knob.BackgroundColor3 = Color3.fromRGB(240, 244, 250)
    Knob.Parent = Sw
    corner(Knob, 8)
    local function paint()
        local on = getState()
        Sw.BackgroundColor3 = on and Color3.fromRGB(56, 126, 245) or Color3.fromRGB(34, 44, 60)
        Knob.Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    end
    paint()
    track(Btn.MouseButton1Click:Connect(function()
        setState(not getState())
        paint()
        Config.write()
    end))
end

makeToggle(0, "Anti-AFK (กดจำลอง)", function() return App.antiAfk end, function(v) App.antiAfk = v end)
makeToggle(28, "Potato Graphics (คืนค่าได้)", function() return App.potato end, setPotato)
makeToggle(56, "ปิดภาพ 3D (ประหยัดสุด)", function() return App.render3dOff end, set3dOff)
makeToggle(84, "ซ่อนผู้เล่นอื่น", function() return App.hidePlayers end, setHidePlayers)
makeToggle(112, "Auto Ultimate", function() return App.autoUlt end, function(v) App.autoUlt = v end, 66)
makeToggle(140, "Auto Retry (เล่นซ้ำ)", function() return App.autoRetry end, function(v) App.autoRetry = v end)

-- ปุ่มสอน: กดแล้วแตะปุ่มสกิลในเกม (ปุ่มโหมดสอน ข้างสวิตช์ Auto Ultimate)
local TeachBtn = Instance.new("TextButton")
TeachBtn.Name = "TeachBtn"
TeachBtn.Size = UDim2.fromOffset(60, 26)
TeachBtn.Position = UDim2.new(1, -60, 0, 112)
TeachBtn.BackgroundColor3 = Color3.fromRGB(34, 44, 60)
TeachBtn.Text = "สอนปุ่ม"
TeachBtn.Font = Enum.Font.GothamBold
TeachBtn.TextSize = 11
TeachBtn.TextColor3 = Color3.fromRGB(240, 244, 250)
TeachBtn.Parent = Body
corner(TeachBtn, 8)
local function paintTeach()
    TeachBtn.Text = Teach.active and ("หยุด " .. math.max(0, math.ceil(Teach.endAt - os.clock())) .. "s") or "สอนปุ่ม"
    TeachBtn.BackgroundColor3 = Teach.active and Color3.fromRGB(170, 110, 30) or Color3.fromRGB(34, 44, 60)
end
track(TeachBtn.MouseButton1Click:Connect(function()
    if Teach.active then teachStop() else teachStart() end
    paintTeach()
end))

-- แถวล็อก FPS: [ล็อก FPS]  [−]  ค่า  [+]   (ไม่วนจากสุดท้ายกลับไปต้น กันกดเกินแล้วเด้งไปปิด)
do
    local Row = Instance.new("Frame")
    Row.Size = UDim2.new(1, 0, 0, 26)
    Row.Position = UDim2.fromOffset(0, 172)
    Row.BackgroundColor3 = Color3.fromRGB(22, 29, 41)
    Row.Parent = Body
    corner(Row, 8)
    local Lbl = Instance.new("TextLabel")
    Lbl.Size = UDim2.new(1, -110, 1, 0)
    Lbl.Position = UDim2.fromOffset(10, 0)
    Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.GothamMedium
    Lbl.TextSize = 12
    Lbl.TextColor3 = Color3.fromRGB(240, 244, 250)
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
    Lbl.Text = "ล็อก FPS"
    Lbl.Parent = Row
    local Value = Instance.new("TextLabel")
    Value.Name = "FpsValue"
    Value.Size = UDim2.fromOffset(56, 26)
    Value.Position = UDim2.new(1, -84, 0, 0)
    Value.BackgroundTransparency = 1
    Value.Font = Enum.Font.GothamBold
    Value.TextSize = 12
    Value.TextColor3 = Color3.fromRGB(56, 126, 245)
    Value.Parent = Row
    local function mkBtn(text, x)
        local b = Instance.new("TextButton")
        b.Name = "Fps" .. (text == "+" and "Plus" or "Minus")
        b.Size = UDim2.fromOffset(24, 24)
        b.Position = UDim2.new(1, x, 0.5, -12)
        b.BackgroundColor3 = Color3.fromRGB(34, 44, 60)
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.fromRGB(240, 244, 250)
        b.Parent = Row
        corner(b, 6)
        return b
    end
    local Minus, Plus = mkBtn("−", -108), mkBtn("+", -28)
    local function paintFps()
        Value.Text = hasFpsCap and fpsLabel(App.fpsCap) or "ไม่รองรับ"
    end
    local function step(dir)
        if not hasFpsCap then return end
        local idx = 1
        for i, o in ipairs(FPS_OPTIONS) do if o == App.fpsCap then idx = i end end
        local nextIdx = math.clamp(idx + dir, 1, #FPS_OPTIONS)
        if nextIdx == idx then return end
        App.fpsCap = FPS_OPTIONS[nextIdx]
        applyFpsCap()
        paintFps()
        Config.write()
    end
    paintFps()
    track(Minus.MouseButton1Click:Connect(function() step(-1) end))
    track(Plus.MouseButton1Click:Connect(function() step(1) end))
end

local Info = Instance.new("TextLabel")
Info.Size = UDim2.new(1, 0, 0, 126)
Info.Position = UDim2.fromOffset(0, 204)
Info.BackgroundTransparency = 1
Info.Font = Enum.Font.Code
Info.TextSize = 11
Info.TextColor3 = Color3.fromRGB(130, 144, 168)
Info.TextXAlignment = Enum.TextXAlignment.Left
Info.TextYAlignment = Enum.TextYAlignment.Top
Info.TextWrapped = true
Info.Parent = Body

local collapsed = Prefs.collapsed
local function applyCollapsed()
    Body.Visible = not collapsed
    Frame.Size = collapsed and UDim2.fromOffset(240, 30) or UDim2.fromOffset(240, 368)
    MinBtn.Text = collapsed and "+" or "—"
end
applyCollapsed()
track(MinBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    applyCollapsed()
    Config.write()
end))
Config.getCollapsed = function() return collapsed end
Config.getPos = function() return { X = Frame.Position.X.Offset, Y = Frame.Position.Y.Offset } end

-- FPS (เฉลี่ย) + Ping + สถานะ อัปเดตทุก 0.5 วินาที
local frames, fpsTimer, fps = 0, 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    frames += 1
    fpsTimer += dt
    if fpsTimer >= 0.5 then
        fps = math.floor(frames / fpsTimer + 0.5)
        frames, fpsTimer = 0, 0
        local ping = "?"
        pcall(function()
            ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)
        local afkText = App.antiAfk and string.format("%d ครั้ง, ล่าสุด %s", App.afkCount,
            App.lastAfk and (math.floor(os.clock() - App.lastAfk) .. " วิก่อน") or "-") or "ปิดอยู่"
        local potatoText = App.potato and (potatoBusy and "กำลังปรับ" or "เปิด") or "ปิด"
        local r3dText = not render3dSupported and "ไม่รองรับ" or (App.render3dOff and "ปิดภาพ" or "ปกติ")
        local capText = (hasFpsCap and App.fpsCap ~= 0) and (" (ล็อก " .. fpsLabel(App.fpsCap) .. ")") or ""
        local ultText = App.autoUlt and string.format("กด %d | %s", Ult.fired, Ult.status) or "ปิดอยู่"
        paintTeach()
        local teachText = Teach.active
            and string.format("กำลังสอน เหลือ %d วิ | แตะปุ่มสกิลในเกม | %s", math.max(0, math.ceil(Teach.endAt - os.clock())), Teach.last)
            or string.format("%d ปุ่ม | %s", #App.taught, Teach.last)
        local retryText = App.autoRetry and Retry.status or "ปิดอยู่"
        Info.Text = string.format("FPS %d%s | Ping %s\nกัน AFK: %s\nวิธี: %s\nPotato %s | 3D %s | ซ่อนคน %s\nอัลติ: %s\nเล่นซ้ำ: %s\nสอนไว้: %s\nConfig: %s",
            fps, capText, ping, afkText, App.afkMethod, potatoText, r3dText, App.hidePlayers and "เปิด" or "ปิด", ultText, retryText, teachText, Config.status)
    end
end))

-- ปิดทั้งหมด (ใช้ตอนรันซ้ำ หรือเรียกเองด้วย AfkPotato.Shutdown())
G.AfkPotato = {
    ResetConfig = Config.reset,
    ListButtons = listButtons,
    UltDebug = ultDebug,
    ForgetButtons = forgetButtons,
    ListTaught = function() for i, path in ipairs(App.taught) do print(i, path) end return App.taught end,
    Shutdown = function()
        teachStop()          -- เลิกฟังปุ่ม/การแตะของโหมดสอน
        Config.closed = true -- ห้ามเขียนไฟล์ระหว่างปิด (ไม่งั้น potato=false ตอนคืนค่ากราฟิก จะไปทับค่าที่บันทึกไว้)
        App.closed = true    -- หยุดลูป Anti-AFK และ Auto Ultimate
        if App.render3dOff then pcall(function() RunService:Set3dRenderingEnabled(true) end) end
        if App.hidePlayers then setHidePlayers(false) end
        App.potato = false
        while potatoBusy do task.wait() end
        restorePotato()
        if fpsTouched and hasFpsCap then pcall(setfpscap, fpsOriginal or 60) fpsTouched = false end
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if Screen then Screen:Destroy() end
    end,
}

-- ถ้าค่าที่บันทึกไว้เปิด Potato อยู่: รอให้เกมโหลดเสร็จ + 2 วินาที (ให้ของในแมพเกิดครบก่อน) แล้วค่อยปรับ
-- ถ้าระหว่างรอผู้ใช้กดปิดเอง จะไม่ปรับ
if App.fpsCap ~= 0 then applyFpsCap() end
if App.hidePlayers then setHidePlayers(true) end
if App.render3dOff then
    task.spawn(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        if App.render3dOff and not App.closed then set3dOff(true) end
    end)
end

if App.potato then
    task.spawn(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        task.wait(2)
        if App.potato and not potatoBusy then setPotato(true) end
    end)
end

print(string.format("[AfkPotato] พร้อมแล้ว: Anti-AFK %s / Potato %s / 3D %s / ซ่อนคน %s / อัลติ %s (โหมด " .. ULT_MODE .. ") / ล็อก FPS %s | Config: %s",
    App.antiAfk and "เปิด" or "ปิด", App.potato and "เปิด (รอเกมโหลดแล้วปรับ)" or "ปิด",
    App.render3dOff and "ปิดภาพ" or "ปกติ", App.hidePlayers and "เปิด" or "ปิด", App.autoUlt and "เปิด" or "ปิด",
    hasFpsCap and fpsLabel(App.fpsCap) or "ไม่รองรับ", Config.status))

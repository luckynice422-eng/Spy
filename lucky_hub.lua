-- ==============================================================================
-- LUCKY HUB  |  รวมสคริปต์ทั้งหมดไว้ไฟล์เดียว + แดชบอร์ดแสดงผลทุกอย่าง (เงิน เพชร ตัวละครในกระเป๋า สถานะระบบ)
--   ล็อบบี้ (Place 132929771812494) : เคลมรางวัลเควส + สุ่มกล่อง + ขายอัตโนมัติ (แบ่งระดับ) แล้วเข้าลิฟต์/Start
--   ด่านเกม  (Place 114068177100380) : วางป้อม + อัปเกรด + ข้ามเวฟ/โหวต/ความเร็ว/รีเพลย์ (รอ 10 วิ แล้วกดทุก 6 วิ)
-- ค่าเริ่มต้น: เปิดทุกอย่าง | ขายจริง ระดับ Basic/Uncommon/Rare/Epic/Legendary (Mythic/Exclusive ไม่ขาย)
--
-- ตั้งค่า (ใส่ก่อนรัน ไม่ต้องใส่ก็ได้):
--   getgenv().HubConfig    = { Equip = true, Summon = true, Start = true, Sell = true, Quest = true, TD = true,
--                              WaitSummon = false,   -- false = รอ StartDelay (10 วิ) แล้วเข้าลิฟต์เลย / true = รอสุ่มจบ+ขายก่อนค่อยเข้าลิฟต์
--                              ElevatorAfter = 180,  -- (WaitSummon=true) เพดานรอ: เข้าลิฟต์ภายในกี่วินาที (0 = รอสุ่มจบเท่านั้น)
--                              SellSettle = 12,      -- (WaitSummon=true) หลังสุ่มจบรอขายอีกกี่วินาทีก่อนเข้าลิฟต์
--                              Requeue = false, ScriptFile = "lucky_hub.lua" }  -- true = ให้สคริปต์ตั้งรันต่อเองหลังวาป (ต้องมีไฟล์ใน workspace) ; ถ้าใช้ autoexec ปล่อย false ไว้
--   getgenv().EquipConfig  = { Unit = "Speakerman", Slot = 1 }   -- ใส่ป้อมหลักลง Slot 1 ก่อนเข้าลิฟต์ (ไม่ต้องเปิดหน้า Inventory)
--   getgenv().SummonConfig = { Crate = "Basic Crate", Amount = 10, MaxRolls = 0 }
--   getgenv().StartConfig  = { Elevator = "Elevator1", StartDelay = 10 }  -- StartDelay = รอกี่วินาทีหลังรันสคริปต์ก่อนเข้าลิฟต์   -- หรือ { Elevator = "auto", Map = "Desert" }
--   getgenv().SellConfig   = { Tiers = { Basic = true, Mythic = false }, DryRun = false }
--   getgenv().QuestConfig  = { Quests = { {"Beat100Waves","Daily"}, {"Place25","Daily"}, {"WinGames3","Daily"} } }  -- เคลมรางวัลเควสในล็อบบี้ (เพิ่มเควสอื่นได้ เช่น {"ชื่อ","Weekly"})
--   getgenv().TdAutoConfig = { MaxTowers = 15, EquipSlot = 1, LeaveAfterRounds = 10 }  -- ครบกี่รอบแล้วกด OnLeave กลับล็อบบี้ (0 = ไม่ออก)
--   getgenv().WebhookConfig = { Url = "ลิงก์ Webhook", Watch = { "Speakerman" }, RareFrom = "Mythic", PingEveryone = true, Machine = "PC1" }  -- แจ้ง Discord เมื่อได้ของใน Watch / ตัวระดับ RareFrom ขึ้นไป (ping @everyone) ; ปิดทั้งระบบ: HubConfig.Webhook = false
-- ==============================================================================

local G = (getgenv and getgenv()) or _G

local LOBBY_ID, GAME_ID = 132929771812494, 114068177100380
local HUB = { Equip = true, Summon = true, Start = true, Sell = true, Quest = true, TD = true, Webhook = true,
              Panel = true, ModulePanels = false, Log = true, Requeue = false, ScriptFile = "lucky_hub.lua",
              WaitSummon = false, ElevatorAfter = 180, SellSettle = 12, SummonMaxWait = 900 }
local forcedPlace
if type(G.HubConfig) == "table" then
    for k, v in pairs(G.HubConfig) do
        if k == "Place" then forcedPlace = tostring(v):lower()
        elseif type(HUB[k]) == "number" then HUB[k] = tonumber(v) or HUB[k]
        elseif type(HUB[k]) == "string" then HUB[k] = tostring(v)
        elseif HUB[k] ~= nil then HUB[k] = v and true or false end
    end
end

if G.LuckyHub and type(G.LuckyHub.Shutdown) == "function" then
    pcall(G.LuckyHub.Shutdown)
end

-- ---------- สถานะที่ต้องจำข้ามการวาประหว่างแมพ (จำนวนรอบ / ขั้นตอน) ----------
-- เก็บใน getgenv (ถ้า executor เก็บข้ามแมพ) และไฟล์ (ถ้ามี readfile/writefile) ; ข้อมูลเก่าเกิน STALE วินาทีถือว่าหมดอายุ
local function makeStateStore(Gt, fileName)
    local STALE = 3600
    local function fresh() return { rounds = 0, phase = "", ts = 0 } end
    local function loadData()
        local d = Gt.LuckyHubData
        if type(d) ~= "table" and type(isfile) == "function" and type(readfile) == "function" then
            local ok, txt = pcall(function() if isfile(fileName) then return readfile(fileName) end end)
            if ok and type(txt) == "string" then
                local r, p, t = txt:match("^(%-?%d+),([%w_]*),(%d+)$")
                if r then d = { rounds = tonumber(r), phase = p, ts = tonumber(t) } end
            end
        end
        if type(d) ~= "table" then d = fresh() end
        if os.time() - (d.ts or 0) > STALE then d = fresh() end
        Gt.LuckyHubData = d
        return d
    end
    local store = {}
    function store.get(k) return loadData()[k] end
    function store.set(k, v)
        local d = loadData()
        d[k] = v
        d.ts = os.time()
        Gt.LuckyHubData = d
        if type(writefile) == "function" then
            pcall(writefile, fileName, string.format("%d,%s,%d", d.rounds or 0, tostring(d.phase or ""), d.ts))
        end
    end
    return store
end

local HubState = makeStateStore(G, "LuckyHub_state.txt")

local function detectPlace()
    if forcedPlace then return forcedPlace end
    local pid = game.PlaceId
    if pid == LOBBY_ID then return "lobby" end
    if pid == GAME_ID then return "game" end
    if workspace:FindFirstChild("Elevators") then return "lobby" end
    local g = workspace:FindFirstChild("Game")
    if g and g:FindFirstChild("Towers") then return "game" end
    return nil
end

-- ========================= โมดูล: Equip (lobby_auto_equip.lua) =========================
local function Module_Equip()
    -- Lobby Auto Equip  |  ใส่ป้อม (ค่าเริ่มต้น Speakerman) ลง Slot 1 อัตโนมัติในล็อบบี้ (Place 132929771812494)
    -- Remote ที่ใช้ (ตามล็อกที่คุณส่งมา):
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteEvent.EquipPart:FireServer("UnequipAll")
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteEvent.EquipPart:FireServer("<GUID ป้อม>")
    -- หา GUID จากชื่อ: รายการใน Inventory (PlayerGui...InventoryFrame.List.ScrollingFrame.<GUID>) มี attribute SearchName = ชื่อป้อม
    -- การทำงาน: ถ้า Speakerman อยู่ Slot 1 แล้ว = ไม่ทำอะไร ; ถ้าไม่ใช่ = ถอดทั้งหมด > ใส่ Speakerman เป็นตัวแรก > ใส่ตัวเดิมกลับ
    --   (เกมไม่มีเลขช่องในคำสั่งใส่ จึงถือว่าตัวที่ใส่ก่อนได้ช่อง 1 ; ถ้าอ่านค่า Slot1 ได้จะตรวจซ้ำให้)
    -- ไม่ต้องเปิดหน้า Inventory: รายการป้อมอยู่ใน UI แม้ปิดหน้าอยู่ (ยืนยันจากผลสแกน) ; ถ้าไม่เห็นรายการจะใช้ FallbackId แทน
    -- ปรับค่า: getgenv().EquipConfig = { Unit = "Speakerman", Slot = 1, FallbackId = "<GUID>" }

    local CFG = {
        Unit          = "Speakerman",   -- ชื่อป้อมที่ต้องการ (ตรงทั้งชื่อ ไม่สนตัวพิมพ์เล็กใหญ่ ; "Car Speakerman" ไม่ใช่)
        Slot          = 1,              -- ช่องที่ต้องการ
        FallbackId    = "25386a7b-8c6d-4ed0-8f9a-3c6bda7e6293",   -- GUID Speakerman ของคุณ (ใช้เมื่อหาในรายการ Inventory ไม่เจอ)
        RestoreOthers = true,           -- ใส่ป้อมตัวอื่นที่เคยใส่อยู่กลับคืนหลังใส่ตัวหลักแล้ว
        EquipGap      = 0.8,            -- เว้นกี่วินาทีระหว่างคำสั่งแต่ละครั้ง
        VerifyWait    = 4,              -- รอเช็คผลหลังใส่ (วินาที)
        Retries       = 1,              -- ใส่ไม่ติดลองซ้ำกี่รอบ (ถอดทั้งหมดแล้วใส่ใหม่)
        WaitInventory = 8,              -- รอรายการ Inventory โผล่นานสุดกี่วินาที ก่อนใช้ FallbackId
        Log           = true,           -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร
        PanelX = -306, PanelY = 360,
        ShowUi        = true,
        AutoStart     = false,
    }

    local G = (getgenv and getgenv()) or _G
    if type(G.EquipConfig) == "table" then
        for k, v in pairs(G.EquipConfig) do
            if CFG[k] ~= nil then CFG[k] = v end
        end
    end
    if G.LobbyEquip and type(G.LobbyEquip.Shutdown) == "function" then
        pcall(G.LobbyEquip.Shutdown)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer

    CFG.Slot = math.max(1, math.min(5, math.floor(tonumber(CFG.Slot) or 1)))
    CFG.EquipGap = math.max(0.3, tonumber(CFG.EquipGap) or 0.8)
    CFG.VerifyWait = math.max(0.5, tonumber(CFG.VerifyWait) or 4)
    CFG.Retries = math.max(0, math.floor(tonumber(CFG.Retries) or 1))
    CFG.WaitInventory = math.max(0, tonumber(CFG.WaitInventory) or 8)

    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[LobbyEquip] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[LobbyEquip] ▶ " .. doing)
        end
    end

    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end
    local function getRemote()
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteEvent", "EquipPart" })
    end
    local function isGuid(s)
        return type(s) == "string" and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
    end

    -- ---------- อ่านรายการป้อมจาก UI ----------
    local function guidOf(inst)
        if isGuid(inst.Name) then return inst.Name end
        for _, key in ipairs({ "Id", "UnitId", "Guid", "GUID", "TowerId" }) do
            local ok, v = pcall(function() return inst:GetAttribute(key) end)
            if ok and isGuid(v) then return v end
        end
        return nil
    end
    local function entryEquipped(inst)
        local eq = false
        pcall(function()
            for _, d in ipairs(inst:GetDescendants()) do
                if d.Name:lower() == "equipped" then
                    local vis = true
                    pcall(function() vis = d.Visible end)
                    if vis then eq = true end
                end
            end
        end)
        return eq
    end
    -- คืนรายการ { guid, name, inst, equipped } เรียงตามลำดับใน UI
    local function scanEntries()
        local out, seen = {}, {}
        local pg = LP and LP:FindFirstChild("PlayerGui")
        if not pg then return out end
        local matched = {}
        for _, d in ipairs(pg:GetDescendants()) do
            local guid = guidOf(d)
            if guid and not seen[guid] then
                local nested, p = false, d.Parent
                while p and p ~= pg do
                    if matched[p] then nested = true break end
                    p = p.Parent
                end
                if not nested then
                    matched[d] = true
                    seen[guid] = true
                    local okN, nm = pcall(function() return d:GetAttribute("SearchName") end)
                    out[#out + 1] = { guid = guid, name = (okN and type(nm) == "string") and nm or nil, inst = d, equipped = entryEquipped(d) }
                end
            end
        end
        return out
    end
    local function findByName(entries, unit)
        local want = tostring(unit):lower()
        for _, e in ipairs(entries) do
            if e.name and e.name:lower() == want then return e end
        end
        return nil
    end
    local function findByGuid(entries, guid)
        for _, e in ipairs(entries) do if e.guid == guid then return e end end
        return nil
    end
    local function slotName()
        local ok, v = pcall(function() return LP:GetAttribute("Slot" .. CFG.Slot) end)
        if ok and type(v) == "string" and v ~= "" then return v end
        return nil
    end

    -- ---------- สถานะ ----------
    local running, gen = false, 0
    local finished, success = false, false
    local status = "พร้อมแล้ว กดปุ่ม 'เริ่ม'"
    local uiStatus, uiButton, uiGui

    local function refreshUi()
        pcall(function()
            if uiStatus then uiStatus.Text = status end
            if uiButton then
                uiButton.Text = running and "หยุด" or "เริ่ม"
                uiButton.BackgroundColor3 = running and Color3.fromRGB(170, 70, 70) or Color3.fromRGB(46, 125, 90)
            end
        end)
    end
    local function setStatus(s) status = s refreshUi() end

    local function sleep(sec, myGen)
        local t = os.clock()
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    local function fire(remote, arg)
        local ok, err = pcall(function() remote:FireServer(arg) end)
        if not ok then warn("[LobbyEquip] ยิง EquipPart ไม่สำเร็จ: " .. tostring(err)) end
        return ok
    end

    -- รอจนป้อม guid ขึ้นว่าใส่อยู่ (คืน true/false/nil ; nil = ไม่เห็นรายการใน UI เลย เช็คไม่ได้)
    local function waitEquipped(guid, myGen)
        local t0 = os.clock()
        local seenAny = false
        while os.clock() - t0 < CFG.VerifyWait do
            if gen ~= myGen or not running then return false end
            local e = findByGuid(scanEntries(), guid)
            if e then
                seenAny = true
                if e.equipped then return true end
            end
            task.wait(0.2)
        end
        if not seenAny then return nil end
        return false
    end

    local function work(myGen)
        local remote = getRemote()
        if not remote then
            warn("[LobbyEquip] ไม่พบ Remote EquipPart (ต้องอยู่ในล็อบบี้)")
            setStatus("ไม่พบ Remote EquipPart")
            return false
        end

        -- 1) ตรวจ Slot ปัจจุบัน (ถ้าเกมเปิดให้อ่าน)
        local cur = slotName()
        if cur and cur:lower() == tostring(CFG.Unit):lower() then
            setStatus("Slot " .. CFG.Slot .. " เป็น " .. cur .. " อยู่แล้ว")
            note("already", "Slot " .. CFG.Slot .. " เป็น " .. cur .. " อยู่แล้ว", "ไม่ต้องใส่ใหม่")
            return true
        end
        note("slot", "ตรวจ Slot " .. CFG.Slot .. " ตอนนี้ = " .. tostring(cur or "(อ่านค่าในล็อบบี้ไม่ได้)"), "หา " .. CFG.Unit .. " ในรายการ Inventory")

        -- 2) หา GUID ของป้อมจากชื่อ (รอรายการ Inventory โผล่ได้ไม่เกิน WaitInventory วินาที)
        local entries, target
        local t0 = os.clock()
        while true do
            entries = scanEntries()
            target = findByName(entries, CFG.Unit)
            if target or os.clock() - t0 >= CFG.WaitInventory then break end
            setStatus("รอรายการ Inventory โหลด")
            note("waitinv", "ยังไม่เจอ " .. CFG.Unit .. " ในรายการ Inventory (พบ " .. #entries .. " รายการ)",
                string.format("รอได้อีก %d วิ ถ้ายังไม่เจอจะใช้ FallbackId", math.max(0, math.ceil(CFG.WaitInventory - (os.clock() - t0)))))
            if not sleep(1, myGen) then return false end
        end
        local guid
        if target then
            guid = target.guid
            note("found", string.format("เจอ %s ใน Inventory (GUID %s, %s)", CFG.Unit, guid:sub(1, 8), target.equipped and "ใส่อยู่" or "ยังไม่ได้ใส่"), "ตรวจว่าอยู่ Slot " .. CFG.Slot .. " หรือไม่")
        elseif isGuid(CFG.FallbackId) then
            guid = CFG.FallbackId
            warn("[LobbyEquip] ไม่เจอ " .. CFG.Unit .. " ในรายการ Inventory ใช้ FallbackId " .. guid:sub(1, 8) .. "…")
            note("fallback", "ใช้ FallbackId แทน (GUID " .. guid:sub(1, 8) .. ")", "ถอดทั้งหมด แล้วใส่ " .. CFG.Unit .. " เป็นตัวแรก")
        else
            warn("[LobbyEquip] ไม่เจอ " .. CFG.Unit .. " และไม่มี FallbackId")
            setStatus("ไม่เจอ " .. CFG.Unit .. " ในรายการ Inventory")
            return false
        end

        -- 3) ใส่อยู่ตัวเดียวและเป็นตัวนี้ = อยู่ Slot 1 แน่นอน ไม่ต้องทำอะไร
        local equippedList, others = {}, {}
        for _, e in ipairs(entries) do
            if e.equipped then
                equippedList[#equippedList + 1] = e
                if e.guid ~= guid then others[#others + 1] = e end
            end
        end
        if target and target.equipped and #others == 0 and cur == nil then
            setStatus(CFG.Unit .. " ใส่อยู่ตัวเดียว (Slot " .. CFG.Slot .. ")")
            note("only", CFG.Unit .. " เป็นป้อมเดียวที่ใส่อยู่ = อยู่ Slot " .. CFG.Slot .. " แล้ว", "ไม่ต้องใส่ใหม่")
            return true
        end

        -- 4) ถอดทั้งหมด > ใส่ตัวหลักก่อน > (ถ้าไม่ติด ลองใหม่) > ใส่ตัวเดิมกลับ
        local ok = false
        local verified
        for attempt = 1, CFG.Retries + 1 do
            setStatus(string.format("ถอดป้อมทั้งหมด (ครั้งที่ %d)", attempt))
            note("unequip" .. attempt, string.format("ถอดป้อมทั้งหมด (ครั้งที่ %d/%d)", attempt, CFG.Retries + 1),
                "ใส่ " .. CFG.Unit .. " เป็นตัวแรก แล้ว" .. ((CFG.RestoreOthers and #others > 0) and (" ใส่ตัวเดิมกลับอีก " .. #others .. " ตัว") or "จบ"))
            fire(remote, "UnequipAll")
            if not sleep(CFG.EquipGap, myGen) then return false end
            setStatus("ใส่ " .. CFG.Unit)
            note("equip" .. attempt, string.format("ใส่ %s (GUID %s)", CFG.Unit, guid:sub(1, 8)), "เช็คว่าไอคอนใส่อยู่ขึ้นภายใน " .. CFG.VerifyWait .. " วิ")
            fire(remote, guid)
            verified = waitEquipped(guid, myGen)
            if gen ~= myGen or not running then return false end
            if verified ~= false then ok = true break end
            note("noverify" .. attempt, "ใส่ " .. CFG.Unit .. " แล้วแต่ยังไม่ขึ้นว่าใส่อยู่", attempt <= CFG.Retries and "ถอดทั้งหมดแล้วลองใส่ใหม่" or "ยอมแพ้การใส่ตัวหลัก (จะใส่ตัวเดิมกลับ)")
        end

        if CFG.RestoreOthers and #others > 0 then
            note("restore", "ใส่ป้อมตัวเดิมกลับ " .. #others .. " ตัว", "ตรวจผลสุดท้าย")
            for i, e in ipairs(others) do
                if not sleep(CFG.EquipGap, myGen) then return false end
                setStatus(string.format("ใส่ตัวเดิมกลับ %d/%d", i, #others))
                fire(remote, e.guid)
            end
        end
        if not sleep(CFG.EquipGap, myGen) then return false end

        -- 5) ตรวจผลสุดท้าย (อ่าน Slot ถ้าเกมให้อ่าน)
        local after = slotName()
        if after and after:lower() ~= tostring(CFG.Unit):lower() then
            warn(string.format("[LobbyEquip] ใส่แล้วแต่ Slot %d เป็น %s ไม่ใช่ %s", CFG.Slot, after, CFG.Unit))
            setStatus("Slot " .. CFG.Slot .. " ยังเป็น " .. after)
            return false
        end
        if not ok then
            warn("[LobbyEquip] ใส่ " .. CFG.Unit .. " ไม่สำเร็จ (ไอคอนใส่อยู่ไม่ขึ้น)")
            setStatus("ใส่ " .. CFG.Unit .. " ไม่สำเร็จ")
            return false
        end
        setStatus(CFG.Unit .. " ใส่ที่ Slot " .. CFG.Slot .. " แล้ว" .. (verified == nil and " (ยืนยันจาก UI ไม่ได้)" or ""))
        note("done", CFG.Unit .. " ใส่ที่ Slot " .. CFG.Slot .. " เรียบร้อย" .. (verified == nil and " (ยืนยันจาก UI ไม่ได้)" or ""), "ไปขั้นต่อไป (สุ่ม/ขาย/เข้าลิฟต์)")
        return true
    end

    local function start()
        if running then return end
        gen = gen + 1
        running, finished, success = true, false, false
        local myGen = gen
        for k in pairs(logKeys) do logKeys[k] = nil end
        setStatus("เริ่มทำงาน")
        note("begin", string.format("เริ่มตรวจ/ใส่ %s ลง Slot %d", CFG.Unit, CFG.Slot), "ถ้าอยู่ Slot " .. CFG.Slot .. " แล้วจะไม่ทำอะไร ไม่งั้นถอดทั้งหมดแล้วใส่ใหม่")
        task.spawn(function()
            local okc, res = pcall(work, myGen)
            if gen ~= myGen then return end
            if not okc then
                warn("[LobbyEquip] เกิดข้อผิดพลาด: " .. tostring(res))
                setStatus("ผิดพลาด ดู Console")
                res = false
            end
            running = false
            finished = true
            success = res and true or false
            if not success then
                note("fail", "ใส่ " .. CFG.Unit .. " ไม่สำเร็จ", "ข้ามไปขั้นต่อไปโดยไม่ใส่ (ดูข้อความเตือนด้านบน)")
            end
            refreshUi()
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            finished = true
            success = false
            setStatus("หยุดแล้ว")
            note("stop", "หยุดการใส่ป้อมตามที่สั่ง", "ไม่ทำอะไรต่อ")
        end
    end

    local function shutdown()
        stop()
        if uiGui then pcall(function() uiGui:Destroy() end) uiGui = nil end
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LobbyEquipGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            uiGui = gui
            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(290, 110)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            label("Auto ใส่ " .. CFG.Unit .. " Slot " .. CFG.Slot, 6, 13)
            uiStatus = label(status, 28, 12, Color3.fromRGB(150, 220, 170))
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(10, 62)
            b.Size = UDim2.new(1, -20, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(46, 125, 90)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = "เริ่ม"
            b.Parent = frame
            local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
            uiButton = b
            b.MouseButton1Click:Connect(function()
                if running then stop() else start() end
            end)
        end)
        if not okUi then warn("[LobbyEquip] สร้างหน้าต่างไม่สำเร็จ ใช้ LobbyEquip.Start() / Stop() แทน") end
    end

    G.LobbyEquip = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        IsRunning = function() return running end,
        Done = function() return finished end,
        Ok = function() return success end,
        Status = function() return status end,
        Config = CFG,
    }

    print("[LobbyEquip] พร้อมแล้ว กดปุ่ม 'เริ่ม' (หรือ LobbyEquip.Start()) | ใส่ " .. CFG.Unit .. " ที่ Slot " .. CFG.Slot)
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: Summon (lobby_auto_summon.lua) =========================
local function Module_Summon()
    -- Lobby Auto Summon  |  สุ่มกล่อง (Crate) อัตโนมัติในล็อบบี้ (Place 132929771812494)
    -- Remote ที่ใช้ (ตามที่เห็นในล็อกของคุณ):
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteFunction.SummonTowers:InvokeServer("Basic Crate", 10)
    -- ปรับค่า: getgenv().SummonConfig = { Crate = "Basic Crate", Amount = 10, Gap = 1.5, MaxRolls = 0 }
    -- ใช้งาน: รันสคริปต์ > กด "เริ่ม" (หรือ LobbySummon.Start())  | หยุด: กดปุ่มอีกครั้ง
    -- ค่าที่เกมตอบกลับจะพิมพ์ใน Console ช่วงแรก (ไว้ตรวจว่าสุ่มได้จริงไหม)

    local CFG = {
        Crate     = "Basic Crate",  -- ชื่อกล่อง (ปุ่ม Crate ในแผงกดสลับได้)
        Amount    = 10,             -- จำนวนต่อครั้ง (ค่าที่เห็นในล็อกคือ 10)
        Gap       = 1.5,            -- เว้นกี่วินาทีระหว่างแต่ละครั้ง
        MaxRolls  = 0,              -- จำนวนครั้งสูงสุด (0 = ไม่จำกัด จนกว่าจะกดหยุด/สุ่มไม่สำเร็จ)
        FailLimit = 3,              -- สุ่มไม่สำเร็จติดกันกี่ครั้งแล้วหยุด (เช่น เงินไม่พอ)
        LogResults = 5,             -- พิมพ์ค่าที่เกมตอบกลับกี่ครั้งแรก (และเมื่อรูปแบบเปลี่ยน)
        PanelX = -286, PanelY = 80,   -- ตำแหน่งแผง (ระยะจากขวา / จากบน)
        Log       = true,           -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร
        ShowUi    = true,
        AutoStart = false,
    }
    local CRATE_FALLBACK = { "Basic Crate", "Exclusive Scientist Crate", "Exclusive Spider Crate", "Woman Crate" }

    local G = (getgenv and getgenv()) or _G
    if type(G.SummonConfig) == "table" then
        for k, v in pairs(G.SummonConfig) do
            if CFG[k] ~= nil then CFG[k] = v end
        end
    end
    if G.LobbySummon and type(G.LobbySummon.Shutdown) == "function" then
        pcall(G.LobbySummon.Shutdown)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    CFG.Amount = math.max(1, math.floor(tonumber(CFG.Amount) or 10))
    CFG.Gap = math.max(0.3, tonumber(CFG.Gap) or 1.5)
    CFG.FailLimit = math.max(1, math.floor(tonumber(CFG.FailLimit) or 3))


    -- log แบบ "กำลังทำ / ถัดไป" : ข้อความเดิมซ้ำติดกันจะไม่พิมพ์ซ้ำ
    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[LobbySummon] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[LobbySummon] ▶ " .. doing)
        end
    end

    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end

    local function getSummonRemote()
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteFunction", "SummonTowers" })
    end

    -- รายชื่อกล่องจริงในเกม (ReplicatedStorage.Assets.Crates) ; ไม่เจอใช้รายการสำรอง
    local function crateNames()
        local list = {}
        local folder = findPath(ReplicatedStorage, { "Assets", "Crates" })
        if folder then
            for _, c in ipairs(folder:GetChildren()) do list[#list + 1] = c.Name end
        end
        if #list == 0 then list = CRATE_FALLBACK end
        return list
    end

    -- แสดงค่าที่ตอบกลับแบบย่อ (ตาราง 2 ชั้น สูงสุด 12 รายการ)
    local function describe(v, depth)
        depth = depth or 0
        if type(v) ~= "table" then return tostring(v) end
        if depth >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. describe(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    -- ค่าที่ตอบกลับแบบไหนถือว่า "ไม่สำเร็จ"
    local function isFailure(res)
        if res == nil or res == false then return true end
        if type(res) == "string" then
            local low = res:lower()
            if low:find("not enough") or low:find("insufficient") or low:find("cannot") or low:find("can't")
                or low:find("fail") or low:find("error") then
                return true
            end
        end
        return false
    end

    local running, gen = false, 0
    local status, countText = "พร้อมแล้ว กดปุ่ม 'เริ่ม'", "สุ่มแล้ว 0 ครั้ง (0 ชิ้น)"
    local uiStatus, uiCount, uiButton, uiCrate, uiGui
    local rolls, pieces = 0, 0

    local function refreshUi()
        pcall(function()
            if uiStatus then uiStatus.Text = status end
            if uiCount then uiCount.Text = countText end
            if uiButton then
                uiButton.Text = running and "หยุด" or "เริ่ม"
                uiButton.BackgroundColor3 = running and Color3.fromRGB(170, 70, 70) or Color3.fromRGB(46, 125, 90)
            end
            if uiCrate then uiCrate.Text = "Crate: " .. CFG.Crate end
        end)
    end

    local function setStatus(s) status = s refreshUi() end

    local function sleep(sec, myGen)
        local t = os.clock()
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    local function loop(myGen)
        local fails = 0
        local logged, lastDesc = 0, nil
        while running and gen == myGen do
            local remote = getSummonRemote()
            if not remote then
                warn("[LobbySummon] ไม่พบ Remote SummonTowers (ต้องอยู่ในล็อบบี้)")
                running = false
                setStatus("ไม่พบ Remote (ต้องอยู่ในล็อบบี้)")
                return
            end
            setStatus(string.format("สุ่ม %s x%d …", CFG.Crate, CFG.Amount))
            note("roll" .. (rolls + fails + 1) .. "_" .. fails, string.format("สุ่ม %s x%d (ครั้งที่ %d)", CFG.Crate, CFG.Amount, rolls + 1),
                "รอเกมตอบกลับ แล้วสุ่มต่อใน " .. tostring(CFG.Gap) .. " วิ")
            local ok, res = pcall(function() return remote:InvokeServer(CFG.Crate, CFG.Amount) end)
            if gen ~= myGen or not running then return end

            local failed
            if not ok then
                failed = true
                warn("[LobbySummon] InvokeServer error: " .. tostring(res))
            else
                failed = isFailure(res)
                local d = describe(res)
                if logged < CFG.LogResults or d ~= lastDesc and logged < CFG.LogResults + 20 then
                    logged = logged + 1
                    print("[LobbySummon] ตอบกลับ = " .. d)
                end
                lastDesc = d
            end

            if failed then
                fails = fails + 1
                if fails >= CFG.FailLimit then
                    running = false
                    setStatus(string.format("หยุด: สุ่มไม่สำเร็จติดกัน %d ครั้ง (เงินไม่พอ?)", fails))
                    note("failstop", string.format("หยุดสุ่ม: ไม่สำเร็จติดกัน %d ครั้ง (เงินไม่พอ?) รวมสุ่มได้ %d ครั้ง (%d ชิ้น)", fails, rolls, pieces),
                        "ไม่สุ่มต่อ (ถ้าใช้ผ่าน Hub: ขาย/เข้าลิฟต์ทำงานตามแผน)")
                    return
                end
                note("fail" .. rolls .. "_" .. fails, string.format("สุ่มไม่สำเร็จ ครั้งที่ %d/%d", fails, CFG.FailLimit),
                    string.format("ลองใหม่ใน %s วิ (ถ้าไม่สำเร็จติดกัน %d ครั้งจะหยุด)", tostring(CFG.Gap), CFG.FailLimit))
            else
                fails = 0
                rolls = rolls + 1
                pieces = pieces + CFG.Amount
                countText = string.format("สุ่มแล้ว %d ครั้ง (%d ชิ้น)", rolls, pieces)
                note("ok" .. rolls, string.format("สุ่มสำเร็จ รวม %d ครั้ง (%d ชิ้น)", rolls, pieces),
                    (CFG.MaxRolls > 0 and rolls >= CFG.MaxRolls) and "ครบจำนวนครั้งที่ตั้งไว้ จะหยุด" or ("สุ่มครั้งถัดไปใน " .. tostring(CFG.Gap) .. " วิ"))
                if CFG.MaxRolls > 0 and rolls >= CFG.MaxRolls then
                    running = false
                    setStatus("เสร็จแล้ว: ครบ " .. rolls .. " ครั้ง")
                    return
                end
            end
            refreshUi()
            if not sleep(CFG.Gap, myGen) then return end
        end
    end

    local function start()
        if running then return end
        gen = gen + 1
        running = true
        local myGen = gen
        local okc = false
        for _, n in ipairs(crateNames()) do if n == CFG.Crate then okc = true break end end
        if not okc then warn("[LobbySummon] ไม่พบกล่องชื่อ '" .. tostring(CFG.Crate) .. "' ใน Assets.Crates (จะลองสุ่มตามชื่อนี้ต่อ)") end
        setStatus("เริ่มทำงาน")
        for k in pairs(logKeys) do logKeys[k] = nil end
        note("begin", string.format("เริ่มสุ่ม %s ครั้งละ %d ชิ้น เว้น %s วิ", CFG.Crate, CFG.Amount, tostring(CFG.Gap)),
            "สุ่มต่อไปเรื่อยๆ จนเงินไม่พอ (ไม่สำเร็จติดกัน " .. CFG.FailLimit .. " ครั้ง)" .. (CFG.MaxRolls > 0 and (" หรือครบ " .. CFG.MaxRolls .. " ครั้ง") or ""))
        task.spawn(function()
            local ok, err = pcall(loop, myGen)
            if not ok then
                warn("[LobbySummon] เกิดข้อผิดพลาด: " .. tostring(err))
                if gen == myGen then running = false setStatus("ผิดพลาด ดู Console") end
            end
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            setStatus("หยุดแล้ว")
            note("stop", "หยุดสุ่มตามที่สั่ง", "ไม่สุ่มต่อ")
        end
    end

    local function shutdown()
        stop()
        if uiGui then pcall(function() uiGui:Destroy() end) uiGui = nil end
    end

    local function setCrate(name)
        CFG.Crate = name
        refreshUi()
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LobbySummonGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            uiGui = gui

            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(270, 150)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame

            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            label("Auto สุ่มกล่อง (ล็อบบี้)", 6, 13)
            uiStatus = label(status, 28, 12, Color3.fromRGB(150, 220, 170))
            uiCount = label(countText, 48, 12, Color3.fromRGB(160, 165, 180))

            local function button(text, y, color)
                local b = Instance.new("TextButton")
                b.Position = UDim2.fromOffset(10, y)
                b.Size = UDim2.new(1, -20, 0, 30)
                b.BackgroundColor3 = color
                b.BorderSizePixel = 0
                b.Font = Enum.Font.GothamMedium
                b.TextSize = 13
                b.TextColor3 = Color3.new(1, 1, 1)
                b.Text = text
                b.Parent = frame
                local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
                return b
            end
            uiButton = button("เริ่ม", 74, Color3.fromRGB(46, 125, 90))
            uiButton.MouseButton1Click:Connect(function()
                if running then stop() else start() end
            end)
            uiCrate = button("Crate: " .. CFG.Crate, 110, Color3.fromRGB(70, 72, 84))
            uiCrate.MouseButton1Click:Connect(function()
                local names = crateNames()
                local idx = 0
                for i, n in ipairs(names) do if n == CFG.Crate then idx = i break end end
                setCrate(names[(idx % #names) + 1])
            end)
            refreshUi()
        end)
        if not okUi then warn("[LobbySummon] สร้างหน้าต่างไม่สำเร็จ ใช้ LobbySummon.Start() / Stop() แทน") end
    end

    G.LobbySummon = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        SetCrate = setCrate,
        IsRunning = function() return running end,
        Stats = function() return { rolls = rolls, pieces = pieces } end,
        Status = function() return status .. " | " .. countText end,
        Config = CFG,
    }

    print("[LobbySummon] พร้อมแล้ว กดปุ่ม 'เริ่ม' (หรือ LobbySummon.Start()) | กล่อง: " .. CFG.Crate .. " x" .. CFG.Amount)
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: Start (lobby_auto_start.lua) =========================
local function Module_Start()
    -- Lobby Auto Start  |  เข้าลิฟต์ + กด Start อัตโนมัติ (Place 132929771812494)
    -- Remote ที่ใช้ (ตามล็อกที่คุณส่งมา):
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteFunction.ElevatorEnter:InvokeServer("Elevator1")
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteFunction.ElevatorStart:InvokeServer("Elevator1")
    -- สถานะลิฟต์อ่านจาก Workspace.Elevators.<ชื่อ> (attribute: Host / Players / MaxPlayers / Time / Map)
    -- ปรับค่า: getgenv().StartConfig = { Elevator = "Elevator1" }   หรือ  { Elevator = "auto", Map = "Toilet City" }
    -- ใช้งาน: รันสคริปต์ > กด "เริ่ม" (หรือ LobbyStart.Start()) | พอวาปไปด่าน สคริปต์จะหายไปเอง

    local CFG = {
        StartDelay  = 10,             -- หลังรันสคริปต์ รอกี่วินาทีก่อนเข้าลิฟต์ + กด Start (นับจากตอนรันสคริปต์)
        Log         = true,           -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร
        Elevator    = "Elevator1",    -- ชื่อลิฟต์ หรือ "auto" = เลือกลิฟต์ว่างของแมพ Map
        Map         = "Toilet City",  -- ใช้เมื่อ Elevator = "auto" (มี Toilet City / Desert / Cameraman HQ)
        EnterWait   = 3.0,            -- รอให้เข้าลิฟต์สำเร็จ (วินาที) ก่อนถือว่าไม่สำเร็จ
        EnterTries  = 3,              -- พยายามเข้าลิฟต์กี่ครั้ง
        StartGap    = 1.3,            -- เว้นกี่วินาทีระหว่างการกด Start (ในล็อกคุณห่างราว 1.3 วิ)
        StartTries  = 12,             -- กด Start กี่ครั้งต่อรอบ
        MaxCycles   = 5,              -- ทำซ้ำ (เข้าใหม่ + Start) กี่รอบถ้ายังไม่วาป
        CycleRest   = 4,              -- พักระหว่างรอบ (วินาที)
        MoveToPad   = true,           -- เข้าลิฟต์ไม่ติด -> ย้ายตัวละครไปยืนบนแท่นลิฟต์แล้วลองใหม่
        LogResults  = 5,              -- พิมพ์ค่าที่เกมตอบกลับกี่ครั้งแรก (และเมื่อเปลี่ยน)
        PanelX = -306, PanelY = 240,  -- ตำแหน่งแผง (ระยะจากขวา / จากบน)
        ShowUi      = true,
        AutoStart   = false,
    }

    local G = (getgenv and getgenv()) or _G
    if type(G.StartConfig) == "table" then
        for k, v in pairs(G.StartConfig) do
            if CFG[k] ~= nil then CFG[k] = v end
        end
    end
    if G.LobbyStart and type(G.LobbyStart.Shutdown) == "function" then
        pcall(G.LobbyStart.Shutdown)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer

    CFG.StartDelay = math.max(0, tonumber(CFG.StartDelay) or 0)
    CFG.StartGap = math.max(0.5, tonumber(CFG.StartGap) or 1.3)
    CFG.StartTries = math.max(1, math.floor(tonumber(CFG.StartTries) or 12))
    CFG.EnterTries = math.max(1, math.floor(tonumber(CFG.EnterTries) or 3))
    CFG.MaxCycles = math.max(1, math.floor(tonumber(CFG.MaxCycles) or 5))

    local loadedAt = os.clock()   -- เวลาที่รันสคริปต์ (ใช้นับ StartDelay)

    -- log แบบ "กำลังทำ / ถัดไป" : ข้อความเดิมซ้ำติดกันจะไม่พิมพ์ซ้ำ
    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[LobbyStart] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[LobbyStart] ▶ " .. doing)
        end
    end

    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end

    local function getRemote(name)
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteFunction", name })
    end

    local function elevatorsFolder() return workspace:FindFirstChild("Elevators") end

    local function attr(inst, name)
        if not inst then return nil end
        local ok, v = pcall(function() return inst:GetAttribute(name) end)
        if ok then return v end
        return nil
    end

    local function describe(v, depth)
        depth = depth or 0
        if type(v) ~= "table" then return tostring(v) end
        if depth >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 10 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. describe(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    -- เลือกลิฟต์: ชื่อที่กำหนด หรือ auto = ลิฟต์ว่าง (Players=0) ของแมพ Map ; ไม่มีว่างใช้ลิฟต์ที่ยังไม่เต็มและไม่มีเจ้าของ
    local function pickElevator()
        local folder = elevatorsFolder()
        if not folder then return nil, "ไม่พบ Workspace.Elevators (ต้องอยู่ในล็อบบี้)" end
        if string.lower(tostring(CFG.Elevator)) ~= "auto" then
            local e = folder:FindFirstChild(CFG.Elevator)
            if not e then return nil, "ไม่พบลิฟต์ชื่อ " .. tostring(CFG.Elevator) end
            return e
        end
        local list = {}
        for _, e in ipairs(folder:GetChildren()) do
            if attr(e, "Map") == CFG.Map then list[#list + 1] = e end
        end
        table.sort(list, function(a, b)
            local na, nb = tonumber(a.Name:match("%d+")) or 0, tonumber(b.Name:match("%d+")) or 0
            return na < nb
        end)
        for _, e in ipairs(list) do
            if (attr(e, "Players") or 0) == 0 then return e end
        end
        for _, e in ipairs(list) do
            if (attr(e, "Players") or 0) < (attr(e, "MaxPlayers") or 5) and (attr(e, "Host") or 0) == 0 then return e end
        end
        return nil, "ไม่มีลิฟต์ว่างของแมพ " .. tostring(CFG.Map)
    end

    local running, gen = false, 0
    local status, info = "พร้อมแล้ว กดปุ่ม 'เริ่ม'", ""
    local uiStatus, uiInfo, uiButton, uiGui

    local function refreshUi()
        pcall(function()
            if uiStatus then uiStatus.Text = status end
            if uiInfo then uiInfo.Text = info end
            if uiButton then
                uiButton.Text = running and "หยุด" or "เริ่ม"
                uiButton.BackgroundColor3 = running and Color3.fromRGB(170, 70, 70) or Color3.fromRGB(46, 125, 90)
            end
        end)
    end
    local function setStatus(s) status = s refreshUi() end

    local function sleep(sec, myGen)
        local t = os.clock()
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    local function elevatorInfo(e)
        return string.format("%s | %s | คน %s/%s | Host %s | เวลา %s", e.Name, tostring(attr(e, "Map")),
            tostring(attr(e, "Players")), tostring(attr(e, "MaxPlayers")), tostring(attr(e, "Host")), tostring(attr(e, "Time")))
    end

    -- ย้ายตัวละครไปบนแท่นลิฟต์ (เฉพาะเมื่อเข้าไม่ติด)
    local function moveToPad(e)
        local ok = pcall(function()
            local area = e:FindFirstChild("Area") or e:FindFirstChild("Pad")
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if area and hrp then
                local cf = area:IsA("BasePart") and area.CFrame or area:GetPivot()
                hrp.CFrame = cf + Vector3.new(0, 3, 0)
            end
        end)
        return ok
    end

    local logged, lastDesc = 0, nil
    local function logResult(tag, ok, res)
        local d = ok and describe(res) or ("error: " .. tostring(res))
        if logged < CFG.LogResults or (d ~= lastDesc and logged < CFG.LogResults + 20) then
            logged = logged + 1
            print("[LobbyStart] " .. tag .. " ตอบกลับ = " .. d)
        end
        lastDesc = d
    end

    local function loop(myGen)
        -- 0) รอ StartDelay วินาทีหลังรันสคริปต์ ก่อนเข้าลิฟต์
        local remain = CFG.StartDelay - (os.clock() - loadedAt)
        if remain > 0 then
            note("delay", string.format("รันสคริปต์แล้ว รอ %d วิ ก่อนเข้าลิฟต์ %s", math.ceil(CFG.StartDelay), tostring(CFG.Elevator)),
                string.format("เมื่อครบเวลา จะเข้าลิฟต์ แล้วกด Start ทุก %s วิ จนวาป", tostring(CFG.StartGap)))
            local lastSec
            while running and gen == myGen do
                remain = CFG.StartDelay - (os.clock() - loadedAt)
                if remain <= 0 then break end
                local sec = math.ceil(remain)
                if sec ~= lastSec then
                    lastSec = sec
                    setStatus(string.format("รออีก %d วิ ก่อนเข้าลิฟต์", sec))
                    if sec % 5 == 0 or sec <= 3 then print("[LobbyStart] ⏳ อีก " .. sec .. " วิ จะเข้าลิฟต์") end
                end
                task.wait(0.1)
            end
            if not (running and gen == myGen) then return end
            print("[LobbyStart] ✔ ครบ " .. math.ceil(CFG.StartDelay) .. " วิแล้ว เริ่มเข้าลิฟต์")
        end
        local enterR, startR = getRemote("ElevatorEnter"), getRemote("ElevatorStart")
        if not enterR or not startR then
            warn("[LobbyStart] ไม่พบ Remote ElevatorEnter/ElevatorStart (ต้องอยู่ในล็อบบี้)")
            running = false
            setStatus("ไม่พบ Remote (ต้องอยู่ในล็อบบี้)")
            return
        end

        for cycle = 1, CFG.MaxCycles do
            if not (running and gen == myGen) then return end
            local e, why = pickElevator()
            if not e then
                running = false
                setStatus(why)
                warn("[LobbyStart] " .. why)
                return
            end
            info = elevatorInfo(e)
            note("pick" .. cycle, string.format("รอบ %d/%d เลือกลิฟต์ %s", cycle, CFG.MaxCycles, elevatorInfo(e)),
                string.format("เข้าลิฟต์ (ลองสูงสุด %d ครั้ง ครั้งละรอ %s วิ)", CFG.EnterTries, tostring(CFG.EnterWait)))

            -- 1) เข้าลิฟต์ (เช็คว่าสำเร็จจากจำนวนคนในลิฟต์ที่เพิ่มขึ้น / Host เป็นเรา)
            local entered = false
            for try = 1, CFG.EnterTries do
                local before = attr(e, "Players")
                setStatus(string.format("รอบ %d: เข้าลิฟต์ %s (ครั้งที่ %d)", cycle, e.Name, try))
                note("enter" .. cycle .. "_" .. try, string.format("เข้าลิฟต์ %s ครั้งที่ %d/%d", e.Name, try, CFG.EnterTries),
                    "ถ้าจำนวนคนเพิ่ม/เป็น Host ภายใน " .. tostring(CFG.EnterWait) .. " วิ = เข้าสำเร็จ -> กด Start")
                local ok, res = pcall(function() return enterR:InvokeServer(e.Name) end)
                logResult("ElevatorEnter", ok, res)
                if not (running and gen == myGen) then return end
                local t0 = os.clock()
                while os.clock() - t0 < CFG.EnterWait and running and gen == myGen do
                    local now = attr(e, "Players")
                    local host = attr(e, "Host")
                    if (host and host == LP.UserId) or (type(before) == "number" and type(now) == "number" and now > before) then
                        entered = true
                        break
                    end
                    if before == nil then entered = ok and res ~= false break end   -- อ่านจำนวนคนไม่ได้: เชื่อค่าที่ตอบกลับ
                    task.wait(0.1)
                end
                if entered then break end
                if CFG.MoveToPad and try >= 2 then
                    setStatus("เข้าไม่ติด ย้ายไปยืนบนแท่นลิฟต์")
                    note("pad" .. cycle .. "_" .. try, "เข้าลิฟต์ไม่ติดครั้งที่ " .. try, "ย้ายตัวละครไปยืนบนแท่นลิฟต์ แล้วลองเข้าใหม่")
                    moveToPad(e)
                    if not sleep(0.5, myGen) then return end
                end
            end
            if not entered then
                warn("[LobbyStart] เข้าลิฟต์ " .. e.Name .. " ไม่สำเร็จ (" .. elevatorInfo(e) .. ")")
                note("fail" .. cycle, "รอบ " .. cycle .. ": เข้าลิฟต์ไม่สำเร็จ", string.format("พัก %s วิ แล้วเลือกลิฟต์/เข้าใหม่ (รอบ %d/%d)", tostring(CFG.CycleRest), cycle + 1, CFG.MaxCycles))
                setStatus("เข้าลิฟต์ไม่สำเร็จ รอบ " .. cycle)
                if not sleep(CFG.CycleRest, myGen) then return end
            else
                -- 2) กด Start ซ้ำจนกว่าจะวาป (สคริปต์หายไปเองตอนวาป)
                note("in" .. cycle, "เข้าลิฟต์ " .. e.Name .. " สำเร็จ", string.format("กด Start สูงสุด %d ครั้ง ทุก %s วิ จนกว่าจะวาปไปด่าน", CFG.StartTries, tostring(CFG.StartGap)))
                for i = 1, CFG.StartTries do
                    info = elevatorInfo(e)
                    setStatus(string.format("รอบ %d: กด Start %d/%d", cycle, i, CFG.StartTries))
                    note("st" .. cycle .. "_" .. i, string.format("กด Start ครั้งที่ %d/%d", i, CFG.StartTries),
                        i < CFG.StartTries and string.format("ถ้ายังไม่วาป กดซ้ำใน %s วิ", tostring(CFG.StartGap)) or "ครบจำนวนครั้งแล้ว รอดูว่าวาปไหม")
                    local ok, res = pcall(function() return startR:InvokeServer(e.Name) end)
                    logResult("ElevatorStart", ok, res)
                    if not (running and gen == myGen) then return end
                    if not sleep(CFG.StartGap, myGen) then return end
                end
                setStatus(string.format("รอบ %d: กด Start ครบ %d ครั้งแล้วยังไม่วาป", cycle, CFG.StartTries))
                note("nostart" .. cycle, string.format("รอบ %d: กด Start ครบ %d ครั้งแล้วยังไม่วาป", cycle, CFG.StartTries),
                    cycle < CFG.MaxCycles and string.format("พัก %s วิ แล้วเข้ารอบ %d/%d", tostring(CFG.CycleRest), cycle + 1, CFG.MaxCycles) or "ครบทุกรอบแล้ว จะหยุด")
                if not sleep(CFG.CycleRest, myGen) then return end
            end
        end
        if running and gen == myGen then
            running = false
            setStatus("หยุด: ครบ " .. CFG.MaxCycles .. " รอบแล้วยังไม่วาป")
            note("end", "หยุด: ครบ " .. CFG.MaxCycles .. " รอบแล้วยังไม่วาป", "ไม่ทำอะไรต่อ (กดปุ่ม เริ่ม เพื่อลองใหม่)")
        end
    end

    local function start()
        if running then return end
        gen = gen + 1
        running = true
        local myGen = gen
        setStatus("เริ่มทำงาน")
        for k in pairs(logKeys) do logKeys[k] = nil end
        task.spawn(function()
            local ok, err = pcall(loop, myGen)
            if not ok then
                warn("[LobbyStart] เกิดข้อผิดพลาด: " .. tostring(err))
                if gen == myGen then running = false setStatus("ผิดพลาด ดู Console") end
            end
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            setStatus("หยุดแล้ว")
            note("stop", "หยุดเข้าลิฟต์/กด Start ตามที่สั่ง", "ไม่ทำอะไรต่อ")
        end
    end

    local function shutdown()
        stop()
        if uiGui then pcall(function() uiGui:Destroy() end) uiGui = nil end
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LobbyStartGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            uiGui = gui
            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(290, 118)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            label("Auto เข้าลิฟต์ + Start (ล็อบบี้)", 6, 13)
            uiStatus = label(status, 28, 12, Color3.fromRGB(150, 220, 170))
            uiInfo = label(info, 48, 11, Color3.fromRGB(160, 165, 180))
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(10, 76)
            b.Size = UDim2.new(1, -20, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(46, 125, 90)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = "เริ่ม"
            b.Parent = frame
            local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
            uiButton = b
            b.MouseButton1Click:Connect(function()
                if running then stop() else start() end
            end)
        end)
        if not okUi then warn("[LobbyStart] สร้างหน้าต่างไม่สำเร็จ ใช้ LobbyStart.Start() / Stop() แทน") end
    end

    G.LobbyStart = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        IsRunning = function() return running end,
        Status = function() return status .. " | " .. info end,
        Config = CFG,
    }

    print("[LobbyStart] พร้อมแล้ว กดปุ่ม 'เริ่ม' (หรือ LobbyStart.Start()) | ลิฟต์: " .. tostring(CFG.Elevator))
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: Sell (lobby_auto_sell.lua) =========================
local function Module_Sell()
    -- Lobby Auto Sell  |  ขายป้อมอัตโนมัติ แบ่งตามระดับ (Rarity) เลือกได้ (Place 132929771812494)
    -- Remote ที่ใช้ (ตามล็อกของคุณ):
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteEvent.SellPart:FireServer({ "<GUID ป้อม>" })
    -- ระดับในเกม: Basic < Uncommon < Rare < Epic < Legendary < Mythic < Exclusive
    --
    -- ความปลอดภัย (การขายย้อนกลับไม่ได้):
    --   * ตั้งค่าเริ่มต้น: ขาย Basic/Uncommon/Rare/Epic/Legendary จริง (Mythic/Exclusive ไม่ขาย) ; DryRun = true จะเป็นโหมดทดลองไม่ขายจริง
    --   * ไม่ขายป้อมที่ใส่อยู่ในช่อง (Slot1-5), ป้อมที่มีไอคอน Equipped/ล็อก, ป้อมชื่อใน KeepNames (ค่าเริ่มต้น Speakerman)
    --   * ไม่ขายระหว่างที่โมดูล Equip กำลังสลับป้อม (LobbyEquip กำลังทำงาน)
    --   * ไม่ขายป้อมที่อ่านระดับไม่ได้ (ไม่แน่ใจ = ไม่ขาย)
    --   * ขายเฉพาะที่อ่านระดับได้ "ชัวร์" จากข้อความ/attribute เท่านั้น (เดาจากสีอย่างเดียว = ไม่ขาย)
    -- วิธีใช้: ไม่ต้องเปิดหน้า Inventory (รายการอยู่ใน UI แม้ปิดหน้าอยู่) > เลือกระดับที่จะขาย > กด "สแกน" ดูผล > ปิดโหมดทดลอง > กด "เริ่ม"
    -- ปรับค่า: getgenv().SellConfig = { DryRun = false, Tiers = { Basic = true, Uncommon = true } }

    local RARITIES = { "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exclusive" }

    local CFG = {
        Tiers      = { Basic = true, Uncommon = true, Rare = true, Epic = true, Legendary = true },  -- ระดับที่จะขาย ("Common" = Basic)
        DryRun     = false,         -- true = ทดลอง ไม่ขายจริง
        SellGap    = 0.4,           -- เว้นกี่วินาทีระหว่างการขายแต่ละครั้ง
        Batch      = 1,             -- ส่งกี่ GUID ต่อหนึ่งคำสั่ง (ล็อกของคุณส่งทีละ 1)
        ScanEvery  = 5,             -- โหมดเริ่ม: สแกนซ้ำทุกกี่วินาที (สุ่มได้ของใหม่แล้วขายต่อ)
        MaxPerScan = 50,            -- ขายสูงสุดกี่ชิ้นต่อการสแกนหนึ่งรอบ
        Retries    = 2,             -- ขายแล้วชิ้นยังอยู่ในคลัง ลองซ้ำกี่ครั้งก่อนยอมแพ้
        PanelX     = -612,
        PanelY     = 80,
        KeepNames  = { "Speakerman" },   -- ชื่อป้อมที่ไม่ขายเด็ดขาด (อ่านจาก attribute SearchName ของรายการ ต้องตรงทั้งชื่อ)
        Log        = true,          -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร
        ShowUi     = true,
        AutoStart  = false,
    }

    local G = (getgenv and getgenv()) or _G
    if type(G.SellConfig) == "table" then
        for k, v in pairs(G.SellConfig) do
            if k == "Tiers" and type(v) == "table" then
                CFG.Tiers = {}
                for name, on in pairs(v) do CFG.Tiers[name] = on and true or nil end
            elseif CFG[k] ~= nil then
                CFG[k] = v
            end
        end
    end
    if G.LobbySell and type(G.LobbySell.Shutdown) == "function" then
        pcall(G.LobbySell.Shutdown)
    end

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LP = Players.LocalPlayer

    CFG.SellGap = math.max(0.2, tonumber(CFG.SellGap) or 0.4)
    CFG.Batch = math.max(1, math.floor(tonumber(CFG.Batch) or 1))
    CFG.ScanEvery = math.max(2, tonumber(CFG.ScanEvery) or 5)

    local KEEP = {}
    for _, n in ipairs(type(CFG.KeepNames) == "table" and CFG.KeepNames or {}) do KEEP[tostring(n):lower()] = true end

    local RARITY_LOWER = {}
    for _, r in ipairs(RARITIES) do RARITY_LOWER[r:lower()] = r end
    RARITY_LOWER["common"] = "Basic"   -- ในเกมระดับต่ำสุดชื่อ Basic


    -- log แบบ "กำลังทำ / ถัดไป" : ข้อความเดิมซ้ำติดกันจะไม่พิมพ์ซ้ำ
    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[LobbySell] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[LobbySell] ▶ " .. doing)
        end
    end
    local function noteReset(key) logKeys[key] = nil end

    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end

    local function isGuid(s)
        return type(s) == "string" and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
    end

    -- ---------- สีของแต่ละระดับ (จาก ReplicatedStorage.Assets.RaritiesGradients) ----------
    local gradientColors   -- { [rarity] = { Color3 first, Color3 last } }
    local function loadGradients()
        gradientColors = {}
        local folder = findPath(ReplicatedStorage, { "Assets", "RaritiesGradients" })
        if not folder then return end
        for _, g in ipairs(folder:GetChildren()) do
            local name = RARITY_LOWER[g.Name:lower()]
            if name then
                pcall(function()
                    local kp = g.Color.Keypoints
                    gradientColors[name] = { kp[1].Value, kp[#kp].Value }
                end)
            end
        end
    end

    local function colorClose(a, b)
        return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02
    end

    local function rarityFromGradient(inst)
        local ok, kp = pcall(function() return inst.Color.Keypoints end)
        if not ok or not kp or #kp == 0 then return nil end
        local first, last = kp[1].Value, kp[#kp].Value
        for name, cols in pairs(gradientColors) do
            if colorClose(first, cols[1]) and colorClose(last, cols[2]) then return name end
        end
        return nil
    end

    -- ---------- อ่านรายการป้อมในคลังจาก UI ----------
    local function guidOf(inst)
        if isGuid(inst.Name) then return inst.Name end
        for _, key in ipairs({ "Id", "UnitId", "Guid", "GUID", "TowerId" }) do
            local ok, v = pcall(function() return inst:GetAttribute(key) end)
            if ok and isGuid(v) then return v end
        end
        return nil
    end

    local function describeEntry(entry)
        local rarity, equipped, locked, hint = nil, false, false, nil
        local ok, err = pcall(function()
            local okA, ra = pcall(function() return entry:GetAttribute("Rarity") end)
            if okA and type(ra) == "string" and RARITY_LOWER[ra:lower()] then rarity = RARITY_LOWER[ra:lower()] end
            for _, d in ipairs(entry:GetDescendants()) do
                local nm = d.Name:lower()
                if not rarity then
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        local t = tostring(d.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                        local r = RARITY_LOWER[t:lower()]
                        if r then rarity = r end
                    end
                end
                if not rarity and d:IsA("UIGradient") then
                    local rg = RARITY_LOWER[d.Name:lower()]   -- เกมตั้งชื่อ UIGradient ใต้ Background เป็นชื่อระดับ เช่น Uncommon / Basic
                    if rg then rarity = rg end
                end
                if not rarity and not hint and d:IsA("UIGradient") then
                    hint = rarityFromGradient(d)   -- เดาจากสี = ใช้แสดงผลเท่านั้น ไม่ใช้ตัดสินใจขาย
                end
                if nm == "equipped" then
                    local vis = true
                    pcall(function() vis = d.Visible end)
                    if vis then equipped = true end
                elseif nm == "lock" or nm == "locked" then
                    local vis = true
                    pcall(function() vis = d.Visible end)
                    if vis then locked = true end
                end
            end
        end)
        if not ok then return nil end
        return rarity, equipped, locked, hint
    end

    local function entryName(inst)
        local ok, v = pcall(function() return inst:GetAttribute("SearchName") end)
        if ok and type(v) == "string" then return v end
        return nil
    end
    local function isKept(name)
        return name ~= nil and KEEP[name:lower()] == true
    end
    local function equipBusy()
        local e = G.LobbyEquip
        return e and type(e.IsRunning) == "function" and e.IsRunning() or false
    end

    local function equippedIds()
        local set = {}
        for i = 1, 5 do
            local ok, v = pcall(function() return LP:GetAttribute("Slot" .. i .. "Id") end)
            if ok and isGuid(v) then set[v] = true end
        end
        return set
    end

    -- คืนรายการ { guid, rarity, equipped, locked, inst }
    local function scanInventory()
        if not gradientColors then loadGradients() end
        local pg = LP and LP:FindFirstChild("PlayerGui")
        local out, seenGuid = {}, {}
        if not pg then return out end
        local protected = equippedIds()
        local matched = {}
        for _, d in ipairs(pg:GetDescendants()) do
            local guid = guidOf(d)
            if guid and not seenGuid[guid] then
                -- ข้ามตัวที่อยู่ใต้รายการที่เจอไปแล้ว (กันนับซ้ำ)
                local nested = false
                local p = d.Parent
                while p and p ~= pg do
                    if matched[p] then nested = true break end
                    p = p.Parent
                end
                if not nested then
                    matched[d] = true
                    seenGuid[guid] = true
                    local rarity, equipped, locked, hint = describeEntry(d)
                    local nm = entryName(d)
                    out[#out + 1] = {
                        guid = guid, rarity = rarity, inst = d, hint = hint, name = nm,
                        equipped = (equipped or protected[guid] or isKept(nm)) and true or false,
                        locked = locked and true or false,
                    }
                end
            end
        end
        return out
    end

    local function summarize(list)
        local count, unknown, prot = {}, 0, 0
        for _, e in ipairs(list) do
            if e.equipped or e.locked then prot = prot + 1
            elseif e.rarity then count[e.rarity] = (count[e.rarity] or 0) + 1
            else unknown = unknown + 1 end
        end
        local parts = {}
        for _, r in ipairs(RARITIES) do
            if count[r] then parts[#parts + 1] = r .. " x" .. count[r] end
        end
        local s = #parts > 0 and table.concat(parts, ", ") or "ไม่มี"
        return string.format("%s | ใส่อยู่/ล็อก %d | อ่านระดับไม่ได้ %d", s, prot, unknown)
    end

    local function reportText(list)
        local lines = { "== SELL SCAN | " .. tostring(LP and LP.Name) .. " | พบ " .. #list .. " รายการ ==" }
        lines[#lines + 1] = summarize(list)
        for i, e in ipairs(list) do
            if i > 25 then lines[#lines + 1] = "... (+" .. (#list - 25) .. ")" break end
            local path = "?"
            pcall(function() path = e.inst:GetFullName() end)
            lines[#lines + 1] = string.format("%s | %s%s%s | %s", e.guid, tostring(e.rarity or (e.hint and ("ไม่รู้ระดับ (สีคล้าย " .. e.hint .. ")") or "ไม่รู้ระดับ")),
                e.equipped and " | ใส่อยู่" or "", e.locked and " | ล็อก" or "", path)
        end
        if #list == 0 then
            lines[#lines + 1] = "ไม่พบรายการที่ชื่อ/attribute เป็น GUID ใน PlayerGui — รายการอาจยังไม่โหลด ลองสแกนใหม่"
            local pg = LP and LP:FindFirstChild("PlayerGui")
            if pg then
                local names = {}
                for _, c in ipairs(pg:GetChildren()) do names[#names + 1] = c.Name end
                lines[#lines + 1] = "PlayerGui: " .. table.concat(names, ", ")
            end
        end
        return table.concat(lines, "\n")
    end

    -- ---------- ขาย ----------
    local running, gen = false, 0
    local status, info = "พร้อมแล้ว (โหมดทดลอง ไม่ขายจริง)", "ยังไม่ได้สแกน"
    local sold, soldTotal, attempts = {}, 0, {}
    local uiStatus, uiInfo, uiButton, uiDry, uiGui
    local uiTier = {}

    local function selectedNames()
        local t = {}
        for _, r in ipairs(RARITIES) do if CFG.Tiers[r] then t[#t + 1] = r end end
        return t
    end

    local function refreshUi()
        pcall(function()
            if uiStatus then uiStatus.Text = status end
            if uiInfo then uiInfo.Text = info end
            if uiButton then
                uiButton.Text = running and "หยุด" or "เริ่ม"
                uiButton.BackgroundColor3 = running and Color3.fromRGB(170, 70, 70) or Color3.fromRGB(46, 125, 90)
            end
            if uiDry then
                uiDry.Text = CFG.DryRun and "โหมดทดลอง: เปิด (ไม่ขายจริง)" or "โหมดทดลอง: ปิด (ขายจริง!)"
                uiDry.BackgroundColor3 = CFG.DryRun and Color3.fromRGB(70, 72, 84) or Color3.fromRGB(190, 120, 40)
            end
            for r, b in pairs(uiTier) do
                b.BackgroundColor3 = CFG.Tiers[r] and Color3.fromRGB(46, 125, 90) or Color3.fromRGB(70, 72, 84)
            end
        end)
    end
    local function setStatus(s) status = s refreshUi() end

    local function sleep(sec, myGen)
        local t = os.clock()
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    local function getSellRemote()
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteEvent", "SellPart" })
    end

    -- ตัดสินใจว่าชิ้นไหนจะขาย (ใช้ร่วมกันทั้งโหมดทดลองและโหมดจริง)
    local function pickSellable(list)
        local picks = {}
        for _, e in ipairs(list) do
            if e.rarity and CFG.Tiers[e.rarity] and not e.equipped and not e.locked
                and not sold[e.guid] and (attempts[e.guid] or 0) <= CFG.Retries then
                picks[#picks + 1] = e
            end
        end
        return picks
    end

    local lastCounts = { counts = {}, total = 0, protected = 0, unknown = 0, scanned = false }
    local function scanOnce()
        local list = scanInventory()
        info = summarize(list)
        local c = { counts = {}, total = #list, protected = 0, unknown = 0, scanned = true }
        for _, e in ipairs(list) do
            if e.equipped or e.locked then c.protected = c.protected + 1
            elseif e.rarity then c.counts[e.rarity] = (c.counts[e.rarity] or 0) + 1
            else c.unknown = c.unknown + 1 end
        end
        lastCounts = c
        refreshUi()
        return list
    end

    local function sellPass(myGen)
        if equipBusy() then
            setStatus("รอโมดูล Equip สลับป้อมให้เสร็จก่อน")
            note("equipbusy", "โมดูล Equip กำลังสลับป้อม", "รอให้เสร็จก่อน แล้วค่อยสแกน/ขาย (กันขายป้อมที่ถูกถอดชั่วคราว)")
            return 0
        end
        noteReset("equipbusy")
        local list = scanOnce()
        if #list == 0 then
            setStatus("ไม่พบรายการในคลัง (รายการยังไม่โหลด?)")
            note("empty", "สแกนคลังแล้วไม่พบรายการ (รายการยังไม่โหลด?)", "สแกนใหม่ใน " .. tostring(CFG.ScanEvery) .. " วิ")
            return 0
        end
        noteReset("empty")
        local picks = pickSellable(list)
        local names = selectedNames()
        if #names == 0 then
            setStatus("ยังไม่ได้เลือกระดับที่จะขาย")
            note("notier", "ยังไม่ได้เลือกระดับที่จะขาย", "เลือกระดับในแดชบอร์ด แล้วจะสแกนใหม่ทุก " .. tostring(CFG.ScanEvery) .. " วิ")
            return 0
        end
        if #picks == 0 then
            setStatus("ไม่มีชิ้นที่ต้องขายในระดับ: " .. table.concat(names, ", "))
            note("nopick", string.format("สแกนพบ %d ชิ้น แต่ไม่มีชิ้นที่ต้องขาย (ระดับที่ขาย: %s)", #list, table.concat(names, ", ")),
                "สแกนใหม่ทุก " .. tostring(CFG.ScanEvery) .. " วิ ถ้ามีของใหม่ในระดับที่เลือกจะขายทันที")
            return 0
        end
        noteReset("nopick")
        if #picks > CFG.MaxPerScan then
            local cut = {}
            for i = 1, CFG.MaxPerScan do cut[i] = picks[i] end
            picks = cut
        end

        if CFG.DryRun then
            local per = {}
            for _, e in ipairs(picks) do per[e.rarity] = (per[e.rarity] or 0) + 1 end
            local parts = {}
            for _, r in ipairs(RARITIES) do if per[r] then parts[#parts + 1] = r .. " x" .. per[r] end end
            local msg = string.format("[ทดลอง] จะขาย %d ชิ้น: %s", #picks, table.concat(parts, ", "))
            setStatus(msg)
            print("[LobbySell] " .. msg .. " (ยังไม่ได้ขายจริง ปิดโหมดทดลองเพื่อขาย)")
            return 0
        end

        do
            local per = {}
            for _, e in ipairs(picks) do per[e.rarity] = (per[e.rarity] or 0) + 1 end
            local parts = {}
            for _, r in ipairs(RARITIES) do if per[r] then parts[#parts + 1] = r .. " x" .. per[r] end end
            print(string.format("[LobbySell] ▶ พบของที่ต้องขาย %d ชิ้น (%s)  |  ⏭ ถัดไป: ขายทีละ %d ชิ้น ห่างกัน %s วิ แล้วสแกนใหม่", #picks, table.concat(parts, ", "), CFG.Batch, tostring(CFG.SellGap)))
        end
        local remote = getSellRemote()
        if not remote then
            warn("[LobbySell] ไม่พบ Remote SellPart (ต้องอยู่ในล็อบบี้)")
            setStatus("ไม่พบ Remote SellPart")
            return 0
        end
        local n = 0
        local i = 1
        while i <= #picks do
            if not (running and gen == myGen) then break end
            if CFG.DryRun then break end   -- ผู้ใช้เปิดโหมดทดลองกลางทาง = หยุดขายทันที
            if equipBusy() then break end  -- Equip เริ่มสลับป้อมกลางทาง = หยุดขายทันที
            local batch = {}
            for j = i, math.min(i + CFG.Batch - 1, #picks) do
                local e = picks[j]
                -- เช็คซ้ำก่อนขายทุกชิ้น: ยังเป็นระดับที่เลือก ไม่ถูกใส่/ล็อก
                local rarity, equipped, locked = describeEntry(e.inst)
                if rarity and CFG.Tiers[rarity] and not equipped and not locked and not equippedIds()[e.guid] and not isKept(entryName(e.inst)) then
                    batch[#batch + 1] = e
                end
            end
            if #batch > 0 then
                local guids = {}
                for k, e in ipairs(batch) do guids[k] = e.guid end
                setStatus(string.format("ขาย %s x%d …", batch[1].rarity, #batch))
                local ok, err = pcall(function() remote:FireServer(guids) end)
                if not ok then warn("[LobbySell] ยิง SellPart ไม่สำเร็จ: " .. tostring(err)) end
                for _, e in ipairs(batch) do
                    attempts[e.guid] = (attempts[e.guid] or 0) + 1
                    sold[e.guid] = true
                    n = n + 1
                end
                soldTotal = soldTotal + #batch
                if not sleep(CFG.SellGap, myGen) then break end
            end
            i = i + CFG.Batch
        end
        -- ชิ้นที่ขายแล้วแต่ยังอยู่ใน UI รอบหน้า = ลองใหม่ได้ (ไม่เกิน Retries) ; ชิ้นที่หายไปแล้วลบออกจากรายการจำ
        if n > 0 and CFG.Log then
            print(string.format("[LobbySell] ▶ ขายรอบนี้ %d ชิ้น (รวมทั้งหมด %d)  |  ⏭ ถัดไป: สแกนใหม่ใน %s วิ", n, soldTotal, tostring(CFG.ScanEvery)))
        end
        return n
    end

    local function loop(myGen)
        while running and gen == myGen do
            local n = sellPass(myGen)
            if gen ~= myGen or not running then return end
            -- ปลดล็อกชิ้นที่ขายแล้วแต่ยังเจออยู่ในสแกนถัดไป (เซิร์ฟเวอร์ยังไม่ตัดออก)
            local present = {}
            for _, e in ipairs(scanInventory()) do present[e.guid] = true end
            for guid in pairs(sold) do
                if present[guid] then sold[guid] = nil else attempts[guid] = nil end
            end
            info = string.format("%s | ขายแล้วรวม %d", info, soldTotal)
            refreshUi()
            if not sleep(CFG.ScanEvery, myGen) then return end
        end
    end

    local function start()
        if running then return end
        gen = gen + 1
        running = true
        local myGen = gen
        setStatus(CFG.DryRun and "เริ่ม (โหมดทดลอง)" or "เริ่มขายจริง")
        for k in pairs(logKeys) do logKeys[k] = nil end
        do
            local names = selectedNames()
            note("begin", (CFG.DryRun and "เริ่มขาย (โหมดทดลอง ไม่ขายจริง)" or "เริ่มขายจริง") .. " ระดับ: " .. (#names > 0 and table.concat(names, ", ") or "(ยังไม่ได้เลือก)"),
                "สแกนคลังทุก " .. tostring(CFG.ScanEvery) .. " วิ ขายชิ้นระดับที่เลือก (ไม่ขายที่ใส่อยู่/ล็อก/อ่านระดับไม่ได้)")
        end
        task.spawn(function()
            local ok, err = pcall(loop, myGen)
            if not ok then
                warn("[LobbySell] เกิดข้อผิดพลาด: " .. tostring(err))
                if gen == myGen then running = false setStatus("ผิดพลาด ดู Console") end
            end
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            setStatus("หยุดแล้ว")
            note("stop", "หยุดขายตามที่สั่ง", "ไม่ขายต่อ")
        end
    end

    local function shutdown()
        stop()
        if uiGui then pcall(function() uiGui:Destroy() end) uiGui = nil end
    end

    local function scanAndCopy()
        local list = scanOnce()
        local text = reportText(list)
        print("[LobbySell] " .. text)
        if setclipboard then pcall(setclipboard, text) end
        setStatus(string.format("สแกนแล้ว พบ %d รายการ (คัดลอกผลแล้ว)", #list))
    end

    local function setTier(name, on)
        if not RARITY_LOWER[name:lower()] then return false end
        CFG.Tiers[RARITY_LOWER[name:lower()]] = on and true or nil
        refreshUi()
        return true
    end

    local function setDryRun(v)
        CFG.DryRun = v and true or false
        refreshUi()
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LobbySellGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            uiGui = gui
            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(290, 244)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            local function button(text, x, y, w, h, color, fn)
                local b = Instance.new("TextButton")
                b.Position = UDim2.fromOffset(x, y)
                b.Size = UDim2.fromOffset(w, h)
                b.BackgroundColor3 = color
                b.BorderSizePixel = 0
                b.Font = Enum.Font.GothamMedium
                b.TextSize = 12
                b.TextColor3 = Color3.new(1, 1, 1)
                b.Text = text
                b.Parent = frame
                local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
                b.MouseButton1Click:Connect(fn)
                return b
            end
            label("Auto ขายป้อม (เลือกระดับ)", 6, 13)
            uiStatus = label(status, 26, 11, Color3.fromRGB(150, 220, 170))
            uiInfo = label(info, 44, 10, Color3.fromRGB(160, 165, 180))
            -- ปุ่มเลือกระดับ 7 ปุ่ม (4 + 3)
            for i, r in ipairs(RARITIES) do
                local row = (i <= 4) and 0 or 1
                local col = (i <= 4) and (i - 1) or (i - 5)
                local w = (i <= 4) and 64 or 86
                local x = 10 + col * ((i <= 4) and 69 or 91)
                uiTier[r] = button(r, x, 68 + row * 32, w, 28, Color3.fromRGB(70, 72, 84), function()
                    setTier(r, not CFG.Tiers[r])
                end)
            end
            uiDry = button("", 10, 136, 270, 28, Color3.fromRGB(70, 72, 84), function() setDryRun(not CFG.DryRun) end)
            button("สแกน (คัดลอกผล)", 10, 170, 130, 30, Color3.fromRGB(70, 72, 84), scanAndCopy)
            uiButton = button("เริ่ม", 150, 170, 130, 30, Color3.fromRGB(46, 125, 90), function()
                if running then stop() else start() end
            end)
            label("ไม่ขายป้อมที่ใส่อยู่ / ล็อก / อ่านระดับไม่ได้", 208, 10, Color3.fromRGB(160, 165, 180))
            refreshUi()
        end)
        if not okUi then warn("[LobbySell] สร้างหน้าต่างไม่สำเร็จ ใช้ LobbySell.Start() / Stop() แทน") end
    end

    G.LobbySell = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        Scan = scanAndCopy,
        SetTier = setTier,
        SetDryRun = setDryRun,
        IsRunning = function() return running end,
        Counts = function()
            local c = lastCounts
            return { counts = c.counts, total = c.total, protected = c.protected, unknown = c.unknown, scanned = c.scanned, sold = soldTotal }
        end,
        Status = function() return status .. " | " .. info end,
        Config = CFG,
    }

    print("[LobbySell] พร้อมแล้ว (โหมดทดลอง) เลือกระดับ > สแกน > ปิดโหมดทดลอง > เริ่ม")
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: Quest (lobby_auto_quest.lua) =========================
local function Module_Quest()
    -- Lobby Auto Quest  |  เคลมรางวัลเควสอัตโนมัติ (Place 132929771812494)
    -- Remote ที่ใช้ (ตามล็อกที่คุณส่งมา):
    --   ReplicatedStorage.ModuleLoader.Shared.Network.RemoteFunction.CollectQuest:InvokeServer("Beat100Waves", "Daily")  ==> true
    --   (เคลมซ้ำ/ยังไม่พร้อม ==> false, "Cooldown")
    -- เควสที่รู้จักจากล็อก: Beat100Waves / Place25 / WinGames3 (หมวด "Daily")
    -- ถ้ามีเควสอื่น (เช่น Weekly) ให้ใส่เพิ่มเอง:  getgenv().QuestConfig = { Quests = { {"Beat100Waves","Daily"}, {"ชื่อเควส","Weekly"} } }
    -- ใช้งาน: รันสคริปต์ > กด "เริ่ม" (หรือ LobbyQuest.Start())

    local CFG = {
        Quests          = { { "Beat100Waves", "Daily" }, { "Place25", "Daily" }, { "WinGames3", "Daily" } },
        FirstDelay      = 3,      -- หลังรันสคริปต์ รอกี่วินาทีก่อนเคลมครั้งแรก
        ClaimGap        = 1.0,    -- เว้นกี่วินาทีระหว่างการเคลมแต่ละเควส (ในล็อกคุณห่างราว 1 วิ)
        RecheckClaimed  = 1800,   -- เคลมสำเร็จแล้ว ตรวจใหม่อีกทีกี่วินาที (เผื่อเควสรีเซ็ต)
        RecheckCooldown = 600,    -- เกมตอบ Cooldown ลองใหม่กี่วินาที
        RecheckFail     = 120,    -- เกมตอบ false อย่างอื่น / error ลองใหม่กี่วินาที
        Log             = true,   -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร
        PanelX = -306, PanelY = 120,
        ShowUi          = true,
        AutoStart       = false,
    }

    local G = (getgenv and getgenv()) or _G
    if type(G.QuestConfig) == "table" then
        for k, v in pairs(G.QuestConfig) do
            if CFG[k] ~= nil then CFG[k] = v end
        end
    end
    if G.LobbyQuest and type(G.LobbyQuest.Shutdown) == "function" then
        pcall(G.LobbyQuest.Shutdown)
    end

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    CFG.FirstDelay = math.max(0, tonumber(CFG.FirstDelay) or 0)
    CFG.ClaimGap = math.max(0.5, tonumber(CFG.ClaimGap) or 1)
    CFG.RecheckClaimed = math.max(30, tonumber(CFG.RecheckClaimed) or 1800)
    CFG.RecheckCooldown = math.max(30, tonumber(CFG.RecheckCooldown) or 600)
    CFG.RecheckFail = math.max(30, tonumber(CFG.RecheckFail) or 120)

    local loadedAt = os.clock()

    -- รายการเควส: รับ "ชื่อ" หรือ {"ชื่อ","หมวด"} (หมวดไม่ใส่ = Daily)
    local quests = {}
    do
        local src = type(CFG.Quests) == "table" and CFG.Quests or {}
        for _, q in ipairs(src) do
            local id, cat
            if type(q) == "string" then id, cat = q, "Daily"
            elseif type(q) == "table" then id, cat = q[1] or q.Id or q.id, q[2] or q.Category or q.category or "Daily" end
            if type(id) == "string" and id ~= "" then
                quests[#quests + 1] = { id = id, cat = tostring(cat), state = "ยังไม่ได้เคลม", kind = "pending", nextAt = 0, tries = 0 }
            end
        end
    end

    -- log แบบ "กำลังทำ / ถัดไป" : ข้อความเดิมซ้ำติดกันจะไม่พิมพ์ซ้ำ
    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[LobbyQuest] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[LobbyQuest] ▶ " .. doing)
        end
    end

    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end
    local function getRemote()
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteFunction", "CollectQuest" })
    end

    local function describe(v, depth)
        depth = depth or 0
        if type(v) ~= "table" then return tostring(v) end
        if depth >= 2 then return "{...}" end
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then parts[#parts + 1] = "..." break end
            parts[#parts + 1] = tostring(k) .. "=" .. describe(x, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end

    local running, gen = false, 0
    local firstDone = false   -- รอบแรก (ลองเคลมครบทุกเควสหนึ่งครั้ง) เสร็จหรือยัง
    local status, info = "พร้อมแล้ว กดปุ่ม 'เริ่ม'", ""
    local uiStatus, uiInfo, uiButton, uiGui

    local function counts()
        local c = { claimed = 0, cooldown = 0, pending = 0, total = #quests }
        for _, q in ipairs(quests) do
            if q.kind == "claimed" then c.claimed = c.claimed + 1
            elseif q.kind == "cooldown" then c.cooldown = c.cooldown + 1
            else c.pending = c.pending + 1 end
        end
        return c
    end
    local function summary()
        local c = counts()
        return string.format("เคลมสำเร็จ %d/%d | Cooldown %d | ยังไม่ได้ %d", c.claimed, c.total, c.cooldown, c.pending)
    end

    local function refreshUi()
        pcall(function()
            if uiStatus then uiStatus.Text = status end
            if uiInfo then uiInfo.Text = info end
            if uiButton then
                uiButton.Text = running and "หยุด" or "เริ่ม"
                uiButton.BackgroundColor3 = running and Color3.fromRGB(170, 70, 70) or Color3.fromRGB(46, 125, 90)
            end
        end)
    end
    local function setStatus(s) status = s refreshUi() end

    local function sleep(sec, myGen)
        local t = os.clock()
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    local function claimOne(q, remote, myGen)
        q.tries = q.tries + 1
        setStatus(string.format("เคลม %s (%s) ครั้งที่ %d", q.id, q.cat, q.tries))
        note("go" .. q.id, string.format("เคลมรางวัลเควส %s (%s)", q.id, q.cat), "ดูผลที่เกมตอบกลับ แล้วตั้งเวลาตรวจใหม่")
        local ok, a, b = pcall(function() return remote:InvokeServer(q.id, q.cat) end)
        if not (running and gen == myGen) then return end
        local now = os.clock()
        if not ok then
            q.kind, q.state = "pending", "ผิดพลาด: " .. tostring(a)
            q.nextAt = now + CFG.RecheckFail
            warn("[LobbyQuest] เคลม " .. q.id .. " ผิดพลาด: " .. tostring(a))
        elseif a == true then
            q.kind, q.state = "claimed", "เคลมสำเร็จ"
            q.nextAt = now + CFG.RecheckClaimed
            note("res" .. q.id, "เคลมสำเร็จ: " .. q.id .. " (" .. q.cat .. ")", string.format("ตรวจอีกครั้งใน %d วิ (เผื่อเควสรีเซ็ต)", CFG.RecheckClaimed))
        elseif a == false then
            local msg = tostring(b)
            if msg == "Cooldown" then
                q.kind, q.state = "cooldown", "Cooldown (เคลมแล้ว/ยังไม่พร้อม)"
                q.nextAt = now + CFG.RecheckCooldown
                note("res" .. q.id, q.id .. ": เกมตอบ Cooldown (เคลมไปแล้วหรือยังไม่พร้อมให้เคลม)", string.format("ลองใหม่ใน %d วิ", CFG.RecheckCooldown))
            else
                q.kind, q.state = "pending", "ยังเคลมไม่ได้: " .. msg
                q.nextAt = now + CFG.RecheckFail
                note("res" .. q.id, q.id .. ": เกมตอบ false (" .. msg .. ")", string.format("ลองใหม่ใน %d วิ", CFG.RecheckFail))
            end
        else
            q.kind, q.state = "pending", "ตอบกลับไม่คาดคิด: " .. describe(a)
            q.nextAt = now + CFG.RecheckFail
            note("res" .. q.id, q.id .. ": เกมตอบค่าที่ไม่คาดคิด " .. describe(a), string.format("ลองใหม่ใน %d วิ", CFG.RecheckFail))
        end
        info = summary()
        refreshUi()
    end

    local function loop(myGen)
        local wait0 = CFG.FirstDelay - (os.clock() - loadedAt)
        if wait0 > 0 then
            setStatus(string.format("รอ %d วิ ก่อนเคลมรางวัลเควสครั้งแรก", math.ceil(wait0)))
            note("delay", string.format("รอ %d วิ ก่อนเคลมรางวัลเควส", math.ceil(wait0)), "เคลมทุกเควสในรายการทีละอัน ห่างกัน " .. CFG.ClaimGap .. " วิ")
            if not sleep(wait0, myGen) then return end
        end
        if #quests == 0 then
            firstDone = true
            setStatus("ไม่มีเควสในรายการ (QuestConfig.Quests)")
            note("empty", "ไม่มีเควสในรายการ (QuestConfig.Quests ว่าง)", "ไม่ทำอะไร")
            return
        end
        while running and gen == myGen do
            local remote = getRemote()
            if not remote then
                firstDone = true
                setStatus("ไม่พบ Remote CollectQuest (ต้องอยู่ในล็อบบี้)")
                note("noremote", "ไม่พบ Remote CollectQuest", "ลองหาใหม่ทุก 10 วิ")
                if not sleep(10, myGen) then return end
            else
                local did = false
                for _, q in ipairs(quests) do
                    if not (running and gen == myGen) then return end
                    if os.clock() >= q.nextAt then
                        if did and not sleep(CFG.ClaimGap, myGen) then return end
                        did = true
                        claimOne(q, remote, myGen)
                    end
                end
                if not firstDone then
                    firstDone = true
                    note("pass1", "รอบแรกเสร็จ: " .. summary(), "ตรวจเควสที่ยังไม่ได้เคลมใหม่ตามเวลาที่ตั้ง (Cooldown " .. CFG.RecheckCooldown .. " วิ)")
                end
                local c = counts()
                setStatus(summary())
                info = c.pending > 0 and "มีเควสที่ยังเคลมไม่ได้ จะลองใหม่เป็นระยะ" or "เควสทั้งหมดเคลมแล้ว/Cooldown"
                refreshUi()
                if not sleep(5, myGen) then return end
            end
        end
    end

    local function start()
        if running then return end
        gen = gen + 1
        running = true
        local myGen = gen
        setStatus("เริ่มทำงาน")
        for k in pairs(logKeys) do logKeys[k] = nil end
        task.spawn(function()
            local ok, err = pcall(loop, myGen)
            if not ok then
                warn("[LobbyQuest] เกิดข้อผิดพลาด: " .. tostring(err))
                if gen == myGen then running = false setStatus("ผิดพลาด ดู Console") end
            end
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            setStatus("หยุดแล้ว")
            note("stop", "หยุดเคลมรางวัลเควสตามที่สั่ง", "ไม่ทำอะไรต่อ")
        end
    end

    local function shutdown()
        stop()
        if uiGui then pcall(function() uiGui:Destroy() end) uiGui = nil end
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            local gui = Instance.new("ScreenGui")
            gui.Name = "LobbyQuestGui"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
            uiGui = gui
            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(290, 118)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            label("Auto เคลมรางวัลเควส (ล็อบบี้)", 6, 13)
            uiStatus = label(status, 28, 12, Color3.fromRGB(150, 220, 170))
            uiInfo = label(info, 48, 11, Color3.fromRGB(160, 165, 180))
            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(10, 76)
            b.Size = UDim2.new(1, -20, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(46, 125, 90)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = "เริ่ม"
            b.Parent = frame
            local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
            uiButton = b
            b.MouseButton1Click:Connect(function()
                if running then stop() else start() end
            end)
        end)
        if not okUi then warn("[LobbyQuest] สร้างหน้าต่างไม่สำเร็จ ใช้ LobbyQuest.Start() / Stop() แทน") end
    end

    G.LobbyQuest = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        IsRunning = function() return running end,
        -- กำลังเคลมรอบแรกอยู่ (ตัวรวมจะรอให้เสร็จก่อนเข้าลิฟต์) ; มีเพดาน FirstDelay + 30 วิ กันค้าง
        IsBusy = function() return running and not firstDone and (os.clock() - loadedAt) < (CFG.FirstDelay + 30) end,
        Claims = function()
            local c = counts()
            local items = {}
            for _, q in ipairs(quests) do items[#items + 1] = { id = q.id, cat = q.cat, kind = q.kind, state = q.state, tries = q.tries } end
            c.items = items
            return c
        end,
        Status = function() return status .. " | " .. info end,
        Config = CFG,
    }

    print("[LobbyQuest] พร้อมแล้ว กดปุ่ม 'เริ่ม' (หรือ LobbyQuest.Start()) | เควส: " .. #quests .. " รายการ")
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: TD (td_auto_place.lua) =========================
local function Module_TD()
    -- ==============================================================================
    -- Auto Place + Upgrade (Speakerman)
    -- วางป้อมเรียงชิดกัน (สูงสุด 15 ตัว)
    -- กฎเหล็ก: ห้ามสั่งวางป้อมตัวใหม่ถ้ามีป้อมของเราตัวใดยังไม่ตัน (เช็คทุกครั้งก่อนยิงคำสั่งวาง)
    -- มีเงินพอเมื่อไหร่อัปเกรดทันที: ยิงสั่งอัปซ้ำเป็นจังหวะถี่ๆ (~0.5 วิ) จนเลเวลขึ้น
    --
    -- ข้อมูลที่ใช้ (มาจากล็อกและไฟล์ dump ที่ส่งมา):
    --   วาง   : Network.RemoteEvent.TowerAdd:FireServer({Pos, CFrame, Name, UnitId})
    --   อัป   : Network.RemoteEvent.TowerUpgrade:FireServer({Id = ชื่อโมเดลป้อมใน Workspace.Game.Towers})
    --   เลเวล : อ่านจากป้าย TroopStatus.TroopLevel  ("💪 Level 3 💪")  อัป 1 ครั้ง = +1 เลเวล  ตัน = Level 3
    --
    -- เสริมอัตโนมัติ (เปิด/ปิดได้จากปุ่มในหน้าต่าง ทำงานแยกจากปุ่มเริ่มวางป้อม):
    --   Auto Skip  : เมื่อ Workspace attribute CanSkip = true  -> WaveSkip:FireServer()
    --   Auto Vote  : เมื่อ IsVoting = true และยังไม่ได้โหวต    -> ModeVote:FireServer("Easy")
    --   Auto Speed : ถ้า GameSpeed ไม่ตรงค่าที่ตั้ง             -> ChangeSpeed:InvokeServer(1.5)
    --
    -- ไม่ได้ดัก/แก้อะไรในเกม แค่ยิง Remote เหมือนที่เกมยิงเอง ช้าๆ ทีละคำสั่ง
    -- ปรับค่าได้สองแบบ: แก้ตัวเลขด้านล่าง หรือกำหนดก่อนรันด้วย
    --   getgenv().TdAutoConfig = { MaxTowers = 6, AutoStart = true }
    -- ==============================================================================

    local CFG = {
        EquipSlot = 1,        -- ช่องป้อมที่ใส่ไว้ในเกม (1-5) สคริปต์จะอ่านชื่อ/UnitId/ราคาจากช่องนี้เอง
        TowerName = "Speakerman",   -- ใช้แทนเฉพาะตอนอ่านจากช่องไม่ได้
        UnitId    = "66818e1f-da23-4d9e-8a3d-bad60643a3ab",
        MaxLevel  = 3,        -- เลเวลตัน (อัป 2 ครั้งจาก Level 1)
        MaxTowers = 15,       -- จำนวนป้อมสูงสุดที่มีพร้อมกัน (ล็อกเพดานไว้ที่ 15 ไม่ว่าตั้งเท่าไหร่)

        -- ช่องวาง: ตารางรอบจุดกลางที่ล็อกพิสูจน์แล้วว่าวางได้ (x -33..-26, z -6..4)
        -- วางไล่จากช่องใกล้จุดกลางออกไปก่อน ช่องไหนวางไม่ได้จะถูกข้าม (มีช่องสำรองเกิน 15)
        CenterX = -29.5, CenterZ = -1.0, Y = -47.41,
        Cols = 5, Rows = 7,
        SpacingX = 3.0, SpacingZ = 3.0,
        AdoptExisting = true, -- ป้อม Speakerman ที่มีอยู่แล้วในพื้นที่ตาราง นับเป็นของเรา ต้องอัปให้ตันก่อนวางตัวใหม่

        MinGap       = 0.3,   -- เว้นระหว่างการยิงแต่ละคำสั่ง (วินาที)
        PlaceWait    = 2.5,   -- รอให้ป้อมใหม่โผล่หลังสั่งวาง
        LateGrace    = 4.0,   -- ถ้ายังไม่โผล่ รอเพิ่มอีกเท่านี้ก่อนสั่งวางซ้ำ/ไปช่องอื่น (กันป้อมโผล่ช้าแล้วไม่ได้อัป)
        PlaceTries   = 3,     -- ลองวางช่องเดิมกี่ครั้งก่อนข้ามไปช่องถัดไป
        SkipLimit    = 3,     -- ข้ามติดกันกี่ช่องแล้วพักรอ (เงินไม่พอ/วางไม่ได้)
        RestSeconds  = 10,    -- พักรอแล้วกลับมาลองช่องที่ค้าง
        UpgradeWait  = 1.5,   -- รอเลเวลขึ้นหลังสั่งอัป (เลเวลขึ้นแล้วสั่งตัวต่อไปทันที)
        UpgradeRetry = 0.5,  -- ถ้าเลเวลไม่ขึ้น (เงินไม่พอ) รอเท่านี้แล้วสั่งอัปใหม่
        OccupiedDist = 2.0,   -- มีป้อมอยู่ใกล้ช่องกว่านี้ = ช่องไม่ว่าง
        MatchDist    = 2.0,   -- ป้อมใหม่ต้องอยู่ใกล้จุดที่สั่งวางไม่เกินเท่านี้

        -- เสริมอัตโนมัติ
        AutoSkip = true,
        AutoVote = true,  VoteMode = "Easy",   -- โหมดที่เห็นในล็อกคือ "Easy" (ในเกมมี Easy/Normal/Hard/Insane)
        AutoSpeed = true, SpeedValue = 1.5,    -- ค่าที่เห็นในล็อกคือ 1.5
        SkipGap = 1.0,         -- เว้นกี่วินาทีระหว่างสั่งข้ามแต่ละครั้ง
        VoteGap = 2.0, VoteMaxTries = 5,
        SpeedGap = 2.0, SpeedMaxTries = 3,   -- ลองติดกันเกินนี้จะรอ SpeedSlowGap แล้วลองใหม่ (ไม่เลิกถาวร)
        SpeedSlowGap = 6.0,
        PlaceCost = 100, UpgradeCosts = { 150, 300 },  -- ราคาวาง / ราคาอัป (เลเวล1→2, 2→3) ใช้เช็คเงินก่อนยิง
        CheckMoney = true,
        Debug = true,          -- พิมพ์ขั้นตอนวางป้อมใน Console (ช่วยหาสาเหตุเวลาไม่วาง)
        LearnCost = true,      -- เรียนรู้ราคาอัปจริงจากเงินที่ลดลงตอนอัปสำเร็จ (ค่า UpgradeCosts ใช้เป็นค่าเริ่มต้น)
        MoneyWaitMax = 8,      -- รอเงินนานเกินนี้ (วินาที) แล้วยังอ่านว่าไม่พอ = เชื่อว่าอ่านผิด ลองยิงเลย
        AutoReplay = true, ReplayDelay = 10, ReplayGap = 6.0, ReplayMaxTries = 0,   -- หน้าจอสรุปผล (GameUI.FinalUI) ขึ้น -> รอ ReplayDelay วิ แล้วกด PlayAgain ทุก ReplayGap วิ (MaxTries 0 = ไม่จำกัด จนกว่าหน้าสรุปผลจะหาย)
        LeaveAfterRounds = 10,  -- เล่นครบกี่รอบแล้วกด OnLeave กลับล็อบบี้ (0 = ไม่ออก เล่นวนไปเรื่อย ๆ) ; นับตอนหน้าจอสรุปผลขึ้นแต่ละครั้ง
        ExpectUnit = "Speakerman",   -- ป้อมที่คาดว่าอยู่ใน EquipSlot (ถ้าไม่ตรง จะเตือนใน Console แต่ยังวางตามป้อมที่อยู่ในช่องนั้น)
        Log = true,            -- พิมพ์ Console: กำลังทำอะไร / ถัดไปจะทำอะไร / เมื่อเข้าเงื่อนไขอะไร

        PanelX = -306, PanelY = 80,   -- ตำแหน่งแผง (ระยะจากขวา / จากบน)
        ShowUi    = true,
        AutoStart = false,
    }
    do
        local user = (getgenv and getgenv() or _G).TdAutoConfig
        if type(user) == "table" then
            for k, v in pairs(user) do
                if CFG[k] ~= nil and type(v) == type(CFG[k]) then CFG[k] = v end
            end
        end
    end

    CFG.MaxTowers = math.max(1, math.min(CFG.MaxTowers, 15))   -- เพดานแข็ง 15 ตัว

    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local G = (getgenv and getgenv()) or _G

    -- รันซ้ำได้: ตัวเก่าหยุดและลบ UI ของตัวเอง
    if G.TdAuto and type(G.TdAuto.Shutdown) == "function" then pcall(G.TdAuto.Shutdown) end

    local function say(msg) print("[TdAuto] " .. msg) end

    -- ---------- สถานะที่ต้องจำข้ามการวาประหว่างแมพ (จำนวนรอบ / ขั้นตอน) ----------
    -- เก็บใน getgenv (ถ้า executor เก็บข้ามแมพ) และไฟล์ (ถ้ามี readfile/writefile) ; ข้อมูลเก่าเกิน STALE วินาทีถือว่าหมดอายุ
    local function makeStateStore(Gt, fileName)
        local STALE = 3600
        local function fresh() return { rounds = 0, phase = "", ts = 0 } end
        local function loadData()
            local d = Gt.LuckyHubData
            if type(d) ~= "table" and type(isfile) == "function" and type(readfile) == "function" then
                local ok, txt = pcall(function() if isfile(fileName) then return readfile(fileName) end end)
                if ok and type(txt) == "string" then
                    local r, p, t = txt:match("^(%-?%d+),([%w_]*),(%d+)$")
                    if r then d = { rounds = tonumber(r), phase = p, ts = tonumber(t) } end
                end
            end
            if type(d) ~= "table" then d = fresh() end
            if os.time() - (d.ts or 0) > STALE then d = fresh() end
            Gt.LuckyHubData = d
            return d
        end
        local store = {}
        function store.get(k) return loadData()[k] end
        function store.set(k, v)
            local d = loadData()
            d[k] = v
            d.ts = os.time()
            Gt.LuckyHubData = d
            if type(writefile) == "function" then
                pcall(writefile, fileName, string.format("%d,%s,%d", d.rounds or 0, tostring(d.phase or ""), d.ts))
            end
        end
        return store
    end
    local State = makeStateStore(G, "LuckyHub_state.txt")

    -- log แบบ "กำลังทำ / ถัดไป" : key เดิมซ้ำจะไม่พิมพ์ซ้ำ (กันรกเวลาวนลูป)
    local logKeys = {}
    local function note(key, doing, nxt)
        if not CFG.Log then return end
        if logKeys[key] == doing then return end
        logKeys[key] = doing
        if nxt and nxt ~= "" then
            print("[TdAuto] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
        else
            print("[TdAuto] ▶ " .. doing)
        end
    end
    local function noteReset(key) logKeys[key] = nil end

    -- ---------- หา Remote (ตามเส้นทางในล็อก) ----------
    local function findPath(root, names)
        local cur = root
        for _, n in ipairs(names) do
            if not cur then return nil end
            cur = cur:FindFirstChild(n)
        end
        return cur
    end
    local function getRemote(name)
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", "RemoteEvent", name })
    end

    -- ---------- สถานะ ----------
    local gen = 0            -- เปลี่ยนค่า = ลูปเก่าหยุด
    local running = false
    local status = "ยังไม่เริ่ม"
    local progress = "-"
    local lastFire = 0
    local uiStatus, uiProgress, uiButton = nil, nil, nil

    local function refreshUi()
        if uiStatus then pcall(function() uiStatus.Text = status end) end
        if uiProgress then pcall(function() uiProgress.Text = progress end) end
        if uiButton then pcall(function() uiButton.Text = running and "หยุด" or "เริ่ม" end) end
    end
    local function setStatus(s) status = s refreshUi() end

    -- ---------- ช่วยอ่านป้อม ----------
    local function towersFolder()
        local game_ = workspace:FindFirstChild("Game")
        return game_ and game_:FindFirstChild("Towers") or nil
    end

    local function towerPos(m)
        local ok, p = pcall(function() return m:GetPivot().Position end)
        if ok and p then return p end
        return nil
    end

    local function towerLevel(m)
        local label = m:FindFirstChild("TroopLevel", true)
        if not label then return nil end
        local ok, text = pcall(function() return label.Text end)
        if not ok or type(text) ~= "string" then return nil end
        local n = text:match("[Ll]evel%s*(%d+)")
        return n and tonumber(n) or nil
    end

    local function dist2d(p, x, z)
        local dx, dz = p.X - x, p.Z - z
        return math.sqrt(dx * dx + dz * dz)
    end

    local function slotOccupied(slot)
        local f = towersFolder()
        if not f then return false end
        for _, m in ipairs(f:GetChildren()) do
            local p = towerPos(m)
            if p and dist2d(p, slot.x, slot.z) < CFG.OccupiedDist then return true end
        end
        return false
    end

    -- ---------- ป้อมของเรา (วางเอง หรือรับช่วงที่มีอยู่แล้วในพื้นที่ตาราง) ----------
    local mine = {}     -- รายการ Id (ชื่อโมเดล) ของป้อมที่เรารับผิดชอบ
    local seen = {}     -- ชื่อโมเดลที่รู้จักแล้ว (ที่โผล่มาใหม่และไม่อยู่ในนี้ = ป้อมใหม่)

    local function towerNameText(m)
        local label = m:FindFirstChild("TroopName", true)
        if not label then return nil end
        local ok, text = pcall(function() return label.Text end)
        if ok and type(text) == "string" then return text end
        return nil
    end

    local function nearAnySlot(p, slots)
        for _, sl in ipairs(slots) do
            if dist2d(p, sl.x, sl.z) <= CFG.MatchDist then return true end
        end
        return false
    end

    local function insideGrid(p, slots)
        local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
        for _, sl in ipairs(slots) do
            minX = math.min(minX, sl.x) maxX = math.max(maxX, sl.x)
            minZ = math.min(minZ, sl.z) maxZ = math.max(maxZ, sl.z)
        end
        local m = CFG.MatchDist
        return p.X >= minX - m and p.X <= maxX + m and p.Z >= minZ - m and p.Z <= maxZ + m
    end

    -- ป้อมใหม่ที่โผล่ใกล้ช่องใดช่องหนึ่ง (รวมถึงตัวที่โผล่ช้ากว่าที่รอ) : รับเป็นของเรา
    local function adoptNew(slots)
        local f = towersFolder()
        if not f then return nil end
        for _, m in ipairs(f:GetChildren()) do
            if not seen[m.Name] then
                local p = towerPos(m)
                local nm = towerNameText(m)
                if p and (nm == nil or nm == CFG.TowerName) and nearAnySlot(p, slots) then
                    seen[m.Name] = true
                    mine[#mine + 1] = m.Name
                    return m.Name
                end
            end
        end
        return nil
    end

    local function pruneMine()
        local f = towersFolder()
        if not f then return end        -- โฟลเดอร์หาไม่เจอชั่วคราว: อย่าตัดรายการทิ้ง
        local keep = {}
        for _, id in ipairs(mine) do
            if f:FindFirstChild(id) then keep[#keep + 1] = id end
        end
        mine = keep
    end

    -- ทุกตัวของเราตันหรือยัง (อ่านเลเวลไม่ได้ = ถือว่ายังไม่ตัน)
    local function allMaxed()
        local f = towersFolder()
        if not f then return false end
        for _, id in ipairs(mine) do
            local m = f:FindFirstChild(id)
            if m then
                local lvl = towerLevel(m)
                if not lvl or lvl < CFG.MaxLevel then return false end
            end
        end
        return true
    end

    local function countMine()
        local f = towersFolder()
        local n = 0
        if f then
            for _, id in ipairs(mine) do
                if f:FindFirstChild(id) then n = n + 1 end
            end
        end
        return n
    end

    -- ---------- ยิง Remote แบบมีจังหวะ ----------
    local function sleep(sec)
        local t = os.clock()
        local myGen = gen
        while os.clock() - t < sec do
            if gen ~= myGen or not running then return false end
            task.wait(math.min(0.1, sec))
        end
        return gen == myGen and running
    end

    -- ---------- อ่านเงิน (leaderstats.Money ; สำรอง: ข้อความ GameUI.Stats.OtherUI.Money.Title) ----------
    local function parseNum(t)
        if type(t) ~= "string" then return nil end
        local d = t:gsub("[,%s%$]", "")
        local num, suf = d:match("^([%d%.]+)([KkMm]?)$")
        num = tonumber(num)
        if not num then return nil end
        suf = suf:lower()
        if suf == "k" then num = num * 1000 elseif suf == "m" then num = num * 1000000 end
        return num
    end

    -- อ่านเงินจากทุกแหล่งที่มี แล้วเอาค่ามากสุด (กันแหล่งใดแหล่งหนึ่งอัปเดตช้า/ค้างที่ 0)
    local function readMoneyRaw()
        local lp = Players.LocalPlayer
        if not lp then return nil end
        local best
        local ls = lp:FindFirstChild("leaderstats")
        local mv = ls and ls:FindFirstChild("Money")
        if mv and type(mv.Value) == "number" then best = mv.Value end
        local node = findPath(lp, { "PlayerGui", "GameUI", "Stats", "OtherUI", "Money", "Title" })
        if node then
            local ok, txt = pcall(function() return node.Text end)
            local g = ok and parseNum(txt) or nil
            if g and (not best or g > best) then best = g end
        end
        return best
    end

    local function readMoney()
        local ok, v = pcall(readMoneyRaw)
        if ok then return v end
        return nil
    end

    local learnedCost = {}   -- ราคาอัปที่เรียนรู้จากเงินที่ลดจริงตอนอัปสำเร็จ (ระดับ lvl → lvl+1)
    local function upgradeCost(lvl)
        if CFG.LearnCost and learnedCost[lvl] then return learnedCost[lvl] end
        local c = CFG.UpgradeCosts
        return c[lvl] or c[#c]
    end

    -- เงินพอหรือยัง (อ่านเงินไม่ได้ = ถือว่าพอ แล้วพึ่งการรอเลเวลขึ้นแทน)
    local moneyBypass = false   -- รอเงินนานเกิน MoneyWaitMax = ไม่เชื่อค่าที่อ่านได้ จนกว่าจะอ่านได้ว่าพอ
    local function canAfford(cost)
        if not CFG.CheckMoney then return true end
        local m = readMoney()
        if m == nil then return true end
        if m >= cost then moneyBypass = false return true end
        return moneyBypass
    end

    -- รอจนเงินพอ (คืน false ถ้าถูกหยุด)
    local warnedMoney = false
    local function waitMoney(cost, label)
        local t0 = os.clock()
        if running and not canAfford(cost) then
            note("money", string.format("%s: เงินไม่พอ (มี %s ต้องใช้ %d) กำลังรอเงิน", label, tostring(readMoney()), cost),
                string.format("เมื่อเงิน >= %d จะสั่งทันที (ถ้ารอเกิน %d วิจะลองยิงเลย)", cost, CFG.MoneyWaitMax))
        end
        while running and not canAfford(cost) do
            if os.clock() - t0 > CFG.MoneyWaitMax then
                if not warnedMoney then
                    warnedMoney = true
                    warn("[TdAuto] รอเงินเกิน " .. CFG.MoneyWaitMax .. " วิ (อ่านได้ " .. tostring(readMoney()) .. " ต้องการ " .. cost .. ") ข้ามการเช็คเงินแล้วลองยิงเลย")
                end
                moneyBypass = true
                return running
            end
            setStatus(string.format("%s: รอเงิน %s/%d", label, tostring(readMoney()), cost))
            task.wait(0.1)
        end
        noteReset("money")
        return running
    end

    -- precheck (ถ้ามี) จะถูกเรียกหลังรอจังหวะเสร็จ ก่อนยิงจริงทันที ถ้าได้ false = ไม่ยิง
    local function fire(remote, payload, precheck)
        local gap = CFG.MinGap - (os.clock() - lastFire)
        if gap > 0 and not sleep(gap) then return false end
        if not running then return false end
        if precheck and not precheck() then return false end
        lastFire = os.clock()
        local ok, err = pcall(function() remote:FireServer(payload) end)
        if not ok then warn("[TdAuto] ยิง Remote ไม่สำเร็จ: " .. tostring(err)) end
        return ok
    end

    -- ---------- วางป้อมที่ช่องหนึ่ง : คืน (Id) ถ้าสำเร็จ  หรือ (nil, "gate") ถ้ายังมีตัวไม่ตัน ----------
    local lastDbg
    local function dbg(msg)
        if CFG.Debug and msg ~= lastDbg then
            lastDbg = msg
            print("[TdAuto] " .. msg)
        end
    end

    local function unmaxedInfo()
        local f = towersFolder()
        local parts = {}
        for i, id in ipairs(mine) do
            local m = f and f:FindFirstChild(id)
            parts[#parts + 1] = string.format("#%d=%s", i, m and tostring(towerLevel(m)) or "หาย")
        end
        return table.concat(parts, " ")
    end

    local function tryPlace(slot, addRemote, slots)
        local pos = Vector3.new(slot.x, CFG.Y, slot.z)
        for attempt = 1, CFG.PlaceTries do
            if not running then return nil end
            local late = adoptNew(slots)
            if late then return late end
            if not allMaxed() then dbg("ยังไม่วาง: มีตัวไม่ตัน เลเวล " .. unmaxedInfo()) return nil, "gate" end
            if not waitMoney(CFG.PlaceCost, string.format("วางช่อง %d", slot.index)) then return nil end
            setStatus(string.format("วางป้อมช่อง %d (ครั้งที่ %d)", slot.index, attempt))
            note("place", string.format("วางป้อม %s ช่อง %d ที่ (%.1f, %.1f) ครั้งที่ %d เงิน %s ป้อมของเรา %d", tostring(CFG.TowerName), slot.index, slot.x, slot.z, attempt, tostring(readMoney()), countMine()),
                string.format("รอป้อมโผล่ไม่เกิน %.1f วิ แล้วอัปเกรดตัวนั้นจนตัน Lv %d", CFG.PlaceWait + CFG.LateGrace, CFG.MaxLevel))
            noteReset("place_wait")
            local fired = fire(addRemote, {
                Pos = pos,
                CFrame = CFrame.new(pos),
                Name = CFG.TowerName,
                UnitId = CFG.UnitId,
            }, function()
                -- เช็คครั้งสุดท้ายก่อนยิง: มีป้อมที่เพิ่งโผล่/ยังไม่ตัน = ห้ามวาง
                adoptNew(slots)
                return allMaxed() and canAfford(CFG.PlaceCost)
            end)
            if not fired then
                if not running then return nil end
                return nil, "gate"
            end
            local t0 = os.clock()
            while os.clock() - t0 < CFG.PlaceWait + CFG.LateGrace do
                if not running then return nil end
                local id = adoptNew(slots)
                if id then return id end
                task.wait(0.1)
            end
            dbg(string.format("ช่อง %d: สั่งวางแล้วไม่เห็นป้อมใหม่ภายใน %.1f วิ (ครั้งที่ %d/%d)", slot.index, CFG.PlaceWait + CFG.LateGrace, attempt, CFG.PlaceTries))
            noteReset("place")
            note("place_fail" .. slot.index .. "_" .. attempt, string.format("ช่อง %d: ไม่เห็นป้อมโผล่ (ครั้งที่ %d/%d)", slot.index, attempt, CFG.PlaceTries),
                attempt < CFG.PlaceTries and "สั่งวางช่องเดิมอีกรอบ" or "ข้ามไปช่องถัดไป")
            -- (คำสั่งวางที่ยังไม่เห็นป้อมจะรอเพิ่มอีก LateGrace วินาที เผื่อป้อมโผล่ช้า
            --  ก่อนจะสั่งวางอีกรอบ จะได้ไม่มีป้อมที่ยังไม่ตัน "หลุด" ไปโดยไม่รู้ตัว)
        end
        return nil
    end

    -- ---------- อัปเกรดป้อมหนึ่งตัวจนตัน (true=ตัน, false=ป้อมหายไป/ถูกหยุด, nil=อ่านเลเวลไม่ได้) ----------
    local function upgradeToMax(id, upRemote, label)
        local fails = 0
        while running do
            local f = towersFolder()
            local m = f and f:FindFirstChild(id)
            if not m then
                setStatus(label .. ": ป้อมหายไประหว่างอัป")
                return false
            end
            local lvl = towerLevel(m)
            if not lvl then
                fails = fails + 1
                setStatus(label .. ": อ่านเลเวลไม่ได้")
                if fails >= 30 then
                    warn("[TdAuto] อ่านเลเวลจากป้ายป้อมไม่ได้ (TroopStatus.TroopLevel) หยุดการทำงาน")
                    return nil
                end
                sleep(0.3)
            elseif lvl >= CFG.MaxLevel then
                note("max" .. id, label .. " ตันแล้ว (Lv " .. lvl .. ")", nil)
                return true
            else
                local cost = upgradeCost(lvl)
                if not waitMoney(cost, string.format("%s: Level %d→%d", label, lvl, lvl + 1)) then return false end
                local cur0 = towerLevel(m)
                if not (cur0 and cur0 > lvl) then
                    setStatus(string.format("%s: อัปเกรด Level %d → %d", label, lvl, lvl + 1))
                    note("up" .. id, string.format("%s: สั่งอัปเกรด Lv %d→%d (ราคา %d, เงิน %s)", label, lvl, lvl + 1, cost, tostring(readMoney())),
                        (lvl + 1 >= CFG.MaxLevel) and "เมื่อขึ้น Lv " .. CFG.MaxLevel .. " = ตัวนี้ตัน -> ไปตัวถัดไป/วางตัวใหม่"
                            or string.format("เมื่อเลเวลขึ้นจะอัปต่อ Lv %d→%d", lvl + 1, lvl + 2))
                    local m0 = readMoney()
                    fire(upRemote, { Id = id }, function() m0 = readMoney() return canAfford(cost) end)
                    local t0 = os.clock()
                    local rose = false
                    while os.clock() - t0 < CFG.UpgradeWait do
                        if not running then return false end
                        local cur = m.Parent and towerLevel(m)
                        if cur and cur > lvl then rose = true break end
                        task.wait(0.05)
                    end
                    if rose then
                        fails = 0
                        local m1 = readMoney()
                        if CFG.LearnCost and m0 and m1 and m0 > m1 then
                            local est = m0 - m1   -- รายได้ที่เข้ามาระหว่างนั้นทำให้ได้ค่าต่ำกว่าจริงเล็กน้อย จึงเก็บค่าสูงสุดที่เคยเห็น
                            if est >= 10 and est <= 1000000 and est > (learnedCost[lvl] or 0) then
                                learnedCost[lvl] = est
                                dbg(string.format("เรียนรู้ราคาอัป Lv %d→%d = %d", lvl, lvl + 1, est))
                            end
                        end
                    else
                        fails = fails + 1
                        if fails == 4 then
                            warn(string.format("[TdAuto] อัปเกรด Level %d→%d ไม่ขึ้นหลายครั้ง (เงิน=%s ราคาที่ตั้ง=%d) ถ้าเงินพอแล้วแต่ไม่ขึ้น ให้แก้ UpgradeCosts",
                                lvl, lvl + 1, tostring(readMoney()), cost))
                        end
                        sleep(CFG.UpgradeRetry)
                    end
                end
            end
        end
        return false
    end

    -- อัปทุกตัวของเราให้ตัน (คืน true เมื่อตันครบ, nil ถ้าหยุดทำงาน/อ่านเลเวลไม่ได้)
    local function finishAll(upRemote, slots)
        while running do
            adoptNew(slots)
            pruneMine()
            if allMaxed() then return true end
            local f = towersFolder()
            local acted = false
            for i, id in ipairs(mine) do
                local m = f and f:FindFirstChild(id)
                local lvl = m and towerLevel(m)
                if m and (not lvl or lvl < CFG.MaxLevel) then
                    acted = true
                    local res = upgradeToMax(id, upRemote, string.format("ตัวที่ %d", i))
                    if res == nil then return nil end
                    break
                end
            end
            if not acted then sleep(0.2) end   -- ไม่มีอะไรให้อัป (เช่นโฟลเดอร์หายชั่วคราว) อย่าวนถี่
        end
        return nil
    end

    -- ---------- ลูปหลัก ----------
    local function buildSlots()
        local slots = {}
        for r = 0, CFG.Rows - 1 do
            for c = 0, CFG.Cols - 1 do
                slots[#slots + 1] = {
                    x = CFG.CenterX + (c - (CFG.Cols - 1) / 2) * CFG.SpacingX,
                    z = CFG.CenterZ + (r - (CFG.Rows - 1) / 2) * CFG.SpacingZ,
                }
            end
        end
        -- เรียงจากใกล้จุดกลางออกไป (วางติดกันเป็นก้อน)
        table.sort(slots, function(a, b)
            local da = dist2d({ X = a.x, Z = a.z }, CFG.CenterX, CFG.CenterZ)
            local db = dist2d({ X = b.x, Z = b.z }, CFG.CenterX, CFG.CenterZ)
            if math.abs(da - db) > 1e-6 then return da < db end
            if a.z ~= b.z then return a.z < b.z end
            return a.x < b.x
        end)
        for i, sl in ipairs(slots) do sl.index = i end
        return slots
    end

    -- อ่านป้อมที่ใส่ไว้ในช่อง EquipSlot: Player attribute Slot<N> (ชื่อ) / Slot<N>Id (UnitId) / ราคาจาก GameUI.Slots.Slot<N>
    -- คืน true ถ้าใช้ได้, false ถ้าช่องว่าง (เกมจะปฏิเสธ "You don't have this exact troop equipped")
    local function resolveEquip()
        local n = math.floor(tonumber(CFG.EquipSlot) or 1)
        if n < 1 or n > 5 then n = 1 end
        local lp = Players.LocalPlayer
        local okN, name = pcall(function() return lp:GetAttribute("Slot" .. n) end)
        local okI, uid = pcall(function() return lp:GetAttribute("Slot" .. n .. "Id") end)
        name = okN and name or nil
        uid = okI and uid or nil
        if type(name) == "string" and type(uid) == "string" then
            if name == "" or uid == "" then
                warn("[TdAuto] Slot " .. n .. " ว่าง (ยังไม่ได้ใส่ป้อม) ใส่ป้อมในช่องนี้ก่อน หรือแก้ EquipSlot")
                return false
            end
            CFG.TowerName, CFG.UnitId = name, uid
            if CFG.ExpectUnit and CFG.ExpectUnit ~= "" and name:lower() ~= tostring(CFG.ExpectUnit):lower() then
                warn(string.format("[TdAuto] Slot %d เป็น '%s' ไม่ใช่ %s (ตัวช่วย Equip ในล็อบบี้ใส่ผิดหรือไม่ได้ทำงาน) จะวาง '%s' ตามที่อยู่ในช่อง", n, name, tostring(CFG.ExpectUnit), name))
            end
        else
            warn("[TdAuto] อ่าน Slot" .. n .. " จากผู้เล่นไม่ได้ ใช้ค่า TowerName/UnitId ที่ตั้งไว้แทน")
        end
        local pn = lp and findPath(lp, { "PlayerGui", "GameUI", "Slots", "Slot" .. n, "TroopFrame", "Price" })
        if pn then
            local ok, txt = pcall(function() return pn.Text end)
            local price = ok and parseNum(txt) or nil
            if price and price > 0 then CFG.PlaceCost = price end
        end
        print(string.format("[TdAuto] ใช้ Slot %d : %s | ราคาวาง %s | UnitId %s", n, tostring(CFG.TowerName), tostring(CFG.PlaceCost), tostring(CFG.UnitId)))
        return true
    end

    local function mainLoop(myGen)
        local addRemote = getRemote("TowerAdd")
        local upRemote = getRemote("TowerUpgrade")
        if not addRemote or not upRemote then
            warn("[TdAuto] ไม่พบ Remote TowerAdd/TowerUpgrade ที่ ReplicatedStorage.ModuleLoader.Shared.Network.RemoteEvent (ต้องอยู่ในด่านก่อน)")
            running = false
            setStatus("ไม่พบ Remote (เข้าด่านก่อน)")
            return
        end

        if not resolveEquip() then
            running = false
            setStatus("Slot " .. tostring(CFG.EquipSlot) .. " ว่าง: ใส่ป้อมในช่องก่อน")
            return
        end

        local slots = buildSlots()
        local target = CFG.MaxTowers
        mine, seen = {}, {}
        note("start", string.format("เริ่มสร้างป้อม เป้าหมาย %d ตัว (ตาราง %d ช่อง)", target, #slots),
            string.format("วางทีละตัว -> อัปจนตัน Lv %d -> ค่อยวางตัวถัดไป จนครบ %d ตัว", CFG.MaxLevel, target))

        -- รู้จักป้อมที่มีอยู่แล้วทั้งหมด และรับช่วงตัว Speakerman ที่อยู่ในพื้นที่ตาราง
        local f = towersFolder()
        if f then
            for _, m in ipairs(f:GetChildren()) do
                seen[m.Name] = true
                if CFG.AdoptExisting then
                    local p = towerPos(m)
                    if p and towerNameText(m) == CFG.TowerName and insideGrid(p, slots) then
                        mine[#mine + 1] = m.Name
                    end
                end
            end
        end

        local slotIdx = 1
        local skips, firstFail = 0, nil
        local placedNow = 0

        while running and gen == myGen do
            -- 1) กฎเหล็ก: ทุกตัวของเราต้องตันก่อน ถึงจะไปขั้นต่อไปได้
            local fin = finishAll(upRemote, slots)
            if not fin then break end
            local have = countMine()
            progress = string.format("ป้อม %d/%d  ตันครบ", have, target)
            refreshUi()
            note("progress", string.format("ป้อม %d/%d ตันครบทุกตัว", have, target),
                have >= target and "ครบแล้ว หยุดวาง/อัป" or string.format("วางตัวที่ %d (ราคา %d)", have + 1, CFG.PlaceCost))

            -- 2) ครบจำนวนแล้ว = เสร็จ
            if have >= target then
                if gen == myGen then
                    running = false
                    setStatus(string.format("เสร็จแล้ว: มีป้อม %d ตัว ตันทุกตัว", have))
                    note("done", string.format("เสร็จ: ป้อมครบ %d ตัว ตันทุกตัว", have),
                        "Skip/Vote/Speed/Replay ทำงานต่อเอง (Replay จะกดเมื่อหน้าจอสรุปผลขึ้น)")
                end
                return
            end

            -- 3) หาช่องว่างถัดไป
            if slotIdx > #slots then
                if firstFail then
                    slotIdx = firstFail
                    firstFail, skips = nil, 0
                    setStatus("ช่องหมดแล้ว รอ " .. CFG.RestSeconds .. " วิ แล้วลองช่องที่ค้างใหม่")
                    note("rest", "ไล่ช่องหมดรอบแล้วแต่ยังไม่ครบ", "พัก " .. CFG.RestSeconds .. " วิ แล้วลองช่องที่ค้างใหม่")
                    sleep(CFG.RestSeconds)
                else
                    setStatus(string.format("หยุด: ช่องวางหมดแล้ว (มีป้อม %d/%d ตัว)", have, target))
                    running = false
                    return
                end
            end
            local slot = slots[slotIdx]
            if slotOccupied(slot) then
                dbg(string.format("ช่อง %d ถูกครอบครองแล้ว ข้ามไป", slot.index))
                slotIdx = slotIdx + 1
            else
                local id, why = tryPlace(slot, addRemote, slots)
                if not running or gen ~= myGen then break end
                if id then
                    skips, firstFail = 0, nil
                    placedNow = placedNow + 1
                    slotIdx = slotIdx + 1
                    -- วนกลับไปขั้นที่ 1 ทันที: อัปตัวใหม่ให้ตันก่อนทำอย่างอื่น
                elseif why == "gate" then
                    -- ยังมีตัวไม่ตัน: วนกลับไปอัปก่อน (ไม่นับเป็นช่องล้มเหลว)
                else
                    skips = skips + 1
                    firstFail = firstFail or slotIdx
                    slotIdx = slotIdx + 1
                    if skips >= CFG.SkipLimit then
                        setStatus("วางไม่ได้ติดกัน " .. skips .. " ช่อง (เงินไม่พอ?) พัก " .. CFG.RestSeconds .. " วิ")
                        note("rest2", "วางไม่ได้ติดกัน " .. skips .. " ช่อง", "พัก " .. CFG.RestSeconds .. " วิ แล้วกลับไปลองช่องที่ค้าง")
                        sleep(CFG.RestSeconds)
                        slotIdx = firstFail
                        firstFail, skips = nil, 0
                    end
                end
            end
        end

        if gen == myGen then
            running = false
            setStatus(string.format("หยุด: มีป้อม %d/%d ตัว", countMine(), target))
        end
    end

    local function start()
        if running then return end
        gen = gen + 1
        running = true
        local myGen = gen
        setStatus("เริ่มทำงาน")
        for k in pairs(logKeys) do logKeys[k] = nil end
        task.spawn(function()
            local ok, err = pcall(mainLoop, myGen)
            if not ok then
                warn("[TdAuto] เกิดข้อผิดพลาด: " .. tostring(err))
                if gen == myGen then running = false setStatus("ผิดพลาด ดู Console") end
            end
        end)
    end

    local function stop()
        if running then
            running = false
            gen = gen + 1
            setStatus("หยุดแล้ว")
            note("stop", "หยุดการวาง/อัปตามที่สั่ง", "ไม่ทำอะไรต่อ (Skip/Vote/Speed/Replay ยังทำงานตามสวิตช์)")
        end
    end

    -- ---------- เสริมอัตโนมัติ: ข้ามเวฟ / โหวตโหมด / ตั้งความเร็ว ----------
    local OPT = { skip = CFG.AutoSkip, vote = CFG.AutoVote, speed = CFG.AutoSpeed, replay = CFG.AutoReplay, leave = CFG.LeaveAfterRounds > 0 }
    local helperGen = 0
    local uiToggles = {}
    local VOTE_MODES = { Easy = true, Normal = true, Hard = true, Insane = true }
    if not VOTE_MODES[CFG.VoteMode] then
        warn("[TdAuto] VoteMode '" .. tostring(CFG.VoteMode) .. "' ไม่รู้จัก ใช้ Easy แทน")
        CFG.VoteMode = "Easy"
    end

    local function wsAttr(name)
        local ok, v = pcall(function() return workspace:GetAttribute(name) end)
        if ok then return v end
        return nil
    end

    local function getNet(folder, name)
        return findPath(ReplicatedStorage, { "ModuleLoader", "Shared", "Network", folder, name })
    end

    local function iVoted(userId)
        if not userId then return false end
        local needle = tostring(userId)
        for mode in pairs(VOTE_MODES) do
            local list = wsAttr(mode .. "Voters")
            if type(list) == "string" and list:find(needle, 1, true) then return true end
        end
        return false
    end

    -- กดปุ่มความเร็วบนหน้าจอ (GameUI.GameSpeeds.<ค่า>) ผ่าน connection ของปุ่ม — ใช้เป็นแผนสำรองเท่านั้น
    local function clickSpeedButton()
        local lp = Players.LocalPlayer
        local node = lp and findPath(lp, { "PlayerGui", "GameUI", "GameSpeeds", tostring(CFG.SpeedValue) })
        if not node then return false end
        local btn
        if node:IsA("GuiButton") then btn = node
        else
            for _, d in ipairs(node:GetDescendants()) do
                if d:IsA("GuiButton") then btn = d break end
            end
        end
        if not btn or type(getconnections) ~= "function" then return false end
        local fired = false
        for _, sigName in ipairs({ "Activated", "MouseButton1Click" }) do
            pcall(function()
                for _, c in ipairs(getconnections(btn[sigName])) do
                    pcall(function() c:Fire() end)
                    fired = true
                end
            end)
            if fired then break end
        end
        return fired
    end

    -- หน้าจอสรุปผลกำลังแสดงอยู่จริงไหม (เช็คทุกชั้นพ่อแม่ของ GameUI.FinalUI ว่า Visible/Enabled)
    local function finalShown()
        local lp = Players.LocalPlayer
        local node = lp and findPath(lp, { "PlayerGui", "GameUI", "FinalUI" })
        if not node then return false end
        local g = node
        while g do
            local okV, v = pcall(function() return g.Visible end)
            if okV and v == false then return false end
            local okE, e = pcall(function() return g.Enabled end)
            if okE and e == false then return false end
            local okP, par = pcall(function() return g.Parent end)
            if not okP then return false end
            g = par
        end
        return true
    end

    local function helperLoop(myGen)
        local lp = Players.LocalPlayer
        local userId = lp and lp.UserId or nil
        local lastSkip, lastVote, lastSpeed = -100, -100, -100
        local voteTries, speedTries = 0, 0
        local warnedSpeed = false
        local lastState = nil
        local lastReplay, replayTries = -100, 0
        local shownSince, lastCountdown = nil, nil
        local leaveMode = false
        do
            local gs = wsAttr("GameSpeed")
            print("[TdAuto] GameSpeed ตอนเริ่ม = " .. tostring(gs) .. " (" .. typeof(gs) .. ") เป้าหมาย " .. tostring(CFG.SpeedValue)
                .. " | พบ ChangeSpeed: " .. tostring(getNet("RemoteFunction", "ChangeSpeed") ~= nil))
        end
        note("helpers", string.format("ตัวช่วยทำงานอยู่: Skip=%s Vote=%s(%s) Speed=%s(%s) Replay=%s", tostring(OPT.skip), tostring(OPT.vote), CFG.VoteMode,
            tostring(OPT.speed), tostring(CFG.SpeedValue), tostring(OPT.replay)),
            string.format("Skip เมื่อข้ามเวฟได้ / Vote เมื่อมีโหวตโหมด / Speed ตั้งเป็น %s / Replay หลังหน้าสรุปผลขึ้น %d วิ แล้วกดทุก %s วิ",
                tostring(CFG.SpeedValue), CFG.ReplayDelay, tostring(CFG.ReplayGap)))
        local lastWaveLogged = nil
        while helperGen == myGen do
            local t = os.clock()

            -- Auto Skip
            if OPT.skip and wsAttr("CanSkip") == true and t - lastSkip >= CFG.SkipGap then
                local r = getNet("RemoteEvent", "WaveSkip")
                if r then
                    lastSkip = t
                    local wv = wsAttr("Wave")
                    if wv ~= lastWaveLogged then
                        lastWaveLogged = wv
                        note("skip", "ข้ามเวฟ (Wave " .. tostring(wv) .. ")", "ข้ามต่อทุก " .. tostring(CFG.SkipGap) .. " วิ ตราบที่ CanSkip เป็น true")
                    end
                    pcall(function() r:FireServer() end)
                end
            end

            -- Auto Vote
            local voting = wsAttr("IsVoting") == true
            if not voting then voteTries = 0 end
            if OPT.vote and voting and voteTries < CFG.VoteMaxTries and t - lastVote >= CFG.VoteGap
                and not iVoted(userId) then
                local r = getNet("RemoteEvent", "ModeVote")
                if r then
                    lastVote = t
                    voteTries = voteTries + 1
                    note("vote" .. voteTries, string.format("โหวตโหมด %s (ครั้งที่ %d/%d)", CFG.VoteMode, voteTries, CFG.VoteMaxTries),
                        "ถ้ายังไม่นับว่าโหวต จะลองอีกใน " .. tostring(CFG.VoteGap) .. " วิ")
                    pcall(function() r:FireServer(CFG.VoteMode) end)
                end
            end

            -- Auto Speed (ไม่เลิกถาวร: ลองถี่ก่อน แล้วลองช้าลงเรื่อยๆ ; รีเซ็ตเมื่อสถานะเกมเปลี่ยน เช่น เริ่มรอบใหม่)
            local state = wsAttr("GameState")
            if state ~= lastState then
                if lastState ~= nil or state ~= nil then
                    print("[TdAuto] ▶ สถานะเกมเปลี่ยน: " .. tostring(lastState) .. " → " .. tostring(state))
                end
                lastState = state
                speedTries = 0
                warnedSpeed = false
            end
            local cur = tonumber(wsAttr("GameSpeed"))   -- รองรับทั้งชนิดตัวเลขและข้อความ เช่น "1.5"
            if cur then
                if math.abs(cur - CFG.SpeedValue) < 0.001 then
                    if speedTries > 0 then print("[TdAuto] ความเร็วเป็น " .. tostring(cur) .. " แล้ว") end
                    speedTries = 0
                    warnedSpeed = false
                elseif OPT.speed then
                    local gap = (speedTries >= CFG.SpeedMaxTries) and CFG.SpeedSlowGap or CFG.SpeedGap
                    if t - lastSpeed >= gap then
                        lastSpeed = t
                        speedTries = speedTries + 1
                        local r = getNet("RemoteFunction", "ChangeSpeed")
                        local n = speedTries
                        if r then
                            task.spawn(function()
                                local ok, res = pcall(function() return r:InvokeServer(CFG.SpeedValue) end)
                                if not ok then
                                    warn("[TdAuto] ChangeSpeed error: " .. tostring(res))
                                elseif n <= 2 then
                                    print("[TdAuto] ChangeSpeed(" .. tostring(CFG.SpeedValue) .. ") ตอบกลับ = " .. tostring(res))
                                end
                            end)
                        end
                        if n >= 2 then clickSpeedButton() end   -- สำรอง: กดปุ่มความเร็วบนหน้าจอ
                        if n == CFG.SpeedMaxTries and not warnedSpeed then
                            warnedSpeed = true
                            warn("[TdAuto] ตั้งความเร็ว " .. tostring(CFG.SpeedValue) .. " ยังไม่สำเร็จ " .. n .. " ครั้ง (GameState=" .. tostring(state) .. ") จะลองต่อทุก " .. CFG.SpeedSlowGap .. " วิ")
                        end
                    end
                end
            end

            -- หน้าจอสรุปผลขึ้น -> นับรอบ ; ครบ LeaveAfterRounds = OnLeave กลับล็อบบี้ ; ไม่ครบ = Replay
            -- (รอ ReplayDelay วิ แล้วกดซ้ำทุก ReplayGap วิ จนกว่าหน้าสรุปผลจะหาย)
            local shown = finalShown()
            if not shown then
                if shownSince then
                    print("[TdAuto] ▶ หน้าจอสรุปผลหายแล้ว (เริ่มรอบใหม่)  |  ⏭ ถัดไป: รอหน้าสรุปผลรอบหน้า")
                end
                replayTries = 0 shownSince = nil lastCountdown = nil leaveMode = false
            elseif not shownSince then
                shownSince = t
                lastReplay = -100
                local n = (tonumber(State.get("rounds")) or 0) + 1
                State.set("rounds", n)
                leaveMode = CFG.LeaveAfterRounds > 0 and n >= CFG.LeaveAfterRounds
                if leaveMode and OPT.leave then
                    State.set("phase", "summon")   -- ล็อบบี้จะรู้ว่ามาจากการเล่นครบรอบ = ต้องสุ่มให้หมดก่อนเข้าลิฟต์
                    print(string.format("[TdAuto] ▶ จบรอบที่ %d/%d (ครบแล้ว)  |  ⏭ ถัดไป: อีก %d วิ กด OnLeave กลับล็อบบี้ แล้วสุ่มกล่อง/ขายให้หมดก่อนกลับมา Start",
                        n, CFG.LeaveAfterRounds, CFG.ReplayDelay))
                elseif OPT.replay then
                    print(string.format("[TdAuto] ▶ จบรอบที่ %d%s  |  ⏭ ถัดไป: อีก %d วิ กด Replay แล้วกดซ้ำทุก %s วิ", n,
                        CFG.LeaveAfterRounds > 0 and ("/" .. CFG.LeaveAfterRounds) or "", CFG.ReplayDelay, tostring(CFG.ReplayGap)))
                else
                    print(string.format("[TdAuto] ▶ จบรอบที่ %d  |  ⏭ ถัดไป: ไม่ทำอะไร (สวิตช์ Replay ปิดอยู่)", n))
                end
            end
            local doLeave = leaveMode and OPT.leave
            if shown and shownSince and (doLeave or OPT.replay) then
                local remoteName = doLeave and "OnLeave" or "PlayAgain"
                local what = doLeave and "OnLeave (กลับล็อบบี้)" or "Replay"
                local waitLeft = CFG.ReplayDelay - (t - shownSince)
                if waitLeft > 0 then
                    local sec = math.ceil(waitLeft)
                    if sec ~= lastCountdown and (sec % 5 == 0 or sec <= 3) then
                        lastCountdown = sec
                        print("[TdAuto] ⏳ รอกด " .. what .. " อีก " .. sec .. " วิ")
                    end
                elseif (CFG.ReplayMaxTries <= 0 or replayTries < CFG.ReplayMaxTries) and t - lastReplay >= CFG.ReplayGap then
                    local r = getNet("RemoteEvent", remoteName)
                    if r then
                        lastReplay = t
                        replayTries = replayTries + 1
                        print(string.format("[TdAuto] ▶ กด %s ครั้งที่ %d (GameState=%s)  |  ⏭ ถัดไป: ถ้ายังอยู่ในด่าน จะกดซ้ำในอีก %s วิ",
                            what, replayTries, tostring(wsAttr("GameState")), tostring(CFG.ReplayGap)))
                        pcall(function() r:FireServer() end)
                    else
                        note("noremote" .. remoteName, "ไม่พบ Remote " .. remoteName, "จะลองหาใหม่ทุกรอบ")
                    end
                elseif CFG.ReplayMaxTries > 0 and replayTries >= CFG.ReplayMaxTries then
                    note("replaymax", string.format("กด %s ครบ %d ครั้งแล้ว", what, replayTries), "หยุดกดจนกว่าหน้าสรุปผลจะหายแล้วขึ้นใหม่")
                end
            end

            task.wait(0.25)
        end
    end

    local function startHelpers()
        helperGen = helperGen + 1
        local myGen = helperGen
        task.spawn(function()
            local ok, err = pcall(helperLoop, myGen)
            if not ok then warn("[TdAuto] ลูปเสริมผิดพลาด: " .. tostring(err)) end
        end)
    end

    local function setOpt(name, value)
        if OPT[name] == nil then return false end
        OPT[name] = value and true or false
        for k, b in pairs(uiToggles) do
            if k == name then
                pcall(function()
                    b.BackgroundColor3 = OPT[name] and Color3.fromRGB(46, 125, 90) or Color3.fromRGB(70, 72, 84)
                end)
            end
        end
        return true
    end

    -- ---------- หน้าต่างควบคุม ----------
    local gui
    local function shutdown()
        running = false
        gen = gen + 1
        helperGen = helperGen + 1
        if gui then pcall(function() gui:Destroy() end) end
        gui = nil
        G.TdAuto = nil
    end

    if CFG.ShowUi then
        local okUi = pcall(function()
            gui = Instance.new("ScreenGui")
            gui.Name = "TdAutoUI"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 999
            gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

            local frame = Instance.new("Frame")
            frame.Size = UDim2.fromOffset(290, 158)
            frame.Position = UDim2.new(1, CFG.PanelX, 0, CFG.PanelY)
            frame.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
            frame.BorderSizePixel = 0
            frame.Active = true
            frame.Draggable = true
            frame.Parent = gui
            local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 8) corner.Parent = frame

            local function label(text, y, size, color)
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Position = UDim2.fromOffset(10, y)
                l.Size = UDim2.new(1, -20, 0, 18)
                l.Font = Enum.Font.GothamMedium
                l.TextSize = size
                l.TextColor3 = color or Color3.fromRGB(230, 232, 240)
                l.TextXAlignment = Enum.TextXAlignment.Left
                l.TextTruncate = Enum.TextTruncate.AtEnd
                l.Text = text
                l.Parent = frame
                return l
            end
            label("Auto วาง + อัปเกรด • Slot " .. tostring(CFG.EquipSlot), 6, 13)
            uiStatus = label(status, 28, 12, Color3.fromRGB(150, 220, 170))
            uiProgress = label(progress, 48, 12, Color3.fromRGB(160, 165, 180))

            local b = Instance.new("TextButton")
            b.Position = UDim2.fromOffset(10, 76)
            b.Size = UDim2.new(1, -20, 0, 32)
            b.BackgroundColor3 = Color3.fromRGB(46, 125, 90)
            b.BorderSizePixel = 0
            b.Font = Enum.Font.GothamMedium
            b.TextSize = 13
            b.TextColor3 = Color3.new(1, 1, 1)
            b.Text = "เริ่ม"
            b.Parent = frame
            local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = b
            uiButton = b
            b.MouseButton1Click:Connect(function()
                if running then stop() else start() end
            end)

            local defs = { { "skip", "Skip" }, { "vote", "Vote" }, { "speed", "Speed" }, { "replay", "Replay" }, { "leave", "Leave" } }
            for i, def in ipairs(defs) do
                local tb = Instance.new("TextButton")
                tb.Position = UDim2.fromOffset(10 + (i - 1) * 55, 116)
                tb.Size = UDim2.fromOffset(51, 28)
                tb.BorderSizePixel = 0
                tb.Font = Enum.Font.GothamMedium
                tb.TextSize = 12
                tb.TextColor3 = Color3.new(1, 1, 1)
                tb.Text = def[2]
                tb.Parent = frame
                local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 6) tc.Parent = tb
                uiToggles[def[1]] = tb
                setOpt(def[1], OPT[def[1]])
                tb.MouseButton1Click:Connect(function() setOpt(def[1], not OPT[def[1]]) end)
            end
        end)
        if not okUi then warn("[TdAuto] สร้างหน้าต่างไม่สำเร็จ ใช้ TdAuto.Start() / TdAuto.Stop() แทน") end
    end

    G.TdAuto = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        Status = function() return status .. " | " .. progress end,
        Set = setOpt,            -- TdAuto.Set("skip", false)  ชื่อ: skip / vote / speed / replay / leave
        Rounds = function() return tonumber(State.get("rounds")) or 0 end,
        Opt = function(name) return OPT[name] end,
        IsRunning = function() return running end,
        Config = CFG,
    }
    startHelpers()

    say("พร้อมแล้ว กดปุ่ม 'เริ่ม' ตอนอยู่ในด่าน (หรือ TdAuto.Start())  ตั้งใจวาง " .. CFG.MaxTowers .. " ตัว เลเวลตัน " .. CFG.MaxLevel)
    if CFG.AutoStart then start() end
end

-- ========================= โมดูล: Webhook (discord_webhook.lua) =========================
local function Module_Webhook()
    -- Discord Webhook  |  ส่งแจ้งเตือนเข้าช่อง Discord ตรง (ไม่ต้องมีบอต ไม่ต้องมีเซิร์ฟเวอร์/VPS)
    --   * ได้ไอเทมใน Watch เพิ่ม            → ข้อความ embed สีเหลือง (ชื่อ +จำนวนที่ได้ (มีทั้งหมด N)) + บัญชี/เครื่อง/เกม
    --   * ได้ตัวระดับ RareFrom ขึ้นไป (Mythic/Exclusive) → แจ้งเหมือนกัน + ping @everyone (ปิดได้ที่ PingEveryone)
    -- อ่านกระเป๋าจาก Lucky Hub (getgenv().LuckyHub) : ล็อบบี้อ่านสด / ในด่านใช้ข้อมูลล็อบบี้ล่าสุดที่ Hub เก็บตอนก่อนวาป
    -- จำจำนวนที่เคยแจ้งไว้ (หน่วยความจำ + ไฟล์ LuckyWebhook_ชื่อบัญชี.txt) จึงแจ้งของที่ได้ระหว่างอยู่ในด่าน/ตอนรีสตาร์ทได้ และไม่แจ้งซ้ำ
    -- ข้อความจะถือว่า "ส่งแล้ว" ก็ต่อเมื่อ Discord ตอบรับ ถ้าเกมวาปก่อนส่งทัน จะส่งใหม่รอบถัดไป
    -- ลิงก์ Webhook เป็นความลับ: ใครได้ลิงก์ไปจะส่งข้อความ/ping เข้าช่องของคุณได้ อย่าแชร์ และอย่าโพสต์ภาพ/ไฟล์ที่เห็นลิงก์
    -- ตั้งค่า (ใส่ก่อนรัน ไม่ต้องใส่ก็ได้):
    --   getgenv().WebhookConfig = { Url = "ลิงก์ Webhook", Watch = { "Speakerman" }, RareFrom = "Mythic", PingEveryone = true,
    --                               Machine = "PC1", GameName = "Tower Defense", Interval = 5, Username = "Lucky Hub", AvatarUrl = "",
    --                               ShowStats = false, TestMessage = false }

    local CFG = {
        Url          = "https://discord.com/api/webhooks/1557233594114510888/uD4vtvMAIfrecwuRIa2hxh_Gpx9pvYQLjQykXKWYKDfwh7AX1rete8xe75OWjA_pz8jj",
        Watch        = { "Speakerman" },   -- ไอเทม/ตัวละครที่อยากให้แจ้งเมื่อเพิ่ม พิมพ์ตามชื่อในเกม (ไม่สนตัวพิมพ์เล็ก-ใหญ่) เพิ่มได้ไม่จำกัด
        RareFrom     = "Mythic",           -- ได้ตัวระดับนี้ขึ้นไป (Basic<Uncommon<Rare<Epic<Legendary<Mythic<Exclusive) แจ้งเสมอ แม้ไม่อยู่ใน Watch ("" = ปิด)
        PingEveryone = true,               -- true = ข้อความของตัวระดับ RareFrom ขึ้นไป ping @everyone
        Machine      = "PC1",              -- ชื่อเครื่องนี้ (โชว์ในข้อความ)
        GameName     = "Tower Defense",    -- ชื่อเกม (โชว์ในข้อความ)
        Interval     = 5,                  -- ตรวจกระเป๋าทุกกี่วินาที (ขั้นต่ำ 3)
        Username     = "Lucky Hub",        -- ชื่อผู้ส่งที่โชว์ใน Discord (ห้ามมีคำว่า discord / clyde)
        AvatarUrl    = "",                 -- ลิงก์รูปโปรไฟล์ผู้ส่ง (เว้นว่าง = ใช้รูปของ Webhook)
        ShowStats    = false,              -- true = ใส่เงิน/เพชรปัจจุบันเพิ่มในข้อความ (เมื่ออยู่ล็อบบี้)
        TestMessage  = false,              -- true = ส่งข้อความทดสอบ 1 ครั้งตอนเริ่ม (ทดสอบเสร็จเปลี่ยนกลับเป็น false)
        AutoStart    = true,
    }

    local G = (getgenv and getgenv()) or _G
    if type(G.WebhookConfig) == "table" then
        for k, v in pairs(G.WebhookConfig) do
            if CFG[k] ~= nil then CFG[k] = v end
        end
    end
    if type(G.LuckyWebhook) == "table" and type(G.LuckyWebhook.Shutdown) == "function" then
        pcall(G.LuckyWebhook.Shutdown)   -- รันซ้ำ: ปิดตัวเก่าก่อน ไม่ให้ส่งซ้อนกัน
    end

    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")

    local STABLE_SECS = 6            -- ล็อบบี้: กระเป๋าต้องนิ่งกี่วินาทีก่อนเริ่มเทียบครั้งแรก (กันรายการที่ยังโหลดไม่ครบถูกนับเป็นของใหม่)
    local MAX_WARMUP = 60            -- รอนิ่งนานสุดกี่วินาที (สุ่มกล่องอยู่กระเป๋าเปลี่ยนตลอด) แล้วเริ่มเทียบเลย
    local CONFIRM_CHECKS = 2         -- ค่าที่เปลี่ยนต้องเห็นเหมือนกันกี่รอบติดกันถึงจะเชื่อ (กันภาพกระเป๋ากะพริบ)
    local FORCE_CONFIRM = 4          -- ถ้าเปลี่ยนไม่หยุดติดกันกี่รอบ ให้เชื่อค่าล่าสุดเลย
    local SEND_GAP = 1.2             -- เว้นระหว่างข้อความอย่างน้อยกี่วินาที (Discord จำกัดความถี่ของ Webhook)
    local BUSY_MAX = 60              -- คำขอค้างเกินกี่วินาทีให้ถือว่าล้มเหลวแล้วลองใหม่
    local WARN_GAP = 60              -- ข้อความเตือนเดิมพิมพ์ซ้ำได้ทุกกี่วินาที
    local QUEUE_MAX = 50             -- คิวข้อความที่รอส่งสูงสุด
    local MAX_RETRY = 8              -- ส่งไม่ได้ชั่วคราว (เน็ตหลุด/Discord ล่ม) ลองซ้ำกี่ครั้งก่อนทิ้ง
    local MAX_RATE_RETRY = 20        -- ถูกจำกัดความถี่ (429) รอซ้ำได้กี่ครั้ง
    local BASE_MAX_AGE = 3 * 86400   -- ค่าที่จำไว้เก่าเกินนี้ (วินาที) = เริ่มนับใหม่โดยไม่แจ้ง
    local SAVE_EVERY = 300           -- ไม่มีอะไรเปลี่ยนก็ต่ออายุที่จำไว้ทุกกี่วินาที
    local DESC_BUDGET = 3800         -- ความยาวรายการในข้อความ (ตัวอักษร) ที่เหลือจะสรุป "…และอีก N รายการ"
    local COLOR_ALERT = 15844367     -- 0xF1C40F สีเหลือง
    local COLOR_TEST = 5763719       -- 0x57F287 สีเขียว
    local RANK = { Basic = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Exclusive = 7 }   -- ระดับในเกม (เหมือน Lucky Hub)
    local RANK_NAME = {}
    for n in pairs(RANK) do RANK_NAME[n:lower()] = n end

    local started = os.clock()
    local stopped = false            -- Shutdown แล้ว
    local running = false            -- เปิดเฝ้าอยู่ไหม (สวิตช์ในแดชบอร์ด)
    local status = "เริ่มทำงาน"       -- สถานะการเฝ้ากระเป๋า
    local sendStatus = nil           -- สถานะการส่งเข้า Discord (nil = ยังไม่เคยส่ง)
    local counters = { ok = 0, fail = 0, dropped = 0, gains = 0, lastCode = nil }

    -- ฟังก์ชัน HTTP ของ executor (แต่ละตัวใช้ชื่อไม่เหมือนกัน)
    local function pickRequest()
        if type(request) == "function" then return request end
        if type(http_request) == "function" then return http_request end
        if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
        if type(fluxus) == "table" and type(fluxus.request) == "function" then return fluxus.request end
        if type(http) == "table" and type(http.request) == "function" then return http.request end
        return nil
    end
    local req = pickRequest()

    local lastWarn = {}
    local function warnOnce(key, msg)
        local now = os.clock()
        local w = lastWarn[key]
        if w and w.msg == msg and now - w.t < WARN_GAP then return end
        lastWarn[key] = { msg = msg, t = now }
        warn("[LuckyWebhook] " .. msg)
    end

    local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

    -- ชื่อไอเทม: ตัดช่องว่างหัวท้าย + ยุบช่องว่างซ้ำ (tidy) / สำหรับเทียบใช้ตัวพิมพ์เล็กด้วย (norm)
    local function tidy(s)
        local t = tostring(s or "")
        t = t:gsub("%s+", " ")
        t = t:gsub("^ ", "")
        t = t:gsub(" $", "")
        return t
    end
    local function norm(s) return tidy(s):lower() end

    local function copyMap(m)
        local r = {}
        for k, v in pairs(m) do r[k] = v end
        return r
    end

    -- ---------- ตรวจค่าตั้ง ----------
    local URL = trim(CFG.Url)
    local watchList, watchSeen = {}, {}
    local rareName, rareRank = nil, nil
    local Interval = math.max(3, tonumber(CFG.Interval) or 5)
    local Machine = (type(CFG.Machine) == "string") and trim(CFG.Machine) or ""
    local GameName = (type(CFG.GameName) == "string") and trim(CFG.GameName) or ""
    local Username = (type(CFG.Username) == "string") and trim(CFG.Username) or ""
    local AvatarUrl = (type(CFG.AvatarUrl) == "string") and trim(CFG.AvatarUrl) or ""
    local PingEveryone = (CFG.PingEveryone == true)
    local ShowStats = (CFG.ShowStats == true)
    local TestMessage = (CFG.TestMessage == true)

    local watchSrc = CFG.Watch
    if type(watchSrc) == "string" then watchSrc = { watchSrc } end
    if type(watchSrc) == "table" then
        for _, name in ipairs(watchSrc) do
            if type(name) == "string" then
                local label = tidy(name)
                local key = norm(label)
                if key ~= "" and not watchSeen[key] then
                    watchSeen[key] = true
                    watchList[#watchList + 1] = { key = key, label = label }
                end
            end
        end
    end
    if type(CFG.RareFrom) == "string" and trim(CFG.RareFrom) ~= "" then
        rareName = RANK_NAME[trim(CFG.RareFrom):lower()]
        if rareName then rareRank = RANK[rareName]
        else warn("[LuckyWebhook] RareFrom \"" .. trim(CFG.RareFrom) .. "\" ไม่รู้จัก (ใช้ได้: Basic, Uncommon, Rare, Epic, Legendary, Mythic, Exclusive) ปิดการแจ้งตามระดับ") end
    end
    if AvatarUrl ~= "" and not AvatarUrl:match("^https?://") then
        warn("[LuckyWebhook] AvatarUrl ต้องขึ้นต้นด้วย http:// หรือ https:// (ข้ามรูปโปรไฟล์)")
        AvatarUrl = ""
    end

    -- ตั้งค่าไม่ครบ: ลงทะเบียนตัวเปล่าให้แดชบอร์ดเห็นเหตุผล แล้วหยุด
    local function inert(reason)
        warn("[LuckyWebhook] " .. reason)
        G.LuckyWebhook = {
            Start = function() end, Stop = function() end, Shutdown = function() end,
            IsRunning = function() return false end,
            Status = function() return "ใช้งานไม่ได้: " .. reason .. " | " end,
            Config = CFG,
        }
    end
    if not req then
        return inert("executor นี้ไม่มีฟังก์ชัน request/http_request จึงส่งข้อมูลไม่ได้")
    end
    if not URL:match("^https?://") then
        return inert("ยังไม่ได้ใส่ลิงก์ Webhook ใน WebhookConfig.Url (Discord: ตั้งค่าช่อง → การผสานรวม → เว็บฮุค → สร้างเว็บฮุคใหม่ → คัดลอก URL)")
    end
    if not URL:match("^https://[%w%.]*discord%.com/api/[%w/]*webhooks/%d+/[%w_%-]+")
        and not URL:match("^https://[%w%.]*discordapp%.com/api/[%w/]*webhooks/%d+/[%w_%-]+") then
        warn("[LuckyWebhook] Url ไม่ใช่ลิงก์ Webhook ของ Discord (ควรเป็น https://discord.com/api/webhooks/ตัวเลข/โทเคน) ส่งต่อไปแต่อาจไม่สำเร็จ")
    end
    if #watchList == 0 and not rareRank then
        return inert("Watch ว่างและ RareFrom ปิดอยู่ ไม่มีอะไรให้เฝ้า (ใส่ชื่อไอเทมใน Watch เช่น { \"Speakerman\" } หรือตั้ง RareFrom = \"Mythic\")")
    end

    -- ---------- ข้อความ: escape / ตัด / จัดรูปตัวเลข ----------
    local MD_ESC = {}
    for c in ("\\*_~|`>[]()<"):gmatch(".") do MD_ESC[c] = true end
    local function esc(s)   -- กัน Markdown ของ Discord ตีความชื่อ (เช่น _ * ~ |)
        return (tostring(s):gsub(".", function(c) if MD_ESC[c] then return "\\" .. c end end))
    end

    local function ulen(s)
        local n = utf8 and utf8.len and utf8.len(s)
        return n or #s
    end
    local function clip(s, n)   -- ตัดให้ไม่เกิน n ตัวอักษร (นับตามอักขระ ไม่ตัดกลางตัวอักษรไทย) ต่อท้าย …
        s = tostring(s)
        if #s <= n then return s end
        local len = utf8 and utf8.len and utf8.len(s)
        if len then
            if len <= n then return s end
            local cut = utf8.offset(s, n)   -- ตำแหน่งไบต์ของอักขระที่ n (เหลือที่ให้ …)
            if cut then return s:sub(1, cut - 1) .. "…" end
        end
        s = s:sub(1, n - 1)
        s = s:gsub("[\192-\255][\128-\191]*$", "")
        return s .. "…"
    end

    local function fmt(n)
        n = tonumber(n) or 0
        local neg = n < 0
        if neg then n = -n end
        local s = string.format("%.0f", n)
        if n ~= math.floor(n) then
            s = string.format("%.2f", n)
            s = s:gsub("0+$", "")
            s = s:gsub("%.$", "")
        end
        local int, rest = s:match("^(%d+)(.*)$")
        if not int then return s end
        int = int:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        int = int:gsub("^,", "")
        return (neg and "-" or "") .. int .. rest
    end

    local function isoNow()
        local ok, s = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ", os.time())
        if ok and type(s) == "string" and s:match("^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then return s end
        return nil
    end

    -- ---------- อ่านกระเป๋าจาก Lucky Hub ----------
    local LP

    -- groups = { {name, rarity, count} ... } → { ชื่อ(ตัวพิมพ์เล็ก) = { n = จำนวนรวม, label = ชื่อ, rarity = ระดับสูงสุดที่เห็น } }, จำนวนรวมทั้งกระเป๋า
    local function tally(groups)
        local all, total = {}, 0
        for _, g in ipairs(groups) do
            if type(g) == "table" then
                local c = tonumber(g.count)
                local label = tidy(g.name)
                local k = label:lower()
                if c and c > 0 and k ~= "" and not k:find("ไม่ทราบชื่อ", 1, true) then
                    local e = all[k]
                    if not e then
                        e = { n = 0, label = label }
                        all[k] = e
                    end
                    e.n = e.n + c
                    local rn = RANK_NAME[tostring(g.rarity or ""):lower()]
                    if rn and (not e.rarity or RANK[rn] > RANK[e.rarity]) then e.rarity = rn end
                    total = total + c
                end
            end
        end
        return all, total
    end

    -- ล็อบบี้: Hub อ่านกระเป๋าสดจาก UI (ทุก ~5 วิ)
    local function readLobby(hub)   -- คืน all หรือ nil, เหตุผลที่ยังไม่พร้อม
        local bag = hub.Bag and hub.Bag() or nil
        if type(bag) ~= "table" or type(bag.groups) ~= "table" then return nil, "รอ Hub อ่านกระเป๋า" end
        local all, total = tally(bag.groups)
        -- อ่านได้ 0 ชิ้น = Hub อาจยังโหลด/อ่านไม่ได้ชั่วคราว ข้ามรอบ (ไม่เชื่อว่าของหายหมด กันเตือนมั่วตอนกลับมาอ่านได้)
        if total == 0 then return nil, "กระเป๋าอ่านได้ 0 ชิ้น รอโหลด" end
        return all
    end

    -- ในด่าน: อ่านกระเป๋าสดไม่ได้ ใช้ข้อมูลล็อบบี้ล่าสุดที่ Hub เก็บไว้ (บันทึกซ้ำตอนก่อนวาป) เป็นข้อมูลนิ่ง
    local function readSnapshot(hub)
        local sn = hub.Snapshot and hub.Snapshot() or nil
        if type(sn) ~= "table" or type(sn.bag) ~= "table" then return nil, "ยังไม่มีข้อมูลล็อบบี้ที่ Hub เก็บไว้ (เข้าล็อบบี้ 1 ครั้งก่อน)" end
        local all, total = tally(sn.bag)
        if total == 0 then return nil, "ข้อมูลกระเป๋าล็อบบี้ที่เก็บไว้ว่างเปล่า" end
        return all
    end

    local function signature(all)
        local keys = {}
        for k in pairs(all) do keys[#keys + 1] = k end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(all[k].n) end
        return table.concat(parts, ";")
    end

    -- รายการที่ติดตาม: ทุกชื่อใน Watch (จำนวน 0 ก็นับ) + ทุกตัวในกระเป๋าที่ระดับ >= RareFrom
    local function track(all)
        local cur = {}
        for _, w in ipairs(watchList) do
            local e = all[w.key]
            cur[w.key] = { n = e and e.n or 0, label = w.label, rarity = e and e.rarity or nil, watch = true }
        end
        if rareRank then
            for k, e in pairs(all) do
                if not cur[k] and e.rarity and RANK[e.rarity] >= rareRank then
                    cur[k] = { n = e.n, label = e.label, rarity = e.rarity }
                end
            end
        end
        return cur
    end

    -- ---------- จำจำนวนที่แจ้งไปแล้ว (หน่วยความจำ + ไฟล์) ----------
    local function fileName()
        return "LuckyWebhook_" .. (tostring(LP.Name):gsub("[^%w_%-]", "_")) .. ".txt"
    end

    local function rareMark() return rareName or "-" end

    local function encodeBase(ts, map)
        local keys = {}
        for k in pairs(map) do keys[#keys + 1] = k end
        table.sort(keys)
        local L = { "v2", "ts=" .. string.format("%.0f", ts), "rare=" .. rareMark() }
        for _, k in ipairs(keys) do L[#L + 1] = string.format("%.14g", map[k]) .. "\t" .. k end
        return table.concat(L, "\n")
    end

    local function decodeBase(text)
        if type(text) ~= "string" then return nil end
        local ts, rare, c, first = nil, nil, {}, true
        for line in text:gmatch("[^\r\n]+") do
            if first then
                if line ~= "v1" and line ~= "v2" then return nil end
                first = false
            else
                local t = line:match("^ts=(%d+)$")
                local r = line:match("^rare=(.+)$")
                if t then ts = tonumber(t)
                elseif r then rare = r
                else
                    local n, k = line:match("^(%S+)\t(.+)$")
                    n = tonumber(n)
                    if n and k then c[k] = n end
                end
            end
        end
        if not ts then return nil end
        return { ts = ts, rare = rare, c = c }
    end

    local function loadBase()   -- คืน { c = key→จำนวน, rare = ระดับที่ใช้ตอนบันทึก } หรือ nil (ไม่มี/หมดอายุ)
        local mem = type(G.LuckyWebhookBase) == "table" and G.LuckyWebhookBase[LP.Name] or nil
        local entry = (type(mem) == "table" and type(mem.c) == "table" and type(mem.ts) == "number") and mem or nil
        if not entry and type(isfile) == "function" and type(readfile) == "function" then
            local ok, txt = pcall(function()
                if isfile(fileName()) then return readfile(fileName()) end
            end)
            if ok and type(txt) == "string" then entry = decodeBase(txt) end
        end
        if entry and os.time() - entry.ts > BASE_MAX_AGE then entry = nil end
        if entry then return { c = copyMap(entry.c), rare = entry.rare } end
        return nil
    end

    -- ref = จำนวนที่ใช้เทียบ (รวมของที่เข้าคิวส่งแล้ว) / base = จำนวนที่ "ส่งถึง Discord แล้ว" และจำลงไฟล์
    local ref, base = nil, nil
    local pendingN = 0               -- ข้อความแจ้งเตือนที่ยังอยู่ในคิว (ยังไม่ยืนยันว่าส่งถึง)
    local lastSave = -1e9
    local function saveBase(force)
        local now = os.clock()
        if not force and now - lastSave < SAVE_EVERY then return end
        lastSave = now
        local ts = os.time()
        if type(G.LuckyWebhookBase) ~= "table" then G.LuckyWebhookBase = {} end
        G.LuckyWebhookBase[LP.Name] = { ts = ts, rare = rareMark(), c = copyMap(base) }
        if type(writefile) == "function" then
            local ok, err = pcall(writefile, fileName(), encodeBase(ts, base))
            if not ok then warnOnce("save", "บันทึกไฟล์จำค่าเดิมไม่ได้ (" .. tostring(err) .. ") จะจำไว้ในหน่วยความจำเท่านั้น") end
        end
    end

    local function pack(nmap)   -- เก็บเฉพาะ Watch (รวม 0) + ตัวที่มีอยู่จริง
        local r = {}
        for k, n in pairs(nmap) do
            if n > 0 or watchSeen[k] then r[k] = n end
        end
        return r
    end

    -- ---------- สร้างข้อความ ----------
    local function encodePayload(embed, content, ping)
        local p = { allowed_mentions = { parse = ping and { "everyone" } or {} }, embeds = { embed } }   -- parse = [] : ไม่ ping ใคร
        if content then p.content = content end
        if Username ~= "" then p.username = clip(Username, 80) end
        if AvatarUrl ~= "" then p.avatar_url = AvatarUrl end
        local ok, js = pcall(function() return HttpService:JSONEncode(p) end)
        if not ok or type(js) ~= "string" then return nil, tostring(js) end
        return js
    end

    local function infoFields(extra)
        local fields = {}
        local function add(name, value)
            value = trim(tostring(value or ""))
            if value == "" then return end
            fields[#fields + 1] = { name = name, value = esc(clip(value, 500)), inline = true }
        end
        add("บัญชี", LP and LP.Name or "?")
        add("เครื่อง", Machine)
        add("เกม", GameName)
        for _, e in ipairs(extra or {}) do add(clip(e.label, 100), e.value) end
        return fields
    end

    local function statExtras(hub)   -- เงิน/เพชรปัจจุบัน (เมื่อเปิด ShowStats) : ล็อบบี้อ่านสด / ในด่านใช้ค่าล่าสุดที่ Hub เก็บไว้
        local out = {}
        if not ShowStats or type(hub) ~= "table" then return out end
        pcall(function()
            if hub.Place == "lobby" then
                local list = hub.Stats and hub.Stats()
                if type(list) ~= "table" then return end
                local seen = {}
                for _, st in ipairs(list) do
                    if (st.kind == "money" or st.kind == "gems") and not seen[st.kind] then
                        local ok, v = pcall(st.get)
                        if ok and v ~= nil then
                            local text = (type(v) == "number") and fmt(v) or trim(v)
                            if text ~= "" then
                                seen[st.kind] = true
                                out[#out + 1] = { label = tostring(st.label or st.kind), value = text }
                            end
                        end
                    end
                end
            elseif hub.Place == "game" then
                local sn = hub.Snapshot and hub.Snapshot() or nil
                if type(sn) ~= "table" then return end
                local function show(v) return (type(v) == "number") and fmt(v) or trim(v) end
                if sn.coins ~= nil and show(sn.coins) ~= "" then out[#out + 1] = { label = tostring(sn.coinsLabel or "Coins"), value = show(sn.coins) } end
                if sn.gems ~= nil and show(sn.gems) ~= "" then out[#out + 1] = { label = tostring(sn.gemsLabel or "Gems"), value = show(sn.gems) } end
            end
        end)
        return out
    end

    local function isRare(rarity) return rareRank ~= nil and rarity ~= nil and RANK[rarity] >= rareRank end

    local function buildAlert(gains, hub)
        table.sort(gains, function(a, b)
            local ra, rb = isRare(a.rarity) and RANK[a.rarity] or 0, isRare(b.rarity) and RANK[b.rarity] or 0   -- ตัวระดับสูงขึ้นก่อน
            if ra ~= rb then return ra > rb end
            if a.add ~= b.add then return a.add > b.add end
            return a.label < b.label
        end)
        local lines, used, topRare = {}, 0, nil
        for _, g in ipairs(gains) do
            local tag = ""
            if isRare(g.rarity) then
                tag = " · " .. g.rarity
                if not topRare or RANK[g.rarity] > RANK[topRare] then topRare = g.rarity end
            end
            local line = string.format("**%s**%s +%s (มีทั้งหมด %s)", esc(clip(g.label, 100)), tag, fmt(g.add), fmt(g.total))
            local n = ulen(line) + 1
            if used + n > DESC_BUDGET then break end
            lines[#lines + 1] = line
            used = used + n
        end
        local rest = #gains - #lines
        if rest > 0 then lines[#lines + 1] = "…และอีก " .. tostring(rest) .. " รายการ" end
        local embed = { title = "ได้ไอเทมที่ต้องการ", description = table.concat(lines, "\n"), color = COLOR_ALERT, fields = infoFields(statExtras(hub)) }
        local ts = isoNow()
        if ts then embed.timestamp = ts end
        local ping = PingEveryone and topRare ~= nil
        local content = ping and ("@everyone ได้ตัวระดับ " .. topRare .. "!") or nil
        return encodePayload(embed, content, ping)
    end

    local function buildTest()
        local names = {}
        for _, w in ipairs(watchList) do names[#names + 1] = "**" .. esc(clip(w.label, 100)) .. "**" end
        local text = "ส่งเข้าช่องนี้ได้แล้ว"
        if #names > 0 then text = text .. "\nกำลังเฝ้า: " .. clip(table.concat(names, ", "), 1500) end
        if rareRank then
            text = text .. "\nตัวระดับ " .. rareName .. " ขึ้นไป: แจ้งอัตโนมัติ" .. (PingEveryone and " + ping @everyone (ข้อความนี้ไม่ได้ ping)" or "")
        end
        local embed = { title = "ทดสอบการส่ง Webhook", description = text, color = COLOR_TEST, fields = infoFields(nil) }
        local ts = isoNow()
        if ts then embed.timestamp = ts end
        return encodePayload(embed, nil, false)
    end

    -- ---------- คิวส่ง (ทีละข้อความ เว้นช่วง ลองใหม่เมื่อล้มเหลวชั่วคราว) ----------
    local queue = {}
    local nextSendAt = 0
    local hadFailure = false

    local function enqueue(body, kind, commit)
        if #queue >= QUEUE_MAX then
            if kind ~= "alert" then counters.dropped = counters.dropped + 1 end   -- ข้อความแจ้งเตือนไม่นับว่าทิ้ง: ยังไม่ขยับค่าเทียบ รอบหน้าลองใหม่
            warnOnce("queue", "คิวส่งเต็ม (" .. tostring(QUEUE_MAX) .. " ข้อความ) ยังไม่ส่งข้อความใหม่ — เช็กลิงก์ Webhook และอินเทอร์เน็ต")
            return false
        end
        queue[#queue + 1] = { body = body, kind = kind, commit = commit, tries = 0, rl = 0 }
        return true
    end

    -- ข้อความออกจากคิวแล้ว (ส่งถึง หรือทิ้งถาวร) : ยืนยันจำนวนที่แจ้งไปแล้วลง base
    local function finishItem(item)
        if queue[1] == item then table.remove(queue, 1) end
        if item.commit then
            pendingN = math.max(0, pendingN - 1)
            if ref and base then
                base = (pendingN == 0) and copyMap(ref) or copyMap(item.commit)
                saveBase(true)
            end
        end
    end

    local function dropItem(item, why)
        finishItem(item)
        counters.dropped = counters.dropped + 1
        counters.fail = counters.fail + 1
        hadFailure = true
        sendStatus = "ส่งไม่สำเร็จ: " .. why
        warn("[LuckyWebhook] ทิ้งข้อความที่ส่งไม่ได้: " .. why)
    end

    local function retryAfter(res)   -- วินาทีที่ Discord ขอให้รอ (429)
        local wait
        local okJ, d = pcall(function() return HttpService:JSONDecode(tostring(res.Body or "")) end)
        if okJ and type(d) == "table" then wait = tonumber(d.retry_after) end
        if not wait and type(res.Headers) == "table" then
            for k, v in pairs(res.Headers) do
                if type(k) == "string" and k:lower() == "retry-after" then wait = tonumber(v) end
            end
        end
        wait = wait or 2
        if wait < 0 then wait = 0 end
        if wait > 60 then wait = 60 end
        return wait
    end

    local function doRequest(item)   -- คืน res หรือ nil, เหตุผล (มีเวลาหมดอายุ ไม่ให้คิวค้างตลอดไป)
        local done, ok, res = false, nil, nil
        task.spawn(function()
            ok, res = pcall(req, { Url = URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = item.body })
            done = true
        end)
        local t0 = os.clock()
        while not done and not stopped and os.clock() - t0 < BUSY_MAX do task.wait(0.1) end
        if not done then return nil, "คำขอค้างเกิน " .. tostring(BUSY_MAX) .. " วินาที" end
        if not ok then return nil, "request ผิดพลาด: " .. tostring(res) end
        if type(res) ~= "table" then return nil, "ไม่ได้รับคำตอบจากเซิร์ฟเวอร์ (เช็กอินเทอร์เน็ต)" end
        return res
    end

    local function onResult(item, res, err)
        if stopped then return end
        if res then
            local code = tonumber(res.StatusCode) or 0
            counters.lastCode = code
            if code >= 200 and code < 300 then
                finishItem(item)
                counters.ok = counters.ok + 1
                sendStatus = "ส่งล่าสุดสำเร็จ"
                if counters.ok == 1 or hadFailure then print("[LuckyWebhook] ส่งเข้า Discord สำเร็จ") end
                hadFailure = false
                return
            end
            local body = tostring(res.Body or ""):sub(1, 150)
            if code == 429 then
                item.rl = item.rl + 1
                if item.rl > MAX_RATE_RETRY then return dropItem(item, "ถูก Discord จำกัดความถี่ (429) ซ้ำเกินกำหนด") end
                nextSendAt = os.clock() + math.max(SEND_GAP, retryAfter(res) + 0.5)
                sendStatus = "ถูก Discord จำกัดความถี่ รอสักครู่"
                return
            end
            if code ~= 0 and code < 500 then   -- 3xx/4xx = ส่งซ้ำก็ไม่หาย
                local hint = ""
                if code == 404 then hint = " (ลิงก์ Webhook ผิด หรือถูกลบไปแล้ว)"
                elseif code == 401 then hint = " (โทเคนในลิงก์ Webhook ไม่ถูกต้อง)"
                elseif code == 400 then hint = " (Discord ปฏิเสธข้อมูล)" end
                return dropItem(item, "HTTP " .. tostring(code) .. hint .. " " .. body)
            end
            err = "HTTP " .. tostring(code) .. " " .. body
        end
        -- ล้มเหลวชั่วคราว (เน็ตหลุด / Discord ล่ม 5xx): ลองใหม่
        item.tries = item.tries + 1
        counters.fail = counters.fail + 1
        hadFailure = true
        if item.tries > MAX_RETRY then return dropItem(item, tostring(err) .. " (ลองครบ " .. tostring(MAX_RETRY) .. " ครั้งแล้ว)") end
        nextSendAt = os.clock() + math.min(item.tries * 10, 60)
        sendStatus = "ส่งไม่สำเร็จ: " .. tostring(err)
        warnOnce("send", "ส่งไม่สำเร็จ: " .. tostring(err) .. " จะลองใหม่ (" .. tostring(item.tries) .. "/" .. tostring(MAX_RETRY) .. ")")
    end

    local function worker()
        while not stopped do
            local item = queue[1]
            if item and os.clock() >= nextSendAt then
                local res, err = doRequest(item)
                if stopped then return end
                nextSendAt = os.clock() + SEND_GAP
                local ok, e = pcall(onResult, item, res, err)
                if not ok then
                    finishItem(item)
                    warnOnce("internal", "ผิดพลาดภายในตอนส่ง: " .. tostring(e))
                end
            else
                task.wait(0.25)
            end
        end
    end

    -- ---------- ตรวจกระเป๋า ----------
    local cand, candN, diffStreak = nil, 0, 0

    local function differs(a, b)   -- ต่างกันไหม (key ที่ไม่มี = 0)
        for k, v in pairs(a) do if (b[k] or 0) ~= v then return true end end
        for k, v in pairs(b) do if (a[k] or 0) ~= v then return true end end
        return false
    end

    -- allowDecrease = false (อ่านจากข้อมูลล็อบบี้ที่เก็บไว้ในด่าน): จำนวนที่ลดลงไม่นำมาใช้ (ข้อมูลเก่ากว่าได้) นับเฉพาะที่เพิ่ม
    local function check(all, hub, allowDecrease)
        local cur = track(all)
        local curN = {}
        for k, e in pairs(cur) do curN[k] = e.n end
        if not ref then   -- ครั้งแรกของรอบนี้: โหลดค่าที่จำไว้ (ไม่มี/หมดอายุ = ตั้งต้นจากกระเป๋าตอนนี้ ไม่แจ้ง)
            local loaded = loadBase()
            local rareOk = loaded ~= nil and loaded.rare == rareMark()
            local init = {}
            for k, e in pairs(cur) do
                local v = loaded and loaded.c[k]
                if type(v) == "number" then init[k] = v
                elseif e.watch then init[k] = e.n                  -- ไอเทมที่เพิ่งเพิ่มใน Watch ก็ตั้งต้นเงียบๆ
                elseif rareOk then init[k] = 0                     -- ตัวระดับสูงที่ไม่มีในค่าที่จำไว้ = เพิ่งได้ → จะแจ้ง
                else init[k] = e.n end                             -- ไม่มีค่าที่จำไว้ / เปลี่ยน RareFrom → ตั้งต้นเงียบๆ
            end
            ref, base = pack(init), pack(init)
            saveBase(true)
            print(string.format("[LuckyWebhook] เริ่มเฝ้า Watch %d รายการ%s%s%s", #watchList,
                rareRank and (" + ตัวระดับ " .. rareName .. " ขึ้นไป") or "",
                (rareRank and PingEveryone) and " (ping @everyone)" or "",
                loaded and " (ต่อจากค่าที่จำไว้)" or " (ตั้งค่าเริ่มต้นจากกระเป๋าตอนนี้)"))
            local none = {}
            for _, w in ipairs(watchList) do if curN[w.key] == 0 then none[#none + 1] = w.label end end
            if #none > 0 then   -- ช่วยจับชื่อที่พิมพ์ผิด: ถ้าได้ของนั้นแล้วยังไม่แจ้ง ให้เช็กว่าสะกดตรงกับชื่อในเกม
                print("[LuckyWebhook] ตอนนี้ยังไม่มีในกระเป๋า: " .. table.concat(none, ", ") .. " (ถ้ามีอยู่แล้วแต่ไม่ขึ้นที่นี่ ให้เช็กว่าพิมพ์ชื่อใน Watch ตรงกับชื่อในเกม)")
            end
        end
        if not allowDecrease then
            for k, v in pairs(ref) do if (curN[k] or 0) < v then curN[k] = v end end
        end
        if not differs(curN, ref) then
            cand, candN, diffStreak = nil, 0, 0
            saveBase(false)
            return
        end
        diffStreak = diffStreak + 1
        if cand and not differs(cand, curN) then candN = candN + 1 else cand, candN = copyMap(curN), 1 end
        if candN < CONFIRM_CHECKS and diffStreak < FORCE_CONFIRM then return end   -- รอยืนยันอีกรอบ
        local gains = {}
        for k, n in pairs(curN) do
            local b = ref[k] or 0
            local e = cur[k]
            if n > b and e then gains[#gains + 1] = { label = e.label, add = n - b, total = n, rarity = e.rarity } end
        end
        local newRef = pack(curN)
        if #gains > 0 then
            local body, err = buildAlert(gains, hub)
            if not body then warnOnce("build", "สร้างข้อความไม่สำเร็จ: " .. tostring(err)) return end   -- ยังไม่ขยับค่าเทียบ รอบหน้าลองใหม่
            if not enqueue(body, "alert", copyMap(newRef)) then return end                              -- คิวเต็ม: รอบหน้าลองใหม่
            counters.gains = counters.gains + 1
            pendingN = pendingN + 1
        end
        ref = newRef
        cand, candN, diffStreak = nil, 0, 0
        if pendingN == 0 then   -- ไม่มีข้อความค้างส่ง (เช่น แค่ของลดลง) : จำค่าใหม่ได้เลย
            base = copyMap(ref)
            saveBase(true)
        end
    end

    local lobbyReady = false
    local stableSig, stableAt = nil, 0
    local nextCheck = 0

    local function expectedPlace()   -- แมพจริงตาม PlaceId (กันอ่านข้อมูลของ Hub ตัวเก่าที่ค้างอยู่ตอนเพิ่งวาป)
        if type(G.HubConfig) == "table" and G.HubConfig.Place then return nil end
        local pid = game.PlaceId
        if LOBBY_ID and pid == LOBBY_ID then return "lobby" end
        if GAME_ID and pid == GAME_ID then return "game" end
        return nil
    end

    local function step()
        if not running then status = "หยุดชั่วคราว" return end
        local hub = G.LuckyHub
        if type(hub) ~= "table" then status = "รอ Lucky Hub โหลด" return end
        local want = expectedPlace()
        if want and hub.Place ~= want then status = "รอ Lucky Hub โหลด" return end
        local now = os.clock()
        if hub.Place == "lobby" then
            if lobbyReady and now < nextCheck then return end
            local all, why = readLobby(hub)
            if not all then status = why return end
            if not lobbyReady then   -- ครั้งแรก: รอให้กระเป๋านิ่งก่อน
                local sig = signature(all)
                if sig ~= stableSig then stableSig, stableAt = sig, now end
                if now - stableAt < STABLE_SECS and now - started < MAX_WARMUP then status = "รอกระเป๋านิ่งก่อนเริ่มเฝ้า" return end
                lobbyReady = true
            end
            nextCheck = now + Interval
            check(all, hub, true)
            status = "เฝ้าอยู่ (" .. tostring(#watchList) .. " รายการ" .. (rareRank and (" + " .. rareName .. "+") or "") .. ")"
        elseif hub.Place == "game" then
            if now < nextCheck then return end
            local all, why = readSnapshot(hub)
            if not all then status = why return end
            nextCheck = now + Interval
            check(all, hub, false)
            status = "เฝ้าอยู่ ตามข้อมูลล็อบบี้ล่าสุด"
        else
            status = "Hub ไม่รู้จักแมพนี้"
        end
    end

    local function sendTest()
        local body, err = buildTest()
        if body then enqueue(body, "test", nil) else warnOnce("build", "สร้างข้อความทดสอบไม่สำเร็จ: " .. tostring(err)) end
    end

    local function start()
        if stopped then return end
        running = true
        if status == "หยุดชั่วคราว" or status == "เริ่มทำงาน" then status = "เริ่มเฝ้า" end
    end
    local function stop()
        running = false
        status = "หยุดชั่วคราว"
    end
    local function shutdown()
        stopped = true
        running = false
    end

    task.spawn(worker)
    task.spawn(function()
        pcall(function() if not game:IsLoaded() then game.Loaded:Wait() end end)
        LP = Players.LocalPlayer
        while not LP and not stopped do task.wait(0.5) LP = Players.LocalPlayer end
        if stopped then return end
        if TestMessage then sendTest() end
        task.wait(0.5)   -- ให้ตัวรวมตั้ง G.LuckyHub ตัวใหม่เสร็จก่อนอ่านครั้งแรก
        while not stopped do
            local ok, err = pcall(step)
            if not ok then warnOnce("step", "ผิดพลาดภายใน: " .. tostring(err)) end
            task.wait(1)
        end
    end)

    G.LuckyWebhook = {
        Start = start,
        Stop = stop,
        Shutdown = shutdown,
        IsRunning = function() return running and not stopped end,
        Status = function() return status .. " | " .. (sendStatus or "ยังไม่เคยส่ง") end,
        Counters = function() return counters end,
        Queue = function() return #queue end,
        Test = function() if LP then sendTest() end end,   -- ส่งข้อความทดสอบทันที
        Config = CFG,
    }
    local names = {}
    for _, w in ipairs(watchList) do names[#names + 1] = w.label end
    print(string.format("[LuckyWebhook] พร้อมแล้ว | เฝ้า: %s%s | ตรวจทุก %s วิ | เครื่อง %s", #names > 0 and table.concat(names, ", ") or "-",
        rareRank and (" + ตัวระดับ " .. rareName .. " ขึ้นไป" .. (PingEveryone and " (ping @everyone)" or "")) or "", tostring(Interval), Machine ~= "" and Machine or "-"))
    if type(writefile) ~= "function" or type(readfile) ~= "function" or type(isfile) ~= "function" then
        print("[LuckyWebhook] executor นี้ไม่มี writefile/readfile: จะจำจำนวนไอเทมได้เฉพาะตอนเกมเปิดอยู่ (ของที่ได้ระหว่างรีสตาร์ทจะไม่แจ้ง)")
    end
    if CFG.AutoStart then start() end
end

-- ========================= ตัวรวม + แดชบอร์ด =========================
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local APIS = { Equip = "LobbyEquip", Summon = "LobbySummon", Start = "LobbyStart", Sell = "LobbySell", Quest = "LobbyQuest", TD = "TdAuto", Webhook = "LuckyWebhook" }
local FNS = { Equip = Module_Equip, Summon = Module_Summon, Start = Module_Start, Sell = Module_Sell, Quest = Module_Quest, TD = Module_TD, Webhook = Module_Webhook }
local PLACE_MODULES = { lobby = { "Equip", "Summon", "Start", "Sell", "Quest", "Webhook" }, game = { "TD", "Webhook" } }
local TITLES = {
    Equip = "ใส่ Speakerman Slot 1", Summon = "สุ่มกล่อง", Start = "เข้าลิฟต์ + Start", Sell = "ขายอัตโนมัติ", Quest = "เคลมรางวัลเควส", TD = "วางป้อม + อัปเกรด",
    Webhook = "แจ้งเตือน Discord",
}

local place = detectPlace()
local enabled = {}
for k, v in pairs(HUB) do enabled[k] = v end
local loaded = {}
local isLoaded = {}   -- โมดูลที่โหลดจริงในรอบนี้ (กัน API เก่าจากการรันสคริปต์ซ้ำมาโผล่ในแดชบอร์ด)
local clock0 = os.clock()

local function api(name) return G[APIS[name]] end

-- log ของตัวคุม: "กำลังทำ / ถัดไป" (ข้อความเดิมซ้ำติดกันไม่พิมพ์ซ้ำ)
local hubLog = {}
local function hlog(key, doing, nxt)
    if HUB.Log == false or hubLog[key] == doing then return end
    hubLog[key] = doing
    if nxt and nxt ~= "" then
        print("[LuckyHub] ▶ " .. doing .. "  |  ⏭ ถัดไป: " .. nxt)
    else
        print("[LuckyHub] ▶ " .. doing)
    end
end

local function setDefault(cfgName, key, value)
    if type(G[cfgName]) ~= "table" then G[cfgName] = {} end
    if G[cfgName][key] == nil then G[cfgName][key] = value end
end

-- ค่าเริ่มต้นของตัวรวม: เปิดทุกอย่าง (ผู้ใช้ตั้งค่าเองใน *Config ได้ จะไม่ถูกทับ)
local function prepareConfigs()
    local own = HUB.ModulePanels and true or false
    setDefault("EquipConfig", "ShowUi", own)   setDefault("EquipConfig", "AutoStart", true)
    setDefault("SellConfig", "KeepNames", { (type(G.EquipConfig) == "table" and G.EquipConfig.Unit) or "Speakerman" })  -- ไม่ขายป้อมหลัก
    setDefault("SummonConfig", "ShowUi", own)  setDefault("SummonConfig", "AutoStart", true)
    setDefault("StartConfig", "ShowUi", own)   setDefault("StartConfig", "AutoStart", false)  -- ตัวรวมเป็นคนสั่งเริ่มตามลำดับ
    setDefault("SellConfig", "ShowUi", own)    setDefault("SellConfig", "AutoStart", true)
    setDefault("QuestConfig", "ShowUi", own)   setDefault("QuestConfig", "AutoStart", true)
    setDefault("TdAutoConfig", "ShowUi", own)  setDefault("TdAutoConfig", "AutoStart", true)
    setDefault("WebhookConfig", "AutoStart", true)
end

-- ---------- อ่านเงิน/เพชร/ทรัพยากร (ค้นหาเอง) ----------
-- kind: "money" = เงิน (Money/Cash/Coins/Gold) , "gems" = เพชร (Gems/Diamonds/Crystals) ; nil = ทรัพยากรอื่น
local NAME_KIND = { money = "money", cash = "money", coin = "money", gold = "money", gem = "gems", diamond = "gems", crystal = "gems" }
local NAME_PREFIX = { [""] = true, total = true, player = true, my = true, current = true, user = true }
local NAME_SUFFIX = { [""] = true, s = true, label = true, text = true, txt = true, lbl = true, amount = true, value = true,
    count = true, display = true, title = true, frame = true, holder = true, ui = true, total = true }
local STAT_EXTRA = { tokens = true, token = true, tickets = true, ticket = true }
local BAD_ANCESTOR = { "shop", "store", "trade", "summon", "index", "quest", "price", "cost", "buy", "reward", "gamepass", "bundle", "template", "product", "crate", "offer" }

local function kindOfName(name)
    local n = tostring(name):lower():gsub("[^%a]", "")
    for w, kind in pairs(NAME_KIND) do
        local i = n:find(w, 1, true)
        if i and NAME_PREFIX[n:sub(1, i - 1)] then
            local rest = n:sub(i + #w)
            if NAME_SUFFIX[rest] or (rest:sub(1, 1) == "s" and NAME_SUFFIX[rest:sub(2)]) then return kind end   -- Gems / GemsAmount / CoinText ...
        end
    end
    return nil
end

local function numericText(t)
    if type(t) ~= "string" then return false end
    local s = t:gsub("[,%$%s]", "")
    return s:match("^%-?[%d%.]+%a?%a?$") ~= nil and s:find("%d") ~= nil
end

local function guiVisible(d, pg)
    local p = d
    while p and p ~= pg do
        local ok, vis = pcall(function() return p.Visible end)
        if ok and vis == false then return false end
        local ok2, en = pcall(function() return p.Enabled end)
        if ok2 and en == false then return false end
        p = p.Parent
    end
    return true
end

local function pathOf(inst, stop)
    local parts, p = {}, inst
    while p and p ~= stop do parts[#parts + 1] = p.Name p = p.Parent end
    local r = {}
    for i = #parts, 1, -1 do r[#r + 1] = parts[i] end
    return table.concat(r, ".")
end

-- คืนรายการ { label, get, kind, src } เรียงตามความน่าเชื่อถือของแหล่งข้อมูล (leaderstats > attribute > Value ใต้ผู้เล่น > ข้อความบนจอ)
local function discoverStats()
    local list, seenLabel, seenKind = {}, {}, {}
    local function add(label, get, kind, src)
        local key = label:lower()
        if seenLabel[key] then return end
        if kind and seenKind[kind] then return end
        seenLabel[key] = true
        if kind then seenKind[kind] = true end
        list[#list + 1] = { label = label, get = get, kind = kind, src = src }
    end
    if not LP then return list end
    -- 1) leaderstats ทั้งหมด
    local ls = LP:FindFirstChild("leaderstats")
    if ls then
        for _, c in ipairs(ls:GetChildren()) do
            local ok, v = pcall(function() return c.Value end)
            if ok and (type(v) == "number" or type(v) == "string") then
                add(c.Name, function() if c.Parent == nil then return nil end return c.Value end, kindOfName(c.Name), "leaderstats." .. c.Name)
            end
        end
    end
    -- 2) attribute ตัวเลขของผู้เล่นที่ชื่อเกี่ยวกับเงิน/เพชร
    local okA, attrs = pcall(function() return LP:GetAttributes() end)
    if okA and type(attrs) == "table" then
        for k, v in pairs(attrs) do
            local kind = kindOfName(k)
            if type(v) == "number" and (kind or STAT_EXTRA[tostring(k):lower()]) then
                add(tostring(k), function() return LP:GetAttribute(k) end, kind, "attribute " .. tostring(k))
            end
        end
    end
    -- 3) Value (IntValue/NumberValue/...) ใต้โฟลเดอร์ข้อมูลของผู้เล่น เช่น Player.Data.Gems
    local okC, kids = pcall(function() return LP:GetChildren() end)
    if okC then
        for _, c in ipairs(kids) do
            local cls = tostring(c.ClassName)
            if c.Name ~= "PlayerGui" and c.Name ~= "Backpack" and c.Name ~= "PlayerScripts" and c.Name ~= "leaderstats" and c.Name ~= "StarterGear" then
                local pool = {}
                if cls:match("Value$") then pool[1] = c
                elseif cls == "Folder" or cls == "Configuration" then
                    local okD, ds = pcall(function() return c:GetDescendants() end)
                    if okD then pool = ds end
                end
                for _, d in ipairs(pool) do
                    if tostring(d.ClassName):match("Value$") then
                        local kind = kindOfName(d.Name)
                        local ok, v = pcall(function() return d.Value end)
                        if ok and type(v) == "number" and (kind or STAT_EXTRA[d.Name:lower()]) then
                            add(d.Name, function() if d.Parent == nil then return nil end return d.Value end, kind, pathOf(d, LP))
                        end
                    end
                end
            end
        end
    end
    -- 4) ข้อความตัวเลขบนจอที่ชื่อ/พ่อแม่ชื่อ Money/Gems/Cash/Coins ... (เช่น GameUI.Stats.OtherUI.Money.Title)
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local okD, desc = pcall(function() return pg:GetDescendants() end)
        if okD then
            local cands = {}
            for _, d in ipairs(desc) do
                if d.ClassName == "TextLabel" then
                    local depth, kind, label = 0, nil, nil
                    local p = d
                    while p and p ~= pg and depth < 3 do
                        kind = kindOfName(p.Name)
                        if kind then label = p.Name break end
                        if depth == 0 and STAT_EXTRA[d.Name:lower()] then label = d.Name break end
                        p = p.Parent
                        depth = depth + 1
                    end
                    if label and numericText(d.Text) then
                        local score = depth * 10
                        if not guiVisible(d, pg) then score = score + 100 end
                        local q = d.Parent
                        local pen = false
                        while q and q ~= pg and not pen do
                            local ln = tostring(q.Name):lower()
                            for _, bad in ipairs(BAD_ANCESTOR) do
                                if ln:find(bad, 1, true) then pen = true break end
                            end
                            q = q.Parent
                        end
                        if pen then score = score + 50 end
                        cands[#cands + 1] = { d = d, label = label, kind = kind, score = score, idx = #cands }
                    end
                end
            end
            table.sort(cands, function(a, b) if a.score ~= b.score then return a.score < b.score end return a.idx < b.idx end)
            for _, c in ipairs(cands) do
                local d = c.d
                add(c.label, function() if d.Parent == nil then return nil end return d.Text end, c.kind, "หน้าจอ " .. pathOf(d, pg))
            end
        end
    end
    return list
end

local function pickKind(list, kind)
    for _, s in ipairs(list) do if s.kind == kind then return s end end
    return nil
end

-- ตัวเลขสั้นๆ : 1234 -> 1.23K , 62000000 -> 62M
local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi" }
local function fmt(v)
    if type(v) == "string" then
        local n = tonumber((v:gsub("[,%$%s]", "")))
        if not n then return v end
        v = n
    end
    if type(v) ~= "number" then return tostring(v) end
    local a, i = math.abs(v), 1
    while a >= 1000 and i < #SUFFIX do a = a / 1000 i = i + 1 end
    local s
    if i == 1 then
        s = (a == math.floor(a)) and string.format("%d", a) or string.format("%.2f", a)
    else
        s = string.format("%.2f", a):gsub("%.?0+$", "") .. SUFFIX[i]
    end
    return (v < 0 and "-" or "") .. s
end

local function clockText(sec)
    sec = math.floor(sec)
    return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60)
end

local RARITY_ORDER = { "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Exclusive" }

-- ข้อความสรุปของแต่ละฟังก์ชัน (แสดงในแดชบอร์ด)
local function moduleText(name)
    local a = api(name)
    if not a then return "ไม่ได้โหลด" end
    local st = a.Status and a.Status() or ""
    if name == "Summon" and a.Stats then
        local s = a.Stats()
        st = string.format("สุ่ม %d ครั้ง (%d ชิ้น) | %s", s.rolls, s.pieces, st:match("^(.-) |") or st)
    elseif name == "Sell" and a.Counts then
        st = string.format("ขายแล้ว %d | %s", a.Counts().sold or 0, st:match("^(.-) |") or st)
    elseif name == "Quest" and a.Claims then
        local c = a.Claims()
        st = string.format("เคลมสำเร็จ %d/%d | Cooldown %d | ยังไม่ได้ %d", c.claimed, c.total, c.cooldown, c.pending)
    end
    return (st:gsub("%s*|%s*$", ""))   -- ตัด " |" ท้ายข้อความที่ไม่มีรายละเอียดต่อ
end

-- ---------- ตัวละครในกระเป๋า (อ่านจากรายการ Inventory ใน UI ไม่ต้องเปิดหน้าต่าง ไม่ยิง Remote) ----------
local RARITY_SET = { basic = "Basic", uncommon = "Uncommon", rare = "Rare", epic = "Epic", legendary = "Legendary", mythic = "Mythic", exclusive = "Exclusive" }
local RARITY_RANK = { Basic = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Exclusive = 7 }
local NAME_KEYS = { "SearchName", "UnitName", "TowerName" }

local function isGuid(s)
    return type(s) == "string" and s:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

local function bagEntry(inst)
    local name, rarity, equipped
    for _, key in ipairs(NAME_KEYS) do
        local ok, v = pcall(function() return inst:GetAttribute(key) end)
        if ok and type(v) == "string" and v ~= "" then name = v break end
    end
    local okR, ra = pcall(function() return inst:GetAttribute("Rarity") end)
    if okR and type(ra) == "string" and RARITY_SET[ra:lower()] then rarity = RARITY_SET[ra:lower()] end
    pcall(function()
        for _, d in ipairs(inst:GetDescendants()) do
            local cls = d.ClassName
            if not rarity then
                if cls == "UIGradient" and RARITY_SET[d.Name:lower()] then rarity = RARITY_SET[d.Name:lower()]
                elseif cls == "TextLabel" then
                    local t = tostring(d.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    if RARITY_SET[t:lower()] then rarity = RARITY_SET[t:lower()] end
                end
            end
            if not equipped and d.Name == "Equipped" then
                local vis = true
                pcall(function() vis = d.Visible end)
                if vis then equipped = true end
            end
        end
    end)
    return name, rarity, equipped and true or false
end

-- คืน { total, kinds, equippedNames, counts = {Rarity = n}, groups = { {name, rarity, count, equipped} ... } } หรือ nil ถ้ายังไม่มี PlayerGui
local function scanBag()
    local pg = LP and LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local items, seen = {}, {}
    local function take(inst)
        if isGuid(inst.Name) and not seen[inst.Name] then
            seen[inst.Name] = true
            local name, rarity, equipped = bagEntry(inst)
            items[#items + 1] = { guid = inst.Name, name = name or "(ไม่ทราบชื่อ)", rarity = rarity, equipped = equipped }
        end
    end
    -- ที่อยู่ที่ยืนยันแล้วของรายการ: Main.Main.Inventory.InventoryFrame.List.ScrollingFrame (มีอยู่แม้ปิดหน้า Inventory)
    local cur = pg
    for _, n in ipairs({ "Main", "Main", "Inventory", "InventoryFrame", "List", "ScrollingFrame" }) do
        cur = cur and cur:FindFirstChild(n)
    end
    if cur then
        for _, c in ipairs(cur:GetChildren()) do take(c) end
    end
    if #items == 0 then   -- ไม่เจอที่อยู่นั้น: ค้นทั้ง PlayerGui (ข้ามชิ้นที่ซ้อนอยู่ในรายการอื่น)
        for _, d in ipairs(pg:GetDescendants()) do
            if isGuid(d.Name) then
                local nested, p = false, d.Parent
                while p and p ~= pg do
                    if isGuid(p.Name) then nested = true break end
                    p = p.Parent
                end
                if not nested then take(d) end
            end
        end
    end
    local groups, byKey, counts, eqNames, kinds = {}, {}, {}, {}, 0
    for _, it in ipairs(items) do
        local key = it.name .. "|" .. (it.rarity or "?")
        local g = byKey[key]
        if not g then
            g = { name = it.name, rarity = it.rarity, count = 0, equipped = 0 }
            byKey[key] = g
            groups[#groups + 1] = g
            kinds = kinds + 1
        end
        g.count = g.count + 1
        if it.equipped then g.equipped = g.equipped + 1 eqNames[#eqNames + 1] = it.name end
        counts[it.rarity or "?"] = (counts[it.rarity or "?"] or 0) + 1
    end
    table.sort(groups, function(a, b)
        local ra, rb = RARITY_RANK[a.rarity or ""] or 0, RARITY_RANK[b.rarity or ""] or 0
        if ra ~= rb then return ra > rb end
        return a.name:lower() < b.name:lower()
    end)
    table.sort(eqNames)
    return { total = #items, kinds = kinds, groups = groups, counts = counts, equippedNames = eqNames }
end

local rarityColors   -- สร้างตอนใช้ครั้งแรก (ไม่ให้สคริปต์ล้มตอนโหลดถ้าไม่มี Color3)
local function rarityColor(r)
    if not rarityColors then
        rarityColors = {}
        pcall(function()
            rarityColors = {
                Basic = Color3.fromRGB(142, 149, 168), Uncommon = Color3.fromRGB(90, 205, 115), Rare = Color3.fromRGB(90, 169, 255),
                Epic = Color3.fromRGB(181, 140, 255), Legendary = Color3.fromRGB(240, 179, 74), Mythic = Color3.fromRGB(245, 85, 115),
                Exclusive = Color3.fromRGB(95, 230, 230),
            }
        end)
    end
    return rarityColors[r]
end

-- ---------- สลับเปิด/ปิดแต่ละฟังก์ชัน ----------
local elevStarted = false
local function setEnabled(name, on)
    enabled[name] = on and true or false
    hlog("toggle" .. name, (on and "เปิด " or "ปิด ") .. (TITLES[name] or name), on and "เริ่มทำงานทันที" or "หยุดทำงานส่วนนี้")
    local a = api(name)
    if not a then return end
    if on then
        if name == "Start" then elevStarted = true end
        if a.Start then pcall(a.Start) end
    else
        if a.Stop then pcall(a.Stop) end
    end
end

-- ---------- ลำดับงานในล็อบบี้ ----------
-- ค่าเริ่มต้น (WaitSummon=false): สุ่ม+ขายเริ่มทันที ลิฟต์ก็ถูกสั่งเริ่มทันทีเช่นกัน แต่ตัวลิฟต์จะรอ StartDelay (10 วิ นับจากรันสคริปต์) ก่อนเข้า+กด Start
-- WaitSummon=true : รอสุ่มจบ + รอขาย SellSettle วิ ก่อนค่อยสั่งลิฟต์ (เพดาน ElevatorAfter วิ)
local idleSince
local cameFromGame = false   -- มาจากการเล่นครบรอบในด่าน (กด OnLeave) = ต้องสุ่มให้หมดก่อนเข้าลิฟต์
local function startElevator(reason)
    elevStarted = true
    HubState.set("phase", "")
    local startApi = api("Start")
    hlog("elev", "เข้าเงื่อนไข: " .. reason .. " -> สั่งโมดูลลิฟต์เริ่มทำงาน", "ลิฟต์จะรอครบ StartDelay (นับจากรันสคริปต์) แล้วเข้าลิฟต์ + กด Start จนวาป")
    pcall(startApi.Start)
end
local function orchestrate()
    if place ~= "lobby" or not enabled.Start or elevStarted then return end
    local startApi = api("Start")
    if not startApi or (startApi.IsRunning and startApi.IsRunning()) then return end
    local t = os.clock() - clock0
    local equipApi = api("Equip")
    if enabled.Equip and equipApi and equipApi.IsRunning and equipApi.IsRunning() then
        hlog("wait_equip", "กำลังใส่ป้อมหลักลง Slot 1 (โมดูล Equip)", "เมื่อเสร็จ จะไปขั้นเข้าลิฟต์ต่อ (ลิฟต์ยังรอครบ StartDelay ด้วย)")
        return
    end
    local questApi = api("Quest")
    if enabled.Quest and questApi and questApi.IsBusy and questApi.IsBusy() then
        hlog("wait_quest", "กำลังเคลมรางวัลเควส (โมดูล Quest) รอบแรก", "เสร็จแล้วค่อยไปขั้นเข้าลิฟต์ต่อ (ลิฟต์ยังรอครบ StartDelay ด้วย)")
        return
    end
    local waitMode = HUB.WaitSummon or cameFromGame
    local cap = cameFromGame and HUB.SummonMaxWait or HUB.ElevatorAfter
    if not waitMode then
        startElevator("ไม่รอสุ่ม/ขาย (WaitSummon=false)")
        return
    end
    local summonApi = api("Summon")
    local summonActive = enabled.Summon and summonApi and summonApi.IsRunning and summonApi.IsRunning()
    if summonActive then
        hlog("wait_summon", "กำลังสุ่มกล่องอยู่", string.format("เมื่อสุ่มจบ (เงินไม่พอ) จะรอขายอีก %d วิ แล้วกลับไป Start ที่ลิฟต์ (เพดานรอ %d วิ นับจากรันสคริปต์)", HUB.SellSettle, cap))
        if cap > 0 and t >= cap then
            startElevator(string.format("รอครบเพดาน %d วิแล้ว สุ่มยังไม่จบ", cap))
        end
        idleSince = nil
        return
    end
    if not idleSince then
        idleSince = os.clock()
        hlog("settle", "สุ่มเสร็จ/ไม่ได้สุ่มแล้ว รอให้ขายของเสร็จ " .. HUB.SellSettle .. " วิ", "ครบเวลานี้แล้วจะสั่งเข้าลิฟต์ + Start")
    end
    if os.clock() - idleSince >= HUB.SellSettle then
        startElevator("รอขายครบ " .. HUB.SellSettle .. " วิหลังสุ่มจบ")
    elseif cap > 0 and t >= cap then
        startElevator(string.format("รอครบเพดาน %d วิแล้ว", cap))
    end
end

-- ---------- แดชบอร์ด ----------
local MAX_BAG_ROWS = 40                              -- แถวกลุ่มตัวละครสูงสุดที่แสดง
local dash = { gui = nil, ui = nil, stats = {}, tab = "overview", mode = "full", lastSt = {} }
local updateData, refreshDashboard                   -- ประกาศล่วงหน้า (ปุ่มของแดชบอร์ดเรียกใช้)
local function setText(lbl, text)
    if lbl and lbl.Text ~= text then lbl.Text = text end
end
local function refreshNow()
    if dash.ui then pcall(refreshDashboard) end
end

-- สถานะของแถวระบบอัตโนมัติ: "off" ปิดอยู่ | "wait" รอคิว | "run" กำลังทำงาน | "idle" ว่าง/เสร็จแล้ว
local function moduleState(name)
    if not enabled[name] then return "off" end
    if name == "Start" and place == "lobby" and not elevStarted then return "wait" end
    local a = api(name)
    return (a and a.IsRunning and a.IsRunning()) and "run" or "idle"
end
local function elevStatusText()
    if not enabled.Start then return "ปิด" end
    local sa = api("Start")
    return (not elevStarted) and "รอขั้นก่อนหน้าเสร็จ" or (sa and sa.Status and (sa.Status():match("^(.-) |") or sa.Status())) or "เริ่มแล้ว"
end

-- สวิตช์หลัก: หยุด/ทำต่อทุกระบบที่โหลดอยู่
local function anyEnabled()
    for _, n in ipairs(loaded) do
        if enabled[n] then return true end
    end
    return false
end
local function pauseAll()
    dash.pausedSet = {}
    for _, n in ipairs(loaded) do
        if enabled[n] then dash.pausedSet[#dash.pausedSet + 1] = n end
    end
    for _, n in ipairs(dash.pausedSet) do setEnabled(n, false) end
end
local function resumeAll()
    local set = (dash.pausedSet and #dash.pausedSet > 0) and dash.pausedSet or loaded
    for _, n in ipairs(set) do
        if n == "Start" and place == "lobby" and not elevStarted then
            enabled.Start = true   -- ยังไม่ถึงคิวเข้าลิฟต์: ให้ตัวคุมเป็นคนสั่งเริ่มตามลำดับเหมือนเดิม
        else
            setEnabled(n, true)
        end
    end
end

-- ---------- สแนปช็อตข้อมูลล็อบบี้ (เงิน/เพชร/กระเป๋า) : เก็บตอนอยู่ล็อบบี้ แล้วโชว์ในด่านด้วย ----------
-- ในด่านไม่มีหน้า Inventory/HUD ของล็อบบี้ให้อ่านสด จึงบันทึกค่าล่าสุดไว้ใน getgenv().LuckyHubSnap + ไฟล์ (ก่อนวาปด้วย) แล้วแสดงพร้อมอายุข้อมูล
local SNAP_FILE, SNAP_MAX_AGE = "LuckyHub_lobby.txt", 86400
local function snapClean(v) return (tostring(v):gsub("[|\r\n]", " ")) end
local function snapEncode(sn)
    local L = { "v1", "ts=" .. tostring(sn.ts) }
    if sn.coins ~= nil then L[#L + 1] = "coins=" .. snapClean(sn.coins) L[#L + 1] = "coinsLabel=" .. snapClean(sn.coinsLabel or "Coins") end
    if sn.gems ~= nil then L[#L + 1] = "gems=" .. snapClean(sn.gems) L[#L + 1] = "gemsLabel=" .. snapClean(sn.gemsLabel or "Gems") end
    for _, g in ipairs(sn.bag or {}) do
        L[#L + 1] = string.format("b=%s|%s|%d|%d", snapClean(g.name), snapClean(g.rarity or "?"), g.count or 0, g.equipped or 0)
    end
    return table.concat(L, "\n")
end
local function snapDecode(text)
    if type(text) ~= "string" then return nil end
    local sn, first = { bag = {} }, true
    for line in text:gmatch("[^\r\n]+") do
        if first then
            if line ~= "v1" then return nil end
            first = false
        else
            local k, v = line:match("^(%w+)=(.*)$")
            if k == "ts" then sn.ts = tonumber(v)
            elseif k == "coins" or k == "gems" or k == "coinsLabel" or k == "gemsLabel" then sn[k] = v
            elseif k == "b" then
                local n, r, c, e = v:match("^(.-)|(.-)|(%d+)|(%d+)$")
                if n then sn.bag[#sn.bag + 1] = { name = n, rarity = (r ~= "?") and r or nil, count = tonumber(c), equipped = tonumber(e) } end
            end
        end
    end
    if not sn.ts then return nil end
    return sn
end
local function snapLoad()
    local sn = G.LuckyHubSnap
    if type(sn) ~= "table" and type(isfile) == "function" and type(readfile) == "function" then
        local ok, txt = pcall(function() if isfile(SNAP_FILE) then return readfile(SNAP_FILE) end end)
        if ok and type(txt) == "string" then sn = snapDecode(txt) end
    end
    if type(sn) ~= "table" or type(sn.ts) ~= "number" then return nil end
    if os.time() - sn.ts > SNAP_MAX_AGE then return nil end
    return sn
end
local function snapToBag(sn)
    local total, eq = 0, {}
    for _, g in ipairs(sn.bag or {}) do
        total = total + (g.count or 0)
        for _ = 1, (g.equipped or 0) do eq[#eq + 1] = g.name end
    end
    table.sort(eq)
    return { total = total, kinds = #(sn.bag or {}), groups = sn.bag or {}, equippedNames = eq, counts = {} }
end
local function ageShort(sec)
    sec = math.max(0, math.floor(sec))
    if sec < 90 then return "<1น." end
    if sec < 3600 then return math.floor(sec / 60) .. "น." end
    return math.floor(sec / 3600) .. "ชม."
end
local snapSig, snapAt = nil, -1e9
-- รวมค่าปัจจุบัน (ค่าที่อ่านไม่ได้ใช้ของเดิมต่อ) แล้วบันทึกเมื่อมีการเปลี่ยนแปลง (ห่างกัน >= 3 วิ) หรือครบ 30 วิ ; force = บันทึกทันที
local function snapSave(force)
    local prev = (type(G.LuckyHubSnap) == "table") and G.LuckyHubSnap or nil
    local sn = { ts = os.time(), coins = prev and prev.coins, coinsLabel = prev and prev.coinsLabel, gems = prev and prev.gems, gemsLabel = prev and prev.gemsLabel, bag = prev and prev.bag or {} }
    local m, g = pickKind(dash.stats, "money"), pickKind(dash.stats, "gems")
    if m then local ok, v = pcall(m.get) if ok and v ~= nil then sn.coins, sn.coinsLabel = tostring(v), m.label end end
    if g then local ok, v = pcall(g.get) if ok and v ~= nil then sn.gems, sn.gemsLabel = tostring(v), g.label end end
    if dash.bag and dash.bag.total > 0 then
        sn.bag = {}
        for _, gr in ipairs(dash.bag.groups) do sn.bag[#sn.bag + 1] = { name = gr.name, rarity = gr.rarity, count = gr.count, equipped = gr.equipped } end
    end
    if sn.coins == nil and sn.gems == nil and #sn.bag == 0 then return end   -- ยังไม่มีข้อมูลอะไรเลย
    local parts = { tostring(sn.coins), tostring(sn.gems) }
    for _, gr in ipairs(sn.bag) do parts[#parts + 1] = gr.name .. "|" .. tostring(gr.rarity) .. "|" .. gr.count .. "|" .. gr.equipped end
    local sig = table.concat(parts, ";")
    local t = os.clock()
    if not force and not ((sig ~= snapSig and t - snapAt >= 3) or t - snapAt >= 30) then return end
    snapSig, snapAt = sig, t
    G.LuckyHubSnap = sn
    if type(writefile) == "function" then pcall(writefile, SNAP_FILE, snapEncode(sn)) end
end
local TAB_DEFS = { { "overview", "ภาพรวม", 62 }, { "bag", "กระเป๋า", 84 }, { "settings", "ตั้งค่า", 56 }, { "system", "ระบบ", 48 } }
local TD_OPTS = { { "skip", "ข้ามเวฟ" }, { "vote", "โหวตโหมด" }, { "speed", "ความเร็วเกม" }, { "replay", "เล่นอีกครั้ง" }, { "leave", "กลับล็อบบี้" } }
local ROW_H = 40   -- ความสูงแถวของรายการระบบอัตโนมัติ

local function buildDashboard()
    local gui = Instance.new("ScreenGui")
    gui.Name = "LuckyHubGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 999
    gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
    dash.gui = gui

    -- หน้าต่างกว้าง ๆ เตี้ย ๆ (เหมาะกับจอมือถือแนวนอน) ปรับตามขนาดจอ
    local W, H = 500, 300
    do
        local vw, vh
        pcall(function() vw, vh = gui.AbsoluteSize.X, gui.AbsoluteSize.Y end)
        if type(vh) ~= "number" or vh <= 0 then pcall(function() local vs = workspace.CurrentCamera.ViewportSize vw, vh = vs.X, vs.Y end) end
        if type(vw) == "number" and vw > 0 then W = math.max(460, math.min(500, math.floor(vw - 16))) end
        if type(vh) == "number" and vh > 0 then H = math.max(236, math.min(300, math.floor(vh - 16))) end
    end
    dash.W, dash.H = W, H
    local HEAD, PAD, GAP, LEFT_W = 44, 14, 12, 168
    local bodyH = H - HEAD - PAD * 2
    local RIGHT_W = W - PAD * 2 - LEFT_W - GAP
    local RX = PAD + LEFT_W + GAP

    local C = Color3.fromRGB
    local th = {
        BG = C(21, 23, 29), SURF = C(29, 32, 41), TABON = C(44, 49, 65),
        TXT = C(236, 238, 244), SUB = C(201, 206, 219), DIM = C(142, 149, 168),
        GREEN = C(70, 199, 154), AMBER = C(240, 179, 74), REDT = C(255, 139, 152), REDBG = C(255, 122, 138),
        OFFSW = C(58, 64, 80), WHITE = C(255, 255, 255), LINE = C(48, 52, 64),
    }
    dash.theme = th
    local BG, SURF, TABON, TXT, SUB, DIM = th.BG, th.SURF, th.TABON, th.TXT, th.SUB, th.DIM
    local GREEN, AMBER, OFFSW, WHITE = th.GREEN, th.AMBER, th.OFFSW, th.WHITE
    local ui = {}

    -- ---------- เครื่องมือสร้างหน้าตา ----------
    local function mk(class, parent, x, y, w, h)
        local o = Instance.new(class)
        o.Position = UDim2.fromOffset(x, y)
        o.Size = UDim2.fromOffset(w, h)
        o.BorderSizePixel = 0
        o.Parent = parent
        return o
    end
    local function round(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = (r == "full") and UDim.new(0.5, 0) or UDim.new(0, r)
        c.Parent = o
    end
    local function stroke(o)
        pcall(function()
            local s = Instance.new("UIStroke")
            s.Color = th.LINE
            s.Thickness = 1
            s.Parent = o
        end)
    end
    local function frame(parent, x, y, w, h, color, r, transp)
        local f = mk("Frame", parent, x, y, w, h)
        f.BackgroundColor3 = color
        f.BackgroundTransparency = transp or 0
        if r then round(f, r) end
        return f
    end
    local function label(parent, str, x, y, w, h, size, color, o)
        local l = mk("TextLabel", parent, x, y, w, h)
        l.BackgroundTransparency = 1
        l.Font = (o and o.bold) and Enum.Font.GothamBold or Enum.Font.GothamMedium
        l.TextSize = math.floor(size)   -- TextSize เป็นจำนวนเต็ม
        l.TextColor3 = color or TXT
        l.TextXAlignment = (o and o.right) and Enum.TextXAlignment.Right or ((o and o.center) and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left)
        if o and o.wrap then
            l.TextWrapped = true
            l.TextYAlignment = Enum.TextYAlignment.Top
        end
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.Text = str
        return l
    end
    local function button(parent, str, x, y, w, h, bg, fn, size, color, transp, r)
        local b = mk("TextButton", parent, x, y, w, h)
        b.BackgroundColor3 = bg
        b.BackgroundTransparency = transp or 0
        b.AutoButtonColor = false
        b.Font = Enum.Font.GothamMedium
        b.TextSize = math.floor(size or 12)
        b.TextColor3 = color or TXT
        b.Text = str
        round(b, r or 8)
        b.MouseButton1Click:Connect(fn)
        return b
    end
    local function switch(parent, x, y, w, h, fn, name)
        local b = mk("TextButton", parent, x, y, w, h)
        b.Name = name
        b.Text = ""
        b.AutoButtonColor = false
        b.BackgroundColor3 = OFFSW
        round(b, "full")
        local k = frame(b, 2, 2, h - 4, h - 4, WHITE, "full")
        b.MouseButton1Click:Connect(fn)
        local sw = { btn = b }
        function sw.set(on)
            on = on and true or false
            if sw.on == on then return end
            sw.on = on
            b.BackgroundColor3 = on and GREEN or OFFSW
            k.Position = UDim2.fromOffset(on and (w - h + 2) or 2, 2)
        end
        sw.set(false)
        return sw
    end
    local function scroller(parent, w, h)
        local s = mk("ScrollingFrame", parent, 0, 0, w, h)
        s.BackgroundTransparency = 1
        s.ScrollBarThickness = 3
        s.ScrollingDirection = Enum.ScrollingDirection.Y
        s.CanvasSize = UDim2.fromOffset(0, 0)
        return s
    end
    local function heading(parent, str, x, y)
        return label(parent, str, x + 2, y, 200, 14, 11, DIM, { bold = true })
    end
    -- รายการ "ชื่อ ... ค่า" เลื่อนได้ (เส้นบางคั่นแถว) ; set({ {label=, value=, tone=} ... })
    local function kvList(parent, x, y, w, h, pitch)
        local box = frame(parent, x, y, w, h, SURF, 10)
        box.ClipsDescendants = true
        local sc = scroller(box, w, h)
        local rows = {}
        local kw = math.floor(w * 0.46)
        local obj = {}
        function obj.set(items)
            for i, it in ipairs(items) do
                local r = rows[i]
                if not r then
                    local ry = (i - 1) * pitch
                    r = {
                        line = frame(sc, 12, ry, w - 24, 1, WHITE, nil, 0.95),
                        k = label(sc, "", 12, ry, kw, pitch, 12, SUB),
                        v = label(sc, "", 12 + kw, ry, w - 24 - kw, pitch, 12, TXT, { right = true, bold = true }),
                    }
                    rows[i] = r
                end
                r.line.Visible = i > 1
                r.k.Visible = true r.v.Visible = true
                setText(r.k, it.label)
                setText(r.v, it.value)
                r.v.TextColor3 = it.tone or TXT
            end
            for i = #items + 1, #rows do
                local r = rows[i]
                r.line.Visible = false
                r.k.Visible = false r.v.Visible = false
                r.k.Text = "" r.v.Text = ""
            end
            sc.CanvasSize = UDim2.fromOffset(0, #items * pitch)
        end
        return obj
    end

    -- ---------- กรอบหน้าต่าง + แถบหัว ----------
    local main = frame(gui, 0, 0, W, H, BG, 14)
    main.Name = "Main"
    main.Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2)   -- กลางจอ
    main.Active = true
    main.Draggable = true
    main.ClipsDescendants = true
    stroke(main)
    ui.main = main

    local setMode, setTab
    local placeName = place == "lobby" and "ล็อบบี้" or place == "game" and "ในด่าน" or "?"
    frame(main, 14, 18, 8, 8, GREEN, "full")
    label(main, "Lucky Hub", 28, 12, 84, 20, 13, TXT, { bold = true })
    local tabsW = 6
    for _, d in ipairs(TAB_DEFS) do tabsW = tabsW + d[3] + 2 end
    tabsW = tabsW - 2
    local tabsX = W - 72 - tabsW
    if tabsX >= 106 + 50 + 6 then   -- จอแคบ: ซ่อนป้ายสถานที่ (ดูได้ในแท็บ "ระบบ")
        local chip = frame(main, 106, 13, 50, 18, WHITE, "full", 0.93)
        label(chip, placeName, 0, 0, 50, 18, 10.5, DIM, { center = true })
    end
    local tabBar = frame(main, tabsX, 8, tabsW, 28, SURF, 9)
    ui.tabs = {}
    local tx = 3
    for _, d in ipairs(TAB_DEFS) do
        local key = d[1]
        local tb = button(tabBar, d[2], tx, 3, d[3], 22, TABON, function() setTab(key) end, 12, DIM, 1, 7)
        tb.Name = "Tab_" .. key
        ui.tabs[key] = tb
        tx = tx + d[3] + 2
    end
    local bMin = button(main, "–", W - 66, 8, 28, 28, BG, function() setMode("mini") end, 15, DIM, 1)
    bMin.Name = "Btn_min"
    local bHide = button(main, "×", W - 38, 8, 28, 28, BG, function() setMode("hidden") end, 15, DIM, 1)
    bHide.Name = "Btn_hide"
    frame(main, 0, HEAD - 1, W, 1, WHITE, nil, 0.94)

    local pages = {}
    for _, d in ipairs(TAB_DEFS) do
        local pf = frame(main, 0, HEAD, W, H - HEAD, BG, nil, 1)
        pf.Name = "Page_" .. d[1]
        pf.Visible = (d[1] == "overview")
        pages[d[1]] = pf
    end

    -- ================= แท็บ ภาพรวม =================
    do
        local ov = pages.overview
        local cardH = math.min(62, math.max(46, math.floor((bodyH - 16 - 60) / 2)))
        local stripH = bodyH - cardH * 2 - 16
        ui.cards = {}
        for i = 1, 2 do
            local cf = frame(ov, PAD, PAD + (i - 1) * (cardH + 8), LEFT_W, cardH, SURF, 10)
            local small = cardH < 56   -- จอเตี้ย: การ์ดเล็กลง ตัวเลขเล็กลงไม่ให้ทับป้ายชื่อ
            local lab = label(cf, "", 12, small and 5 or 7, LEFT_W - 24, 14, 11, DIM)
            local val = label(cf, "", 12, small and 18 or (cardH - 31), LEFT_W - 24, 26, small and 18 or 20, TXT, { bold = true })
            ui.cards[i] = { lab = lab, val = val }
        end
        local sf = frame(ov, PAD, PAD + 2 * (cardH + 8), LEFT_W, stripH, GREEN, 10, 0.92)
        frame(sf, 12, 11, 6, 6, GREEN, "full")
        label(sf, "ตอนนี้", 24, 7, 60, 14, 10.5, DIM)
        ui.upt = label(sf, "00:00:00", LEFT_W - 12 - 72, 7, 72, 14, 10, DIM, { right = true })
        ui.now = label(sf, "", 12, 24, LEFT_W - 24, 30, 12, TXT, { wrap = true })
        ui.nxt = label(sf, "", 12, 56, LEFT_W - 24, 28, 10.5, SUB, { wrap = true })
        if stripH < 80 then ui.nxt.Visible = false end

        heading(ov, "ระบบอัตโนมัติ", RX, PAD - 1)
        ui.onCount = label(ov, "", RX + RIGHT_W - 102, PAD - 1, 100, 14, 11, DIM, { right = true, bold = true })
        local names = {}
        for _, name in ipairs(PLACE_MODULES[place] or {}) do
            if isLoaded[name] and api(name) then names[#names + 1] = name end
        end
        local boxH = math.max(ROW_H, math.min(bodyH - 17, #names * ROW_H))
        local box = frame(ov, RX, PAD + 17, RIGHT_W, boxH, SURF, 10)
        box.ClipsDescendants = true
        local sc = scroller(box, RIGHT_W, boxH)
        ui.rows = {}
        for i, name in ipairs(names) do
            local ry = (i - 1) * ROW_H
            if i > 1 then frame(sc, 12, ry, RIGHT_W - 24, 1, WHITE, nil, 0.95) end
            local sw = switch(sc, 12, ry + 12, 30, 17, function()
                setEnabled(name, not enabled[name])
                refreshNow()
            end, "Switch_" .. name)
            local nm = label(sc, TITLES[name], 52, ry + 5, RIGHT_W - 64, 16, 12.5, TXT)
            local st = label(sc, "", 52, ry + 22, RIGHT_W - 64, 14, 10.5, DIM)
            ui.rows[name] = { sw = sw, name = nm, status = st }
        end
        sc.CanvasSize = UDim2.fromOffset(0, #names * ROW_H)
        if #names == 0 then label(box, "ไม่มีระบบที่เปิดใช้งาน", 12, 12, RIGHT_W - 24, 16, 12, DIM) end
        if place == "game" then   -- ในด่าน: ใต้รายการระบบ มี "ค่าในด่าน" (ความเร็ว, รอบ, เงิน/เพชรล็อบบี้ล่าสุด ฯลฯ)
            local sy = PAD + 17 + boxH + 10
            heading(ov, "ค่าในด่าน", RX, sy)
            ui.statsList = kvList(ov, RX, sy + 17, RIGHT_W, math.max(30, PAD + bodyH - (sy + 17)), 28)
        end
    end

    -- ================= แท็บ กระเป๋า =================
    do
        local bg = pages.bag
        local tot = frame(bg, PAD, PAD, LEFT_W, 74, SURF, 10)
        label(tot, "ตัวละครทั้งหมด", 12, 7, LEFT_W - 24, 14, 11, DIM)
        ui.bagTotal = label(tot, "—", 12, 22, 90, 28, 22, TXT, { bold = true })
        ui.bagUnit = label(tot, "", 40, 31, 30, 16, 11, DIM)
        local barW = LEFT_W - 24
        frame(tot, 12, 56, barW, 6, WHITE, "full", 0.92)
        ui.bagSegs = {}
        for i = 1, 8 do
            local sg = frame(tot, 12, 56, 3, 6, DIM, "full")
            sg.Visible = false
            ui.bagSegs[i] = sg
        end
        ui.bagBarW = barW
        local lg = frame(bg, PAD, PAD + 82, LEFT_W, bodyH - 82, SURF, 10)
        lg.ClipsDescendants = true
        ui.legend = {}
        for i = 1, 8 do
            local ly = 6 + (i - 1) * 18
            local r = {
                dot = frame(lg, 12, ly + 5, 8, 8, DIM, "full"),
                name = label(lg, "", 28, ly, LEFT_W - 28 - 48, 18, 12, SUB),
                n = label(lg, "", LEFT_W - 12 - 40, ly, 40, 18, 12, TXT, { right = true, bold = true }),
            }
            r.dot.Visible = false
            ui.legend[i] = r
        end

        heading(bg, "รายชื่อ", RX, PAD - 1)
        ui.bagAge = label(bg, "", RX + RIGHT_W - 222, PAD - 1, 220, 14, 10.5, DIM, { right = true })
        local lh = bodyH - 17
        local lbox = frame(bg, RX, PAD + 17, RIGHT_W, lh, SURF, 10)
        lbox.ClipsDescendants = true
        local sc = scroller(lbox, RIGHT_W, lh)
        ui.bagMsg1 = label(lbox, "", 12, math.floor(lh / 2) - 22, RIGHT_W - 24, 18, 12.5, TXT, { center = true })
        ui.bagMsg2 = label(lbox, "", 20, math.floor(lh / 2) - 2, RIGHT_W - 40, 30, 10.5, DIM, { center = true, wrap = true })
        ui.bagMsg2.TextXAlignment = Enum.TextXAlignment.Center
        local rows = {}
        local PITCH = 34
        local tagW = 64
        local cntW = 36
        local nameW = RIGHT_W - 12 - tagW - 4 - cntW - 6 - 28
        dash.bagUpdate = function(bag, age)
            local groups = bag and bag.groups or {}
            local m1, m2
            if not bag then
                if place == "game" then
                    m1, m2 = "ยังไม่มีข้อมูลจากล็อบบี้", "เข้าล็อบบี้ 1 ครั้ง ระบบจะเก็บค่าไว้ให้แสดงที่นี่"
                else
                    m1, m2 = "ยังไม่ได้สแกนกระเป๋า", "รอรายการโหลด (สแกนใหม่ทุก 5 วิ)"
                end
            elseif bag.total == 0 then
                if place == "game" then
                    m1, m2 = "ล็อบบี้ยังไม่พบตัวละคร", "เข้าล็อบบี้อีกครั้งเพื่ออัปเดต"
                else
                    m1, m2 = "ไม่พบตัวละครในกระเป๋า", "รายการอาจยังไม่โหลด จะสแกนใหม่เรื่อย ๆ"
                end
            end
            setText(ui.bagMsg1, m1 or "")
            setText(ui.bagMsg2, m2 or "")
            setText(ui.bagAge, bag and bag.total > 0 and (place == "game" and ("ค่าล่าสุดจากล็อบบี้ · " .. (age or "?")) or (bag.kinds .. " ชนิด")) or "")
            ui.bagAge.TextColor3 = place == "game" and AMBER or DIM
            setText(ui.tabs.bag, "กระเป๋า" .. ((bag and bag.total > 0) and (" " .. bag.total) or ""))

            -- สรุปจำนวนต่อระดับความหายาก (นับจากกลุ่ม ใช้ได้ทั้งค่าสดและค่าที่เก็บไว้)
            local counts, present = {}, {}
            local total = 0
            for _, g in ipairs(groups) do
                local rk = g.rarity or "?"
                if not counts[rk] then counts[rk] = 0 present[#present + 1] = rk end
                counts[rk] = counts[rk] + (g.count or 0)
                total = total + (g.count or 0)
            end
            table.sort(present, function(a, b)
                local ra, rb = RARITY_RANK[a] or 0, RARITY_RANK[b] or 0
                if ra ~= rb then return ra > rb end
                return a < b
            end)
            setText(ui.bagTotal, total > 0 and tostring(total) or "—")
            setText(ui.bagUnit, total > 0 and "ตัว" or "")
            ui.bagUnit.Position = UDim2.fromOffset(12 + #tostring(total) * 13 + 4, 31)
            local x = 0
            for i, sgm in ipairs(ui.bagSegs) do
                local rk = present[i]
                if rk and total > 0 then
                    local w = (i == #present) and (ui.bagBarW - x) or math.max(3, math.floor(ui.bagBarW * counts[rk] / total) - 2)
                    sgm.Position = UDim2.fromOffset(12 + x, 56)
                    sgm.Size = UDim2.fromOffset(math.max(3, w), 6)
                    sgm.BackgroundColor3 = rarityColor(rk) or DIM
                    sgm.Visible = true
                    x = x + w + 2
                else
                    sgm.Visible = false
                end
            end
            for i, lr in ipairs(ui.legend) do
                local rk = present[i]
                if rk then
                    lr.dot.BackgroundColor3 = rarityColor(rk) or DIM
                    lr.dot.Visible = true
                    setText(lr.name, rk == "?" and "ไม่ทราบ" or rk)
                    setText(lr.n, tostring(counts[rk]))
                else
                    lr.dot.Visible = false
                    lr.name.Text = "" lr.n.Text = ""
                end
            end

            -- รายชื่อ
            local shown = math.min(#groups, MAX_BAG_ROWS)
            for i = 1, shown do
                local g = groups[i]
                local row = rows[i]
                if not row then
                    local ry = (i - 1) * PITCH
                    row = {
                        line = frame(sc, 12, ry, RIGHT_W - 24, 1, WHITE, nil, 0.95),
                        dot = frame(sc, 12, ry + 13, 8, 8, DIM, "full"),
                        name = label(sc, "", 28, ry, nameW, PITCH, 12.5, TXT),
                        cnt = label(sc, "", RIGHT_W - 12 - tagW - 4 - cntW, ry, cntW, PITCH, 11, DIM, { right = true }),
                        tagBg = frame(sc, RIGHT_W - 12 - tagW, ry + 8, tagW, 18, GREEN, "full", 0.86),
                    }
                    row.tag = label(row.tagBg, "", 0, 0, tagW, 18, 10.5, GREEN, { center = true })
                    rows[i] = row
                end
                row.line.Visible = i > 1
                row.dot.Visible = true row.name.Visible = true row.cnt.Visible = true
                row.dot.BackgroundColor3 = rarityColor(g.rarity or "") or DIM
                setText(row.name, g.name)
                setText(row.cnt, g.count > 1 and ("×" .. g.count) or "")
                local eq = g.equipped or 0
                row.tagBg.Visible = eq > 0
                setText(row.tag, eq > 0 and (eq > 1 and ("ใส่อยู่ ×" .. eq) or "ใส่อยู่") or "")
            end
            for i = shown + 1, #rows do
                local row = rows[i]
                row.line.Visible = false row.dot.Visible = false
                row.name.Visible = false row.cnt.Visible = false row.tagBg.Visible = false
                row.name.Text = "" row.cnt.Text = "" row.tag.Text = ""
            end
            local extra = #groups - shown
            if extra > 0 then
                if not rows.more then
                    rows.more = label(sc, "", 12, MAX_BAG_ROWS * PITCH, RIGHT_W - 24, 24, 10.5, DIM)
                end
                rows.more.Visible = true
                setText(rows.more, "… และอีก " .. extra .. " กลุ่ม")
            elseif rows.more then
                rows.more.Visible = false
                rows.more.Text = ""
            end
            sc.CanvasSize = UDim2.fromOffset(0, shown * PITCH + (extra > 0 and 28 or 0))
        end
        ui.bagScroll = sc
    end

    -- ================= แท็บ ตั้งค่า =================
    do
        local st = pages.settings
        ui.chips = {}
        ui.tdRows = {}
        if place == "lobby" and isLoaded.Sell and api("Sell") then
            heading(st, "ระดับที่ขายอัตโนมัติ", PAD, PAD - 1)
            label(st, "เปิดไว้ = ขายของระดับนั้น", W - PAD - 202, PAD - 1, 200, 14, 10.5, DIM, { right = true })
            local cw = math.floor((W - PAD * 2 - 3 * 8) / 4)
            for i, r in ipairs(RARITY_ORDER) do
                local rr, cc = math.floor((i - 1) / 4), (i - 1) % 4
                local b = button(st, r, PAD + cc * (cw + 8), PAD + 20 + rr * 38, cw, 30, SURF, function()
                    local sell = api("Sell")
                    if sell then sell.SetTier(r, not sell.Config.Tiers[r]) end
                    refreshNow()
                end, 12, DIM, 0, 9)
                frame(b, 10, 11, 8, 8, rarityColor(r) or DIM, "full")
                ui.chips[r] = b
            end
            local my = PAD + 20 + 2 * 38 + 6
            heading(st, "โหมดขาย", PAD, my)
            local segBox = frame(st, PAD, my + 20, 244, 32, SURF, 9)
            ui.segReal = button(segBox, "ขายจริง", 3, 3, 118, 26, TABON, function()
                local sell = api("Sell")
                if sell then sell.SetDryRun(false) end
                refreshNow()
            end, 12, DIM, 1, 7)
            ui.segDry = button(segBox, "ทดลอง", 123, 3, 118, 26, TABON, function()
                local sell = api("Sell")
                if sell then sell.SetDryRun(true) end
                refreshNow()
            end, 12, DIM, 1, 7)
            ui.dryHint = label(st, "", PAD + 254, my + 20, W - PAD * 2 - 254, 32, 10.5, DIM, { wrap = true })
        elseif place == "game" and isLoaded.TD and api("TD") then
            heading(st, "ตัวช่วยในด่าน", PAD, PAD - 1)
            local bh = bodyH - 17
            local box = frame(st, PAD, PAD + 17, W - PAD * 2, bh, SURF, 10)
            box.ClipsDescendants = true
            local sc = scroller(box, W - PAD * 2, bh)
            for i, d in ipairs(TD_OPTS) do
                local key = d[1]
                local ry = (i - 1) * 38
                if i > 1 then frame(sc, 12, ry, W - PAD * 2 - 24, 1, WHITE, nil, 0.95) end
                local sw = switch(sc, 12, ry + 10, 30, 17, function()
                    local a = api("TD")
                    if a then a.Set(key, not a.Opt(key)) end
                    refreshNow()
                end, "Opt_" .. key)
                label(sc, d[2], 52, ry + 4, 200, 16, 12.5, TXT)
                ui.tdRows[key] = { sw = sw, hint = label(sc, "", 52, ry + 20, W - PAD * 2 - 64, 14, 10.5, DIM) }
            end
            sc.CanvasSize = UDim2.fromOffset(0, #TD_OPTS * 38)
        else
            label(st, "ไม่มีตัวเลือกให้ตั้งตอนนี้", PAD, PAD + 40, W - PAD * 2, 18, 12.5, DIM, { center = true })
        end
    end

    -- ================= แท็บ ระบบ =================
    do
        local sy = pages.system
        local mc = frame(sy, PAD, PAD, LEFT_W, 78, SURF, 10)
        label(mc, "ทำงานอัตโนมัติ", 12, 12, 100, 20, 12.5, TXT, { bold = true })
        ui.master = switch(mc, LEFT_W - 12 - 38, 12, 38, 21, function()
            if anyEnabled() then pauseAll() else resumeAll() end
            refreshNow()
        end, "Switch_master")
        ui.masterHint = label(mc, "", 12, 40, LEFT_W - 24, 32, 10.5, DIM, { wrap = true })
        ui.refreshBtn = button(sy, "รีเฟรชข้อมูล", PAD, PAD + bodyH - 74, LEFT_W, 34, TABON, function()
            pcall(updateData, true)
            if place == "game" then dash.snap = snapLoad() or dash.snap end
            dash.bagDirty = true
            refreshNow()
        end, 12.5, TXT, 0, 9)
        ui.stopBtn = button(sy, "หยุดสคริปต์", PAD, PAD + bodyH - 34, LEFT_W, 34, th.REDBG, function()
            local t = os.clock()
            if dash.stopArm and t - dash.stopArm <= 4 then   -- แตะซ้ำภายใน 4 วิ = หยุดจริง (กันกดพลาด)
                if G.LuckyHub and G.LuckyHub.Shutdown then G.LuckyHub.Shutdown() end
                return
            end
            dash.stopArm = t
            refreshNow()
        end, 12.5, th.REDT, 0.88, 9)
        ui.stopBtn.Name = "Btn_stop"
        heading(sy, "รายละเอียด", RX, PAD - 1)
        ui.sysList = kvList(sy, RX, PAD + 17, RIGHT_W, bodyH - 17, 30)
    end

    -- ================= ตอนย่อ (แถบเล็ก) + ปุ่มเรียกกลับตอนซ่อน =================
    local pill = frame(gui, 0, 0, 340, 40, BG, "full")
    pill.Name = "Mini"
    pill.Position = main.Position
    pill.Visible = false
    pill.Active = true
    pill.Draggable = true
    stroke(pill)
    ui.pill = pill
    ui.pillDot = frame(pill, 15, 16, 8, 8, GREEN, "full")
    label(pill, "Lucky Hub", 30, 10, 74, 20, 12.5, TXT, { bold = true })
    frame(pill, 106, 12, 1, 16, WHITE, nil, 0.9)
    ui.pillText = label(pill, "", 116, 10, 122, 20, 12, TXT)
    ui.pillTime = label(pill, "", 240, 10, 56, 20, 11, DIM, { right = true })
    local pExpand = button(pill, "+", 304, 6, 28, 28, TABON, function() setMode("full") end, 15, TXT, 0, "full")
    pExpand.Name = "Btn_expand"

    local dot = mk("TextButton", gui, 0, 0, 34, 34)
    dot.Name = "Restore"
    dot.Text = ""
    dot.AutoButtonColor = false
    dot.BackgroundColor3 = BG
    round(dot, "full")
    stroke(dot)
    dot.Position = main.Position
    dot.Visible = false   -- (ไม่ให้ลากได้: ลากแล้วปล่อยจะนับเป็นการกดเรียกกลับ)
    frame(dot, 12, 12, 10, 10, GREEN, "full")
    dot.MouseButton1Click:Connect(function() setMode("full") end)
    ui.dot = dot

    function setTab(key)
        dash.tab = key
        for k, pf in pairs(pages) do pf.Visible = (k == key) end
        for k, tb in pairs(ui.tabs) do
            local on = (k == key)
            tb.BackgroundTransparency = on and 0 or 1
            tb.TextColor3 = on and TXT or DIM
        end
    end
    -- โหมดหน้าต่าง: full = เต็ม | mini = แถบเล็ก | hidden = ซ่อน (เหลือปุ่มกลมเล็ก ๆ ให้กดเรียกกลับ)
    function setMode(mode)
        local src = (dash.mode == "mini" and pill) or (dash.mode == "hidden" and dot) or main
        local pos = src.Position
        dash.mode = mode
        local dst = (mode == "mini" and pill) or (mode == "hidden" and dot) or main
        dst.Position = pos
        main.Visible = (mode == "full")
        pill.Visible = (mode == "mini")
        dot.Visible = (mode == "hidden")
    end
    dash.setTab, dash.setMode = setTab, setMode
    setTab("overview")
    dash.ui = ui
end

-- อ่านข้อมูล (เงิน/เพชร/กระเป๋า) ตามรอบเวลา ; ทำงานแม้ไม่มีแดชบอร์ด เพื่อให้บันทึกสแนปช็อตได้ ; force = อ่านเดี๋ยวนี้
function updateData(force)
    if force or os.clock() >= (dash.nextScan or 0) then
        dash.stats = discoverStats()
        local m, g = pickKind(dash.stats, "money"), pickKind(dash.stats, "gems")
        local missing = (#dash.stats == 0) or (place == "lobby" and (not m or not g))
        dash.nextScan = os.clock() + (missing and 10 or 30)   -- ยังไม่เจอ: ลองใหม่ทุก 10 วิ ; เจอแล้ว: เช็คใหม่ทุก 30 วิ
        if m then hlog("src_money", "พบ 'เงิน' ที่: " .. m.src) end
        if g then hlog("src_gems", "พบ 'เพชร' ที่: " .. g.src) end
    end
    local moneyS, gemsS = pickKind(dash.stats, "money"), pickKind(dash.stats, "gems")
    if place == "lobby" and os.clock() - clock0 >= 15 then   -- ค้นมา 15 วิแล้วยังไม่เจอ: บอกใน Console
        if not moneyS then hlog("src_money_none", "ยังไม่พบตำแหน่ง 'เงิน' ในล็อบบี้ (ช่องเงินจะขึ้น —)", "รัน lobby_inv_probe.lua แล้วส่งผลมา เพื่อระบุตำแหน่งที่แน่นอน") end
        if not gemsS then hlog("src_gems_none", "ยังไม่พบตำแหน่ง 'เพชร' ในล็อบบี้ (ช่องเพชรจะขึ้น —)", "รัน lobby_inv_probe.lua แล้วส่งผลมา เพื่อระบุตำแหน่งที่แน่นอน") end
    end
    if place == "lobby" and (force or os.clock() >= (dash.nextBag or 0)) then   -- ตัวละครในกระเป๋า: สแกนทุก 5 วิ (อ่านอย่างเดียว)
        dash.nextBag = os.clock() + 5
        local okB, bag = pcall(scanBag)
        if okB then dash.bag = bag end
        dash.bagDirty = true
    end
end

function refreshDashboard()
    local ui = dash.ui
    if not ui then return end
    local th = dash.theme
    local TXT, SUB, DIM, GREEN, AMBER, SURF = th.TXT, th.SUB, th.DIM, th.GREEN, th.AMBER, th.SURF
    local placeName = place == "lobby" and "ล็อบบี้" or place == "game" and "ในด่าน" or "?"
    local up = clockText(os.clock() - clock0)
    setText(ui.upt, up)

    -- ---------- ตัวเลขการ์ด + ค่าอื่น ๆ ----------
    local moneyS, gemsS = pickKind(dash.stats, "money"), pickKind(dash.stats, "gems")
    local function valueText(st)
        local ok, v = pcall(st.get)
        if (not ok or v == nil) and st.src then dash.nextScan = math.min(dash.nextScan or 0, os.clock() + 5) end   -- ค่าหาย (UI ถูกสร้างใหม่) ให้ค้นหาใหม่
        return (ok and v ~= nil) and fmt(v) or "—"
    end
    local function titleOf(st)
        if st.kind == "money" then return "เงิน · " .. st.label end
        if st.kind == "gems" then return "เพชร · " .. st.label end
        return st.label
    end
    local function noValue() return nil end
    local cards, extras = {}, {}
    if place == "lobby" then   -- ล็อบบี้: สองการ์ดคือเงินกับเพชรเสมอ (ไม่เจอขึ้น —)
        cards[1] = moneyS or { label = "Money", kind = "money", get = noValue }
        cards[2] = gemsS or { label = "Gems", kind = "gems", get = noValue }
        for _, st in ipairs(dash.stats) do
            if st ~= moneyS and st ~= gemsS then extras[#extras + 1] = st end
        end
    else
        local rounds = { label = "รอบที่เล่น", get = function()
            local td = api("TD")
            if not td or not td.Rounds then return nil end
            local lim = td.Config and td.Config.LeaveAfterRounds or 0
            return lim > 0 and (td.Rounds() .. "/" .. lim) or td.Rounds()
        end }
        cards[1] = { label = "คลื่น (Wave)", get = function() return workspace:GetAttribute("Wave") end }
        cards[2] = moneyS or rounds
        extras[#extras + 1] = { label = "ความเร็วเกม", get = function() return workspace:GetAttribute("GameSpeed") end }
        if moneyS then extras[#extras + 1] = rounds end
        if gemsS then extras[#extras + 1] = gemsS end
        local sn = dash.snap   -- เงิน/เพชรของล็อบบี้ (ค่าล่าสุดที่เก็บไว้) : ในด่านอ่านสดไม่ได้
        if sn then
            local age = ageShort(os.time() - sn.ts)
            if sn.coins ~= nil then extras[#extras + 1] = { label = "เงินล็อบบี้ · " .. age, get = function() return sn.coins end } end
            if sn.gems ~= nil and not gemsS then extras[#extras + 1] = { label = "เพชรล็อบบี้ · " .. age, get = function() return sn.gems end } end
        end
        for _, st in ipairs(dash.stats) do
            if st ~= moneyS and st ~= gemsS then extras[#extras + 1] = st end
        end
    end
    for i, cd in ipairs(ui.cards) do
        local st = cards[i]
        setText(cd.lab, titleOf(st))
        setText(cd.val, valueText(st))
    end
    if ui.statsList then
        local items = {}
        for _, st in ipairs(extras) do items[#items + 1] = { label = titleOf(st), value = valueText(st) } end
        ui.statsList.set(items)
    end

    -- ---------- แถวระบบอัตโนมัติ ----------
    local onN, total = 0, 0
    for name, row in pairs(ui.rows or {}) do
        total = total + 1
        if enabled[name] then onN = onN + 1 end
        local state = moduleState(name)
        local text = (state == "off") and "ปิดอยู่" or (state == "wait") and "รอขั้นก่อนหน้าเสร็จ" or moduleText(name)
        setText(row.status, text)
        row.status.TextColor3 = (state == "run" and GREEN) or (state == "wait" and AMBER) or (state == "idle" and SUB) or DIM
        row.name.TextColor3 = enabled[name] and TXT or DIM
        row.sw.set(enabled[name])
    end
    setText(ui.onCount, "เปิด " .. onN .. "/" .. total)

    -- ---------- "ตอนนี้ / ถัดไป" : ใช้สถานะล่าสุดที่เปลี่ยนของระบบที่เปิดอยู่ ----------
    for _, name in ipairs(PLACE_MODULES[place] or {}) do
        local a = name ~= "Webhook" and isLoaded[name] and enabled[name] and api(name)   -- แจ้งเตือน Discord ไม่ขึ้นที่ "ตอนนี้/ถัดไป" (ไม่ใช่ขั้นตอนของออโต้ฟาร์ม)
        if a and a.Status then
            local full = a.Status()
            local head = full:match("^(.-) |") or full
            if dash.lastSt[name] ~= head then
                dash.lastSt[name] = head
                dash.latest = (head == "เริ่มทำงาน" or head == "หยุดแล้ว") and (TITLES[name] .. ": " .. head) or head
            end
        end
    end
    local masterOn = anyEnabled()
    local now, nxt
    if not masterOn then
        now, nxt = "หยุดชั่วคราว", "เปิดสวิตช์ที่แท็บระบบเพื่อทำต่อ"
    else
        now = dash.latest or "เริ่มระบบ…"
        if place == "lobby" then
            if enabled.Start and not elevStarted then nxt = "เข้าลิฟต์ + กด Start"
            elseif elevStarted then nxt = "วาปเข้าด่าน"
            else nxt = "—" end
        else
            local td = api("TD")
            local lim = td and td.Config and td.Config.LeaveAfterRounds or 0
            if td and td.Opt and td.Opt("leave") and lim > 0 then
                nxt = string.format("ครบ %d รอบ แล้วกลับล็อบบี้ (ตอนนี้ %d)", lim, td.Rounds and td.Rounds() or 0)
            else
                nxt = "—"
            end
        end
    end
    setText(ui.now, now)
    setText(ui.nxt, "ถัดไป · " .. nxt)

    -- ---------- แท็บกระเป๋า ----------
    if place == "game" and os.clock() >= (dash.nextBagDraw or 0) then   -- ในด่าน: วาดใหม่ทุก 30 วิ ให้อายุข้อมูลเดินตาม
        dash.nextBagDraw = os.clock() + 30
        dash.bagDirty = true
    end
    if dash.bagUpdate and dash.bagDirty then
        dash.bagDirty = false
        if place == "game" then
            local sn = dash.snap
            pcall(dash.bagUpdate, sn and snapToBag(sn) or nil, sn and ageShort(os.time() - sn.ts) or nil)
        else
            pcall(dash.bagUpdate, dash.bag)
        end
    end

    -- ---------- แท็บตั้งค่า ----------
    local sell = api("Sell")
    if sell and ui.segDry then
        for rname, b in pairs(ui.chips) do
            local on = sell.Config.Tiers[rname] and true or false
            b.BackgroundColor3 = on and GREEN or SURF
            b.BackgroundTransparency = on and 0.82 or 0
            b.TextColor3 = on and TXT or DIM
        end
        local dry = sell.Config.DryRun and true or false
        ui.segDry.BackgroundTransparency = dry and 0 or 1
        ui.segDry.TextColor3 = dry and TXT or DIM
        ui.segReal.BackgroundTransparency = dry and 1 or 0
        ui.segReal.TextColor3 = dry and DIM or AMBER
        setText(ui.dryHint, dry and "ทดลอง: ไม่ส่งคำสั่งขายจริง" or "ขายจริง: ของระดับที่เปิดไว้จะถูกขายทันที")
    end
    local td = api("TD")
    if td and td.Opt then
        for key, r in pairs(ui.tdRows) do
            local on = td.Opt(key) and true or false
            local cfg = td.Config or {}
            local hint
            if key == "skip" then hint = "ข้ามเวฟทันทีเมื่อข้ามได้"
            elseif key == "vote" then hint = "โหวตโหมด " .. tostring(cfg.VoteMode or "")
            elseif key == "speed" then hint = "ตั้งความเร็วเกมเป็น ×" .. tostring(cfg.SpeedValue or "")
            elseif key == "replay" then hint = "กดเล่นอีกครั้งหลังจบด่าน"
            else
                local lim = cfg.LeaveAfterRounds or 0
                hint = lim > 0 and ("ครบ " .. lim .. " รอบ แล้วกลับล็อบบี้") or "ไม่จำกัดรอบ"
            end
            r.sw.set(on)
            setText(r.hint, on and hint or "ปิดอยู่")
        end
    end

    -- ---------- แท็บระบบ ----------
    ui.master.set(masterOn)
    setText(ui.masterHint, masterOn and "เปิดอยู่ · ปิดสวิตช์นี้ ทุกระบบจะหยุดรอ" or "หยุดชั่วคราว · เปิดสวิตช์เพื่อทำต่อ")
    local armed = dash.stopArm and (os.clock() - dash.stopArm) <= 4
    if dash.stopArm and not armed then dash.stopArm = nil end
    setText(ui.stopBtn, armed and "แตะอีกครั้งเพื่อหยุด" or "หยุดสคริปต์")
    local planned = #(PLACE_MODULES[place] or {})
    local items = {
        { label = "สถานที่", value = placeName },
        { label = "Place ID", value = tostring(game.PlaceId) },
        { label = "ทำงานมาแล้ว", value = up },
        { label = "โหลดระบบแล้ว", value = #loaded .. " / " .. planned, tone = (#loaded == planned) and GREEN or AMBER },
    }
    if place == "lobby" then
        items[#items + 1] = { label = "ลิฟต์", value = elevStatusText() }
        local sn = (type(G.LuckyHubSnap) == "table") and G.LuckyHubSnap or nil
        items[#items + 1] = { label = "บันทึกข้อมูลล็อบบี้", value = (sn and type(sn.ts) == "number") and ("เมื่อ " .. ageShort(os.time() - sn.ts)) or "ยังไม่มี" }
        for _, st in ipairs(extras) do items[#items + 1] = { label = titleOf(st), value = valueText(st) } end
    else
        local sn = dash.snap
        items[#items + 1] = { label = "ข้อมูลล็อบบี้ล่าสุด", value = sn and ("เมื่อ " .. ageShort(os.time() - sn.ts)) or "ไม่มี", tone = sn and AMBER or DIM }
    end
    ui.sysList.set(items)

    -- ---------- แถบตอนย่อ ----------
    setText(ui.pillText, masterOn and (dash.latest or "เริ่มระบบ…") or "หยุดชั่วคราว")
    setText(ui.pillTime, up)
    ui.pillDot.BackgroundColor3 = masterOn and GREEN or DIM
end

-- ---------- ให้สคริปต์รันต่อเองหลังวาปไปแมพอื่น (ล็อบบี้ <-> ด่าน) ----------
local function queueRerun()
    if HUB.Requeue == false then return end
    local q = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if type(q) ~= "function" then
        hlog("requeue", "executor นี้ไม่มี queue_on_teleport", "ถ้าวาปแล้วสคริปต์หาย ให้วางสคริปต์ไว้ในโฟลเดอร์ autoexec")
        return
    end
    local canFile = type(isfile) == "function" and type(readfile) == "function"
    local code, from
    if canFile and HUB.ScriptFile ~= "" and isfile(HUB.ScriptFile) then
        code, from = string.format("loadstring(readfile(%q))()", HUB.ScriptFile), "ไฟล์ " .. HUB.ScriptFile
    else
        -- ลองอ่านซอร์สของตัวเอง (บาง executor ให้ debug.getinfo(...).source เป็นโค้ดทั้งก้อน)
        local okS, src = pcall(function()
            local info = debug.getinfo(1, "S")
            return info and info.source
        end)
        if okS and type(src) == "string" and #src > 5000 and src:find("LUCKY HUB", 1, true) and type(writefile) == "function" then
            local boot = "lucky_hub_boot.lua"
            local okW = pcall(writefile, boot, src)
            if okW then code, from = string.format("loadstring(readfile(%q))()", boot), "สำเนาตัวเอง (" .. boot .. ")" end
        end
    end
    if not code then
        hlog("requeue", "หาตัวสคริปต์เพื่อรันต่อหลังวาปไม่ได้",
            "บันทึกสคริปต์เป็นไฟล์ workspace/" .. tostring(HUB.ScriptFile) .. " (หรือวางใน autoexec) ไม่งั้นหลังวาปสคริปต์จะหายและต้องรันเอง")
        return
    end
    local ok, err = pcall(q, code)
    if ok then
        hlog("requeue", "ตั้งให้รันสคริปต์ต่ออัตโนมัติหลังวาปแล้ว (จาก " .. from .. ")", "พอวาปไปแมพถัดไป สคริปต์จะรันต่อเอง")
    else
        warn("[LuckyHub] queue_on_teleport ผิดพลาด: " .. tostring(err))
    end
end

-- ---------- เริ่มทำงาน ----------
local stopped = false
local teleConn
if not place or not PLACE_MODULES[place] then
    warn("[LuckyHub] ไม่รู้จักแมพนี้ (PlaceId " .. tostring(game.PlaceId) .. ") รันในล็อบบี้หรือในด่านเกม")
else
    prepareConfigs()
    if place == "lobby" then
        cameFromGame = (HubState.get("phase") == "summon")
        HubState.set("rounds", 0)   -- กลับล็อบบี้แล้ว เริ่มนับรอบใหม่ตอนเข้าด่านรอบหน้า
        if cameFromGame then
            hlog("plan", "กลับมาล็อบบี้หลังเล่นครบรอบ: เคลมรางวัลเควส + ใส่ Speakerman + สุ่มกล่องให้หมด + ขายอัตโนมัติ",
                string.format("เมื่อสุ่มหมด รอขาย %d วิ แล้วกลับไป Start ที่ลิฟต์ (เพดานรอ %d วิ)", HUB.SellSettle, HUB.SummonMaxWait))
        else
            hlog("plan", "แผนในล็อบบี้: เคลมรางวัลเควส + ใส่ Speakerman ลง Slot 1 + สุ่มกล่อง + ขายอัตโนมัติ เริ่มพร้อมกันทันที",
                HUB.WaitSummon and string.format("รอสุ่มจบ + ขาย %d วิ แล้วเข้าลิฟต์ + Start (เพดาน %d วิ)", HUB.SellSettle, HUB.ElevatorAfter)
                    or "รอครบ 10 วิ (นับจากรันสคริปต์) แล้วเข้าลิฟต์ + กด Start (ตั้งได้ที่ StartConfig.StartDelay)")
        end
    else
        if HubState.get("phase") ~= "" then HubState.set("phase", "") end
        hlog("plan", "แผนในด่าน: วางป้อม + อัปเกรดจนตัน แล้วทำ Skip/Vote/Speed/Replay อัตโนมัติ",
            "เริ่มวางป้อมทันที ครบ 10 รอบจะกด OnLeave กลับล็อบบี้ (ตั้งได้ที่ TdAutoConfig.LeaveAfterRounds) ดู log ว่ากำลังทำอะไร")
    end
    queueRerun()
    if place == "game" then
        dash.snap = snapLoad()
        dash.bagDirty = true
        hlog("snap", dash.snap and ("พบข้อมูลล็อบบี้ล่าสุด (อายุ " .. ageShort(os.time() - dash.snap.ts) .. ") แสดงเงิน/เพชร/กระเป๋าในแดชบอร์ด")
            or "ยังไม่มีข้อมูลล็อบบี้ที่เก็บไว้ (เข้าล็อบบี้ 1 ครั้งก่อน)", nil)
    end
    for _, name in ipairs(PLACE_MODULES[place]) do
        if enabled[name] then
            local ok, err = pcall(FNS[name])
            if ok then loaded[#loaded + 1] = name isLoaded[name] = true
            else warn("[LuckyHub] โมดูล " .. name .. " ผิดพลาด: " .. tostring(err)) enabled[name] = false end
        end
    end
    if HUB.Panel then
        local okUi, errUi = pcall(buildDashboard)
        if not okUi then
            warn("[LuckyHub] สร้างแดชบอร์ดไม่สำเร็จ (" .. tostring(errUi) .. ") ฟังก์ชันยังทำงานปกติ")
            if dash.gui then pcall(function() dash.gui:Destroy() end) dash.gui = nil end   -- ไม่ทิ้งหน้าต่างที่สร้างค้างครึ่งเดียว
            dash.ui = nil
        end
    end
    if place == "lobby" then   -- ก่อนวาปไปด่าน: อ่านค่าสดแล้วบันทึกทันที
        pcall(function()
            teleConn = LP.OnTeleport:Connect(function()
                pcall(updateData, true)
                pcall(snapSave, true)
            end)
        end)
    end
    task.spawn(function()
        while not stopped do
            pcall(orchestrate)
            if place == "lobby" or dash.gui then pcall(updateData) end
            if place == "lobby" then pcall(snapSave, false) end
            if dash.gui then
                local ok, err = pcall(refreshDashboard)
                if not ok and not dash.warned then dash.warned = true warn("[LuckyHub] อัปเดตแดชบอร์ดผิดพลาด: " .. tostring(err)) end
            end
            task.wait(1)
        end
    end)
end

G.LuckyHub = {
    Place = place,
    Loaded = loaded,
    Enabled = enabled,
    SetEnabled = setEnabled,
    Refresh = function() if dash.gui then pcall(refreshDashboard) end end,
    Bag = function() return dash.bag end,
    Stats = function() return dash.stats end,
    Snapshot = function() return dash.snap or G.LuckyHubSnap end,
    Show = function() if dash.setMode then dash.setMode("full") end end,   -- เรียกหน้าต่างกลับมา (ถ้าซ่อน/ย่ออยู่)
    Mode = function() return dash.mode end,
    Shutdown = function()
        stopped = true
        if teleConn then pcall(function() teleConn:Disconnect() end) teleConn = nil end
        for _, name in ipairs(loaded) do
            local a = api(name)
            if a and type(a.Shutdown) == "function" then pcall(a.Shutdown) end
        end
        if dash.gui then pcall(function() dash.gui:Destroy() end) dash.gui = nil end
        dash.ui = nil
    end,
}
print("[LuckyHub] แมพ: " .. tostring(place) .. " | โหลดแล้ว: " .. (#loaded > 0 and table.concat(loaded, ", ") or "ไม่มี"))

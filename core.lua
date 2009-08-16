local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

local MAX_AURAS = 10
local BGTEX = "Interface\\AddOns\\clcret\\textures\\minimalist"
local BORDER_WIDTH = 2

-- cleanse spell name, used for gcd
local cleanseSpellName = GetSpellInfo(4987) 			-- cleanse -> 

-- various spell names, used for default settings
local taowSpellName = GetSpellInfo(59578) 				-- the art of war
local awSpellName = GetSpellInfo(31884) 				-- avenging wrath
local dpSpellName = GetSpellInfo(54428)					-- divine plea
local sovName
if UnitFactionGroup("player") == "Alliance" then
	sovName = GetSpellInfo(31803)						-- holy vengeance
else
	sovName = GetSpellInfo(53742)						-- blood corruption
end

-- priority queue generated from fcfs
local pq
-- number of spells in the queue
local numSpells
-- display queue
local dq = {	
	{name = "", cdStart = 0, cdDuration = 0, cd = 0},
	{name = "", cdStart = 0, cdDuration = 0, cd = 0},
}

-- main and secondary skill buttons
local buttons = {}
-- configurable buttons
local auraButtons = {}
local auraIndex

-- addon status
local addonEnabled = false	-- enabled
local addonInit = false		-- init completed
clcret.locked = true		-- main frame locked

-- shortcut for db options
local db

-- the spells used in fcfs
clcret.spells = {
	how		= { id = 48806 },
	cs 		= { id = 35395 },
	ds 		= { id = 53385 },
	jol 	= { id = 53408 },		-- jow
	cons 	= { id = 48819 },
	exo 	= { id = 48801 },
	dp 		= { id = 54428 },
	ss 		= { id = 53601 },
}

-- ---------------------------------------------------------------------------------------------------------------------
-- DEFAULT VALUES
-- ---------------------------------------------------------------------------------------------------------------------
clcret.defaults = {
	char = {
		-- layout settings for the main frame (the black box you toggle on and off)
		x = 500,
		y = 300,
		scale = 1,
		alpha = 1,
		show = "always",
		
		-- fcfs
		fcfs = {
			"how",
			"cs",
			"jol",
			"ds",
			"cons",
			"exo",
			"none",
			"none",
			"none",
			"none",
		},
		
		-- behaviour
		updatesPerSecond = 10,
		updatesPerSecondAuras = 5,
		manaCons = 0,
		manaConsPerc = 0,
		manaDP = 0,
		manaDPPerc = 0,
		loadDelay = 10,
		
		-- layout of the 2 skill button
		layout = {
			button1 = {
				size = 70,
				alpha = 1,
				x = 0,
				y = 0,
				point = "CENTER",
				pointParent = "CENTER",
			},
			button2 = {
				size = 40,
				alpha = 1,
				x = 50,
				y = 0,
				point = "BOTTOMLEFT",
				pointParent = "BOTTOMRIGHT",
			}
		},
		
		-- aura buttons
		-- 4 examples, rest init to "blank" later
		auras = {
			-- 1
			-- avenging wrath
			{
				enabled = true,
				data = {
					exec = "AuraButtonExecSkillVisibleAlways",
					spell = awSpellName,
					texture = "",
					unit = "",
				},
				layout = {
					size = 30,
					x = 0,
					y = 5,
					point = "BOTTOMRIGHT",
					pointParent = "BOTTOMLEFT",
				},
			},
			
			-- 2
			-- divine plea
			{
				enabled = true,
				data = {
					exec = "AuraButtonExecSkillVisibleNoCooldown",
					spell = dpSpellName,
					unit = "",
				},
				layout = {
					size = 30,
					x = -35,
					y = 5,
					point = "BOTTOMRIGHT",
					pointParent = "BOTTOMLEFT",
				},
			},
			
			-- 3
			-- sov
			{
				enabled = true,
				data = {
					exec = "AuraButtonExecGenericDebuff",
					spell = sovName,
					unit = "target",
				},
				layout = {
					size = 30,
					x = 0,
					y = 40,
					point = "BOTTOMRIGHT",
					pointParent = "BOTTOMLEFT",
				},
			},
			
			
			-- 4
			-- taow
			{
				enabled = true,
				data = {
					exec = "AuraButtonExecGenericBuff",
					spell = taowSpellName,
					unit = "player",
				},
				layout = {
					size = 30,
					x = -35,
					y = 40,
					point = "BOTTOMRIGHT",
					pointParent = "BOTTOMLEFT",
				},
			}
		}
	}
}
-- blank rest of the auras buttons in default options
for i = 5, MAX_AURAS do 
	clcret.defaults.char.auras[i] = {
		enabled = false,
		data = {
			exec = "AuraButtonExecNone",
			spell = "",
			unit = "",
		},
		layout = {
			size = 30,
			x = 0,
			y = 0,
			point = "BOTTOM",
			pointParent = "TOP",
		},
	}
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
-- ---------------------------------------------------------------------------------------------------------------------
local throttle = 0
local throttleAuras = 0
local function OnUpdate(this, elapsed)
	throttle = throttle + elapsed
	throttleAuras = throttleAuras + elapsed
	
	if throttle > clcret.scanFrequency then
		throttle = 0
		clcret:CheckQueue()
		clcret:CheckRange()
	end
	
	if throttleAuras > clcret.scanFrequencyAuras then
		throttleAuras = 0
		for i = 1, MAX_AURAS do
			if db.auras[i].enabled then clcret:UpdateAuraButton(i) end
		end
	end
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- INIT
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:OnInitialize()
	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcretDB", self.defaults)
	db = self.db.char
	
	self.scanFrequency = 1 / db.updatesPerSecond
	self.scanFrequencyAuras = 1 / db.updatesPerSecondAuras
	
	self:RegisterChatCommand("rl", ReloadUI)
	self:ScheduleTimer("Init", db.loadDelay)
end
function clcret:Init()
	self:InitSpells()
	self:InitOptions()
	
	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("clcret", self.options)
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions("clcret")
	self:RegisterChatCommand("clcret", function() InterfaceOptionsFrame_OpenToCategory("clcret") end)
	self:RegisterChatCommand("clcreteq", "EditQueue") -- edit the queue from command line
	self:RegisterChatCommand("clcretpq", "DisplayFCFS") -- display the queue
	
	self:UpdateFCFS()
	self:InitUI()
	self:PLAYER_TALENT_UPDATE()
	self:UpdateShowMethod()
	
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:RegisterEvent("UNIT_ENTERED_VEHICLE", "VEHICLE_CHECK")
	self:RegisterEvent("UNIT_EXITED_VEHICLE", "VEHICLE_CHECK")
end
-- get the spell names from ids
function clcret:InitSpells()
	for alias, data in pairs(self.spells) do
		data.name = GetSpellInfo(data.id)
	end
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- FCFS Helpers
-- ---------------------------------------------------------------------------------------------------------------------
-- print fcfs
function clcret:DisplayFCFS()
	for i, data in ipairs(pq) do
		bprint(i .. " " .. data.name)
	end
end

-- make a fcfs from a command line list of arguments
function clcret:EditQueue(args)
	local list = { strsplit(" ", args) }
	
	-- add args to options
	local num = 0
	for i, arg in ipairs(list) do
		if self.spells[arg] then
			num = num + 1
			db.fcfs[num] = arg
		else
			bprint(arg .. " not found")
		end
	end
	
	-- none on the rest
	if num < 10 then
		for i = num + 1, 10 do
			db.fcfs[i] = "none"
		end
	end
	
	-- redo queue
	self:UpdateFCFS()
	self:DisplayFCFS()
end

-- update pq from fcfs
function clcret:UpdateFCFS()
	local newpq = {}
	local check = {}
	numSpells = 0
	
	for i, alias in ipairs(db.fcfs) do
		if not check[alias] then -- take care of double entries
			check[alias] = true
			if alias ~= "none" then
				numSpells = numSpells + 1
				newpq[numSpells] = { alias = alias, name = self.spells[alias].name }
			end
		end
	end
	
	pq = newpq
end
-- ---------------------------------------------------------------------------------------------------------------------



-- ---------------------------------------------------------------------------------------------------------------------
-- SHOW WHEN SETTINGS
-- ---------------------------------------------------------------------------------------------------------------------

-- updates the settings from db and register/unregisters the needed events
function clcret:UpdateShowMethod()
	-- unregister all events first
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UnregisterEvent("UNIT_FACTION")
	-- self:CancelAllTimers()

	if db.show == "combat" then
		if addonEnabled then
			if UnitAffectingCombat("player") then
				self.frame:Show()
			else
				self.frame:Hide()
			end
		end
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		
	elseif db.show == "valid" then
		self:PLAYER_TARGET_CHANGED()
		-- self:ScheduleRepeatingTimer("PLAYER_TARGET_CHANGED", 5) -- small hack till I find out all the events that affect the target
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_FACTION")
	else
		if addonEnabled then
			self.frame:Show()
		end
	end
end

-- out of combat
function clcret:PLAYER_REGEN_ENABLED()
	if not addonEnabled then return end
	self.frame:Hide()
end
-- in combat
function clcret:PLAYER_REGEN_DISABLED()
	if not addonEnabled then return end
	self.frame:Show()
end
-- target change
function clcret:PLAYER_TARGET_CHANGED()
	if not addonEnabled then return end
	if UnitExists("target") and UnitCanAttack("player", "target") and (not UnitIsDead("target")) then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end
-- unit faction changed - test if it gets fired everytime a target switches friend -> enemy
function clcret:UNIT_FACTION(event, unit)
	if unit == "target" then
		self:PLAYER_TARGET_CHANGED()
	end
end

-- disable/enable according to spec
-- use the same function for vehicle check
function clcret:PLAYER_TALENT_UPDATE()
	-- vehicle check
	if UnitUsingVehicle("player") then
		self:Disable()
		return
	end
	
	-- check cs talent
	local _, _, _, _, rank = GetTalentInfo(3, 23)
	if rank == 1 then
		self:Enable()
	else
		self:Disable()
	end
end

-- check if we need to update vehicle status
function clcret:VEHICLE_CHECK(event, unit)
	if unit == "player" then
		self:PLAYER_TALENT_UPDATE()
	end
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- UPDATE FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------

-- updates the 2 skill buttons
function clcret:UpdateUI()
	-- queue
	for i = 1, 2 do
		local button = buttons[i]
		button.texture:SetTexture(GetSpellTexture(dq[i].name))
			
		if dq[i].cd > 0 then
				button.cooldown:SetCooldown(dq[i].cdStart, dq[i].cdDuration)
				button.cooldown:Show()
		else
				button.cooldown:Hide()
		end
	end
end

-- calls the exec function for a specific aura button
function clcret:UpdateAuraButton(index)
	-- TODO: check docs to see how it's done properly
	auraIndex = index
	self[db.auras[index].data.exec]()
end

-- just show the button for positioning
function clcret:AuraButtonExecNone(index)
	auraButtons[auraIndex]:Show()
end

-- shows a skill use always with a visible cooldown when needed
function clcret:AuraButtonExecSkillVisibleAlways()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end
	
	button:Show()
	
	if IsUsableSpell(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	local start, duration = GetSpellCooldown(data.spell)
	if start ~= button.start then 
		button.start = start
		button.duration = duration
		local cd = start + duration - GetTime()
		if cd > 0 then
				button.cooldown:SetCooldown(start, duration)
				button.cooldown:Show()
		else
				button.cooldown:Hide()
		end
	end
end

-- shows a skill only when out of cooldown
function clcret:AuraButtonExecSkillVisibleNoCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end

	local start, duration = GetSpellCooldown(data.spell)
	
	if IsUsableSpell(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	if duration > 1.6 then
		button:Hide()
	else
		button:Show()
	end
end

-- checks for a buff cast by player on specified unit
function clcret:AuraButtonExecGenericBuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not UnitExists(data.unit) then
		button:Hide()
		return
	end
	
	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitBuff(data.unit, data.spell)
	if name and (caster == "player") then 
		-- found the debuff
		-- update only if it changes
		if button.expirationTime ~= expirationTime then
			button.expirationTime = expirationTime
			button.cooldown:SetCooldown(expirationTime - duration, duration)
		end
		
		-- fix texture once
		if not button.hasTexture then
			button.texture:SetTexture(icon)
			button.hasTexture = true
		end
		
		button:Show()
		
		if count > 1 then
			button.stack:SetText(count)
			button.stack:Show()
		else
			button.stack:Hide()
		end
	else
		button:Hide()
	end
end

-- checks for a debuff cast by player on specified unit
function clcret:AuraButtonExecGenericDebuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not UnitExists(data.unit) then
		button:Hide()
		return
	end
	
	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(data.unit, data.spell)
	if name and (caster == "player") then 
		-- found the debuff
		-- update only if it changes
		if button.expirationTime ~= expirationTime then
			button.expirationTime = expirationTime
			button.cooldown:SetCooldown(expirationTime - duration, duration)
		end
		
		-- fix texture once
		if not button.hasTexture then
			button.texture:SetTexture(icon)
			button.hasTexture = true
		end
		
		button:Show()
		
		if count > 1 then
			button.stack:SetText(count)
			button.stack:Show()
		else
			button.stack:Hide()
		end
	else
		button:Hide()
	end
end

-- melee range check
function clcret:CheckRange()
	local range = IsSpellInRange(self.spells["cs"].name, "target")	
	if range ~= nil and range == 0 then
		for i = 1, 2 do
			buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
		end
	else
		for i = 1, 2 do
			buttons[i].texture:SetVertexColor(1, 1, 1)
		end
	end
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- QUEUE LOGIC
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:CheckQueue()
	local mana, manaPerc, ctime, gcd, gcdStart, gcdDuration, v
	ctime = GetTime()
	
	mana = UnitPower("player")
	manaPerc = floor( mana * 100 / UnitPowerMax("player") + 0.5)
	
	-- get gcd
	gcdStart, gcdDuration = GetSpellCooldown(cleanseSpellName)
	gcd = max(0, gcdStart + gcdDuration - ctime)
	
	-- update cooldowns
	for i=1, numSpells do
		v = pq[i]
		
		v.cdStart, v.cdDuration = GetSpellCooldown(v.name)
		if v.cdStart == nil then return end -- try to solve respec issues
		
		v.cd = max(0, v.cdStart + v.cdDuration - ctime)
		
		-- how check
		if v.alias == "how" then
			if not IsUsableSpell(v.name) then v.cd = 100 end
		-- art of war for exorcism check
		elseif v.alias == "exo" then
			if UnitBuff("player", taowSpellName) == nil then v.cd = 100 end
		-- consecration min mana
		elseif v.alias == "cons" then
			if (db.manaCons > 0 and mana < db.manaCons) or (db.manaConsPerc and manaPerc < db.manaConsPerc) then v.cd = 100 end
		-- divine plea max mana
		elseif v.alias == "dp" then
			if (db.manaDP > 0 and mana > db.manaDP) or (db.manaDPPerc > 0 and manaPerc > db.manaDPPerc) then v.cd = 100 end
		end
		
		-- v.xcd = v.cd
		v.xcd = v.cd - gcd
	end

	self:GetBest(1)
	self:GetBest(2)
	
	self:UpdateUI()
end
-- gets best skill from pq according to priority and cooldown
function clcret:GetBest(pos)
	local xcd, xindex, v
	xindex = 1
	xcd = pq[1].xcd
	
	for i = 1, numSpells do
		v = pq[i]
		if v.xcd < xcd or (v.xcd == xcd and i < xindex) then
			xindex = i
			xcd = v.xcd
		end
		v.xcd = max(0, v.xcd - 1.5)
	end
	self:QD(pos, xindex)
	pq[xindex].xcd = 1000
end
-- safe copy 
function clcret:QD(i, j)
	dq[i].name = pq[j].name
	dq[i].cdStart = pq[j].cdStart
	dq[i].cdDuration = pq[j].cdDuration
	dq[i].cd = pq[j].cd
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- ENABLE/DISABLE
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:Enable()
	if addonInit then
		addonEnabled = true
		self.frame:Show()
	end
end

function clcret:Disable()
	if addonInit then
		addonEnabled = false
		self.frame:Hide()
	end
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- UPDATE LAYOUT
-- ---------------------------------------------------------------------------------------------------------------------

-- toggle main frame for drag
function clcret:ToggleLock()
	if self.locked then
		self.locked = false
		self.frame:EnableMouse(true)
		self.frame.texture:Show()
	else
		self.locked = true
		self.frame:EnableMouse(false)
		self.frame.texture:Hide()
	end
end

-- center the main frame
function clcret:CenterHorizontally()
	db.x = (UIParent:GetWidth() - clcretFrame:GetWidth() * db.scale) / 2 / db.scale
	self:UpdateFrameSettings()
end

-- update size, width, position, alpha for main buttons 
function clcret:UpdateSkillButtonsLayout()
	clcretFrame:SetWidth(db.layout.button1.size + 10)
	clcretFrame:SetHeight(db.layout.button1.size + 10)
	
	for i = 1, 2 do
		local button = buttons[i]
		local opt = db.layout["button" .. i]
		button:SetWidth(opt.size)
		button:SetHeight(opt.size)
		button:SetAlpha(opt.alpha)
		button:ClearAllPoints()
		button:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
		
		-- adjust border
		button.topBorder:SetWidth(opt.size)
		button.bottomBorder:SetWidth(opt.size)
		button.leftBorder:SetHeight(opt.size)
		button.rightBorder:SetHeight(opt.size)	
	end
end

-- update size, width, position for aura buttons
function clcret:UpdateAuraButtonLayout(index)
	local button = auraButtons[index]
	local opt = db.auras[index].layout
	button:SetWidth(opt.size)
	button:SetHeight(opt.size)
	button:ClearAllPoints()
	button:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
	
	-- adjust border
	button.topBorder:SetWidth(opt.size)
	button.bottomBorder:SetWidth(opt.size)
	button.leftBorder:SetHeight(opt.size)
	button.rightBorder:SetHeight(opt.size)	
end

-- update scale, alpha, position for main frame
function clcret:UpdateFrameSettings()
	self.frame:SetScale(db.scale)
	self.frame:SetAlpha(db.alpha)
	self.frame:SetPoint("BOTTOMLEFT", db.x, db.y)
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- INIT LAYOUT
-- ---------------------------------------------------------------------------------------------------------------------

-- initialize main frame and all the buttons
function clcret:InitUI()
	local frame = CreateFrame("Frame", "clcretFrame", UIParent)
	frame:SetWidth(db.layout.button1.size + 10)
	frame:SetHeight(db.layout.button1.size + 10)
	frame:SetPoint("BOTTOMLEFT", db.x, db.y)
	
	frame:EnableMouse(false)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		db.x = clcretFrame:GetLeft()
		db.y = clcretFrame:GetBottom()
	end)
	
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetTexture(BGTEX)
	texture:SetVertexColor(0, 0, 0, 1)
	texture:Hide()
	frame.texture = texture

	self.frame = frame
	
	-- queue
	local opt
	for i = 1, 2 do
		opt = db.layout["button" .. i]
		buttons[i] = self:CreateButton("B2", opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
		buttons[i]:SetAlpha(opt.alpha)
		buttons[i]:Show()
	end
	
	self:InitAuraButtons()
	
	frame:SetScale(db.scale)
	
	addonInit = true
	self:Disable()
	self.frame:SetScript("OnUpdate", OnUpdate)
end

-- initialize aura buttons
function clcret:InitAuraButtons()
	local data, layout
	for i = 1, 10 do
		data = db.auras[i].data
		layout = db.auras[i].layout
		auraButtons[i] = self:CreateButton("aura"..i, layout.size, layout.point, clcretFrame, layout.pointParent, layout.x, layout.y, true)
		auraButtons[i].start = 0
		auraButtons[i].duration = 0
		auraButtons[i].expirationTime = 0
		auraButtons[i].hasTexture = false
	end
end

-- create button
function clcret:CreateButton(name, size, point, parent, pointParent, offsetx, offsety, hasStack)
	local button = CreateFrame("Frame", "clcret"..name, parent)
	button:SetWidth(size)
	button:SetHeight(size)
	button:SetPoint(point, parent, pointParent, offsetx, offsety)
	
	local texture = button:CreateTexture(nil,"BACKGROUND")
	texture:SetAllPoints(button)
	texture:SetTexture(BGTEX)
	texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	button.texture = texture
	
	-- border
	local line
	-- top BORDER_WIDTH
	line = button:CreateTexture(nil, "ARTWORK")
	line:SetTexture(BGTEX)
	line:SetVertexColor(0, 0, 0, 1)
	line:SetWidth(size)
	line:SetHeight(BORDER_WIDTH)
	line:SetPoint("TOP", 0, 0)
	button.topBorder = line
	
	-- bottom line
	line = button:CreateTexture(nil, "ARTWORK")
	line:SetTexture(BGTEX)
	line:SetVertexColor(0, 0, 0, 1)
	line:SetWidth(size)
	line:SetHeight(BORDER_WIDTH)
	line:SetPoint("BOTTOM", 0, 0)
	button.bottomBorder = line
	
	-- left line
	line = button:CreateTexture(nil, "ARTWORK")
	line:SetTexture(BGTEX)
	line:SetVertexColor(0, 0, 0, 1)
	line:SetWidth(BORDER_WIDTH)
	line:SetHeight(size)
	line:SetPoint("LEFT", 0, 0)
	button.leftBorder = line
	
	-- right line
	line = button:CreateTexture(nil, "ARTWORK")
	line:SetTexture(BGTEX)
	line:SetVertexColor(0, 0, 0, 1)
	line:SetWidth(BORDER_WIDTH)
	line:SetHeight(size)
	line:SetPoint("RIGHT", 0, 0)
	button.rightBorder = line
	
	local cooldown = CreateFrame("Cooldown", "$parentCooldown", button)
	cooldown:SetAllPoints(button)
	cooldown:Hide()
	button.cooldown = cooldown
	
	if hasStack then
		local stack = cooldown:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
		local fontFace, _, fontFlags = stack:GetFont()
		stack:SetFont(fontFace, 15, fontFlags)
		stack:SetPoint("BOTTOMRIGHT", 3, -3)
		stack:Hide()
		button.stack = stack
	end
	
	button:Hide()	
	return button
end
-- ---------------------------------------------------------------------------------------------------------------------


-- 2 small helper functions
function clcret:AuraButtonResetTexture(index)
	auraButtons[index].hasTexture = false
end

function clcret:AuraButtonHide(index)
	auraButtons[index]:Hide()
end

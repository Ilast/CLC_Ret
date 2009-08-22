local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

local MAX_AURAS = 10
local MAX_SOVBARS = 5
local BGTEX = "Interface\\AddOns\\clcret\\textures\\minimalist"
local BORDERTEX = "Interface\\AddOns\\clcret\\textures\\border"

-- cleanse spell name, used for gcd
local cleanseSpellName = GetSpellInfo(4987) 			-- cleanse -> 

-- various spell names, used for default settings
local taowSpellName = GetSpellInfo(59578) 				-- the art of war
local awSpellName = GetSpellInfo(31884) 				-- avenging wrath
local dpSpellName = GetSpellInfo(54428)					-- divine plea
local sovName, sovId, sovTextureSpell
if UnitFactionGroup("player") == "Alliance" then
	sovId = 31803
	sovName = GetSpellInfo(31803)						-- holy vengeance
	sovTextureSpell = GetSpellInfo(31801)
else
	sovId = 53742
	sovName = GetSpellInfo(53742)						-- blood corruption
	sovTextureSpell = GetSpellInfo(53736)
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
local enabledAuraButtons
local numEnabledAuraButtons 
local auraIndex
-- bars for sov tracking
local sovBars = {}
local MAX_SOVBARS = 5
local sovAnchor
clcret.showSovAnchor = false

-- addon status
local addonEnabled = false			-- enabled
local addonInit = false				-- init completed
clcret.locked = true				-- main frame locked

-- shortcut for db options
local db

-- used for sov tracking
local playerName

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
		-- layout settings for the main frame (the black box you toggle on and off)\
		zoomIcons = true,
		noBorder = false,
		borderColor = {0, 0, 0, 1},
		x = 500,
		y = 300,
		scale = 1,
		alpha = 1,
		show = "always",
		fullDisable = false,
		
		lbf = {
			Skills = {},
			Auras = {},
		},
		
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
		
		-- behavior
		updatesPerSecond = 10,
		updatesPerSecondAuras = 5,
		manaCons = 0,
		manaConsPerc = 0,
		manaDP = 0,
		manaDPPerc = 0,
		gcdDpSs = 0,
		delayedStart = 5,
		
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
					unit = "",		-- target
					byPlayer = true,	
				},
				layout = {
					size = 30,
					x = 0,
					y = 5,
					alpha = 1,
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
					byPlayer = true,
				},
				layout = {
					size = 30,
					x = -35,
					y = 5,
					alpha = 1,
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
					byPlayer = true,					
				},
				layout = {
					size = 30,
					x = 0,
					y = 40,
					alpha = 1,
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
					byPlayer = true,
				},
				layout = {
					size = 30,
					x = -35,
					y = 40,
					alpha = 1,
					point = "BOTTOMRIGHT",
					pointParent = "BOTTOMLEFT",
				},
			}
		},
		
		-- Sov bars
		sov = {
			enabled = false,
			width = 200,
			height = 15,
			spacing = 5,
			color = {1, 1, 0, 1},
			point = "TOP",
			pointParent = "BOTTOM",
			x = 0,
			y = 0,
			growth = "down",
			updatesPerSecond = 20,
			colorNonTarget = {1, 1, 0, 1},
			targetDifference = false,
			useButtons = false,
		},
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
			byPlayer = true,
		},
		layout = {
			size = 30,
			x = 0,
			y = 0,
			alpha = 1,
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
local throttleSov = 0
local function OnUpdate(this, elapsed)
	throttle = throttle + elapsed
	if throttle > clcret.scanFrequency then
		throttle = 0
		clcret:CheckQueue()
		clcret:CheckRange()
	end
	
	throttleAuras = throttleAuras + elapsed
	if throttleAuras > clcret.scanFrequencyAuras then
		throttleAuras = 0
		for i = 1, numEnabledAuraButtons do
			-- TODO: check docs to see how it's done properly
			auraIndex = enabledAuraButtons[i]
			clcret[db.auras[auraIndex].data.exec]()
		end
	end
	
	if db.sov.enabled then
		throttleSov = throttleSov + elapsed
		if throttleSov > clcret.scanFrequencySov then
			throttleSov = 0
			clcret:UpdateSovBars()
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

	self:ScheduleTimer("Init", db.delayedStart)
end
function clcret:Init()
	-- get player name for sov tracking 
	playerName = UnitName("player")
	
	self.LBF = LibStub('LibButtonFacade', true)
	
	-- update rates
	self.scanFrequency = 1 / db.updatesPerSecond
	self.scanFrequencyAuras = 1 / db.updatesPerSecondAuras
	self.scanFrequencySov = 1 / db.sov.updatesPerSecond

	self:InitSpells()
	self:InitOptions()
	
	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("clcret", self.options)
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions("clcret")
	self:RegisterChatCommand("clcret", function() InterfaceOptionsFrame_OpenToCategory("clcret") end)
	self:RegisterChatCommand("clcreteq", "EditQueue") -- edit the queue from command line
	self:RegisterChatCommand("clcretpq", "DisplayFCFS") -- display the queue
	
	self:UpdateEnabledAuraButtons()
	
	self:UpdateFCFS()
	self:InitUI()
	self:PLAYER_TALENT_UPDATE()
	
	if self.LBF then
		self.LBF:RegisterSkinCallback('clcret', self.OnSkin, self)
		self.LBF:Group("clcret", "Skills"):Skin(unpack(db.lbf.Skills))
		self.LBF:Group("clcret", "Auras"):Skin(unpack(db.lbf.Auras))
	end
	
	if not db.fullDisable then
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", "VEHICLE_CHECK")
		self:RegisterEvent("UNIT_EXITED_VEHICLE", "VEHICLE_CHECK")
	end
	
	-- init sov bars
	-- TODO: Make it dynamic later
	self:InitSovBars()
	if db.sov.enabled then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end
-- get the spell names from ids
function clcret:InitSpells()
	for alias, data in pairs(self.spells) do
		data.name = GetSpellInfo(data.id)
	end
end
function clcret:OnSkin(skin, glossAlpha, gloss, group, _, colors)
	local styleDB
	if group == 'Skills' then
		styleDB = db.lbf.Skills
	elseif group == 'Auras' then
		styleDB = db.lbf.Auras
	end

	if styleDB then
		styleDB[1] = skin
		styleDB[2] = glossAlpha
		styleDB[3] = gloss
		styleDB[4] = colors
	end
	
	self:UpdateAuraButtonsLayout()
	self:UpdateSkillButtonsLayout()
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
		
	elseif db.show == "valid" or db.show == "boss" then
		self:PLAYER_TARGET_CHANGED()
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
	
	if db.show == "boss" then
		if UnitClassification("target") ~= "worldboss" then
			self.frame:Hide()
			return
		end
	end
	
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
	if db.fullDisable then
		self:Disable()
		return
	end

	-- vehicle check
	if UnitUsingVehicle("player") then
		self:Disable()
		return
	end
	
	-- check cs talent
	local _, _, _, _, rank = GetTalentInfo(3, 23)
	if rank == 1 then
		self:Enable()
		self:UpdateShowMethod()
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
			
		if dq[i].cdDuration > 0 then
			button.cooldown:SetCooldown(dq[i].cdStart, dq[i].cdDuration)
		end
	end
end

-- just show the button for positioning
function clcret:AuraButtonExecNone(index)
	auraButtons[auraIndex]:Show()
end

-- shows a skill always with a visible cooldown when needed
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
	if duration > 0 then
		button.cooldown:SetCooldown(start, duration)
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
	
	if duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
end

-- shows an equiped usable item always with a visible cooldown when needed
function clcret:AuraButtonExecItemVisibleAlways()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- hide the item if is not equiped
	if not IsEquippedItem(data.spell) then
		button:Hide()
		return
	end
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetItemIcon(data.spell))
	end
	
	button:Show()
	
	if IsUsableItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	local start, duration = GetItemCooldown(data.spell)
	if duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	end

end

-- shows shows an equiped usable item only when out of cooldown
function clcret:AuraButtonExecItemVisibleNoCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- hide the item if is not equiped
	if not IsEquippedItem(data.spell) then
		button:Hide()
		return
	end
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetItemIcon(data.spell))
	end

	local start, duration = GetItemCooldown(data.spell)
	
	if IsUsableItem(data.spell) then
		button.texture:SetVertexColor(1, 1, 1, 1)
	else
		button.texture:SetVertexColor(0.3, 0.3, 0.3, 1)
	end
	
	if duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
end

-- checks for a buff by player (or someone) on unit
function clcret:AuraButtonExecGenericBuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not UnitExists(data.unit) then
		button:Hide()
		return
	end
	
	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitBuff(data.unit, data.spell)
	if name then
		if data.byPlayer and (caster ~= "player") then
			-- player required and not found
			button:Hide()
		else
			-- found the debuff
			if duration > 0 then
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
		end
	else
		button:Hide()
	end
end

-- checks for a debuff cast by player (or someone) on unit
function clcret:AuraButtonExecGenericDebuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not UnitExists(data.unit) then
		button:Hide()
		return
	end
	
	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitDebuff(data.unit, data.spell)
	if name then
		if data.byPlayer and (caster ~= "player") then
			button:Hide()
		else
			-- found the debuff
			if duration > 0 then
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
			if (db.manaDP > 0 and mana > db.manaDP) or (db.manaDPPerc > 0 and manaPerc > db.manaDPPerc) then
				v.cd = 100
			else
				v.cd = v.cd + db.gcdDpSs
			end
		elseif v.alias == "ss"then
			v.cd = v.cd + db.gcdDpSs
		end
		
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
		if db.gcdDpSs > 0 then
			if not (v.alias == "dp" or v.alias == "ss") then
				v.xcd = max(0, v.xcd - 1.5)
			end
		else
			v.xcd = max(0, v.xcd - 1.5)
		end
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

-- update for aura buttons 
function clcret:UpdateSkillButtonsLayout()
	clcretFrame:SetWidth(db.layout.button1.size + 10)
	clcretFrame:SetHeight(db.layout.button1.size + 10)
	
	for i = 1, 2 do
		self:UpdateButtonLayout(buttons[i], db.layout["button" .. i])
	end
end
-- update aura buttons 
function clcret:UpdateAuraButtonsLayout()
	for i = 1, MAX_AURAS do
		self:UpdateButtonLayout(auraButtons[i], db.auras[i].layout)
	end
end
-- update aura for a single button (tmp use in options)
function clcret:UpdateAuraButtonLayout(index)
	self:UpdateButtonLayout(auraButtons[index], db.auras[index].layout)
end
-- update a given button
function clcret:UpdateButtonLayout(button, opt)
	local scale = opt.size / button.defaultSize
	button:SetScale(scale)
	button:ClearAllPoints()
	button:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x / scale, opt.y / scale)
	button:SetAlpha(opt.alpha)
	button.border:SetVertexColor(unpack(db.borderColor))
	
	button.stack:ClearAllPoints()
	button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, 0)
	
	if db.zoomIcons then
		button.texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	else
		button.texture:SetTexCoord(0, 1, 0, 1)
	end
	
	if db.noBorder then
		button.border:Hide()
	else
		button.border:Show()
	end
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
	
	-- init the buttons
	local opt
	for i = 1, 2 do
		opt = db.layout["button" .. i]
		buttons[i] = self:CreateButton("SB" .. i, opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y, "Skills")
		buttons[i]:SetAlpha(opt.alpha)
		buttons[i]:Show()
	end
	self:InitAuraButtons()
	
	-- set scale
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
		auraButtons[i] = self:CreateButton("aura"..i, layout.size, layout.point, clcretFrame, layout.pointParent, layout.x, layout.y, "Auras")
		auraButtons[i].start = 0
		auraButtons[i].duration = 0
		auraButtons[i].expirationTime = 0
		auraButtons[i].hasTexture = false
	end
end

-- create button
function clcret:CreateButton(name, size, point, parent, pointParent, offsetx, offsety, bfGroup)
	name = "clcret" .. name
	local button = CreateFrame("Button", name , parent)
	button:EnableMouse(false)
	
	button:SetWidth(64)
	button:SetHeight(64)
	
	button.texture = button:CreateTexture("$parentIcon", "BACKGROUND")
	button.texture:SetAllPoints()
	button.texture:SetTexture(BGTEX)
	
	button.border = button:CreateTexture(nil, "BACKGROUND") -- not $parentBorder so it can work when bf is enabled
	button.border:SetAllPoints()
	button.border:SetTexture(BORDERTEX)
	button.border:SetVertexColor(unpack(db.borderColor))
	
	button.cooldown = CreateFrame("Cooldown", "$parentCooldown", button)
	button.cooldown:SetAllPoints(button)
	
	button.stack = button:CreateFontString("$parentCount", "HIGHLIGHT", "TextStatusBarText")
	local fontFace, _, fontFlags = button.stack:GetFont()
	button.stack:SetFont(fontFace, 30, fontFlags)
	button.stack:SetJustifyH("RIGHT")
	button.stack:ClearAllPoints()
	button.stack:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 4, 0)
	
	button.defaultSize = button:GetWidth()
	local scale = size / button.defaultSize
	button:SetScale(scale)
	button:ClearAllPoints()
	button:SetPoint(point, parent, pointParent, offsetx / scale, offsety / scale)
	
	if self.LBF then
		self.LBF:Group("clcret", bfGroup):AddButton(button)
	end
	
	if db.zoomIcons then
		button.texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	end
	
	if db.noBorder then
		button.border:Hide()
	end
	
	button:Hide()
	return button
end
-- ---------------------------------------------------------------------------------------------------------------------

-- ---------------------------------------------------------------------------------------------------------------------
-- FULL DISABLE
-- TODO: Unregister/Register all events here ?
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:FullDisableToggle()
	if db.fullDisable then
		-- enabled
		db.fullDisable = false
		
		-- register events
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:RegisterEvent("UNIT_ENTERED_VEHICLE", "VEHICLE_CHECK")
		self:RegisterEvent("UNIT_EXITED_VEHICLE", "VEHICLE_CHECK")
		
		if db.sov.enabled then
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
		
		-- do the normal load rutine
		self:PLAYER_TALENT_UPDATE()
	else
		-- disabled
		db.fullDisable = true
		
		-- unregister events
		self:UnregisterEvent("PLAYER_TALENT_UPDATE")
		self:UnregisterEvent("UNIT_ENTERED_VEHICLE", "VEHICLE_CHECK")
		self:UnregisterEvent("UNIT_EXITED_VEHICLE", "VEHICLE_CHECK")
		
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self:UnregisterEvent("UNIT_FACTION")
		
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		
		-- disable
		self:Disable()
	end
end

-- ---------------------------------------------------------------------------------------------------------------------


-- 2 small helper functions
function clcret:AuraButtonResetTexture(index)
	auraButtons[index].hasTexture = false
end

function clcret:AuraButtonHide(index)
	auraButtons[index]:Hide()
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- MULTIPLE TARGET SOV TRACKING - Experimental
-- ---------------------------------------------------------------------------------------------------------------------
-- CLUE EVENTS TO TRACK
-- SPELL_AURA_APPLIED -> dot applied 
-- SPELL_AURA_APPLIED_DOSE -> dot stacks
-- SPELL_AURA_REMOVED_DOSE -> dot stacks get removed
-- SPELL_AURA_REFRESH -> dot refresh at 5 stacks
-- SPELL_AURA_REMOVED -> dot removed
-- ---------------------------------------------------------------------------------------------------------------------

function clcret:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, spellType, dose, ...)
	if spellId == sovId then
		if sourceName == playerName then
			if combatEvent == "SPELL_AURA_APPLIED" then
				self:Sov_SPELL_AURA_APPLIED(destGUID, destName)
			elseif combatEvent == "SPELL_AURA_APPLIED_DOSE" then
				self:Sov_SPELL_AURA_APPLIED_DOSE(destGUID, destName, dose)
			elseif combatEvent == "SPELL_AURA_REMOVED_DOSE" then
				self:Sov_SPELL_AURA_REMOVED_DOSE(destGUID, destName, dose)
			elseif combatEvent == "SPELL_AURA_REFRESH" then
				self:Sov_SPELL_AURA_REFRESH(destGUID, destName)
			elseif combatEvent == "SPELL_AURA_REMOVED" then
				self:Sov_SPELL_AURA_REMOVED(destGUID)
			end
		end
	end
end

-- starts to track the hot for that guid
function clcret:Sov_SPELL_AURA_APPLIED(guid, name, dose)
	dose = dose or 1
	for i = 1, MAX_SOVBARS do
		if sovBars[i].active == false then
			local bar = sovBars[i]
			bar.active = true
			bar.guid = guid
			bar.label:SetText(name)
			bar.start = GetTime()
			bar.duration = 15
			bar.labelStack:SetText(dose)
			return
		end
	end
end

-- updates the stack for the guid if it founds it, also refreshes timer
function clcret:Sov_SPELL_AURA_APPLIED_DOSE(guid, name, dose)
	for i = 1, MAX_SOVBARS do
		if sovBars[i].guid == guid then
			sovBars[i].labelStack:SetText(dose)
			sovBars[i].start = GetTime()
			sovBars[i].active = true
			return
		end
	end
	
	-- not found, but try to apply it
	clcret:Sov_SPELL_AURA_APPLIED(guid, name, dose)
end

-- updates the stack for the guid if it founds it
function clcret:Sov_SPELL_AURA_REMOVED_DOSE(guid, name, dose)
	for i = 1, MAX_SOVBARS do
		if sovBars[i].guid == guid then
			sovBars[i].labelStack:SetText(dose)
			sovBars[i].active = true
			return
		end
	end
	
	-- not found, but try to apply it
	clcret:Sov_SPELL_AURA_APPLIED(guid, name, dose)
end

-- refreshes the timer
function clcret:Sov_SPELL_AURA_REFRESH(guid, name)
	for i = 1, MAX_SOVBARS do
		if sovBars[i].guid == guid then
			sovBars[i].start = GetTime()
			sovBars[i].active = true
			return
		end
	end
	
	-- not found, but try to apply it
	clcret:Sov_SPELL_AURA_APPLIED(guid, name, 5)
end

-- deactivates the bar
function clcret:Sov_SPELL_AURA_REMOVED(guid)
	for i = 1, MAX_SOVBARS do
		if sovBars[i].guid == guid then
			sovBars[i].active = false
			sovBars[i]:Hide()
			return
		end
	end
end


-- update the bars
function clcret:UpdateSovBars()
	if db.sov.targetDifference then
		self.targetGUID = UnitGUID("target")
	end

	for i = 1, MAX_SOVBARS do
		self:UpdateSovBar(i)
	end
end
function clcret:UpdateSovBar(index)
	local bar = sovBars[index]
	if not bar.active then return end
	
	local opt = db.sov
	
	local remaining = bar.duration - (GetTime() - bar.start)
	if remaining <= 0 then
		bar:Hide()
		bar.active = false
		return
	end
	bar:Show()
	
	if opt.useButtons then
		-- alpha difference in targeted units
		if db.sov.targetDifference then
			if bar.guid ~= self.targetGUID then
				bar:SetAlpha(self.sovNonTargetAlpha)
			else
				bar:SetAlpha(1)
			end
		end
		if bar.duration > 0 then
			bar.cooldown:SetCooldown(bar.start, bar.duration)
		end
	else
		-- alpha difference in targeted units
		if db.sov.targetDifference then
			if bar.guid == self.targetGUID then
				bar.texture:SetVertexColor(unpack(opt.color))
				bar.bgtexture:SetAlpha(0.5)
			else
				bar.texture:SetVertexColor(unpack(opt.colorNonTarget))
				bar.bgtexture:SetAlpha(self.sovNonTargetAlpha)
			end
		end
		
		local width, height
		width = opt.width - opt.height
		height = opt.height
		
		local progress = width * remaining / bar.duration - width
		local texture = bar.texture
		texture:SetPoint("RIGHT", bar, "RIGHT", progress, 0)
		
		bar.labelTimer:SetText(floor(remaining + 0.5))
	end	
end

-- updates everything
function clcret:UpdateSovBarsLayout()
	local opt = db.sov
	local bar, fontFace, fontFlags
	
	_, _, _, self.sovNonTargetAlpha = unpack(db.sov.colorNonTarget)
	self.sovNonTargetAlpha = 0.5 * self.sovNonTargetAlpha
	
	if opt.useButtons then
		clcretSovAnchor:SetWidth(opt.height)
		clcretSovAnchor:SetHeight(opt.height)
		clcretSovAnchor:ClearAllPoints()
		clcretSovAnchor:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
	else
		clcretSovAnchor:SetWidth(opt.width)
		clcretSovAnchor:SetHeight(opt.height)
		clcretSovAnchor:ClearAllPoints()
		clcretSovAnchor:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
	end
	
	for i = 1, MAX_SOVBARS do
		bar = sovBars[i]
		bar.texture:SetVertexColor(unpack(db.sov.color))
		bar:SetAlpha(1)
		bar.texture:SetVertexColor(unpack(opt.color))
		bar.bgtexture:SetAlpha(0.5)
		
		if db.zoomIcons then
			bar.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
		else
			bar.icon:SetTexCoord(0, 1, 0, 1)
		end
		
		bar.icon:SetWidth(opt.height)
		bar.icon:SetHeight(opt.height)
		
		fontFace, _, fontFlags = bar.label:GetFont()
		bar.label:SetFont(fontFace, max(5, opt.height - 3), fontFlags)
		bar.label:SetWidth(max(5, opt.width - 2.2 * opt.height))
		bar.label:SetHeight(max(5, opt.height - 5))
		bar.labelTimer:SetFont(fontFace, max(5, opt.height - 3), fontFlags)
		
		bar:ClearAllPoints()
		bar.icon:ClearAllPoints()
		bar.labelStack:ClearAllPoints()
		if opt.useButtons then
			-- positioning
			if opt.growth == "up" then
				bar:SetPoint("BOTTOM", clcretSovAnchor, "BOTTOM", 0, (i - 1) * (opt.height + opt.spacing))
			elseif opt.growth == "left" then
				bar:SetPoint("LEFT", clcretSovAnchor, "LEFT", (1 - i) * (opt.height + opt.spacing), 0)
			elseif opt.growth == "right" then
				bar:SetPoint("RIGHT", clcretSovAnchor, "RIGHT", (i - 1) * (opt.height + opt.spacing), 0)
			else
				bar:SetPoint("TOP", clcretSovAnchor, "TOP", 0, (1 - i) * (opt.height + opt.spacing) )
			end
			
			bar:SetWidth(opt.height)
			bar:SetHeight(opt.height)
			
			bar.icon:SetPoint("CENTER", bar, "CENTER", 0, 0)
			bar.labelStack:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 3, -3)
			
			fontFace, _, fontFlags = bar.labelStack:GetFont()
			bar.labelStack:SetFont(fontFace, max(5, opt.height / 2), fontFlags)
			
			-- hide bar stuff
			bar.texture:Hide()
			bar.bgtexture:Hide()
			bar.label:Hide()
			bar.labelTimer:Hide()
			
			-- show cooldown
			bar.cooldown:Show()
			
			-- show border
			bar.border:SetAllPoints(bar)
			bar.border:SetVertexColor(unpack(db.borderColor))
			bar.border:Show()
			
		else
			-- positioning
			if opt.growth == "up" then
				bar:SetPoint("BOTTOM", clcretSovAnchor, "BOTTOM", opt.height / 2, (i - 1) * (opt.height + opt.spacing))
			elseif opt.growth == "left" then
				bar:SetPoint("LEFT", clcretSovAnchor, "LEFT", (1 - i) * (opt.width + opt.spacing) + opt.height, 0)
			elseif opt.growth == "right" then
				bar:SetPoint("RIGHT", clcretSovAnchor, "RIGHT", (i - 1) * (opt.width + opt.spacing), 0)
			else
				bar:SetPoint("TOP", clcretSovAnchor, "TOP", opt.height / 2, (1 - i) * (opt.height + opt.spacing) )
			end
			
			bar:SetWidth(opt.width - opt.height)
			bar:SetHeight(opt.height)
			
			bar.icon:SetPoint("RIGHT", bar, "LEFT", 0, 0)
			bar.labelStack:SetPoint("CENTER", bar.icon, "CENTER", 0, 0)
			
			fontFace, _, fontFlags = bar.labelStack:GetFont()
			bar.labelStack:SetFont(fontFace, max(5, opt.height - 2), fontFlags)
			
			-- show bar stuff
			bar.texture:Show()
			bar.bgtexture:Show()
			bar.label:Show()
			bar.labelTimer:Show()
			
			-- hide cooldown
			bar.cooldown:Hide()
			
			-- hide border
			bar.border:Hide()
		end
	end
end

-- initialize the bars
function clcret:InitSovBars()
	-- create sov anchor
	sovAnchor = self:CreateSovAnchor()
	for i = 1, MAX_SOVBARS do
		sovBars[i] = self:CreateSovBar(i)
	end
	
	self:UpdateSovBarsLayout()
end
function clcret:CreateSovBar(index)
	local frame = CreateFrame("Frame", "clcretSovBar" .. index, clcretFrame)
	frame:Hide()
	
	local opt = db.sov
	
	-- background
	frame.bgtexture = frame:CreateTexture(nil, "BACKGROUND")
	frame.bgtexture:SetAllPoints()
	frame.bgtexture:SetVertexColor(0, 0, 0, 0.5)
	frame.bgtexture:SetTexture(BGTEX)
	
	-- texture
	frame.texture = frame:CreateTexture(nil, "BACKGROUND")
	frame.texture:SetAllPoints()
	frame.texture:SetTexture(BGTEX)
	
	-- icon
	frame.icon = frame:CreateTexture(nil, "BACKGROUND")
	frame.icon:SetTexture(GetSpellTexture(sovTextureSpell))
	
	frame.border = frame:CreateTexture(nil, "BACKGROUND")
	frame.border:SetTexture(BORDERTEX)
	frame.border:Hide()
	
	local fontFace, fontFlags
	
	-- label for the name of the unit
	frame.label = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
	frame.label:SetPoint("LEFT", frame, "LEFT", 3, 1)
	frame.label:SetJustifyH("LEFT")
	
	-- label for timer
	frame.labelTimer = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
	frame.labelTimer:SetPoint("RIGHT", frame, "RIGHT", -1, 1)
	
	-- cooldown for button mode
	frame.cooldown = CreateFrame("Cooldown", "$parentCooldown", frame)
	frame.cooldown:SetAllPoints(frame)
	
	-- stack
	frame.labelStack = frame.cooldown:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	
	-- other vars used
	frame.start = 0
	frame.duration = 0
	frame.active = false	-- we can attach a timer to it
	frame.guid = 0

	return frame
end
function clcret:CreateSovAnchor()
	local frame = CreateFrame("Frame", "clcretSovAnchor", clcretFrame)
	frame:Hide()
	
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetTexture(BGTEX)
	texture:SetVertexColor(0, 0, 0, 1)

	return frame
end

-- toggle anchor visibility
function clcret:ToggleSovAnchor()
	if self.showSovAnchor then
		-- hide
		self.showSovAnchor = false
		clcretSovAnchor:Hide()
	else
		-- show
		self.showSovAnchor = true
		clcretSovAnchor:Show()
	end
end

-- toggle it on and off
function clcret:ToggleSovTracking()
	if db.sov.enabled then
		-- disable
		db.sov.enabled = false
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		
		-- hide the bars
		for i = 1, MAX_SOVBARS do
			sovBars[i].active = false
			sovBars[i]:Hide()
		end
	else
		-- enable
		db.sov.enabled = true
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end
-- ---------------------------------------------------------------------------------------------------------------------

-- update the used aura buttons to shorten the for
function clcret:UpdateEnabledAuraButtons()
	numEnabledAuraButtons = 0
	enabledAuraButtons = {}
	for i = 1, MAX_AURAS do
		if db.auras[i].enabled then
			numEnabledAuraButtons = numEnabledAuraButtons + 1
			enabledAuraButtons[numEnabledAuraButtons] = i
		end
	end
end

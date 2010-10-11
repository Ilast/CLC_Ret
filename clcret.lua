local GetTime = GetTime

clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0")

local MAX_AURAS = 20
local BGTEX = "Interface\\AddOns\\clcret\\textures\\minimalist"
local BORDERTEX = "Interface\\AddOns\\clcret\\textures\\border"
local borderType = {
	"Interface\\AddOns\\clcret\\textures\\border",					-- light
	"Interface\\AddOns\\clcret\\textures\\border_medium",			-- medium
	"Interface\\AddOns\\clcret\\textures\\border_heavy"				-- heavy
}

local taowSpellName = GetSpellInfo(59578) 				-- the art of war proc
local spellHandOfLight = GetSpellInfo(90174)			-- hand of light proc

-- priority queue generated from fcfs
local pq
local ppq
-- number of spells in the queue
local numSpells
-- display queue
local dq = { cleanseSpellName, cleanseSpellName }

-- main and secondary skill buttons
local buttons = {}
-- configurable buttons
local auraButtons = {}
local enabledAuraButtons
local numEnabledAuraButtons 
local auraIndex

local icd = {}
local playerName

-- addon status
local addonEnabled = false			-- enabled
local addonInit = false				-- init completed
clcret.locked = true				-- main frame locked

-- shortcut for db options
local db

--[[
clcret.auraButtons = auraButtons
clcret.icd = icd
--]]

-- spells used
local spells = {
	how		= { id = 24275 	},		-- hammer of wrath
	cs 		= { id = 35395 	},		-- crusader strike
	tv 		= { id = 85256 	},		-- templar's verdict
	inq 	= { id = 84963	},		-- inquisition
	ds 		= { id = 53385 	},		-- divine storm
	j 		= { id = 20271 	},		-- judgement
	cons 	= { id = 26573 	},		-- consecration
	exo 	= { id = 879 		},		-- exorcism
	hw		= { id = 2812  	},		-- holy wrath
	cls 	= { id = 4987		},		-- cleanse
}
clcret.spells = spells

local fillers = { exo = {}, how = {}, j = {}, hw = {}, cons = {} }
clcret.fillers = fillers

-- used for the highlight lock on skill use
local lastgcd = 0
local startgcd = -1
local lastMS = ""
local gcdMS = 0


-- presets
local MAX_PRESETS = 10

local strataLevels = {
	"BACKGROUND",
	"LOW",
	"MEDIUM",
	"HIGH",
	"DIALOG",
	"FULLSCREEN",
	"FULLSCREEN_DIALOG",
	"TOOLTIP",
}


-- ---------------------------------------------------------------------------------------------------------------------
-- DEFAULT VALUES
-- ---------------------------------------------------------------------------------------------------------------------
local defaults = {
	profile = {
		version = 1,
		-- layout settings for the main frame (the black box you toggle on and off)\
		zoomIcons = true,
		noBorder = false,
		borderColor = {0, 0, 0, 1},
		borderType = 2,
		x = 500,
		y = 300,
		scale = 1,
		alpha = 1,
		show = "always",
		fullDisable = false,
		strata = 3,
		grayOOM = false,
		
		lbf = {
			Skills = {},
			Auras = {},
		},
		
		-- icd
		icd = {
			visibility = {
				ready = 1,
				cd = 3,
			},
		},
		
		-- fcfs
		fcfs = {
			"exo", "how", "j", "hw",
			"none",
			"none",
			"none",
			"none",
			"none",
			"none",
		},
		
		-- presets for ret fcfs
		presets = {},
		
		presetFrame = {
			visible = false,
			enableMouse = false,
			expandDown = false,
			alpha = 1,
			width = 200,
			height = 25,
			x = 0,
			y = 0,
			point = "TOP",
			pointParent = "BOTTOM",
			backdropColor = { 0.1, 0.1, 0.1, 0.5 },
			backdropBorderColor = { 0.4, 0.4, 0.4 },
			fontSize = 13,
			fontColor = { 1, 1, 1, 1 },
		},
		
		-- behavior
		updatesPerSecond = 10,
		updatesPerSecondAuras = 5,
		delayedStart = 5,
		rangePerSkill = false,
		csBoost = 0.5,
		
		-- layout of the 2 skill buttons
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
			},
		},
		
		-- aura buttons
		-- 4 examples, rest init to "blank" later
		auras = {},
		
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
		
		swing = {
			enabled = false,
			width = 200,
			height = 10,
			color = {1, 1, 0, 1},
			point = "BOTTOM",
			pointParent = "TOP",
			x = 0,
			y = 50,
		},
	}
}
-- blank rest of the auras buttons in default options
for i = 1, MAX_AURAS do 
	defaults.profile.auras[i] = {
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
-- blank presets
for i = 1, MAX_PRESETS do 
	defaults.profile.presets[i] = {
		name = "",
		data = "",
	}
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- MAIN UPDATE FUNCTION
-- ---------------------------------------------------------------------------------------------------------------------
local throttle = 0
local throttleAuras = 0
local throttleSov = 0
local function OnUpdate(self, elapsed)
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
	
	if db.swing.enabled then
		clcret:UpdateSwingBar()
	end
	
	--[[ DEBUG
	clcret:UpdateDebugFrame()
	--]]
end
-- ---------------------------------------------------------------------------------------------------------------------

--[[ DEBUG

function clcret:GetFastLeft(spell)
	local start, duration = GetSpellCooldown(spell)
	if start > 0 then
		return duration - (GetTime() - start)
	end
	return 0
end

function clcret:UpdateDebugFrame()
	local line, gcd
	line = clcret.debugLines[1]
	
	gcd = self:GetFastLeft("Cleanse")
	
	line:Show()
	line.icon:SetTexture(GetSpellTexture("Cleanse"))
	line.text1:Show()
	line.text1:SetText(string.format("%.3f", gcd))
	line.text2:Show()
	line.text2:SetText(string.format("%.3f", lastgcd))
	line.text3:Show()
	line.text3:SetText(string.format("%.3f", startgcd))
	line.text4:Show()
	line.text4:SetText(string.format("%.3f", gcdMS))
	
	for i = 1, 9 do
		line = clcret.debugLines[i + 1]
		if pq[i] and pq[i].cd and pq[i].xcd then
			line:Show()
			line.icon:SetTexture(GetSpellTexture(pq[i].name))
			line.text1:Show()
			line.text1:SetText(string.format("%.3f", self:GetFastLeft(pq[i].name)))
			line.text2:Show()
			line.text2:SetText(string.format("%.3f", self:GetFastLeft(pq[i].name) - gcd))
			line.text3:Show()
			line.text3:SetText(string.format("%.3f", pq[i].xcd))
			line.text4:Show()
			line.text4:SetText(string.format("%.3f", pq[i].cd))
			-- line.text5:Show()
			-- line.text5:SetText(string.format("%.3f", pq[i].cd + 1.5))
		else
			line:Hide()
		end
	end
end

function clcret:InitDebugFrame()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetWidth(300)
	frame:SetHeight(200)
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetVertexColor(0, 0, 0, 1)
	texture:SetTexture(BGTEX)
	frame:SetPoint("RIGHT")
	
	clcret.debugLines = {}
	local line, fs
	for i = 1, 10 do
		local line = CreateFrame("Frame", nil, frame)
		line:SetWidth(300)
		line:SetHeight(20)
		line:SetPoint("TOPLEFT", 0, -(i * 20 - 20))
		
		texture = line:CreateTexture(nil, "BACKGROUND")
		texture:SetAllPoints()
		texture:SetVertexColor(0.1, 0.1, 0.1, 1)
		texture:SetTexture(BGTEX)
		
		texture = line:CreateTexture(nil, "ARTWORK")
		texture:SetWidth(18)
		texture:SetHeight(18)
		texture:SetPoint("BOTTOMLEFT", 1, 1)
		texture:SetVertexColor(1, 1, 1, 1)
		line.icon = texture
		
		fs = line:CreateFontString(nil, nil, "GameFontHighlight")
		fs:SetFont(STANDARD_TEXT_FONT, 10)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(50)
		fs:SetHeight(18)
		fs:SetPoint("RIGHT", line, "LEFT", 70, 0)
		fs:SetText("1.234")
		fs:Hide()
		line.text1 = fs
		
		fs = line:CreateFontString(nil, nil, "GameFontHighlight")
		fs:SetFont(STANDARD_TEXT_FONT, 10)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(50)
		fs:SetHeight(18)
		fs:SetPoint("RIGHT", line, "LEFT", 120, 0)
		fs:SetText("1.234")
		fs:Hide()
		line.text2 = fs
		
		fs = line:CreateFontString(nil, nil, "GameFontHighlight")
		fs:SetFont(STANDARD_TEXT_FONT, 10)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(50)
		fs:SetHeight(18)
		fs:SetPoint("RIGHT", line, "LEFT", 170, 0)
		fs:SetText("1.234")
		fs:Hide()
		line.text3 = fs
		
		fs = line:CreateFontString(nil, nil, "GameFontHighlight")
		fs:SetFont(STANDARD_TEXT_FONT, 10)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(50)
		fs:SetHeight(18)
		fs:SetPoint("RIGHT", line, "LEFT", 220, 0)
		fs:SetText("1.234")
		fs:Hide()
		line.text4 = fs
		
		fs = line:CreateFontString(nil, nil, "GameFontHighlight")
		fs:SetFont(STANDARD_TEXT_FONT, 10)
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(50)
		fs:SetHeight(18)
		fs:SetPoint("RIGHT", line, "LEFT", 270, 0)
		fs:SetText("1.234")
		fs:Hide()
		line.text5 = fs
		
		clcret.debugLines[i] = line
		line:Hide()
	end
	
	clcret.debugFrame = frame
end
--]]

-- ---------------------------------------------------------------------------------------------------------------------
-- INIT
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:ProfileChanged(db, sourceProfile)
	-- relink 
	ReloadUI()
end
-- load if needed and show options
local function ShowOptions()
	if not clcret.optionsLoaded then LoadAddOn("CLCRet_Options") end
	InterfaceOptionsFrame_OpenToCategory("CLCRet")
end
function clcret:OnInitialize()
	-- try to change from char to profile
	if clcretDB then
		if clcretDB.char then
			clcretDB.profiles = clcretDB.char
			clcretDB.char = nil
		end
	end

	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcretDB", defaults)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
	db = self.db.profile

	-- TODO: worth using acetimer just for this ?
	LibStub("AceTimer-3.0"):ScheduleTimer(self.Init, db.delayedStart, self)
end
function clcret:Init()
	-- test if it's a paladin or not
	local localclass, trueclass = UnitClass("player")
	if trueclass ~= "PALADIN" then
		print("clcret:", "|cffff0000Warning!|cffffffff This addon is not designed to work with " .. localclass .. " class. Probably would be better to disable it on this char.")
		return
	end
	
	playerName = UnitName("player")

	-- get player name for sov tracking 
	self.spec = "Holy"
	self["CheckQueue"] = self["CheckQueueHoly"]
	
	self.LBF = LibStub('LibButtonFacade', true)
	
	-- update rates
	self.scanFrequency = 1 / db.updatesPerSecond
	self.scanFrequencyAuras = 1 / db.updatesPerSecondAuras
	self.scanFrequencySov = 1 / db.sov.updatesPerSecond

	self:InitSpells()
	
	-- blank options page for title
	local optionFrame = CreateFrame("Frame", nil, UIParent)
	optionFrame.name = "CLCRet"
	local optionFrameLoad = CreateFrame("Button", nil, optionFrame, "UIPanelButtonTemplate")
	optionFrameLoad:SetWidth(150)
	optionFrameLoad:SetHeight(22)
	optionFrameLoad:SetText("Load Options")
	optionFrameLoad:SetPoint("TOPLEFT", 20, -20)
	optionFrameLoad:SetScript("OnClick", ShowOptions)
	InterfaceOptions_AddCategory(optionFrame)
	-- chat command that points to our category
	self:RegisterChatCommand("clcret", ShowOptions)
	
	self:RegisterChatCommand("clcreteq", "EditQueue") -- edit the queue from command line
	self:RegisterChatCommand("clcretpq", "DisplayFCFS") -- display the queue
	self:RegisterChatCommand("clcretlp", "Preset_LoadByName") -- load the specified preset
	self:RegisterChatCommand("clcreportmincd", "ICDReportMinCd") -- report the min cd for that button
	
	self:UpdateEnabledAuraButtons()
	
	self:UpdateFCFS()
	self:InitUI()
	self:UpdateAuraButtonsCooldown()
	self:PLAYER_TALENT_UPDATE()
	
	if self.LBF then
		self.LBF:RegisterSkinCallback("clcret", self.OnSkin, self)
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
	
	-- init swing bar
	-- TODO: Make it dynamic
	self:InitSwingBar()
	
	-- icd stuff
	self:AuraButtonUpdateICD()
	
	-- preset frame
	if db.presetFrame.visible then
		self:PresetFrame_Init()
	end
	--[[ DEBUG
	self:InitDebugFrame()
	--]]
end
-- get the spell names from ids
function clcret:InitSpells()
	for alias, data in pairs(self.spells) do
		data.name = GetSpellInfo(data.id)
	end
	
	for alias, data in pairs(self.fillers) do
		data.id = spells[alias].id
		data.name = spells[alias].name
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
	print("clcret:", "Active Retribution FCFS:")
	for i, data in ipairs(pq) do
		print("clcret:", i .. " " .. data.name)
	end
end

-- make a fcfs from a command line list of arguments
function clcret:EditQueue(args)
	local list = { strsplit(" ", args) }
	
	-- add args to options
	local num = 0
	for i, arg in ipairs(list) do
		if self.fillers[arg] then
			num = num + 1
			db.fcfs[num] = arg
		else
			print("clcret:", arg .. " not found")
		end
	end
	
	-- none on the rest
	if num < MAX_PRESETS then
		for i = num + 1, MAX_PRESETS do
			db.fcfs[i] = "none"
		end
	end
	
	-- redo queue
	self:UpdateFCFS()
	self:DisplayFCFS()
	
	if InterfaceOptionsFrame:IsVisible() then
		InterfaceOptionsFrame_OpenToCategory("FCFS")
	end
	
	if self.presetFrame then
		self:PresetFrame_Update()
	end
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
				if not self.fillers[alias] then
					db.fcfs[i] = "none"
				else
					numSpells = numSpells + 1
					newpq[numSpells] = { alias = alias, name = self.fillers[alias].name }
				end
			end
		end
	end
	
	pq = newpq
	
	-- check if people added enough spells
	if numSpells < 2 then
		print("clcret:", "You need at least 2 skills in the queue.")
		-- toggle it off
		db.fullDisable = false
		self:FullDisableToggle()
	end
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
	
	-- check talents
	-- zealotry
	local _, _, _, _, csRank = GetTalentInfo(3, 20)
	
	if csRank == 1 then
		self.spec = "Ret"
		dq[1] = pq[1].name
		dq[2] = pq[2].name
		self:Enable()
		self:UpdateShowMethod()
	else
		self.spec = "Holy"
		self:Disable()
	end
	
	self["CheckQueue"] = self["CheckQueue" .. self.spec]
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
	if duration and duration > 0 then
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
	
	if duration and duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
end

-- shows a skill only when on cooldown
function clcret:AuraButtonExecSkillVisibleOnCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- fix the texture once
	if not button.hasTexture then
		button.hasTexture = true
		button.texture:SetTexture(GetSpellTexture(data.spell))
	end

	local start, duration = GetSpellCooldown(data.spell)
	
	if duration and duration > 1.5 then
		button:Show()
		button.cooldown:SetCooldown(start, duration)
	else
		button:Hide()
	end
end

-- shows an equiped usable item always with a visible cooldown when needed
function clcret:AuraButtonExecItemVisibleAlways()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- hide the item if is not equiped
	--[[
	if not IsEquippedItem(data.spell) then
		button:Hide()
		return
	end
	--]]
	
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
	if duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	end

end

-- shows shows an equiped usable item only when out of cooldown
function clcret:AuraButtonExecItemVisibleNoCooldown()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	-- hide the item if is not equiped
	--[[
	if not IsEquippedItem(data.spell) then
		button:Hide()
		return
	end
	--]]
	
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
	
	if duration and duration > 1.5 then
		button:Hide()
	else
		button:Show()
	end
end


-- displayed when a specific spell isn't active on player
function clcret:AuraButtonExecPlayerMissingBuff()
	local index = auraIndex
	local button = auraButtons[index]
	local data = db.auras[index].data
	
	if not button.hasTexture then
		button.texture:SetTexture(GetSpellTexture(data.spell))
		button.hasTexture = true
	end
	
	local name, rank, icon, count, debuffType, duration, expirationTime, caster = UnitBuff("player", data.spell)
	if not name then
		button:Show()
	else
		button:Hide()
	end
end

-- experimental item with icd stuff
-- states:
--	no icd
--  buff active
--  icd
function clcret:AuraButtonExecICDItem()
	local index = auraIndex
	local button = auraButtons[index]
	local data = icd.data[index]
	
	if not button.hasTexture then
		local _, _, tex = GetSpellInfo(data.id)
		button.texture:SetTexture(tex)
		button.hasTexture = true
	end

	local gt = GetTime()
	if (gt - data.start) > data.durationBuff then data.active = false end
	if (gt - data.start) > data.durationICD then data.enabled = false end
	
	if data.active then 
		-- always show the button when proc is active
		button:Show()
		button.cooldown:Show()
		button.cooldown:SetCooldown(data.start, data.durationBuff)
		button:SetAlpha(1)
		
	elseif data.enabled then
		-- check how to display
		if db.icd.visibility.cd == 1 then
			button:Show()
			button:SetAlpha(1)
		elseif db.icd.visibility.cd == 2 then
			button:Show()
			button:SetAlpha(0.3)
		else
			button:Hide()
			return
		end
		
		button.cooldown:Show()
		button.cooldown:SetCooldown(data.start, data.durationICD)
	else
		if db.icd.visibility.ready == 1 then
			button:Show()
			button:SetAlpha(1)
		elseif db.icd.visibility.ready == 2 then
			button:Show()
			button:SetAlpha(0.5)
		else
			button:Hide()
		end
		
		button.cooldown:Hide()
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
			if duration and duration > 0 then
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
			if duration and duration > 0 then
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


-- resets the vertex color when grayOOM option changes
function clcret:ResetButtonVertexColor()
	buttons[1].texture:SetVertexColor(1, 1, 1, 1)
	buttons[2].texture:SetVertexColor(1, 1, 1, 1)
end

-- updates the 2 skill buttons
function clcret:UpdateUI()
	-- queue
	for i = 1, 2 do
		local button = buttons[i]
		button.texture:SetTexture(GetSpellTexture(dq[i]))
		
		local start, duration = GetSpellCooldown(dq[i])
		if duration and duration > 0 then
			button.cooldown:Show()
			button.cooldown:SetCooldown(start, duration)
		else
			button.cooldown:Hide()
		end
		
		if db.grayOOM then
			local _, nomana = IsUsableSpell(dq[i])
			if nomana then 
				button.texture:SetVertexColor(0.3, 0.3, 0.3, 0.3)
			else
				button.texture:SetVertexColor(1, 1, 1, 1)
			end
		end
		
	end
end



-- melee range check
function clcret:CheckRange()
	local range
	if db.rangePerSkill then
		-- each skill shows the range of the ability
		for i = 1, 2 do
			range = IsSpellInRange(dq[i], "target")
			if range ~= nil and range == 0 then
				buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
			else
				buttons[i].texture:SetVertexColor(1, 1, 1)
			end
		end
	else
		-- both skills show melee range
		range = IsSpellInRange(self.spells.cs.name, "target")	
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
end
-- ---------------------------------------------------------------------------------------------------------------------


-- ---------------------------------------------------------------------------------------------------------------------
-- QUEUE LOGIC
-- ---------------------------------------------------------------------------------------------------------------------
-- holy blank function
function clcret:CheckQueueHoly()
	print("clcret:", "This message shouldn't be here")
end



function clcret:CheckQueueRet()
	csBoost = db.csBoost
	useInq = false	-- disable this for ptr
	minHPInq = 3
	preInq = 5

	local ctime, cdStart, cdDuration, cs, gcd
	ctime = GetTime()
	
	-- gcd
	cdStart, cdDuration = GetSpellCooldown(spells.cls.name)
	if cdStart > 0 then
		gcd = cdStart + cdDuration - ctime
	else
		gcd = 0
	end
	
	-- get HP, HoL
	local hp = UnitPower("player", SPELL_POWER_HOLY_POWER)
	local hol = UnitBuff("player", spellHandOfLight) or false
	
	if hp == 3 and hol then
		-- got lucky, double tv
		dq[1] = spells.tv.name
		dq[2] = spells.tv.name
	else
		-- didn't get lucky, find out cs + filler cooldowns
		
		-- cs
		cdStart, cdDuration = GetSpellCooldown(spells.cs.name)
		if cdStart > 0 then
			cs = cdStart + cdDuration - ctime
		else
			cs = 0
		end
		cs = cs - gcd - csBoost
		
		if hp == 3 or hol then
			-- tv + x
			dq[1] = spells.tv.name
			
			-- everything now is delayed by 1.5s
			cs = cs - 1.5  -- adjust cs
			
			-- test maybe we don't need to check rest of cooldowns
			if cs <= 0 then
				-- got lucky, tv + cs
				dq[2] = spells.cs.name
			else
				-- get cooldowns for fillers
				local v, cd, index
				
				for i = 1, #pq do
					v = pq[i]
					v.name = spells[v.alias].name
					
					cdStart, cdDuration = GetSpellCooldown(v.name)
					if cdStart > 0 then
						v.cd = cdStart + cdDuration - ctime - 1.5 - gcd
					else
						v.cd = 0
					end
					
					if v.alias == "how" then
						if not IsUsableSpell(v.name) then v.cd = 100 end
					elseif v.alias == "exo" then
						if UnitBuff("player", taowSpellName) == nil then v.cd = 100 end
					end
					
					-- clamp so sorting is proper
					if v.cd < 0 then v.cd = 0 end
				end
				
				-- sort cooldowns once, get min cd and the index in the table
				index = 1
				cd = pq[1].cd
				for i = 1, #pq do
					v = pq[i]
					if (v.cd < cd) or ((v.cd == cd) and (i < index)) then
						index = i
						cd = v.cd
					end
				end
				
				-- test vs cs
				if cs <= cd then
					-- tv + cs
					dq[2] = spells.cs.name
				else
					-- tv + f1
					dq[2] = pq[index].name
				end
			end
		else
			-- no tv -> it's either cs + filler or 2 fillers
			-- TODO : is 2 fillers even viable at low haste?
			
			-- get cooldowns for fillers
			local v, cd, index
			
			for i = 1, #pq do
				v = pq[i]
				v.name = spells[v.alias].name
				
				cdStart, cdDuration = GetSpellCooldown(v.name)
				if cdStart > 0 then
					v.cd = cdStart + cdDuration - ctime - gcd
				else
					v.cd = 0
				end
				
				if v.alias == "how" then
					if not IsUsableSpell(v.name) then v.cd = 100 end
				elseif v.alias == "exo" then
					if UnitBuff("player", taowSpellName) == nil then v.cd = 100 end
				end
				
				-- clamp so sorting is proper
				if v.cd < 0 then v.cd = 0 end
			end
			
			-- sort cooldowns once, get min cd and the index in the table
			index = 1
			cd = pq[1].cd
			for i = 1, #pq do
				v = pq[i]
				if (v.cd < cd) or ((v.cd == cd) and (i < index)) then
					index = i
					cd = v.cd
				end
			end
			
			-- test vs cs
			if cs <= cd then
				-- cs + f1
				dq[1] = spells.cs.name
				if hp == 2 then
					-- 3 hp ability
					dq[2] = spells.tv.name
				else
					dq[2] = pq[index].name
				end
			else
				-- f1 + cs or f2
				dq[1] = pq[index].name
				
				-- delay everything by 1.5 now
				-- todo: take haste into account here, since s1 might be a spell
				cs = cs - 1.5
				
				-- one more hope with cs
				if cs <= 0 then
					-- f1 + cs
					dq[2] = spells.cs.name
				else
					-- worst case scenario possible
					pq[index].cd = 1000 -- delay last used skill a lot
					
					-- get new clamped cooldowns
					for i = 1, #pq do
						v.cd = v.cd - 1.5
						if v.cd < 0 then v.cd = 0 end
					end
					
					-- get min again
					index = 1
					cd = pq[1].cd
					for i = 1, #pq do
						v = pq[i]
						if (v.cd < cd) or ((v.cd == cd) and (i < index)) then
							index = i
							cd = v.cd
						end
					end
						
					-- test vs cs
					if cs <= cd then
						-- f1 + cs
						dq[2] = spells.cs.name
					else
						-- f1 + f2
						dq[2] = pq[index].name
					end
				end
			end
			
		end
	end
	
	-- inquisition, if active and needed -> change first tv in dq1 or dq2 with inquisition
	if useInq then
		local inqLeft = 0
		local name, rank, icon, count, debuffType, duration, expirationTime = UnitBuff("player", spells.inq.name)
		if name then 
			inqLeft = expirationTime - ctime
		end
		
		-- test time for 2nd skill
		-- check for spell gcd?
		if (inqLeft - 1.5) <= preInq then
			if (dq[1] == spells.tv.name) and (inqLeft <= preInq) then
				dq[1] = spells.inq.name
			elseif (dq[2] == spells.tv.name) and ((inqLeft - 1.5) <= preInq) then
				dq[2] = spells.inq.name
			end
		end
	end
	
	self:UpdateUI()
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
	button.border:SetTexture(borderType[db.borderType])
	
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
	self.frame:SetScale(max(db.scale, 0.01))
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
	frame:SetFrameStrata(strataLevels[db.strata])
	frame:SetWidth(db.layout.button1.size + 10)
	frame:SetHeight(db.layout.button1.size + 10)
	frame:SetPoint("BOTTOMLEFT", db.x, db.y)
	
	frame:EnableMouse(false)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
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
	
	-- init main skill button
	local opt
	opt = db.layout["button1"]
	buttons[1] = self:CreateButton("SB1", opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y, "Skills", true)
	buttons[1]:SetAlpha(opt.alpha)
	buttons[1]:Show()
	
	-- init secondary skill button
	opt = db.layout["button2"]
	buttons[2] = self:CreateButton("SB2", opt.size, opt.point, clcretFrame, opt.pointParent, opt.x, opt.y, "Skills")
	buttons[2]:SetAlpha(opt.alpha)
	buttons[2]:Show()
	
	-- aura buttons
	self:InitAuraButtons()
	
	-- set scale, alpha, position
	self:UpdateFrameSettings()
	
	addonInit = true
	self:Disable()
	self.frame:SetScript("OnUpdate", OnUpdate)
end

-- initialize aura buttons
function clcret:InitAuraButtons()
	local data, layout
	for i = 1, MAX_AURAS do
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
function clcret:CreateButton(name, size, point, parent, pointParent, offsetx, offsety, bfGroup, isChecked)
	name = "clcret" .. name
	local button
	if isChecked then
		button = CreateFrame("CheckButton", name , parent)
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight", "ADD")
	else
		button = CreateFrame("Button", name , parent)
	end
	button:EnableMouse(false)
	
	button:SetWidth(64)
	button:SetHeight(64)
	
	button.texture = button:CreateTexture("$parentIcon", "BACKGROUND")
	button.texture:SetAllPoints()
	button.texture:SetTexture(BGTEX)
	
	button.border = button:CreateTexture(nil, "BORDER") -- not $parentBorder so it can work when bf is enabled
	button.border:SetAllPoints()
	button.border:SetTexture(BORDERTEX)
	button.border:SetVertexColor(unpack(db.borderColor))
	button.border:SetTexture(borderType[db.borderType])
	
	button.cooldown = CreateFrame("Cooldown", "$parentCooldown", button)
	button.cooldown:SetAllPoints(button)
	
	button.stack = button:CreateFontString("$parentCount", "OVERLAY", "TextStatusBarText")
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
		
		self:RegisterCLEU()
		
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

-- PRESET FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------

function clcret:PresetFrame_Init()
	local opt = db.presetFrame
	
	local backdrop = {
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 3, right = 3, top = 5, bottom = 3 }
	}

	-- frame
	local frame = CreateFrame("Button", nil, clcretFrame)
	self.presetFrame = frame
	
	frame:EnableMouse(opt.enableMouse)
	frame:SetBackdrop(backdrop)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	
	-- fontstring
	local fs = frame:CreateFontString(nil, nil, "GameFontHighlight")
	frame.text = fs
	
	-- popup frame
	local popup = CreateFrame("Frame", nil, frame)
	self.presetPopup = popup
	
	popup:Hide()
	popup:SetBackdrop(backdrop)
	popup:SetFrameStrata("FULLSCREEN_DIALOG")
	
	-- buttons for the popup frame
	local button
	self.presetButtons = {}
	for i = 1, MAX_PRESETS do
		button = CreateFrame("Button", nil, popup)
		self.presetButtons[i] = button
		
		button.highlightTexture = button:CreateTexture(nil, "HIGHLIGHT")
		button.highlightTexture:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
		button.highlightTexture:SetBlendMode("ADD")
		button.highlightTexture:SetAllPoints()
		
		button.name = button:CreateFontString(nil, nil, "GameFontHighlight")
		button.name:SetText(db.presets[i].name)
		
		button:SetScript("OnClick", function()
			self:Preset_Load(i)
			popup:Hide()
		end)
	end
	
	-- toggle popup on click
	frame:SetScript("OnClick", function()
		if popup:IsVisible() then
			popup:Hide()
		else
			popup:Show()
		end
	end)
	
	-- update the layout
	self:PresetFrame_UpdateLayout()
	
	-- update the preset
	self:PresetFrame_Update()
end

function clcret:PresetFrame_UpdateMouse()
	if self.presetFrame then
		self.presetFrame:EnableMouse(db.presetFrame.enableMouse)
	end
end

-- update layout
function clcret:PresetFrame_UpdateLayout()
	local opt = db.presetFrame

	-- preset frame
	local frame = self.presetFrame
		
	frame:SetWidth(opt.width)
	frame:SetHeight(opt.height)
	frame:ClearAllPoints()
	frame:SetPoint(opt.point, clcretFrame, opt.pointParent, opt.x, opt.y)
	
	frame:SetBackdropColor(unpack(opt.backdropColor))
	frame:SetBackdropBorderColor(unpack(opt.backdropBorderColor))
	
	frame.text:SetFont(STANDARD_TEXT_FONT, opt.fontSize)
	frame.text:SetVertexColor(unpack(opt.fontColor))
	
	frame.text:SetAllPoints(frame)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetJustifyV("MIDDLE")
	
	-- popup
	local popup = self.presetPopup
	popup:SetBackdropColor(unpack(opt.backdropColor))
	popup:SetBackdropBorderColor(unpack(opt.backdropBorderColor))
	
	popup:SetWidth(opt.width)
	popup:SetHeight((opt.fontSize + 7) * MAX_PRESETS + 40)
	popup:ClearAllPoints()
	if opt.expandDown then
		popup:SetPoint("TOP", frame, "BOTTOM", 0, 0)
	else
		popup:SetPoint("BOTTOM", frame, "TOP", 0, 0)
	end
	
	local button
	for i = 1, MAX_PRESETS do
		button = self.presetButtons[i]
	
		button:SetWidth(opt.width - 20)
		button:SetHeight(opt.fontSize + 7)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -10 - (opt.fontSize + 9) * (i - 1))

		button.name:SetJustifyH("LEFT")
		button.name:SetJustifyV("MIDDLE")
		button.name:SetAllPoints()
		button.name:SetVertexColor(unpack(opt.fontColor))
		
		button.name:SetFont(STANDARD_TEXT_FONT, opt.fontSize)
	end
	
end

-- checks if the current rotation is in any of the presets and updates text
function clcret:PresetFrame_Update()
	if not self.presetFrame then return end

	local t = {}
	for i = 1, #pq do
		t[i] = pq[i].alias
	end
	local rotation = table.concat(t, " ")
	
	local preset = "no preset"
	for i = 1, MAX_PRESETS do
		-- print("clcret:", rotation, " | ", db.presets[i].data)
		if db.presets[i].data == rotation and rotation ~= "" then
			preset = db.presets[i].name
			break
		end
	end
	
	self.presetFrame.text:SetText(preset)
	
	-- update the buttons
	if self.presetButtons then
		local button
		for i = 1, MAX_PRESETS do
			button = self.presetButtons[i]
			if db.presets[i].name ~= "" then
				button.name:SetText(db.presets[i].name)
				button:Show()
			else
				button:Hide()
			end
		end
	end
end

-- toggles show and hide
function clcret:PresetFrame_Toggle()
	-- the frame is not loaded by default, so check if init took place
	if not self.presetFrame then
		-- need to do init
		self:PresetFrame_Init()
		self.presetFrame:Show()
		db.presetFrame.visible = true
		return
	end
		


	if self.presetFrame:IsVisible() then
		self.presetFrame:Hide()
		db.presetFrame.visible = false
	else
		self.presetFrame:Show()
		db.presetFrame.visible = true
	end
end

-- load a preset
function clcret:Preset_Load(index)
	if db.presets[index].name == "" then return end

	if (not self.presetFrame) or (not self.presetFrame:IsVisible()) then
		print("clcret:", "Loading preset:", db.presets[index].name)
	end
	
	local list = { strsplit(" ", db.presets[index].data) }

	local num = 0
	for i = 1, #list do
		if self.fillers[list[i]] then
			num = num + 1
			db.fcfs[num] = list[i]
		end
	end
	
	-- none on the rest
	if num < MAX_PRESETS then
		for i = num + 1, MAX_PRESETS do
			db.fcfs[i] = "none"
		end
	end
	
	-- redo queue
	self:UpdateFCFS()
	self:PresetFrame_Update()
end

-- loads a prset by name (used for cmd function)
function clcret:Preset_LoadByName(name)
	name = string.lower(strtrim(name))
	if name == "" then return end
	for i = 1, MAX_PRESETS do
		if name == string.lower(db.presets[i].name) then return self:Preset_Load(i) end
	end
end

-- save current to preset
function clcret:Preset_SaveCurrent(index)
	local t = {}
	for i = 1, #pq do
		t[i] = pq[i].alias
	end
	local rotation = table.concat(t, " ")
	db.presets[index].data = rotation
	
	self:PresetFrame_Update()
end

-- ---------------------------------------------------------------------------------------------------------------------



-- HELPER FUNCTIONS
-- ---------------------------------------------------------------------------------------------------------------------
function clcret:AuraButtonResetTextures()
	for i = 1, MAX_AURAS do
		auraButtons[i].hasTexture = false
	end
end

function clcret:AuraButtonResetTexture(index)
	auraButtons[index].hasTexture = false
end

function clcret:AuraButtonHide(index)
	auraButtons[index]:Hide()
end

-- reversed and edged cooldown look for buffs and debuffs
function clcret:UpdateAuraButtonsCooldown()
	for i = 1, MAX_AURAS do
		if (db.auras[i].data.exec == "AuraButtonExecGenericBuff") or (db.auras[i].data.exec == "AuraButtonExecGenericDebuff") then
			auraButtons[i].cooldown:SetReverse(true)
			auraButtons[i].cooldown:SetDrawEdge(true)
		else
			auraButtons[i].cooldown:SetReverse(false)
			auraButtons[i].cooldown:SetDrawEdge(false)
		end
	end
end

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


local ceAuraApplied = {
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_AURA_APPLIED_DOSE"] = true,
}

local ceAuraRemoved = {
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_AURA_REMOVED_DOSE"] = true,
}


-- icd related stuff
-- helper functions

-- reports min icd for a specified aura button
function clcret:ICDReportMinCd(args)
	local id = tonumber(args)
	if icd.data[id] then
		print("clcret:", icd.data[id].mincd)
	else
		print("clcret:", "No data found")
	end
end

-- check the aura list and enables cleu if needed, also resets all data
function clcret:AuraButtonUpdateICD()
	icd.spells = {}
	icd.data = {}
	icd.cleu = false

	for i = 1, MAX_AURAS do
		if db.auras[i].data.exec == "AuraButtonExecICDItem" and db.auras[i].data.spell ~= "" and db.auras[i].enabled then
			local id = tonumber(db.auras[i].data.spell)
			local durationICD, durationBuff = strsplit(":", db.auras[i].data.unit)
			durationICD = tonumber(durationICD) or 0
			durationBuff = tonumber(durationBuff) or 0
			
			icd.cleu = true
			icd.spells[id] = i
			icd.data[i] = { id = db.auras[i].data.spell, durationICD = durationICD, durationBuff = durationBuff, start = 0, enabled = false, active = false, last = 0, mincd = 10000 }
		end
	end
	
	-- register/unregister combat log proccessing
	self:RegisterCLEU()
end


function clcret:RegisterCLEU()
	if icd.cleu or db.sov.enabled or db.swing.enabled then
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	else
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end


-- cleu dispatcher wannabe
function clcret:COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, spellType, dose, ...)
	-- pass info for the sov function
	if db.sov.enabled then
		clcret:SOV_COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, spellType, dose, ...)
	end
	
	-- swing timer
	if db.swing.enabled then
		clcret:SWING_COMBAT_LOG_EVENT_UNFILTERED(event, timestamp, combatEvent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, spellId, spellName, spellSchool, spellType, dose, ...)
	end
	
	-- return if no icd
	if not icd.cleu then return end
	
	-- icd logic
	if destName == playerName and icd.spells[spellId] then
		local i = icd.spells[spellId]
		if ceAuraApplied[combatEvent] then
			icd.data[i].start = GetTime()
			icd.data[i].cd = floor(icd.data[i].start - icd.data[i].last + 0.5)
			icd.data[i].last = icd.data[i].start
			-- check if it's a smaller cd than the one used
			if icd.data[i].start > 0 and icd.data[i].cd < icd.data[i].durationICD then
				print("clcret:", "Warning: " .. spellId .. "(" .. GetSpellInfo(spellId) .. ") activated after " .. icd.data[i].cd .. " seconds and specified ICD is " .. icd.data[i].durationICD .. " seconds.")
			end
			-- save min cd
			if icd.data[i].cd < icd.data[i].mincd then icd.data[i].mincd = icd.data[i].cd end
			icd.data[i].enabled = true
			icd.data[i].active = true
		end
	end
end
-- ---------------------------------------------------------------------------------------------------------------------

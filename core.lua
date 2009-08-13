local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

-- the art of war
local taowSpellName = GetSpellInfo(59578)
local awSpellName = GetSpellInfo(31884)
local cleanseSpellName = GetSpellInfo(4987)

local clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")


local spells = {
	how		= { id = 48806 },
	cs 		= { id = 35395 },
	ds 		= { id = 53385 },
	jol 	= { id = 53408 },		-- jow
	cons 	= { id = 48819 },
	exo 	= { id = 48801 },
	dp 		= { id = 54428 },
	ss 		= { id = 53601 },
}

local pq	-- queue generated from fcfs
local dq = {	-- display queue
	{name = "", cdStart = 0, cdDuration = 0, cd = 0},
	{name = "", cdStart = 0, cdDuration = 0, cd = 0},
	{name = "", cdStart = 0, cdDuration = 0, cd = 0},
}	
local lastq = nil
local buttons = {}
local enabled = false
local awButton = nil
local aw = { ["start"] = 0, ["duration"] = 0 }
local dp = { ["start"] = 0, ["duration"] = 0 }
local init = false
local locked = true
local scanFrequency
local numSpells

local db
local defaults = {
	char = {
		x = 500,
		y = 300,
		scale = 1,
		alpha = 1,
		show = "always",
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
		manaCons = 0,
		manaDP = 0,
		
	}
}

local function GetSpellChoice()
	local spellChoice = { none = "None" }
	for alias, data in pairs(spells) do
		spellChoice[alias] = data.name
	end
	
	return spellChoice
end
local options = {
	type = "group",
	args = {
		-- lock frame
		lock = {
			order = 1,
			type = "toggle",
			name = "Lock Frame",
			get = function(info) return locked end,
			set = function(info, val)
				clcret:ToggleLock()
			end,
		},
		
		-- appearance
		appearance = {
			order = 2,
			name = "Appearance",
			type = "group",
			args = {
				scale = {
					order = 1,
					type = "range",
					name = "Scale",
					min = 0,
					max = 3,
					step = 0.01,
					get = function(info) return db.scale end,
					set = function(info, val)
						db.scale = val
						clcret:UpdateFrameSettings()
					end,
				},
				alpha = {
					order = 2,
					type = "range",
					name = "Alpha",
					min = 0,
					max = 1,
					step = 0.001,
					get = function(info) return db.alpha end,
					set = function(info, val)
						db.alpha = val
						clcret:UpdateFrameSettings()
					end,
				},
				x = {
					order = 10,
					type = "range",
					name = "X",
					min = 0,
					max = 5000,
					step = 1,
					get = function(info) return db.x end,
					set = function(info, val)
						db.x = val
						clcret:UpdateFrameSettings()
					end,
				},
				y = {
					order = 11,
					type = "range",
					name = "Y",
					min = 0,
					max = 3000,
					step = 1,
					get = function(info) return db.y end,
					set = function(info, val)
						db.y = val
						clcret:UpdateFrameSettings()
					end,
				},
				align = {
					order = 12,
					type = "execute",
					name = "Center Horizontally",
					func = function()
						clcret:CenterHorizontally()
					end,
				},
				show = {
					order = 20,
					type = "select",
					name = "Show",
					get = function(info) return db.show end,
					set = function(info, val)
						db.show = val
						clcret:UpdateShowMethod()
					end,
					values = { always = "Always", combat = "In Combat", valid = "Valid Target" }
				},
			},
		},
		
		-- fcfs edit
		fcfs = {
			order = 3,
			name = "FCFS",
			type = "group",
			args = {
			},
		},
		
		-- behaviour
		behaviour = {
			order = 4,
			name = "Behaviour",
			type = "group",
			args = {
				ups = {
					order = 1,
					type = "range",
					name = "Updates per second",
					min = 1,
					max = 100,
					step = 1,
					get = function(info) return db.updatesPerSecond end,
					set = function(info, val)
						db.updatesPerSecond = val
						scanFrequency = 1 / val
					end,
				},
				manaCons = {
					order = 2,
					type = "range",
					name = "Minimum mana for Consecration",
					min = 0,
					max = 10000,
					step = 1,
					get = function(info) return db.manaCons end,
					set = function(info, val) db.manaCons = val end,
				},
				manaDP = {
					order = 3,
					type = "range",
					name = "Maximum mana for Divine Plea",
					min = 0,
					max = 10000,
					step = 1,
					get = function(info) return db.manaDP end,
					set = function(info, val) db.manaDP = val end,
				},
			},
		}
	}
}

function clcret:UpdateFrameSettings()
	self.frame:SetScale(db.scale)
	self.frame:SetAlpha(db.alpha)
	self.frame:SetPoint("BOTTOMLEFT", db.x, db.y)
end


function clcret:UpdateShowMethod()
	-- unregister all events first
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")

	if db.show == "combat" then
		if enabled then
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
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
	else
		if enabled then
			self.frame:Show()
		end
	end
end

-- out of combat
function clcret:PLAYER_REGEN_ENABLED()
	if not enabled then return end
	self.frame:Hide()
end
-- in combat
function clcret:PLAYER_REGEN_DISABLED()
	if not enabled then return end
	self.frame:Show()
end
-- target change
function clcret:PLAYER_TARGET_CHANGED()
	if not enabled then return end
	if UnitExists("target") and UnitCanAttack("player", "target") then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end


function clcret:OnInitialize()
	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcretDB", defaults)
	db = self.db.char
	
	scanFrequency = 1 / db.updatesPerSecond
	
	self:RegisterChatCommand("rl", ReloadUI)
	self:ScheduleTimer("Init", 10)
end


function clcret:OptionsAddPriorities()
	local root = options.args.fcfs.args
	for i = 1, 10 do
		root["p"..i] = {
			name = "",
			type = "select",
			order = i,
			get = function(info)
				return db.fcfs[i]
			end,
			set = function(info, val)
				db.fcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = GetSpellChoice,
		}
	end
	
end


function clcret:Init()
	self:InitSpells()
	self:OptionsAddPriorities()
	
	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("clcret", options)
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions("clcret")
	self:RegisterChatCommand("clcret", function() InterfaceOptionsFrame_OpenToCategory("clcret") end)
	self:RegisterChatCommand("clcretpq", function()
		for i, data in ipairs(pq) do
			bprint(data.priority .. " " .. data.name)
		end
	end)
	
	self:UpdateFCFS()
	self:InitUI()
	self:PLAYER_TALENT_UPDATE()
	self:UpdateShowMethod()
	
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
end

function clcret:InitSpells()
	for alias, data in pairs(spells) do
		spells[alias].name = GetSpellInfo(data.id)
	end
end


function clcret:UpdateFCFS()
	pq = {}
	local check = {}
	numSpells = 0
	
	for i, alias in ipairs(db.fcfs) do
		if not check[alias] then -- take care of double entries
			check[alias] = true
			if alias ~= "none" then
				numSpells = numSpells + 1
				pq[numSpells] = { alias = alias, name = spells[alias].name, priority = i }
			end
		end
	end
end


function clcret:PLAYER_TALENT_UPDATE()
	-- check cs talent
	local _, _, _, _, rank = GetTalentInfo(3, 23)
	if rank == 1 then
		self:Enable()
	else
		self:Disable()
	end
end

local throttle = 0
local function OnUpdate(this, elapsed)
	throttle = throttle + elapsed
	if throttle > scanFrequency then
		throttle = 0
		clcret:CheckQueue()
		clcret:CheckRange()
		clcret:CheckAW()
		clcret:CheckDP()
	end
end


function clcret:CreateButton(name, width, height, point, parent, pointParent, offsetx, offsety)
	local button = CreateFrame("Frame", "clcret"..name, parent)
	button:SetWidth(width)
	button:SetHeight(height)
	button:SetPoint(point, parent, pointParent, offsetx, offsety)
	
	local texture = button:CreateTexture(nil,"BACKGROUND")
	texture:SetTexture(nil)
	texture:SetAllPoints(button)
	--texture:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	button.texture = texture
	
	local cooldown = CreateFrame("Cooldown", "$parentCooldown", button)
	cooldown:SetAllPoints(button)
	cooldown:Hide()
	button.cooldown = cooldown
	
	return button
end


function clcret:UpdateUI()
	-- queue
	for i = 1, 3 do
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

-- melee range check
function clcret:CheckRange()
	local range = IsSpellInRange(spells["cs"].name, "target")	
	if range ~= nil and range == 0 then
		for i=1, 3 do
			buttons[i].texture:SetVertexColor(0.8, 0.1, 0.1)
		end
	else
		for i=1, 3 do
			buttons[i].texture:SetVertexColor(1, 1, 1)
		end
	end
end


function clcret:CheckAW()
	local start, duration = GetSpellCooldown(awSpellName)
	if duration > 0 then
		awButton:Hide()
	else
		awButton:Show()
	end
	--[[
	local start, duration = GetSpellCooldown(spells["aw"].name)
	if start ~= aw.start then 
			aw.start = start
			aw.duration = duration
			local cd = start + duration - GetTime()
			if cd > 0 then
					awButton.cooldown:SetCooldown(aw.start, aw.duration)
					awButton.cooldown:Show()
			else
					awButton.cooldown:Hide()
			end
	end
	]]
end

function clcret:CheckDP()
	local start, duration = GetSpellCooldown(spells["dp"].name)
	if duration > 1.6 then
		dpButton:Hide()
	else
		dpButton:Show()
	end
end

local function MySort(a, b)
	if a.cd == b.cd then
		return a.priority < b.priority
	else
		return a.cd < b.cd
	end
end

local lastgcd = 0
function clcret:CheckQueue()
	local mana, ctime, gcd, gcdStart, gcdDuration, v
	ctime = GetTime()
	
	mana = UnitMana("player")
	
	-- get gcd
	gcdStart, gcdDuration = GetSpellCooldown(cleanseSpellName)
	gcd = max(0, gcdStart + gcdDuration - ctime)
	
	-- update cooldowns
	for i=1, numSpells do
		v = pq[i]
		pq[i].cdStart, pq[i].cdDuration = GetSpellCooldown(v.name)
		pq[i].cd = max(0, pq[i].cdStart + pq[i].cdDuration - ctime)
		
		-- how check
		if v.alias == "how" then
			if not IsUsableSpell(v.name) then pq[i].cd = 100 end
		-- art of war for exorcism check
		elseif v.alias == "exo" then
			if UnitBuff("player", taowSpellName) == nil then pq[i].cd = 100 end
		-- consecration min mana
		elseif v.alias == "cons" then
			if db.manaCons > 0 and mana < db.manaCons then pq[i].cd = 100 end
		-- divine plea max mana
		elseif v.alias == "dp" then
			if db.manaDP > 0 and mana > db.manaDP then pq[i].cd = 100 end
		end
		
		-- pq[i].xcd = pq[i].cd
		pq[i].xcd = pq[i].cd - gcd
	end

	self:GetBest(1)
	self:GetBest(2)
	self:GetBest(3)
	
	self:UpdateUI()
end

function clcret:GetBest(pos)
	local xprio, xcd, xindex
	xindex = 1
	xprio = 1
	xcd = pq[1].xcd
	
	for i = 1, numSpells do
		if pq[i].xcd < xcd or (pq[i].xcd == xcd and pq[i].priority < xprio) then
			xindex = i
			xprio = pq[i].priority
			xcd = pq[i].xcd
		end
		pq[i].xcd = max(0, pq[i].xcd - 1.5)
	end
	self:QD(pos, xindex)
	pq[xindex].xcd = 1000
end

function clcret:QD(i, j)
	dq[i].name = pq[j].name
	dq[i].cdStart = pq[j].cdStart
	dq[i].cdDuration = pq[j].cdDuration
	dq[i].cd = pq[j].cd
end

function clcret:Enable()
	if init then
		enabled = true
		self.frame:Show()
	end
end

function clcret:Disable()
	if init then
		enabled = false
		self.frame:Hide()
	end
end


function clcret:OnEnable()
	self:Enable()
end

function clcret:OnDisable() 
	self:Disable()
end


function clcret:ToggleLock()
	if locked then
		locked = false
		self.frame:EnableMouse(true)
		self.frame.texture:Show()
	else
		locked = true
		self.frame:EnableMouse(false)
		self.frame.texture:Hide()
	end
end


function clcret:CenterHorizontally()
	db.x = (UIParent:GetWidth() / 2 - 110 * db.scale) / db.scale
	self:UpdateFrameSettings()
end


function clcret:InitUI()
	local frame = CreateFrame("Frame", "clcretFrame", UIParent)
	frame:SetWidth(220)
	frame:SetHeight(70)
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
	texture:SetTexture("Interface\\AddOns\\clcret\\textures\\minimalist")
	texture:SetVertexColor(0, 0, 0, 1)
	texture:Hide()
	frame.texture = texture

	self.frame = frame
	
	-- queue
	buttons[1] = self:CreateButton("B1", 70, 70, "CENTER", clcretFrame, "CENTER", 0, 0)
	buttons[2] = self:CreateButton("B2", 40, 40, "CENTER", clcretFrame, "CENTER", 57, -15)
	buttons[3] = self:CreateButton("B3", 30, 30, "CENTER", clcretFrame, "CENTER", 94, -20)
	
	-- aw
	awButton = self:CreateButton("AW", 40, 40, "CENTER", clcretFrame, "CENTER", -57, -15)
	awButton.texture:SetTexture(GetSpellTexture(awSpellName))
	-- dp
	dpButton = self:CreateButton("DP", 30, 30, "CENTER", clcretFrame, "CENTER", -94, -20)
	dpButton.texture:SetTexture(GetSpellTexture(spells["dp"].name))
	
	frame:SetScale(db.scale)
	
	init = true
	self:Disable()
	self.frame:SetScript("OnUpdate", OnUpdate)
end

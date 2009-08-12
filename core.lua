-- localization dependant stuff
local primarySpec = "Activate Primary Spec"
local secondarySpec = "Activate Secondary Spec"
-- ------------------------------------------------------------------------------------------

local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

-- the art of war
local taowSpellName = GetSpellInfo(59578)
local awSpellName = GetSpellInfo(31884)

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
local q 	-- work queue
local lastq = nil
local buttons = {}
local enabled = false
local awButton = nil
local aw = { ["start"] = 0, ["duration"] = 0 }
local dp = { ["start"] = 0, ["duration"] = 0 }
local init = false
local locked = true

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
		}
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
				p1 = {
					
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
	
	self:RegisterEvent("PLAYER_TALENT_UPDATE")
	self:ScheduleTimer("Init", 1)
	self:RegisterEvent("UNIT_SPELLCAST_START")
end


function clcret:UNIT_SPELLCAST_START(event, unit, spell, spellRank)
	if not enabled then return end
	
	if unit == "player" then
		if spell == primarySpec or spell == secondarySpec then
			self:Disable()
			self:ScheduleTimer("PLAYER_TALENT_UPDATE", 6) -- check again in case player decided not to finish the cast
		end
	end
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
end

function clcret:InitSpells()
	for alias, data in pairs(spells) do
		spells[alias].name = GetSpellInfo(data.id)
	end
end


function clcret:UpdateFCFS()
	pq = {}
	local check = {}
	
	for i, alias in ipairs(db.fcfs) do
		if not check[alias] then -- take care of double entries
			check[alias] = true
			if alias ~= "none" then
				table.insert(pq, { alias = alias, name = spells[alias].name, priority = i })
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
local function clcretOnUpdate(this, elapsed)
	throttle = throttle + elapsed
	if throttle > 0.1 then
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
		button.texture:SetTexture(GetSpellTexture(q[i].name))
			
		if q[i].cd > 0 then
				button.cooldown:SetCooldown(q[i].cdStart, q[i].cdDuration)
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

function clcret:CheckQueue()
	q = pq

	-- update cooldowns
	-- save start/duration for cd display
	local ctime = GetTime()
	for i, v in ipairs(q) do
		q[i].cdStart, q[i].cdDuration, enabled = GetSpellCooldown(GetSpellInfo(v.name))
		q[i].cd = max(0, q[i].cdStart + q[i].cdDuration - ctime)
		
		-- how check
		if v.alias == "how" then
			if not IsUsableSpell(v.name) then
				q[i].cd = 100
			end
		-- art of war for exorcism check
		elseif v.alias == "exo" then
			if UnitBuff("player", taowSpellName) == nil then
				q[i].cd = 100
			end
		end
		
	end

	-- sort the list
	table.sort(q, MySort)
	
	self:UpdateUI()
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
	self.frame:SetScript("OnUpdate", clcretOnUpdate)
end

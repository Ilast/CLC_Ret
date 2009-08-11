-- localization dependant stuff
local primarySpec = "Activate Primary Spec"
local secondarySpec = "Activate Secondary Spec"
-- ------------------------------------------------------------------------------------------

-- the art of war
taow = GetSpellInfo(59578)

local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

local clcret = LibStub("AceAddon-3.0"):NewAddon("clcret", "AceEvent-3.0", "AceConsole-3.0", "AceTimer-3.0")

local fcfs = { "how", "cs", "jol", "ds", "cons", "exo" }


local spells = {
	how		= { id = 48806 },
	cs 		= { id = 35395 },
	ds 		= { id = 53385 },
	jol 	= { id = 20271 },
	cons 	= { id = 48819 },
	exo 	= { id = 48801 },
	dp 		= { id = 54428 },
	ss 		= { id = 53601 },
	aw 		= { id = 31884 },
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

function clcret:OnInitialize()
		self:RegisterChatCommand("clcret", function()
			if enabled then
				self:Enable()
			else
				self:Enable()
			end
        end)
		
		self:RegisterEvent("PLAYER_TALENT_UPDATE")
		self:ScheduleTimer("Init", 15)
		self:RegisterEvent("UNIT_SPELLCAST_START")
end


function clcret:UNIT_SPELLCAST_START(event, unit, spell, spellRank)
	if not enabled then return end
	
	if unit == "player" and (spell == primarySpec or spell == secondarySpec) then
		self:Disable()
		self:ScheduleTimer("PLAYER_TALENT_UPDATE", 6) -- check again in case player decided not to finish the cast
	end
end


function clcret:Init()
	self:InitSpells()
	self:InitUI()
	self:PLAYER_TALENT_UPDATE()
end

function clcret:InitSpells()
	for alias, data in pairs(spells) do
		spells[alias].name = GetSpellInfo(data.id)
	end
	
	pq = {}
	
	for i, alias in ipairs(fcfs) do
		table.insert(pq, { alias = alias, name = spells[alias].name, priority = i })
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


function clcret:InitUI()
	self.frame = CreateFrame("Frame", "clcretFrame", UIParent)
	self.frame:SetWidth(200)
	self.frame:SetHeight(100)
	self.frame:SetPoint("CENTER", 0, -200)

	-- queue
	buttons[1] = self:CreateButton("B1", 70, 70, "CENTER", clcretFrame, "CENTER", 0, 0)
	buttons[2] = self:CreateButton("B2", 40, 40, "CENTER", clcretFrame, "CENTER", 57, -15)
	buttons[3] = self:CreateButton("B3", 30, 30, "CENTER", clcretFrame, "CENTER", 94, -20)
	
	-- aw
	awButton = self:CreateButton("AW", 40, 40, "CENTER", clcretFrame, "CENTER", -57, -15)
	awButton.texture:SetTexture(GetSpellTexture(spells["aw"].name))
	-- dp
	dpButton = self:CreateButton("DP", 30, 30, "CENTER", clcretFrame, "CENTER", -94, -20)
	dpButton.texture:SetTexture(GetSpellTexture(spells["dp"].name))
	
	init = true
	self:Disable()
	self.frame:SetScript("OnUpdate", clcretOnUpdate)
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
	local start, duration = GetSpellCooldown(spells["aw"].name)
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
			if UnitBuff("player", taow) == nil then
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

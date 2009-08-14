-- get beacon and ss buff names from the spells
local buffBoL = GetSpellInfo(53563)
local buffSS = GetSpellInfo(53601)
local buffFoL = GetSpellInfo(66922)
local buffJotP = GetSpellInfo(53655)
-- the icon for SS buff since the proc has the same name
local buffIconSS = "Interface\\Icons\\Ability_Paladin_BlessedMending"

local layoutPlayerBars = { "jotp", "bol", "ss" }

-- TOOLS
local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcbpt: "..tostring(s))
end

local clcbpt = LibStub("AceAddon-3.0"):NewAddon("clcbpt", "AceEvent-3.0", "AceConsole-3.0")
local Media = LibStub("LibSharedMedia-3.0", true)

DEFAULT_LSM_FONT = Media:GetDefault("font")
DEFAULT_LSM_TEXTURE = 'Minimalist'
DEFAULT_LSM_SOUND = 'BellTollNightElf'

-- register the sound I used so far
if not Media:IsValid('sound', 'BellTollNightElf') then
	Media:Register('sound', 'BellTollNightElf', 'Sound\\Doodad\\BellTollNightElf.wav')
end
-- there seems to be no sound in LSM without other addons, so set the bell default
if DEFAULT_LSM_SOUND == "None" then
	DEFAULT_LSM_SOUND = 'BellTollNightElf'
end

-- register the minimalist texture too
if not Media:IsValid('statusbar', 'Minimalist') then
	Media:Register('statusbar', 'Minimalist', 'Interface\\AddOns\\clcbpt\\textures\\minimalist')
end

local bgtex = 'Interface\\AddOns\\clcbpt\\textures\\minimalist'

local db
local scanDelay

-- default options
-- default values
local defaults = {
	char = {
		performance = {
			barFPS = 20,
			scanFrequency = 2,
		},
		player = {
			growUp = true,
			x = 400,
			y = 400,
			width = 200,
			height = 9,
			font = 9,
			fontName = DEFAULT_LSM_FONT,
			bars = {
				ss = {
					color = {0, 0, 1, 1},
					texture = DEFAULT_LSM_TEXTURE,
					sound = DEFAULT_LSM_SOUND,
					soundWarn = true,
					pulseWarn = true,
					enabled = true,
				},
				bol = {
					color = {1, 0, 0, 1},
					texture = DEFAULT_LSM_TEXTURE,
					sound = DEFAULT_LSM_SOUND,
					soundWarn = true,
					pulseWarn = true,
					enabled = true,
				},
				jotp = {
					color = {1, 1, 0, 1},
					texture = DEFAULT_LSM_TEXTURE,
					sound = DEFAULT_LSM_SOUND,
					soundWarn = true,
					pulseWarn = true,
					enabled = true,
				},
			},
			fol = {
				color = {0, 1, 0, 1},
				texture = DEFAULT_LSM_TEXTURE,
				enabled = true,
			}
		},
		group = {
			growUp = true,
			x = 400,
			y = 300,
			width = 130,
			height = 8,
			font = 8,
			fontName = DEFAULT_LSM_FONT,
			texture = DEFAULT_LSM_TEXTURE,
			enabled = true,
		},
		warn = {
			sound = true,
			pulse = true,
			pulseDuration = 2,
			timer = 3,
			pulseMin = 100,
			pulseMax = 150,
			x = 0,
			y = 0,
		},
	}
}

local options = {
	type = "group",
	args = {
		-- anchors
		anchors = {
			type = "execute",
			name = "Anchors",
			func = function()
				clcbpt:ToggleAnchors()
			end,
		},
		
		-- scan frequency
		scans = {
			type = "range",
			name = "Scans per second",
			min = 1,
			max = 10,
			step = 1,
			get = function(info) return db.performance.scanFrequency end,
			set = function(info, val)
				db.performance.scanFrequency = val
				scanDelay = 1 / db.performance.scanFrequency
			end,
		},
		
		-- warnings
		warnings = {
			type = "group",
			name = "Warnings",
			order = 3,
			args = {
				soundToggle = {
					type = "toggle",
					name = "Sound Warnings",
					get = function(info) return db.warn.sound end,
					set = function(info, val) db.warn.sound = val end,
			
				},
				pulseToggle = {
					type = "toggle",
					name = "Pulse Warnings",
					get = function(info) return db.warn.pulse end,
					set = function(info, val) db.warn.pulse = val end,
			
				},
				awarnTimer = {
					type = "range",
					name = "Warn Time",
					min = 1,
					max = 60,
					step = 1,
					bigStep = 1,
					get = function(info) return db.warn.timer end,
					set = function(info, val) db.warn.timer = val end,
				},
				bpulseDuration = {
					type = "range",
					name = "Pulse Duration",
					min = 1,
					max = 10,
					step = 1,
					bigStep = 1,
					get = function(info) return db.warn.pulseDuration end,
					set = function(info, val) db.warn.pulseDuration = val end,
				},
				pulseSizeMin = {
					type = "range",
					name = "Pulse Size Min",
					min = 10,
					max = 400,
					step = 1,
					bigStep = 10,
					get = function(info) return db.warn.pulseMin end,
					set = function(info, val)
						db.warn.pulseMin = val
						clcbpt:NewPulse("Interface\\Icons\\ability_paladin_beaconoflight")
					end,
				},
				pulseSizeMax = {
					type = "range",
					name = "Pulse Size Max",
					min = 15,
					max = 500,
					step = 1,
					bigStep = 10,
					get = function(info) return db.warn.pulseMax end,
					set = function(info, val)
						db.warn.pulseMax = val
						clcbpt:NewPulse("Interface\\Icons\\ability_paladin_beaconoflight")
					end,
				},
				pulsePosX = {
					type = "range",
					name = "Pulse Position Horizontal",
					min = -2000,
					max = 2000,
					step = 1,
					bigStep = 10,
					get = function(info) return db.warn.x end,
					set = function(info, val)
						db.warn.x = val
						clcbpt:NewPulse("Interface\\Icons\\ability_paladin_beaconoflight")
					end,
				},
				pulsePosY = {
					type = "range",
					name = "Pulse Position Vertical",
					min = -2000,
					max = 2000,
					step = 1,
					bigStep = 10,
					get = function(info) return db.warn.y end,
					set = function(info, val)
						db.warn.y = val
						clcbpt:NewPulse("Interface\\Icons\\ability_paladin_beaconoflight")
					end,
				},
			}
		}, 
		
		-- bars
		player = {
			type = "group",
			name = "Player",
			order = 1,
			args = {
				growUp = {
					order = 1,
					type = "toggle",
					name = "Grow Up",
					get = function(info) return db.player.growUp end,
					set = function(info, val) db.player.growUp = val end,
				},
				width = {
					type = "range",
					name = "Width",
					min = 10,
					max = 400,
					step = 1,
					bigStep = 10,
					order = 5,
					get = function(info) return db.player.width end,
					set = function(info, val)
						clcbpt:PlayerBarsUpdateLayout()
						db.player.width = val
					end,
				},
				height = {
					type = "range",
					name = "Height",
					min = 5,
					max = 100,
					step = 1,
					bigStep = 5,
					order = 6,
					get = function(info) return db.player.height end,
					set = function(info, val)
						db.player.height = val
						clcbpt:PlayerBarsUpdateLayout()
					end,
				},
				font = {
					type = "range",
					name = "Font",
					min = 5,
					max = 50,
					step = 1,
					bigStep = 1,
					order = 10,
					get = function(info) return db.player.font end,
					set = function(info, val)
						db.player.font = val
						clcbpt:PlayerBarsUpdateLayout()
					end,
				},
				fontName = {
					name = "Font Family",
					type = "select",
					order = 11,
					get = function()
						return db.player.fontName
					end,
					set = function(info, value)
						db.player.fontName = value
						clcbpt:PlayerBarsUpdateLayout()
					end,
					values = Media:HashTable('font'),
					dialogControl = 'LSM30_Font',
				},
				fol = {
					type = "group",
					name = "fol hot",
					order = 1,
					args = {
						enabled = {
							type = "toggle",
							name = "Enabled",
							order = 1,
							get = function(info) return db.player.fol.enabled end,
							set = function(info, val)
								db.player.fol.enabled = val
							end,
						},
						color = {
							type = "color",
							name = "color",
							order = 2,
							hasAlpha = true,
							get = function(info) return unpack(db.player.fol.color) end,
							set = function(info, r, g, b, a)
								db.player.fol.color = {r, g, b, a}
								clcbpt:FolBarsUpdateLayout()
							end,
						},
						texture = {
							name = "texture",
							type = "select",
							order = 3,
							get = function()
								return db.player.fol.texture
							end,
							set = function(info, value)
								db.player.fol.texture = value
								clcbpt:FolBarsUpdateLayout()
							end,
							values = Media:HashTable('statusbar'),
							dialogControl = 'LSM30_Statusbar',
						},
					},
				},
			},
		},
		group = {
			type = "group",
			name = "Group",
			order = 2,
			args = {
				enabled = {
					type = "toggle",
					name = "Enabled",
					order = 1,
					get = function(info) return db.group.enabled end,
					set = function(info, val)
						db.group.enabled = val
					end,
				},
				growUp = {
					order = 2,
					type = "toggle",
					name = "Grow Up",
					get = function(info) return db.group.growUp end,
					set = function(info, val) db.group.growUp = val end,
				},
				width = {
					type = "range",
					name = "Width",
					order = 4,
					min = 10,
					max = 400,
					step = 1,
					bigStep = 10,
					get = function(info) return db.group.width end,
					set = function(info, val)
						db.group.width = val
						clcbpt:GroupBarsUpdateLayout()
					end,
				},
				height = {
					type = "range",
					name = "Height",
					order = 5,
					min = 5,
					max = 100,
					step = 1,
					bigStep = 5,
					get = function(info) return db.group.height end,
					set = function(info, val)
						db.group.height = val
						clcbpt:GroupBarsUpdateLayout()
					end,
				},
				font = {
					type = "range",
					name = "Font",
					order = 6,
					min = 5,
					max = 50,
					step = 1,
					bigStep = 1,
					get = function(info) return db.group.font end,
					set = function(info, val)
						db.group.font = val
						clcbpt:GroupBarsUpdateLayout()
					end,
				},
				fontName = {
					name = "Font Family",
					type = "select",
					order = 7,
					get = function()
						return db.group.fontName
					end,
					set = function(info, value)
						db.group.fontName = value
						clcbpt:GroupBarsUpdateLayout()
					end,
					values = Media:HashTable('font'),
					dialogControl = 'LSM30_Font',
				},
				texture = {
					name = "Texture",
					type = "select",
					order = 8,
					get = function()
						return db.group.texture
					end,
					set = function(info, value)
						db.group.texture = value
						clcbpt:GroupBarsUpdateLayout()
					end,
					values = Media:HashTable('statusbar'),
					dialogControl = 'LSM30_Statusbar',
				},
			}
		}
	}
}

function clcbpt:AddPlayerBarsOptions()
	for _, name in ipairs(layoutPlayerBars) do
		options.args.player.args[name] = {
			type = "group",
			name = name,
			order = 2,
			args = {
				enabled = {
					type = "toggle",
					name = "Enabled",
					order = 1,
					get = function(info) return db.player.bars[name].enabled end,
					set = function(info, val)
						db.player.bars[name].enabled = val
					end,
				},
				color = {
					type = "color",
					name = "color",
					order = 2,
					hasAlpha = true,
					get = function(info) return unpack(db.player.bars[name].color) end,
					set = function(info, r, g, b, a)
						db.player.bars[name].color = {r, g, b, a}
						clcbpt:PlayerBarUpdateLayout(name)
					end,
				},
				texture = {
					name = "texture",
					type = "select",
					order = 3,
					get = function()
						return db.player.bars[name].texture
					end,
					set = function(info, value)
						db.player.bars[name].texture = value
						clcbpt:PlayerBarUpdateLayout(name)
					end,
					values = Media:HashTable('statusbar'),
					dialogControl = 'LSM30_Statusbar',
				},
				sound = {
					name = "sound",
					type = "select",
					order = 4,
					get = function()
						return db.player.bars[name].sound
					end,
					set = function(info, value)
						db.player.bars[name].sound = value
					end,
					values = Media:HashTable('sound'),
					dialogControl = 'LSM30_Sound',
				},
				pulseWarn = {
					type = "toggle",
					name = "Pulse Warning",
					order = 5,
					get = function(info) return db.player.bars[name].pulseWarn end,
					set = function(info, val)
						db.player.bars[name].pulseWarn = val
					end,
				},
				soundWarn = {
					type = "toggle",
					name = "Sound Warning",
					order = 6,
					get = function(info) return db.player.bars[name].soundWarn end,
					set = function(info, val)
						db.player.bars[name].soundWarn = val
					end,
				},
			}
		}
	end
end

local roster = { "player" }

local groupBars = {}
local numGroupBars = 0
local usedGroupBars = 0
local usedGroupBarsLast = 0

local playerBars = {}
local orderPlayerBars

local folBars = {}
local numFolBars = 0
local usedFolBars = 0
local usedFolBarsLast = 0
local orderFolBars

local updateStepBars
local scanDelay

local showAnchors = false

local pulse


local throttleCheckAuras = 0
local throttleBarsUpdate = 0
local throttleFolUpdate = 0
local function OnUpdate(this, elapsed)
	throttleFolUpdate = throttleFolUpdate + elapsed
	if throttleFolUpdate > 0.05 then
		clcbpt:FolBarsUpdate()
		clcbpt:PulseUpdate()
		throttleFolUpdate = 0
	end

	throttleBarsUpdate = throttleBarsUpdate + elapsed
	if throttleBarsUpdate > 0.1 then
		clcbpt:PlayerBarsUpdate()
		clcbpt:GroupBarsUpdate()
		throttleBarsUpdate = 0
	end

	throttleCheckAuras = throttleCheckAuras + elapsed
	if throttleCheckAuras > scanDelay then
		clcbpt:CheckAuras()
		throttleCheckAuras = 0
	end
end


function clcbpt:OnInitialize()
	-- SAVEDVARS
	self.db = LibStub("AceDB-3.0"):New("clcbptDB", defaults)
	db = self.db.char
	
	-- throttles
	updateStepBars = 1 / db.performance.barFPS
	scanDelay = 1 / db.performance.scanFrequency
	
	player = UnitName("player")
	
	-- options
	self:AddPlayerBarsOptions()
	
	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("clcbpt", options)
	
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions("clcbpt")
	
	-- register chat commands
	-- self:RegisterChatCommand("rl", ReloadUI)
	self:RegisterChatCommand("clcbpt", function() InterfaceOptionsFrame_OpenToCategory("clcbpt") end)
	
	-- roster
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateRoster")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateRoster")
	
	-- create anchors
	self:CreateAnchor("Player", db.player.width, db.player.height, db.player.x, db.player.y)
	self:CreateAnchor("Group", db.group.width, db.group.height, db.group.x, db.group.y)
	
	self:CreatePulse()
	self:SetupPlayerBars()
	self:PlayerBarsUpdateLayout()
	
	-- update frame
	self.uf = CreateFrame("Frame")
	self.uf:SetScript("OnUpdate", OnUpdate)
end


function clcbpt:CreatePulse()
	local frame = CreateFrame("Frame", "clcPulse", UIParent)
	frame.icon = frame:CreateTexture(nil, "BACKGROUND")
	frame.icon:SetAllPoints()
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame:Hide()
	
	pulse = frame
	pulse.start = 0
	pulse.duration = 0
end
function clcbpt:NewPulse(icon)
	-- update position too, for the "interactive" options
	local opt = db.warn
	pulse:SetPoint("CENTER", UIParent, opt.x, opt.y)
	pulse.start = GetTime()
	pulse.duration = opt.pulseDuration

	pulse.icon:SetTexture(icon)
	pulse:SetWidth(opt.pulseMax)
	pulse:SetHeight(opt.pulseMax)
	pulse:SetAlpha(1)
	
	pulse:Show()
end
function clcbpt:PulseUpdate()
	local current = GetTime() - pulse.start
	if current > pulse.duration then
		pulse:Hide()
		return
	end
	
	-- last 1s pulse
	---[[
	local opt = db.warn
	if (pulse.duration - current) < 1 then
		current = pulse.duration - current
		local size = opt.pulseMin + (opt.pulseMax - opt.pulseMin) * current
		pulse:SetWidth(size)
		pulse:SetHeight(size)
		pulse:SetAlpha(current)
	end
end

-- warning function
function clcbpt:Warn(name)
	local bar = playerBars[name]
	local opt = db.player.bars[name]

	if db.warn.sound and opt.soundWarn then
		PlaySoundFile(Media:Fetch('sound', opt.sound))
	end
	
	if db.warn.pulse and opt.pulseWarn then
		self:NewPulse(bar.optIcon)
	end
end


function clcbpt:UpdateRoster()
	local xr = {} -- roster
	
	local unit
	if GetNumRaidMembers() > 0 then
		for i = 1, 40 do 
			unit = "raid" .. i
			if UnitExists(unit) then table.insert(xr, unit) end
		end
	else
		table.insert(xr, "player")
		if GetNumPartyMembers() > 0 then
			for i = 1, 4 do 
				unit = "party" .. i
				if UnitExists(unit) then table.insert(xr, unit) end
			end
		end
	end
			
	roster = xr
end


function clcbpt:CheckAuras()
	local name, icon, duration, expirationTime, caster, targetName
	
	-- jotp check
	if db.player.bars["jotp"].enabled then
		name, _, _, _, _, duration, expirationTime = UnitBuff("player", buffJotP)
		self:UpdatePlayerBarData("jotp", duration or 0, expirationTime or 0, "JotP")
	end
	
	local nobol = true
	local noss = true
	
	local usedGroupBars = 0
	local usedFolBars = 0

	---[[
	local i
	for _, unit in ipairs(roster) do
		-- check BoL
		if db.player.bars["bol"].enabled then
			if nobol then
				name, _, _, _, _, duration, expirationTime, caster = UnitBuff(unit, buffBoL)
				if name and caster == "player" then
					nobol = false
					self:UpdatePlayerBarData("bol", duration, expirationTime, UnitName(unit))
				end
			end
		end
		
		if db.player.fol.enabled then
			-- check for fol hot
			name, _, _, _, _, duration, expirationTime, caster = UnitBuff(unit, buffFoL)
			if name and caster == "player" then
				usedFolBars = usedFolBars + 1
				self:UpdateFolBarData(usedFolBars, duration, expirationTime, UnitName(unit))
			end
		end
		
		-- check for ss and if found look for the proper one, gg naming 2 buffs with the exact same fucking name and no way to get buffs by ID
		name, _, icon, _, _, duration, expirationTime, caster = UnitBuff(unit, buffSS)
		if name and caster then
			if caster == "player" then
				if db.player.bars["ss"].enabled then
					noss = false
					if icon == buffIconSS then
						self:UpdatePlayerBarData("ss", duration, expirationTime, UnitName(unit))
					else
						duration, expirationTime = self:GetSS(unit)
						self:UpdatePlayerBarData("ss", duration, expirationTime, UnitName(unit))
					end
				end
			elseif db.group.enabled then
				-- another paladin's ss
				if not (icon == buffIconSS) then
					duration, expirationTime = self:GetSS(unit)
				end
				usedGroupBars = usedGroupBars + 1
				self:UpdateGroupBarData(usedGroupBars, duration, expirationTime, UnitName(caster), UnitName(unit))
			end
		end
	end
	
	if nobol and db.player.bars["bol"].enabled then self:UpdatePlayerBarData("bol", 0, 0, "") end
	if noss and db.player.bars["ss"].enabled then self:UpdatePlayerBarData("ss", 0, 0, "") end
	
	-- disable not used groupBars
	if db.group.enabled then
		if usedGroupBarsLast > usedGroupBars then
			for index = (usedGroupBars + 1), usedGroupBarsLast do
				groupBars[index]:Hide()
				groupBars[index].active = false
			end	
		end
		usedGroupBarsLast = usedGroupBars
	end
	
	-- disable not used folBars
	if db.player.fol.enabled then
		if usedFolBarsLast > usedFolBars then
			for index = usedFolBars + 1, usedFolBarsLast do
				folBars[index]:Hide()
				folBars[index].active = false
			end
		end
		usedFolBarsLast = usedFolBars
	end
end


function clcbpt:GetSS(unit)	
	local name, icon, duration, expirationTime
	local i = 1
	while true do
		name, _, icon, _, _, duration, expirationTime = UnitBuff(unit, i)
		if not name then break end
		if name == buffSS and icon == buffIconSS then
			return duration, expirationTime
		end
		i = i + 1
	end
	return 0, 0
end


function clcbpt:UpdatePlayerBarData(name, duration, expirationTime, targetName)
	local bar = playerBars[name]
	bar.oldExpirationTime = bar.expirationTime
	bar.expirationTime = expirationTime
	bar.duration = duration
	
	-- buff refresh
	if bar.oldExpirationTime < bar.expirationTime then
		bar.warn = true
	end
	
	-- title of the bar
	if bar.targetName ~= targetName then
		bar.targetName = targetName
		bar.label:SetText(targetName)
	end
end


function clcbpt:UpdateFolBarData(index, duration, expirationTime, targetName)
	-- create more if we don't have enough
	if index > numFolBars then self:CreateFolBar() end
	local bar = folBars[index]
	bar.active = true
	
	-- timer
	bar.expirationTime = expirationTime
	bar.duration = duration
	
	-- label
	if targetName then
		bar.label:SetText(targetName)
	end
end


function clcbpt:UpdateGroupBarData(index, duration, expirationTime, sourceName, targetName)
	-- create more if we don't have enough
	if index > numGroupBars then self:CreateGroupBar() end
	local bar = groupBars[index]
	bar.active = true
	
	-- timer
	bar.expirationTime = expirationTime
	bar.duration = duration
	
	-- label
	if sourceName then
		bar.label:SetText(sourceName .. "-" .. targetName)
	end
end


function clcbpt:SetupPlayerBars()
	-- jotp, bol, ss bars
	self:CreatePlayerBar("jotp", "Interface\\Icons\\ability_paladin_judgementofthepure")
	self:CreatePlayerBar("bol", "Interface\\Icons\\ability_paladin_beaconoflight")
	self:CreatePlayerBar("ss", "Interface\\Icons\\ability_paladin_blessedmending")
end


-- player bars update
----------------------------------------------------------------------------
function clcbpt:PlayerBarsUpdate()
	orderPlayerBars = 1
	-- jotp, bol, ss
	for _, name in ipairs(layoutPlayerBars) do
		self:PlayerBarUpdate(name)
	end
	orderPlayerBars = orderPlayerBars - 1
end
function clcbpt:PlayerBarUpdate(name)
	if not db.player.bars[name].enabled then
		playerBars[name]:Hide()
		return
	end

	local bar = playerBars[name]
	local opt = db.player
	local optBar = db.player.bars[name]

	local xtime = GetTime()
	remaining = bar.expirationTime - xtime
	if remaining <= 0 then
		if bar.warn then
			bar.warn = false
			self:Warn(name)
		end
		bar:Hide()
		return
	end
	
	bar:Show()
	
	-- check for warn
	if remaining <= db.warn.timer and bar.warn then
		bar.warn = false -- only do it one time
		self:Warn(name)
	end
	
	local width, height
	width = opt.width - opt.height
	height = opt.height
	
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar.icon:SetWidth(height)
	bar.icon:SetHeight(height)
	
	local progress = width * remaining / bar.duration - width
	local texture = bar.texture
	texture:SetPoint("RIGHT", bar, "RIGHT", progress, 0)
	
	local spark = bar.spark
	spark:SetPoint("TOP", texture, "TOPRIGHT", 0, 7)
	spark:SetPoint("BOTTOM", texture, "BOTTOMRIGHT", 0, -7)
	
	bar.labelTimer:SetText(floor(remaining + 0.5))
	
	if db.player.growUp then
		bar:SetPoint("TOPLEFT", "clcbptAnchorsPlayer", "BOTTOMLEFT", opt.height, opt.height * orderPlayerBars) 
	else
		bar:SetPoint("TOPLEFT", "clcbptAnchorsPlayer", "TOPLEFT", opt.height, -opt.height * (orderPlayerBars - 1)) 
	end
	orderPlayerBars = orderPlayerBars + 1
end
----------------------------------------------------------------------------


-- fol bars update
----------------------------------------------------------------------------
function clcbpt:FolBarsUpdate()
	for index, bar in ipairs(folBars) do
		if not bar.active then return end
		self:FolBarUpdate(index)
	end
end
function clcbpt:FolBarUpdate(index)
	if not db.player.fol.enabled then
		folBars[index]:Hide()
		return
	end


	local bar = folBars[index]
	local opt = db.player
	
	local xtime = GetTime()
	remaining = bar.expirationTime - xtime
	if remaining <= 0 then
		bar:Hide()
		return
	end
	
	bar:Show()
	
	local width, height
	width = opt.width - opt.height
	height = opt.height
	
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar.icon:SetWidth(height)
	bar.icon:SetHeight(height)
	
	local progress = width * remaining / bar.duration - width
	local texture = bar.texture
	texture:SetPoint("RIGHT", bar, "RIGHT", progress, 0)
	
	local spark = bar.spark
	spark:SetPoint("TOP", texture, "TOPRIGHT", 0, 7)
	spark:SetPoint("BOTTOM", texture, "BOTTOMRIGHT", 0, -7)
	
	bar.labelTimer:SetText(floor(remaining + 0.5))
	
	if db.player.growUp then
		bar:SetPoint("TOPLEFT", "clcbptAnchorsPlayer", "BOTTOMLEFT", opt.height, opt.height * (index + orderPlayerBars)) 
	else
		bar:SetPoint("TOPLEFT", "clcbptAnchorsPlayer", "TOPLEFT", opt.height, - opt.height * (index + orderPlayerBars - 1)) 
	end
end
----------------------------------------------------------------------------


-- group bars update
----------------------------------------------------------------------------
function clcbpt:GroupBarsUpdate()
	for index, bar in ipairs(groupBars) do
		if not bar.active then return end
		self:GroupBarUpdate(index)
	end
end
function clcbpt:GroupBarUpdate(index)
	if not db.group.enabled then
		groupBars[index]:Hide()
		return
	end


	local bar = groupBars[index]
	local opt = db.group
	
	local xtime = GetTime()
	remaining = bar.expirationTime - xtime
	if remaining <= 0 then
		bar:Hide()
		return
	end
	
	bar:Show()
	
	local width, height
	width = opt.width - opt.height
	height = opt.height
	
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar.icon:SetWidth(height)
	bar.icon:SetHeight(height)
	
	local progress = width * remaining / bar.duration - width
	local texture = bar.texture
	texture:SetPoint("RIGHT", bar, "RIGHT", progress, 0)
	
	local spark = bar.spark
	spark:SetPoint("TOP", texture, "TOPRIGHT", 0, 7)
	spark:SetPoint("BOTTOM", texture, "BOTTOMRIGHT", 0, -7)
	
	bar.labelTimer:SetText(floor(remaining + 0.5))
	
	if db.group.growUp then
		bar:SetPoint("TOPLEFT", "clcbptAnchorsGroup", "BOTTOMLEFT", opt.height, opt.height * index) 
	else
		bar:SetPoint("TOPLEFT", "clcbptAnchorsGroup", "TOPLEFT", opt.height, - opt.height * (index - 1)) 
	end
end
----------------------------------------------------------------------------

-- update the look of the player bars
----------------------------------------------------------------------------
function clcbpt:PlayerBarsUpdateLayout()
	for name, _ in pairs(playerBars) do
		self:PlayerBarUpdateLayout(name)
	end
	
	-- adjust width and height for anchor
	clcbptAnchorsPlayer:SetWidth(db.player.width)
	clcbptAnchorsPlayer:SetHeight(db.player.height)
end
function clcbpt:PlayerBarUpdateLayout(name)
	local bar = playerBars[name]
	local opt = db.player
	local optBar = db.player.bars[name]
	
	-- color
	bar.texture:SetVertexColor(unpack(optBar.color))
	-- texture
	bar.texture:SetTexture(Media:Fetch('statusbar', optBar.texture))
	-- font size and family
	local _, _, fontFlags = bar.label:GetFont()
	local fontName = Media:Fetch("font", opt.fontName)
	bar.label:SetFont(fontName, opt.font, fontFlags)
	bar.labelTimer:SetFont(fontName, opt.font, fontFlags)
	-- normal update
	-- self:PlayerBarUpdate(name)
end
----------------------------------------------------------------------------

-- update the look of the fol bars
----------------------------------------------------------------------------
function clcbpt:FolBarsUpdateLayout()
	for index in ipairs(folBars) do
		self:FolBarUpdateLayout(index)
	end
end
function clcbpt:FolBarUpdateLayout(index)
	local bar = folBars[index]
	-- color
	bar.texture:SetVertexColor(unpack(db.player.fol.color))
	-- texture
	bar.texture:SetTexture(Media:Fetch('statusbar', db.player.fol.texture))
	-- font size and family
	local _, _, fontFlags = bar.label:GetFont()
	local fontName = Media:Fetch("font", db.player.fontName)
	bar.label:SetFont(fontName, db.player.font, fontFlags)
	bar.labelTimer:SetFont(fontName, db.player.font, fontFlags)
	-- normal update
	-- self:FolBarUpdate(index)
end
----------------------------------------------------------------------------

-- update the look of the group bars
----------------------------------------------------------------------------
function clcbpt:GroupBarsUpdateLayout()
	for index in ipairs(groupBars) do
		self:GroupBarUpdateLayout(index)
	end
	
	-- adjust width and height for anchor
	clcbptAnchorsGroup:SetWidth(db.group.width)
	clcbptAnchorsGroup:SetHeight(db.group.height)
end
function clcbpt:GroupBarUpdateLayout(index)
	local bar = groupBars[index]
	local opt = db.group
	-- color
	bar.texture:SetVertexColor(unpack(db.player.bars["ss"].color))
	-- texture
	bar.texture:SetTexture(Media:Fetch('statusbar', opt.texture))
	-- font size and family
	local _, _, fontFlags = bar.label:GetFont()
	local fontName = Media:Fetch("font", opt.fontName)
	bar.label:SetFont(fontName, opt.font, fontFlags)
	bar.labelTimer:SetFont(fontName, opt.font, fontFlags)
	-- normal update
	-- self:GroupBarUpdate(index)
end
----------------------------------------------------------------------------

function clcbpt:CreateBarFrame(name)
	local frame = CreateFrame("Frame", "clcbpt"..name, UIParent)
	frame.texture = frame:CreateTexture(nil, "ARTWORK")
	
	frame.bgtexture = frame:CreateTexture(nil, "BACKGROUND")
	frame.bgtexture:SetAllPoints()
	frame.bgtexture:SetVertexColor(0, 0, 0, 0.5)
	frame.bgtexture:SetTexture(bgtex)
	
	local spark = frame:CreateTexture(nil, "OVERLAY")
	spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	spark:SetWidth(10)
	spark:SetHeight(10)
	spark:SetBlendMode("ADD")
	spark:SetTexCoord(0, 1, 0, 1)
	frame.spark = spark
	
	frame.label = frame:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	frame.label:ClearAllPoints()
	frame.label:SetPoint("LEFT", frame, "LEFT", 3, 0)
	
	frame.labelTimer = frame:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	frame.labelTimer:ClearAllPoints()
	frame.labelTimer:SetPoint("RIGHT", frame, "RIGHT", -3, 0)
	
	frame.icon = frame:CreateTexture(nil, "OVERLAY")
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	return frame
end


function clcbpt:CreatePlayerBar(name, icon)
	playerBars[name] = self:CreateBarFrame(name)
	local bar = playerBars[name]
	
	-- options
	bar.optIcon = icon
	bar.duration = 0
	bar.expirationTime = 0
	bar.oldExpirationTime = 0
	bar.warn = false
	bar.targetName = ""
	
	local texture = bar.texture
	texture:SetAllPoints()
	
	local iconTex = bar.icon
	iconTex:SetTexture(icon)
	iconTex:SetPoint("RIGHT", bar, "LEFT", 0, 0)
	iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	
	bar:Hide()
end


function clcbpt:CreateFolBar()
	numFolBars = numFolBars + 1
	folBars[numFolBars] = self:CreateBarFrame("Fol" .. numFolBars)
	local bar = folBars[numFolBars]
	
	bar.optIcon = "Interface\\Icons\\spell_holy_flashheal"
	bar.duration = 0
	bar.expirationTime = 0
	bar.active = false
	
	local texture = bar.texture
	texture:SetAllPoints()
	
	local iconTex = bar.icon
	iconTex:SetTexture(bar.optIcon)
	iconTex:SetPoint("RIGHT", bar, "LEFT", 0, 0)
	iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	
	self:FolBarUpdateLayout(numFolBars)
	
	bar:Hide()
end


function clcbpt:CreateGroupBar()
	numGroupBars = numGroupBars + 1
	groupBars[numGroupBars] = self:CreateBarFrame("Group" .. numGroupBars)
	local bar = groupBars[numGroupBars]
	
	bar.optIcon = "Interface\\Icons\\ability_paladin_blessedmending"
	bar.duration = 0
	bar.expirationTime = 0
	bar.active = false
	
	local texture = bar.texture
	texture:SetAllPoints()
	
	local iconTex = bar.icon
	iconTex:SetTexture(bar.optIcon)
	iconTex:SetPoint("RIGHT", bar, "LEFT", 0, 0)
	iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	
	self:GroupBarUpdateLayout(numGroupBars)
	
	bar:Hide()
end


function clcbpt:AnchorsStopMovingOrSizing()
	db.player.x = clcbptAnchorsPlayer:GetLeft()
	db.player.y = clcbptAnchorsPlayer:GetBottom()
	db.group.x 	= clcbptAnchorsGroup:GetLeft()
	db.group.y 	= clcbptAnchorsGroup:GetBottom()
end

-- create an anchor frame
function clcbpt:CreateAnchor(name, width, height, x, y)
	local frame = CreateFrame("Frame", "clcbptAnchors" .. name, UIParent)
	frame:Hide()

	frame:SetWidth(width)
	frame:SetHeight(height)
	frame:SetPoint("BOTTOMLEFT", UIParent, x, y)
	
	local texture = frame:CreateTexture(nil, "BACKGROUND")
	texture:SetAllPoints()
	texture:SetTexture(bgtex)
	texture:SetVertexColor(0, 0, 0, 1)

	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetMovable(true)
	frame:SetScript("OnDragStart", function() this:StartMoving() end)
	frame:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
		clcbpt:AnchorsStopMovingOrSizing()
	end)

	local cheader = frame:CreateFontString(nil, "OVERLAY")
	cheader:ClearAllPoints()
	cheader:SetWidth(150)
	cheader:SetHeight(30)
	cheader:SetPoint("BOTTOM", frame, "TOP", 10, 0)
	cheader:SetFont("Fonts\\FRIZQT__.TTF", 12)
	cheader:SetJustifyH("LEFT")
	cheader:SetText(name)
	cheader:SetShadowOffset(.8, -.8)
	cheader:SetShadowColor(0, 0, 0, 1)

	return frame
end


function clcbpt:ToggleAnchors()
	if showAnchors then
		showAnchors = false
		clcbptAnchorsPlayer:Hide()
		clcbptAnchorsGroup:Hide()
	else
		showAnchors = true
		clcbptAnchorsPlayer:Show()
		clcbptAnchorsGroup:Show()
	end
end

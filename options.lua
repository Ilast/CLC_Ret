local MAX_AURAS = 10
local function bprint(s)
	DEFAULT_CHAT_FRAME:AddMessage("clcret: "..tostring(s))
end

local function GetSpellChoice()
	local spellChoice = { none = "None" }
	for alias, data in pairs(clcret.spells) do
		spellChoice[alias] = data.name
	end
	
	return spellChoice
end

function clcret:InitOptions()
	local db = self.db.char
	local defaults = self.defaults

	local anchorPoints = { CENTER = "CENTER", TOP = "TOP", BOTTOM = "BOTTOM", LEFT = "LEFT", RIGHT = "RIGHT", TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT", BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT" }
	local execList = {
		AuraButtonExecNone = "None",
		AuraButtonExecSkillVisibleAlways = "Skill always visible",
		AuraButtonExecSkillVisibleNoCooldown = "Skill visible when available",
		AuraButtonExecItemVisibleAlways = "OnUse item always visible",
		AuraButtonExecItemVisibleNoCooldown = "OnUse item visible when available",
		AuraButtonExecGenericBuff = "Generic buff",
		AuraButtonExecGenericDebuff = "Generic debuff",
	}
	local skillButtonNames = { "Main skill", "Secondary skill" }
	
	self.options = {
		type = "group",
		args = {
			-- lock frame
			lock = {
				order = 1,
				type = "toggle",
				name = "Lock Frame",
				get = function(info) return self.locked end,
				set = function(info, val)
					clcret:ToggleLock()
				end,
			},
			
			-- full disable toggle
			fullDisable = {
				order = 2,
				type = "toggle",
				name = "Addon disabled",
				get = function(info) return db.fullDisable end,
				set = function(info, val) clcret:FullDisableToggle() end,
			},
			-- full disable toggle
			protEnabled = {
				order = 3,
				type = "toggle",
				name = "Enable prot module",
				get = function(info) return db.protEnabled end,
				set = function(info, val)
					db.protEnabled = val
					clcret:PLAYER_TALENT_UPDATE()
				end,
			},
		
			-- appearance
			appearance = {
				order = 10,
				name = "Appearance",
				type = "group",
				args = {
					zoomIcons = {
						order = 1,
						type = "toggle",
						name = "Zoomed icons",
						get = function(info) return db.zoomIcons end,
						set = function(info, val)
							db.zoomIcons = val
							clcret:UpdateSkillButtonsLayout()
							clcret:UpdateAuraButtonsLayout()
							clcret:UpdateSovBarsLayout()
						end,
					},
					noBorder = {
						order = 2,
						type = "toggle",
						name = "Hide border",
						get = function(info) return db.noBorder end,
						set = function(info, val)
							db.noBorder = val
							clcret:UpdateSkillButtonsLayout()
							clcret:UpdateAuraButtonsLayout()
							clcret:UpdateSovBarsLayout()
						end,
					},
					borderColor = {
						order = 3,
						type = "color",
						name = "Border color",
						hasAlpha = true,
						get = function(info) return unpack(db.borderColor) end,
						set = function(info, r, g, b, a)
							db.borderColor = {r, g, b, a}
							clcret:UpdateSkillButtonsLayout()
							clcret:UpdateAuraButtonsLayout()
							clcret:UpdateSovBarsLayout()
						end,
					},
					scale = {
						order = 5,
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
						order = 7,
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
						values = { always = "Always", combat = "In Combat", valid = "Valid Target", boss = "Boss" }
					},
				},
			},
		
			-- behavior
			behavior = {
				order = 15,
				name = "Behavior",
				type = "group",
				args = {
					highlight = {
						order = 11,
						type = "toggle",
						name = "Highlight on use",
						get = function(info) return db.highlight end,
						set = function(info, val) db.highlight = val end,
					},
					latency = {
						order = 12, 
						type = "range",
						name = "Client max latency",
						min = 0,
						max = 1,
						step = 0.01,
						get = function(info) return db.latency end,
						set = function(info, val)
							db.latency = val
						end,
					},
					dpssLatency = {
						order = 100, 
						type = "range",
						name = "Divine Plea and SS Latency",
						min = 0,
						max = 1,
						step = 0.01,
						get = function(info) return db.dpssLatency end,
						set = function(info, val)
							db.dpssLatency = val
						end,
					},
					ups = {
						order = 5,
						type = "range",
						name = "Updates per second",
						min = 1,
						max = 100,
						step = 1,
						get = function(info) return db.updatesPerSecond end,
						set = function(info, val)
							db.updatesPerSecond = val
							self.scanFrequency = 1 / val
						end,
					},
					upsAuras = {
						order = 10,
						type = "range",
						name = "Updates per second for Aura Buttons",
						min = 1,
						max = 100,
						step = 1,
						get = function(info) return db.updatesPerSecondAuras end,
						set = function(info, val)
							db.updatesPerSecondAuras = val
							self.scanFrequencyAuras = 1 / val
						end,
					},
					rangePerSkill = {
						order = 15,
						type = "toggle",
						name = "Check range for each skill",
						get = function(info) return db.rangePerSkill end,
						set = function(info, val) db.rangePerSkill = val end,
					},
					delayedStart = {
						order = 20,
						type = "range",
						name = "Delay start by (seconds)",
						min = 0,
						max = 30,
						step = 1,
						get = function(info) return db.delayedStart end,
						set = function(info, val) db.delayedStart = val end,
					},
					manaCons = {
						order = 25,
						type = "range",
						name = "Minimum mana for Consecration",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaCons end,
						set = function(info, val) db.manaCons = val end,
					},
					manaConsPerc = {
						order = 30,
						type = "range",
						name = "% Minimum mana for Consecration",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaConsPerc end,
						set = function(info, val) db.manaConsPerc = val end,
					},
					manaDP = {
						order = 35,
						type = "range",
						name = "Maximum mana for Divine Plea",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaDP end,
						set = function(info, val) db.manaDP = val end,
					},
					manaDPPerc = {
						order = 40,
						type = "range",
						name = "% Maximum mana for Divine Plea",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaDPPerc end,
						set = function(info, val) db.manaDPPerc = val end,
					},
					gcdDpSs = {
						order = 50,
						type = "range",
						min = 0,
						max = 2,
						step = 0.1,
						name = "Extra delay for DP and SS",
						get = function(info) return db.gcdDpSs end,
						set = function(info, val) db.gcdDpSs = val end,
					},
				},
			},
			
			
			-- fcfs edit
			fcfs = {
				order = 10,
				name = "FCFS",
				type = "group",
				args = {},
			},
			
			-- prot fcfs
			pfcfs = {
				order = 11,
				name = "ProtFCFS",
				type = "group",
				args = {},
			},
			
						-- aura buttons
			auras = {
				order = 30,
				name = "Aura Buttons",
				type = "group",
				args = {},
			},
		
			-- layout
			layout = {
				order = 31,
				name = "Layout",
				type = "group",
				args = {},
			},
			
			
			-- sov tracking
			sov = {
				order = 40,
				name = "SoV Tracking",
				type = "group",
				args = {
					enabled = {
						order = 1,
						type = "toggle",
						name = "Enable vengeance/corruption tracking on multiple targets",
						get = function(info) return db.sov.enabled end,
						set = function(info, val) clcret:ToggleSovTracking() end,
					},
					updatesPerSecond = {
						order = 3,
						type = "range",
						name = "Updates per second",
						min = 1,
						max = 100,
						step = 1,
						get = function(info) return db.sov.updatesPerSecond end,
						set = function(info, val)
							db.sov.updatesPerSecond = val
							self.scanFrequencySov = 1 / val
						end,
					},
					showAnchor = {
						order = 5,
						type = "toggle",
						name = "Show anchor (not movable)",
						get = function(info) return clcret.showSovAnchor end,
						set = function(invo, val) clcret:ToggleSovAnchor() end,
					},
					useButtons = {
						order = 5,
						type = "toggle",
						name = "Buttons instead of bars",
						get = function(info) return db.sov.useButtons end,
						set = function(invo, val)
							db.sov.useButtons = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					growth = {
						order = 10,
						type = "select",
						name = "Growth direction",
						get = function(info) return db.sov.growth end,
						set = function(info, val)
							db.sov.growth = val
							clcret:UpdateSovBarsLayout()
						end,
						values = { up = "Up", down = "Down", left = "Left", right = "Right" }
					},
					spacing = {
						order = 11,
						type = "range",
						name = "Spacing",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.sov.spacing end,
						set = function(info, val)
							db.sov.spacing = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					targetDifference = {
						order = 15,
						type = "toggle",
						name = "Different color for target",
						get = function(info) return db.sov.targetDifference end,
						set = function(info, val)
							db.sov.targetDifference = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					color = {
						order = 16,
						type = "color",
						name = "Bar color",
						hasAlpha = true,
						get = function(info) return unpack(db.sov.color) end,
						set = function(info, r, g, b, a)
							db.sov.color = {r, g, b, a}
							clcret:UpdateSovBarsLayout()
						end,
					},
					colorNonTarget = {
						order = 17,
						type = "color",
						name = "Non target color",
						hasAlpha = true,
						get = function(info) return unpack(db.sov.colorNonTarget) end,
						set = function(info, r, g, b, a)
							db.sov.colorNonTarget = {r, g, b, a}
						end,
					},
					anchor = {
						order = 20,
						type = "select",
						name = "Anchor",
						get = function(info) return db.sov.point end,
						set = function(info, val)
							db.sov.point = val
							clcret:UpdateSovBarsLayout()
						end,
						values = anchorPoints,
					},
					anchorTo = {
						order = 21,
						type = "select",
						name = "Anchor To",
						get = function(info) return db.sov.pointParent end,
						set = function(info, val)
							db.sov.pointParent = val
							clcret:UpdateSovBarsLayout()
						end,
						values = anchorPoints,
					},
					x = {
						order = 22,
						type = "range",
						name = "X",
						min = -1000,
						max = 1000,
						step = 1,
						get = function(info) return db.sov.x end,
						set = function(info, val)
							db.sov.x = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					y = {
						order = 23,
						type = "range",
						name = "Y",
						min = -1000,
						max = 1000,
						step = 1,
						get = function(info) return db.sov.y end,
						set = function(info, val)
							db.sov.y = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					width = {
						order = 30,
						type = "range",
						name = "Width",
						min = 1,
						max = 1000,
						step = 1,
						get = function(info) return db.sov.width end,
						set = function(info, val)
							db.sov.width = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					height = {
						order = 31,
						type = "range",
						name = "Height (Size for buttons)",
						min = 1,
						max = 500,
						step = 1,
						get = function(info) return db.sov.height end,
						set = function(info, val)
							db.sov.height = val
							clcret:UpdateSovBarsLayout()
						end,
					},
				},
			},
		},
	}
	
		-- add main buttons to layout
	for i = 1, 2 do
		self.options.args.layout.args["button" .. i] = {
			order = i,
			name = skillButtonNames[i],
			type = "group",
			args = {
				size = {
					order = 1,
					type = "range",
					name = "Size",
					min = 1,
					max = 300,
					step = 1,
					get = function(info) return db.layout["button" .. i].size end,
					set = function(info, val)
						db.layout["button" .. i].size = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				alpha = {
					order = 2,
					type = "range",
					name = "Alpha",
					min = 0,
					max = 1,
					step = 0.01,
					get = function(info) return db.layout["button" .. i].alpha end,
					set = function(info, val)
						db.layout["button" .. i].alpha = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				anchor = {
					order = 6,
					type = "select",
					name = "Anchor",
					get = function(info) return db.layout["button" .. i].point end,
					set = function(info, val)
						db.layout["button" .. i].point = val
						clcret:UpdateSkillButtonsLayout()
					end,
					values = anchorPoints,
				},
				anchorTo = {
					order = 6,
					type = "select",
					name = "Anchor To",
					get = function(info) return db.layout["button" .. i].pointParent end,
					set = function(info, val)
						db.layout["button" .. i].pointParent = val
						clcret:UpdateSkillButtonsLayout()
					end,
					values = anchorPoints,
				},
				x = {
					order = 10,
					type = "range",
					name = "X",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.layout["button" .. i].x end,
					set = function(info, val)
						db.layout["button" .. i].x = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
				y = {
					order = 11,
					type = "range",
					name = "Y",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.layout["button" .. i].y end,
					set = function(info, val)
						db.layout["button" .. i].y = val
						clcret:UpdateSkillButtonsLayout()
					end,
				},
			},
		}
	end

	-- add the buttons to options
	for i = 1, MAX_AURAS do
		-- aura options
		self.options.args.auras.args["aura" .. i] = {
			order = i,
			type = "group",
			name = "Aura Button " .. i,
			args = {
				enabled = {
					order = 1,
					type = "toggle",
					name = "Enabled",
					get = function(info) return db.auras[i].enabled end,
					set = function(info, val)
						if db.auras[i].data.spell == "" then
							val = false
							bprint("Not a valid spell name/id or buff name!")
						end
						db.auras[i].enabled = val
						if not val then clcret:AuraButtonHide(i) end
						clcret:UpdateEnabledAuraButtons()
					end,
				},
				spell = {
					order = 5,
					type = "input",
					name = "Spell/item name/id or buff to track",
					get = function(info) return db.auras[i].data.spell end,
					set = function(info, val)
						-- skill
						if (db.auras[i].data.exec == "AuraButtonExecSkillVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecSkillVisibleNoCooldown") then
							local name = GetSpellInfo(val)
							if name then
								db.auras[i].data.spell = name
							else
								db.auras[i].data.spell = ""
								db.auras[i].enabled = false
								clcret:AuraButtonHide(i)
								clcret:UpdateEnabledAuraButtons()
								bprint("Not a valid spell name or id !")
							end
						-- item
						elseif (db.auras[i].data.exec == "AuraButtonExecItemVisibleAlways") or (db.auras[i].data.exec == "AuraButtonExecItemVisibleNoCooldown") then
							local name = GetItemInfo(val)
							if name then
								db.auras[i].data.spell = name
							else
								db.auras[i].data.spell = ""
								db.auras[i].enabled = false
								clcret:AuraButtonHide(i)
								clcret:UpdateEnabledAuraButtons()
								bprint("Not a valid item name or id !")
							end
						else
							db.auras[i].data.spell = val
						end
						clcret:AuraButtonResetTexture(i)
					end,
				},
				exec = {
					order = 10,
					type = "select",
					name = "Type",
					get = function(info) return db.auras[i].data.exec end,
					set = function(info, val)
						db.auras[i].data.exec = val
						-- skill
						if (val == "AuraButtonExecSkillVisibleAlways") or (val == "AuraButtonExecSkillVisibleNoCooldown") then
							if not GetSpellInfo(db.auras[i].data.spell) then
								db.auras[i].data.spell = ""
								db.auras[i].enabled = false
								clcret:AuraButtonHide(i)
								bprint("Not a valid spell name or id !")
							end
						-- item
						elseif (val == "AuraButtonExecItemVisibleAlways") or (val == "AuraButtonExecItemVisibleNoCooldown") then
							if not GetItemInfo(db.auras[i].data.spell) then
								db.auras[i].data.spell = ""
								db.auras[i].enabled = false
								clcret:AuraButtonHide(i)
								bprint("Not a valid item name or id !")
							end
						end
						clcret:UpdateEnabledAuraButtons()
						clcret:UpdateAuraButtonsCooldown()
					end,
					values = execList,
				},
				unit = {
					order = 15,
					type = "input",
					name = "Target unit",
					get = function(info) return db.auras[i].data.unit end,
					set = function(info, val) db.auras[i].data.unit = val end
				},
				byPlayer = {
					order = 16,
					type = "toggle",
					name = "Cast by player",
					get = function(info) return db.auras[i].data.byPlayer end,
					set = function(info, val) db.auras[i].data.byPlayer = val end
				}
			},
		}
		
		-- layout
		self.options.args.layout.args["aura" .. i] = {
			order = 10 + i,
			type = "group",
			name = "Aura Button " .. i,
			args = {
				size = {
					order = 1,
					type = "range",
					name = "Size",
					min = 1,
					max = 300,
					step = 1,
					get = function(info) return db.auras[i].layout.size end,
					set = function(info, val)
						db.auras[i].layout.size = val
						clcret:UpdateAuraButtonLayout(i)
					end,
				},
				anchor = {
					order = 6,
					type = "select",
					name = "Anchor",
					get = function(info) return db.auras[i].layout.point end,
					set = function(info, val)
						db.auras[i].layout.point = val
						clcret:UpdateAuraButtonLayout(i)
					end,
					values = anchorPoints,
				},
				anchorTo = {
					order = 6,
					type = "select",
					name = "Anchor To",
					get = function(info) return db.auras[i].layout.pointParent end,
					set = function(info, val)
						db.auras[i].layout.pointParent = val
						clcret:UpdateAuraButtonLayout(i)
					end,
					values = anchorPoints,
				},
				x = {
					order = 10,
					type = "range",
					name = "X",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.auras[i].layout.x end,
					set = function(info, val)
						db.auras[i].layout.x = val
						clcret:UpdateAuraButtonLayout(i)
					end,
				},
				y = {
					order = 11,
					type = "range",
					name = "Y",
					min = -1000,
					max = 1000,
					step = 1,
					get = function(info) return db.auras[i].layout.y end,
					set = function(info, val)
						db.auras[i].layout.y = val
						clcret:UpdateAuraButtonLayout(i)
					end,
				},
			},
		}
	end

	local root = self.options.args.fcfs.args
	for i = 1, 10 do
		root["p"..i] = {
			name = "",
			type = "select",
			order = i,
			get = function(info) return db.fcfs[i] end,
			set = function(info, val)
				db.fcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = GetSpellChoice,
		}
	end
	
	root = self.options.args.pfcfs.args
	for i = 1, 2 do
		root["p" .. i] = {
			name = "6",
			type = "select",
			get = function(info) return db.pfcfs[i] end,
			set = function(info, val)
				db.pfcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = { sor = clcret.protSpells["sor"].name, hotr = clcret.protSpells["hotr"].name }
		}
	end
	
	for i = 3, 5 do
		root["p" .. i] = {
			name = "9",
			type = "select",
			get = function(info) return db.pfcfs[i] end,
			set = function(info, val)
				db.pfcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = { hs = clcret.protSpells["hs"].name, cons = clcret.protSpells["cons"].name, jol = clcret.protSpells["jol"].name }
		}
	end
end

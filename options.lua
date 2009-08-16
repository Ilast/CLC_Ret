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
		
			-- layout
			layout = {
				order = 10,
				name = "Layout",
				type = "group",
				args = {},
			},
			
			auras = {
				order = 5,
				name = "Aura Buttons",
				type = "group",
				args = {},
			},
		
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
							self.scanFrequency = 1 / val
						end,
					},
					upsAuras = {
						order = 2,
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
					manaCons = {
						order = 5,
						type = "range",
						name = "Minimum mana for Consecration",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaCons end,
						set = function(info, val) db.manaCons = val end,
					},
					manaConsPerc = {
						order = 6,
						type = "range",
						name = "% Minimum mana for Consecration",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaConsPerc end,
						set = function(info, val) db.manaConsPerc = val end,
					},
					manaDP = {
						order = 10,
						type = "range",
						name = "Maximum mana for Divine Plea",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaDP end,
						set = function(info, val) db.manaDP = val end,
					},
					manaDPPerc = {
						order = 11,
						type = "range",
						name = "% Maximum mana for Divine Plea",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaDPPerc end,
						set = function(info, val) db.manaDPPerc = val end,
					},
					delay = {
						order = 20,
						type = "range",
						name = "Delay before addon loads",
						min = 0,
						max = 30,
						step = 1,
						get = function(info) return db.loadDelay end,
						set = function(info, val) db.loadDelay = val end,
					},
				},
			}
		}
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
					min = 0,
					max = 100,
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
					end,
				},
				spell = {
					order = 5,
					type = "input",
					name = "Spell name/id or buff to track",
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
								bprint("Not a valid spell name or id !")
							end
						-- item
						elseif (val == "AuraButtonExecItemVisibleAlways") or (val == "AuraButtonExecItemVisibleNoCooldown") then
							if not GetItemInfo(db.auras[i].data.spell) then
								db.auras[i].data.spell = ""
								db.auras[i].enabled = false
								bprint("Not a valid item name or id !")
							end
						end
					end,
					values = execList,
				},
				unit = {
					order = 15,
					type = "input",
					name = "Unit to track",
					get = function(info) return db.auras[i].data.unit end,
					set = function(info, val) db.auras[i].data.unit = val end
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
					min = 0,
					max = 100,
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
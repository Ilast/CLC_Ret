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
		name = "clcret",
		args = {
			global = {
				type = "group",
				name = "clcret",
				args = {
					-- lock frame
					lock = {
						order = 1,
						width = "full",
						type = "toggle",
						name = "Lock Frame",
						get = function(info) return self.locked end,
						set = function(info, val)
							clcret:ToggleLock()
						end,
					},
					
					show = {
						order = 10,
						type = "select",
						name = "Show",
						get = function(info) return db.show end,
						set = function(info, val)
							db.show = val
							clcret:UpdateShowMethod()
						end,
						values = { always = "Always", combat = "In Combat", valid = "Valid Target", boss = "Boss" }
					},
					
					-- full disable toggle
					fullDisable = {
						order = 20,
						width = "full",
						type = "toggle",
						name = "Addon disabled",
						get = function(info) return db.fullDisable end,
						set = function(info, val) clcret:FullDisableToggle() end,
					},
					__protEnabled = {
						order = 30,
						type = "header",
						name = "Protection Module",
					},
					____protEnabled = {
						order = 31,
						type = "description",
						name = "|cffff0000WARNING|cffffffff The protection module wasn't tested at all in the new version. It's also very unlikely that I will test it anytime soon.\nSo use it at your own risk and let me know what problems there you have with it (tickets or comments on the site where you downloaded the addon from.",
					},
					-- full disable toggle
					protEnabled = {
						order = 32,
						width = "full",
						type = "toggle",
						name = "Enable prot module",
						get = function(info) return db.protEnabled end,
						set = function(info, val)
							db.protEnabled = val
							clcret:PLAYER_TALENT_UPDATE()
						end,
					},
				},
			},
		
			-- appearance
			appearance = {
				order = 10,
				name = "Appearance",
				type = "group",
				args = {
					__buttonAspect = {
						type = "header",
						name = "Button Aspect",
						order = 1,
					},
					zoomIcons = {
						order = 2,
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
						order = 3,
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
						order = 4,
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
					borderType = {
						order = 5,
						type = "select",
						name = "Border type",
						get = function(info) return db.borderType end,
						set = function(info, val)
							db.borderType = val
							clcret:UpdateSkillButtonsLayout()
							clcret:UpdateAuraButtonsLayout()
							clcret:UpdateSovBarsLayout()
						end,
						values = { "Light", "Medium", "Heavy" }
					},
					__hudAspect = {
						type = "header",
						name = "HUD Aspect",
						order = 10,
					},
					scale = {
						order = 11,
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
						order = 12,
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
					_hudPosition = {
						type = "header",
						name = "HUD Position",
						order = 13,
					},
					x = {
						order = 20,
						type = "range",
						name = "X",
						min = 0,
						max = 5000,
						step = 21,
						get = function(info) return db.x end,
						set = function(info, val)
							db.x = val
							clcret:UpdateFrameSettings()
						end,
					},
					y = {
						order = 22,
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
						order = 23,
						type = "execute",
						name = "Center Horizontally",
						func = function()
							clcret:CenterHorizontally()
						end,
					},
				},
			},
		
			-- behavior
			behavior = {
				order = 15,
				name = "Behavior",
				type = "group",
				args = {
					__updateRates = {
						order = 1,
						type = "header",
						name = "Updates per Second",
					},
					ups = {
						order = 5,
						type = "range",
						name = "FCFS Detection",
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
						order = 6,
						type = "range",
						name = "Aura Detection",
						min = 1,
						max = 100,
						step = 1,
						get = function(info) return db.updatesPerSecondAuras end,
						set = function(info, val)
							db.updatesPerSecondAuras = val
							self.scanFrequencyAuras = 1 / val
						end,
					},
				
					__highlight = {
						order = 10,
						type = "header",
						name = "Highlight Main Skill",
					},
					____highlight = {
						order = 11,
						type = "description",
						name = "Highlights the main skill when an action is performed until the server confirms the action.\nFor Blizzard's default buttons and some BF skins \"Checked\" state is a lot more visible than \"Highlight\" state. If that's the case, enable the 2nd option too.",
					},
					highlight = {
						order = 12,
						type = "toggle",
						name = "Highlight on use",
						get = function(info) return db.highlight end,
						set = function(info, val) db.highlight = val end,
					},
					highlightChecked = {
						order = 13,
						type = "toggle",
						name = "Use \"Checked\" state",
						get = function(info) return db.highlightChecked end,
						set = function(info, val) db.highlightChecked = val end,
					},
					__rangePerSkill = {
						order = 15,
						type = "header",
						name = "Range Display",
					},
					____rangePerSkill = {
						order = 16,
						type = "description",
						name = "By default the addon checks if you are in melee range and colors both main and secondary skills if not. This option allows you to display the range of the actual skills displayed.",
					},
					rangePerSkill = {
						order = 17,
						type = "toggle",
						width = "full",
						name = "Check range for each skill",
						get = function(info) return db.rangePerSkill end,
						set = function(info, val) db.rangePerSkill = val end,
					},
					__delayedStart = {
						order = 20,
						type = "header",
						name = "Delayed Start",
					},
					____delayedStart = {
						order = 21,
						type = "description",
						name = "Sometimes the talent checks fail at load. If that happens adjust this slider to a higher value.",
					},
					delayedStart = {
						order = 22,
						type = "range",
						name = "Delay start by (seconds)",
						min = 0,
						max = 30,
						step = 1,
						get = function(info) return db.delayedStart end,
						set = function(info, val) db.delayedStart = val end,
					},
					__manaCons = {
						order = 25,
						type = "header",
						name = "Consecration Mana Settings",
					},
					____manaCons = {
						order = 26,
						type = "description",
						name = "If your mana drops under the specified value Consecration will be ignored in FCFS detection. A value of 0 deactivates the check.\nFixed value takes precedence so if you want to use the percentage value, set fixed one to 0.",
					},
					manaCons = {
						order = 27,
						type = "range",
						name = "Fixed value",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaCons end,
						set = function(info, val) db.manaCons = val end,
					},
					manaConsPerc = {
						order = 28,
						type = "range",
						name = "Percentage",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaConsPerc end,
						set = function(info, val) db.manaConsPerc = val end,
					},
					__manaDP = {
						order = 35,
						type = "header",
						name = "Divine Plea Mana Settings",
					},
					____manaDP = {
						order = 36,
						type = "description",
						name = "If your mana is above the specified value Divine Plea will be ignored in FCFS detection. A value of 0 deactivates the check.\nFixed value takes precedence so if you want to use the percentage value, set fixed one to 0.",
					},
					manaDP = {
						order = 37,
						type = "range",
						name = "Fixed value",
						min = 0,
						max = 10000,
						step = 1,
						get = function(info) return db.manaDP end,
						set = function(info, val) db.manaDP = val end,
					},
					manaDPPerc = {
						order = 38,
						type = "range",
						name = "Percentage",
						min = 0,
						max = 100,
						step = 1,
						get = function(info) return db.manaDPPerc end,
						set = function(info, val) db.manaDPPerc = val end,
					},
					__gcdDpSs = {
						order = 50,
						type = "header",
						name = "Extra Delay for DP/SS",
					},
					____gcdDpSs = {
						order = 51,
						type = "description",
						name = "In case you want to use your non damaging abilities (Divine Plea and Sacred Shield) only when it won't delay at all the other abilities adjust this value. A value of 0 disables the check.",
					},
					gcdDpSs = {
						order = 52,
						type = "range",
						min = 0,
						max = 2,
						step = 0.1,
						name = "Extra delay (in seconds)",
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
				args = {
					ret = {
						order = 1,
						name = "Retribution",
						type = "group",
						args = {},
					},
					prot = {
						order = 5,
						name = "Protection",
						type = "group",
						args = {},
					},
				},
			},
			
			-- prot fcfs
			pfcfs = {
				order = 11,
				name = "Protection FCFS",
				type = "group",
				args = {},
			},
			
						-- aura buttons
			auras = {
				order = 30,
				name = "Aura Buttons",
				type = "group",
				args = {
					____info = {
						order = 1,
						type = "description",
						name = "These are cooldown watchers. You can select a player skill, an item or a buff/debuff (on a valid target) to watch.\nItems and skills only need a valid item/spell id (or name) and the type. Target (the target to scan) and Cast by player (filters or not buffs cast by others) are specific to buffs/debuffs.\nValid targets are the ones that work with /cast [target=name] macros. For example: player, target, focus, raid1, raid1target.",
					},
				},
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
				name = "SoV/SoCorr Tracking",
				type = "group",
				args = {
					____info = {
						order = 1,
						type = "description",
						name = "This module provides bars or icons to watch the cooldown of your Seal of Vengeance/Corruption debuff on different targets.\nIt tracks combat log events so disable it unless you really need it.\nTargets are tracked by their GUID from combat log events.",
					},
					enabled = {
						order = 2,
						type = "toggle",
						name = "Enable",
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
					__display = {
						order = 10,
						type = "header",
						name = "Appearance"
					},
					useButtons = {
						order = 11,
						width = "full",
						type = "toggle",
						name = "Icons instead of bars",
						get = function(info) return db.sov.useButtons end,
						set = function(invo, val)
							db.sov.useButtons = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					____alpha = {
						order = 20,
						type = "description",
						name = "You can control if the bar/icon of your current target looks different than the other ones.\nFor bars it uses both alpha and color values while the icons only change their alpha.",
					},
					targetDifference = {
						order = 21,
						width = "full",
						type = "toggle",
						name = "Different color for target",
						get = function(info) return db.sov.targetDifference end,
						set = function(info, val)
							db.sov.targetDifference = val
							clcret:UpdateSovBarsLayout()
						end,
					},
					color = {
						order = 22,
						type = "color",
						name = "Target color/alpha",
						hasAlpha = true,
						get = function(info) return unpack(db.sov.color) end,
						set = function(info, r, g, b, a)
							db.sov.color = {r, g, b, a}
							clcret:UpdateSovBarsLayout()
						end,
					},
					colorNonTarget = {
						order = 23,
						type = "color",
						name = "Non target color/alpha",
						hasAlpha = true,
						get = function(info) return unpack(db.sov.colorNonTarget) end,
						set = function(info, r, g, b, a)
							db.sov.colorNonTarget = {r, g, b, a}
						end,
					},
					__layout = {
						order = 40,
						type = "header",
						name = "Layout",
					},
					showAnchor = {
						order = 50,
						width = "full",
						type = "toggle",
						name = "Show anchor (not movable)",
						get = function(info) return clcret.showSovAnchor end,
						set = function(invo, val) clcret:ToggleSovAnchor() end,
					},
					growth = {
						order = 60,
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
						order = 70,
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
					
					anchor = {
						order = 80,
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
						order = 81,
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
						order = 82,
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
						order = 83,
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
						order = 90,
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
						order = 91,
						type = "range",
						name = "Height (Size for Icons)",
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
			order = i + 10,
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

	local root = self.options.args.fcfs.args.ret.args
	for i = 1, 10 do
		root["p"..i] = {
			order = i,
			name = "",
			type = "select",
			get = function(info) return db.fcfs[i] end,
			set = function(info, val)
				db.fcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = GetSpellChoice,
		}
	end
	
	root = self.options.args.fcfs.args.prot.args
	for i = 1, 2 do
		root["p" .. i] = {
			order = i,
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
			order = i,
			type = "select",
			get = function(info) return db.pfcfs[i] end,
			set = function(info, val)
				db.pfcfs[i] = val
				clcret:UpdateFCFS()
			end,
			values = { hs = clcret.protSpells["hs"].name, cons = clcret.protSpells["cons"].name, jol = clcret.protSpells["jol"].name }
		}
	end
	
	-- the init stuff
	local AceConfig = LibStub("AceConfig-3.0")
	AceConfig:RegisterOptionsTable("clcret", self.options)
	local AceConfigDialog = LibStub("AceConfigDialog-3.0")
	AceConfigDialog:AddToBlizOptions("clcret", "clcret", nil, "global")
	AceConfigDialog:AddToBlizOptions("clcret", "Appearance", "clcret", "appearance")
	AceConfigDialog:AddToBlizOptions("clcret", "Behavior", "clcret", "behavior")
	AceConfigDialog:AddToBlizOptions("clcret", "FCFS", "clcret", "fcfs")
	AceConfigDialog:AddToBlizOptions("clcret", "Aura Buttons", "clcret", "auras")
	AceConfigDialog:AddToBlizOptions("clcret", "Layout", "clcret", "layout")
	AceConfigDialog:AddToBlizOptions("clcret", "SoV Tracking", "clcret", "sov")
end


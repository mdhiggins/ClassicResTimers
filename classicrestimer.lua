local function Round(num, numDecimalPlaces)
	if numDecimalPlaces and numDecimalPlaces>0 then
		local mult = 10^numDecimalPlaces
		return math.floor(num * mult + 0.5) / mult
	end
	return math.floor(num + 0.5)
end
  

local function Split(s, sep)
    local fields = {}
    
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    
    return fields
end

function OnUpdate(self, elapsed)
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
	local zone = GetZoneText()
	if not self.zones[zone] then
		self.timestr:SetText("")
		self.timestr:Hide()
	end

	if (self.TimeSinceLastUpdate < self.UpdateInterval) then
		return
	end

	-- zone = "Warsong Gulch"
	if (self.zones[zone]) then
		local subzone = GetSubZoneText() or ""
		-- subzone = "Silverwing Hold"

		local time = GetAreaSpiritHealerTime()
		-- local output = "ClassicResTimer (" .. #self.reporting .. ")"
		local output = ""
		local count = 0

		if (time > 0 and (GetTime() - (self.lastlost[subzone] or 0) > 2)) then
			local adjustment = (self.timeleft[subzone] or 0) - time
			if adjustment > 2 or adjustment < -2 then
				print("Estimate was off by " .. adjustment)
			end
			self.timeleft[subzone] = time
			C_ChatInfo.SendAddonMessage(self.AddonPrefix, subzone .. ":" ..time, "INSTANCE_CHAT");
		end

		for k, v in pairs(self.timeleft) do
			if (time > 0 and k == subzone) then
				-- pass
			else
				self.timeleft[k] = self.timeleft[k] - self.TimeSinceLastUpdate;
			end

			if self.timeleft[k] < 0 then
				self.timeleft[k] = self.ResInterval + self.timeleft[k]
			end

			-- print(string.format("%s in %00.0f", k, self.timeleft[k]))
			if string.len(output) > 0 then
				output = output .. "\n "
			end
			local prettyname = self.prettynames[zone][k] or k
			if self.timeleft[k] > self.maxres then
				-- self.timestr:SetText(string.format("%s Now", k))
				output = output .. string.format("%s Now", prettyname)
			else
				-- self.timestr:SetText(string.format("%s in %00.0f", k, Round(self.timeleft[k]), 0))
				output = output .. string.format("%s in %00.0f", prettyname, Round(self.timeleft[k]), 0)
			end
			count = count + 1
		end
		self.timestr:SetText(output)
		self:SetHeight(42 + (12 * count))
		self.timestr:SetHeight(self:GetHeight())
		self.timestr:Show()
	end
	self.TimeSinceLastUpdate = 0.0
end

function OnEvent(self, event, ...)
	if event == "CHAT_MSG_ADDON" then
		if (select(1,...) == self.AddonPrefix) then
			local sender = select(5,...)
			if sender == UnitName("Player") then
				return
			end
			local str = ""..select(2,...)
			local splitstr = Split(str, ":")
			local subzone = splitstr[1]
			local timeleft = splitstr[2]
			
			-- zone = "Warsong Gulch"
			if (self.zones[zone] and (self.lastlost[subzone] or 0) > 2) then
				timeleft = tonumber(timeleft)
				self.timeleft[subzone] = timeleft
				self.reporting[sender] = true
				self.lastsync[subzone] = GetTime()
				print("Chat event sync received from " .. sender .. ": " .. timeleft .. " for " .. subzone)
			end
		end
	end

	if (event == "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
		local message = select(1, ...)
		local startOffset = self.startText[message]
		if (startOffset ~= nil) then
			for k, v in pairs(self.timeleft) do
				self.timeleft[k] = self.ResInterval + startOffset
			end
        end
	end

	if (event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE") then
		local message = select(1, ...)
		local zone = GetZoneText()
		local messageFaction = self.factionmatch[event]
		local faction = UnitFactionGroup("Player")

		local assault = strfind(message,"has assaulted")
		local taken = strfind(message,"has taken")
		local defended = strfind(message,"has defended")
		-- local claim = strfind(message,"claims the")

		if self.graveyardmatch[zone] then 
			for k, v in pairs(self.graveyardmatch[zone]) do
				if strfind(string.lower(message), string.lower(k)) then
					local subzone = self.graveyardmatch[zone][k]
					if (taken or defended) and messageFaction == faction  then
						-- print("Graveyard capped, starting timer for " .. subzone)
						self.timeleft[subzone] = (self.ResInterval + 2.0)
					end
					if assault and messageFaction ~= faction and self.timeleft[subzone] then
						-- print("Graveyard lost, removing timer for " .. subzone)
						self.timeleft[subzone] = nil
						self.lastlost[subzone] = GetTime()
					end
					break
				end
			end
		end
	end

	if event == "ZONE_CHANGED_NEW_AREA" then
		self.Reset(self)
	end
	
	if event == "ADDON_LOADED" then
		local message = select(1, ...)
		if message == "ClassicResTimer" then
			self.Reset(self)
		end
	end
end

function Reset(self)
	local zone = GetZoneText()
	if (self.zones[zone]) then
		self.timeleft = { }
		self.lastlost = { }
		self.reporting = { }
		local faction = UnitFactionGroup("Player")
		for k, v in pairs(self.initialgraveyards[zone][faction]) do
			self.timeleft[k] = v
		end
		
		self:Show()
		self:SetScript('OnUpdate', OnUpdate)
	else
		self:Hide()
	end 
end

local ResTimerClassic = CreateFrame('frame', 'resframe', UIParent)
-- ResTimerClassic:SetBackdrop({
--	bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
--	edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
--	tile=1, tileSize=32, edgeSize=32,
--	insets={left=10, right=10, top=10, bottom=10}
--  })
ResTimerClassic:SetWidth(200)
ResTimerClassic:SetHeight(45)
ResTimerClassic:SetPoint("CENTER",0,0)
ResTimerClassic:EnableMouse(true)
ResTimerClassic:SetMovable(true)
ResTimerClassic:Show()
ResTimerClassic:RegisterForDrag("LeftButton")
ResTimerClassic:SetScript("OnDragStart", function(self) self:StartMoving() end)
ResTimerClassic:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)


ResTimerClassic.timestr = ResTimerClassic:CreateFontString("CFontString")
ResTimerClassic.timestr:SetFontObject(GameFontNormalSmall)
ResTimerClassic.timestr:SetPoint("TOP", ResTimerClassic, "TOP", 0, 15)
ResTimerClassic.timestr:SetWidth(ResTimerClassic:GetWidth())
ResTimerClassic.timestr:SetHeight(ResTimerClassic:GetHeight())
ResTimerClassic.timestr:SetText("")
-- ResTimerClassic.timestr:SetTextColor(1,1,1)

ResTimerClassic:SetScript('OnEvent', OnEvent)
ResTimerClassic:SetScript('OnUpdate', OnUpdate)
ResTimerClassic.Reset = Reset
ResTimerClassic:RegisterEvent('CHAT_MSG_ADDON')
ResTimerClassic:RegisterEvent('CHAT_MSG_BG_SYSTEM_NEUTRAL')
ResTimerClassic:RegisterEvent('CHAT_MSG_BG_SYSTEM_ALLIANCE')
ResTimerClassic:RegisterEvent('CHAT_MSG_BG_SYSTEM_HORDE')
ResTimerClassic:RegisterEvent('ZONE_CHANGED_NEW_AREA')
ResTimerClassic:RegisterEvent('ADDON_LOADED')


ResTimerClassic.AddonPrefix = "rtc"
C_ChatInfo.RegisterAddonMessagePrefix(ResTimerClassic.AddonPrefix);
ResTimerClassic.TimeSinceLastUpdate = 0.0
ResTimerClassic.ResInterval = 31.44
ResTimerClassic.UpdateInterval = 0.5
ResTimerClassic.maxres = 30

ResTimerClassic.zones = {
    ["Alterac Valley"] = true,
	["Warsong Gulch"] = true,
	["Arathi Basin"] = true
}

ResTimerClassic.factionmatch = {
	["CHAT_MSG_BG_SYSTEM_ALLIANCE"] = "Alliance",
	["CHAT_MSG_BG_SYSTEM_HORDE"] = "Horde"
}

ResTimerClassic.graveyardmatch = {
	["Arathi Basin"] = {
		["the stables"] = "Stables",
		["the lumber mill"] = "Lumber Mill",
		["the blacksmith"] = "Blacksmith",
		["the farm"] = "Farm",
		["the mine"] = "Gold Mine"
	},
	["Alterac Valley"] = {
		["Stonehearth Graveyard"] = "Stonehearth Graveyard",
		["Stormpike Graveyard"] = "Stormpike Graveyard",
		["Snowfall graveyard"] = "Snowfall Graveyard",
		["Stormpike Aid Station"] = "Dun Baldar",
		["Iceblood Graveyard"] = "Iceblood Graveyard",
		["Frostwolf Graveyard"] = "Frostwolf Graveyard",
		["Frostwolf Relief Hut"] = "Frostwolf Keep"
	}
}

ResTimerClassic.timeleft = { }
ResTimerClassic.lastlost = { }
ResTimerClassic.lastsync = { }
ResTimerClassic.reporting = { }

ResTimerClassic.initialgraveyards = {
	["Warsong Gulch"] = {
		["Alliance"] = {
			["Silverwing Hold"] = ResTimerClassic.ResInterval
		},
		["Horde"] = {
			["Warsong Lumber Mill"] = ResTimerClassic.ResInterval
		}
	},
	["Arathi Basin"] = {
		["Alliance"] = {
			["Trollbane Hall"] = ResTimerClassic.ResInterval
		 },
		["Horde"] = {
			["Defiler's Den"] = ResTimerClassic.ResInterval
		 }
	},
	["Alterac Valley"] = {
		["Alliance"] = {
			[""] = ResTimerClassic.ResInterval,
			["Stormpike Graveyard"] = ResTimerClassic.ResInterval,
			["Stonehearth Graveyard"] = ResTimerClassic.ResInterval,
			["Dun Baldar"] = ResTimerClassic.ResInterval,
		 },
		["Horde"] = { }
	}
}

ResTimerClassic.prettynames = {
	["Alterac Valley"] = {
		[""] = "Dun Baldar Pass",
		["Dun Baldar"] = "Stormpike Aid Station",
		["Frostwolf Keep"] = "Frostwolf Relief Hut"
	},
	["Arathi Basin"] = { },
	["Warsong Gulch"] = { }
}

ResTimerClassic.startText = {
	["The Battle for Alterac Valley has begun!"] = 5,
	["The Battle for Arathi Basin has begun!"] = 5,
    ["Let the battle for Warsong Gulch begin!"] = 5,
}
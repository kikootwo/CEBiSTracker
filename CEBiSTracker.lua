cbtConfigDB = {
    editRank = 1,
}
ceMinimapDB = {
	hide = false,
}

playersDB = {}
local selectedPlayer = {}
local userRankIndex = -1
local overrideMinRank = false
local versionsDict = {}

local cebistracker = LibStub("AceAddon-3.0"):NewAddon("CEBiSTracker", "AceComm-3.0", "AceEvent-3.0", "AceHook-3.0", "AceSerializer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local LD = LibStub("LibDeflate")
local LSM = LibStub("LibSharedMedia-3.0")
local DEFAULT_FONT = LSM.MediaTable.font[LSM:GetDefault('font')]

--table.removekey Function
function table.removekey(t, key)
    local element = t[key]
    t[key] = nil
    return element
end

--pairsByKeys Function
local function pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end

function cebistracker:GetMyClassColor()
    local color = RAID_CLASS_COLORS[UnitClass("player"):upper()]
    return color.colorStr
end

--GetPlayerByName Function
function cebistracker:GetPlayerByName(name)
    for _, player in pairs(playersDB) do
        if player.name == name then
            return player
        end
    end
end

function cebistracker:GetPermission()
    if cbtConfigDB.editRank == 1 then
        return true
    elseif(userRankIndex <= cbtConfigDB.editRank - 1) then
        return true
    else
        return false
    end
end

function cebistracker:ToggleBoxes(enabled)
    local permission = cebistracker:GetPermission()
    for _, obj in ipairs(gearButtons) do
        if not permission then
            obj.checkbox:SetDisabled(true)
        else
            obj.checkbox:SetDisabled(not enabled)
        end
    end
end

--UpdatePermissions Function
function cebistracker:UpdatePermissions()
    local permission = self:GetPermission()
    self.editRank:SetDisabled(not permission)
    self.importRaid:SetDisabled(not permission)
    self.broadcast:SetDisabled(not permission)
    self.ToggleBoxes(permission)
end

--Clear All Labels Function
function cebistracker:AllItemsFalse()
    for _, obj in ipairs(gearButtons) do
        obj.checkbox:SetValue(false)
    end
end

--Select Player Function
function cebistracker:SelectPlayer(labelIndex)
	local errorMessage = "Invalid index."
	if not labelIndex then
		return errorMessage
	end

	local playerLabel = self.players.playerLabels[labelIndex]
	if not playerLabel then
		return errorMessage
	end

	local player = playerLabel.player
	if not player then
		return errorMessage
	end

	self:AllItemsFalse()
    self:ToggleBoxes(true)
    selectedPlayer = player
    --|cFFFF7D0A<Casual Encounters> BiS Tracker|r
    self.gearLabel:SetText("|c" .. player.classColor.colorStr .. player.name .. "'s|r BiS Tokens")

    for item, value in pairs(player.items) do
        gearButtons[gearNameToIndex[item]].checkbox:SetValue(value)
    end
end

function cebistracker:PopulatePlayers()
    local labelIndex = 0
    local playerLabels = self.players.playerLabels
    local populate = function (index)
        labelIndex = labelIndex + 1
        local player = playersDB[index]
        local label
        if playerLabels[labelIndex] then
            label = playerLabels[labelIndex]
            label.frame:EnableMouse(true)
        else
            label = AceGUI:Create("InteractiveLabel")
            label:SetFont(DEFAULT_FONT, 12, "")
            label.label:SetTextColor(player.classColor.r, player.classColor.g, player.classColor.b, 1)
			label:SetHighlight("Interface\\Buttons\\UI-Listbox-Highlight")
            label:SetFullWidth(true)
			label.OnClick = function()
				if GetMouseButtonClicked() == "LeftButton" then
					self:SelectPlayer(label.labelIndex)
				elseif GetMouseButtonClicked() == "RightButton" then
					self.playerDropdownMenu.clickedEntry = label.dbIndex
					self.playerDropdownMenu:Show()
				end
			end
			label:SetCallback("OnClick", label.OnClick)
			self.players:AddChild(label)
			table.insert(playerLabels, label)
        end

        label.dbIndex = index
        label.labelIndex = labelIndex
        label.player = player
        label:SetText(player.name)
        label.label:SetTextColor(player.classColor.r, player.classColor.g, player.classColor.b, 1)
    end

    local playerKeys = {}
    for index, player in ipairs(playersDB) do
        playerKeys[player.name] = index
    end

    for _, index in pairsByKeys(playerKeys) do
        populate(index)
    end

    while labelIndex < #playerLabels do
        labelIndex = labelIndex + 1
        playerLabels[labelIndex].player = nil
        playerLabels[labelIndex]:SetText(nil)
        playerLabels[labelIndex].frame:EnableMouse(false)
    end

    self.players:DoLayout()
    self:AllItemsFalse()
    self:ToggleBoxes(false)
    self.gearLabel:SetText("Select a player")
end

local function GetRaidPlayers()
	local raidPlayers = {}
	local subGroups = {}
	for group = 1, 8 do
		table.insert(subGroups, {})
	end
	for index = 1, 40 do
		-- setting fileName as class, since it should be language agnostic
		local name, _, subgroup, _, _, class = GetRaidRosterInfo(index)
		if name then
			name = strsplit("-", name)
			table.insert(subGroups[subgroup], name)
			raidPlayers[name] = {}
            raidPlayers[name].name = name
			raidPlayers[name].class = class
            local color = RAID_CLASS_COLORS[class:upper()]
            raidPlayers[name].classColor = {}
            raidPlayers[name].classColor.r = color.r
            raidPlayers[name].classColor.g = color.g
            raidPlayers[name].classColor.b = color.b
            raidPlayers[name].classColor.colorStr = color.colorStr
            raidPlayers[name].items = {
                -- head = false,
                -- neck = false,
                -- shoulders = false,
                -- back = false,
                -- chest = false,
                -- wrist = false,
                -- hands = false,
                -- waist = false,
                -- legs = false,
                -- feet = false,
                -- finger1 = false,
                -- finger2 = false,
                -- trinket1 = false,
                -- trinket2 = false,
                -- mainhand = false,
                -- offhand = false,
                -- ranged = false
            }
		end
	end
	return raidPlayers
end


function cebistracker:SendComm(message)
	local messageSerialized = LD:EncodeForWoWAddonChannel(LD:CompressDeflate(self:Serialize(message)))
	self:SendCommMessage("cebistracker", messageSerialized, "GUILD")
end

function cebistracker:SendCommTo(message, player)
    local messageSerialized = LD:EncodeForWoWAddonChannel(LD:CompressDeflate(self:Serialize(message)))
	self:SendCommMessage("cebistracker", messageSerialized, "WHISPER", player)
end

function cebistracker:Broadcast()
    local message = {
        key = "BROADCAST",
        sender = UnitName("player"),
        value = {
            players = playersDB,
            config = cbtConfigDB
        }
    }
    self:SendComm(message)
end

--OnCommReceived Function
function cebistracker:OnCommReceived(prefix, message, distribution, sender)
	if prefix ~= "cebistracker" or sender == UnitName("player") or not message then
		return
	end

	local decoded = LD:DecodeForWoWAddonChannel(message)
	if not decoded then
		print("Could not decode addon message. Sender needs to update to the latest version of cleangroupassigns!")
		return
	end
	local decompressed = LD:DecompressDeflate(decoded)
	if not decompressed then
		print("Failed to decompress addon message. Sender needs to update to the latest version of cleangroupassigns!")
		return
	end

	local didDeserialize, message = self:Deserialize(decompressed)
	if not didDeserialize then
		print("Failed to deserialize sync: " .. message)
		return
	end

    local key = message["key"]
	if not key then
		print("Failed to parse deserialized comm.")
		return
	end

    if key == "BROADCAST" then
        local value = message["value"]
        local sender = message["sender"]

        if(self.broadcastConfirm and self.broadcastConfirm:IsVisible()) then
            self.broadcastConfirm:Show()
            return
        end

        self.broadcastConfirm = AceGUI:Create("Frame")
        self.broadcastConfirm:SetWidth(300)
        self.broadcastConfirm:SetHeight(200)
        self.broadcastConfirm:SetTitle("Accept Broadcast from " .. sender .. "?")
        self.broadcastConfirm:SetCallback("OnClose", function(widget) AceGUI:Release(widget) self.broadcastConfirm = nil end)
        self.broadcastConfirm:SetLayout("Flow")
        self.broadcastConfirm:EnableResize(false)
        local yesButton = AceGUI:Create("Button")
        yesButton:SetText("Yes")
        yesButton:SetWidth(100)
        yesButton:SetCallback("OnClick", function()
            playersDB = value.players
            cbtConfigDB = value.config
            overrideMinRank = true
            self.editRank:SetValue(cbtConfigDB.editRank)
            overrideMinRank = false
            self:UpdatePermissions()
            self:PopulatePlayers()
            AceGUI:Release(self.broadcastConfirm)
            self.broadcastConfirm = nil
            local returnMessage = {
                key = "BROADCAST_ACCEPTED",
                sender = UnitName("player"),
                senderColor = self:GetMyClassColor()
            }
            self:SendCommTo(returnMessage, sender)
        end)
        local noButton = AceGUI:Create("Button")
        noButton:SetText("No")
        noButton:SetWidth(100)
        noButton:SetCallback("OnClick", function()
            AceGUI:Release(self.broadcastConfirm)
            self.broadcastConfirm = nil
        end)


        AceGUI:RegisterLayout("ConfirmBroadcastLayout", function()
            if self.broadcastConfirm.frame:GetWidth() > 300 then
				self.broadcastConfirm:SetWidth(300)
			end
			if self.broadcastConfirm.frame:GetHeight() > 200 then
				self.broadcastConfirm:SetHeight(200)
			end
            yesButton:SetPoint("RIGHT", self.broadcastConfirm.frame, "CENTER", -5, 0)
            noButton:SetPoint("LEFT", self.broadcastConfirm.frame, "CENTER", 5, 0)
		end)
        self.broadcastConfirm:AddChild(yesButton)
        self.broadcastConfirm:AddChild(noButton)
        self.broadcastConfirm:SetLayout("ConfirmBroadcastLayout")
        self.broadcastConfirm:DoLayout()
    elseif key == "ADDCHECK" then
        local value = message["value"]
        local affectedPlayer = message["player"]
        local found = false
        for _, player in pairs(playersDB) do
            if player.name == affectedPlayer then
                if selectedPlayer and selectedPlayer.name == affectedPlayer then
                    gearButtons[gearNameToIndex[value]].checkbox:SetValue(true)
                end
                player.items[value] = true
                found = true
                break
            end
        end
        if not found then
            local returnMessage = {
                key = "MISSING_PLAYER",
                sender = UnitName("player"),
                player = affectedPlayer
            }
            self:SendCommTo(returnMessage, sender)
        end
    elseif key == "REMOVECHECK" then
        local value = message["value"]
        local affectedPlayer = message["player"]
        local found = false
        for _, player in pairs(playersDB) do
            if player.name == affectedPlayer then
                if selectedPlayer and selectedPlayer.name == affectedPlayer then
                    gearButtons[gearNameToIndex[value]].checkbox:SetValue(false)
                end
                table.removekey(player.items, value)
                found = true
                break
            end
        end
        if not found then
            local returnMessage = {
                key = "MISSING_PLAYER",
                sender = UnitName("player"),
                player = affectedPlayer
            }
            self:SendCommTo(returnMessage, sender)
        end
    elseif key == "BROADCAST_ACCEPTED" then
        local sender = message["sender"]
        local senderColor = message["senderColor"]
        print("|cFFFF7D0ACEBiSTracker:|r Broadcast accepted by |c" .. senderColor .. sender .. "|r")
    elseif key == "VERSION" then
        local version = GetAddOnMetadata("CEBiSTracker", "Version")
        local sender = message["sender"]
        local returnMessage = {
            key = "VERSION_RESPONSE",
            value = version,
            sender = UnitName("player"),
            senderColor = self:GetMyClassColor()
        }
        self:SendCommTo(returnMessage, sender)
    elseif key == "VERSION_RESPONSE" then
        local version = message["value"]
        local sender = message["sender"]
        local senderColor = message["senderColor"]
        if versionsDict[version] then
            versionsDict[version] = versionsDict[version] .. ", |c" .. senderColor .. sender .. "|r"
        else
            versionsDict[version] = "|c" .. senderColor .. sender .. "|r"
        end
    elseif key == "MISSING_PLAYER" then
        local sender = message["sender"]
        local affectedPlayer = message["player"]
        local player = self:GetPlayerByName(affectedPlayer)
        local returnMessage = {
            key = "PLAYER_INFO",
            sender = UnitName("player"),
            player = player
        }
        self:SendCommTo(returnMessage, sender)
    elseif key == "PLAYER_INFO" then
        local sender = message["sender"]
        local player = message["player"]
        local found = false
        for _, p in pairs(playersDB) do
            if p.name == player.name then
                found = true
                break
            end
        end
        if not found then
            table.insert(playersDB, player)
            self:PopulatePlayers()
        end
    end
end

--GearButtonClicked
function cebistracker:GearButtonClicked(obj)
    if(obj.check:IsVisible()) then
        obj.check.frame:Hide()
    else
        obj.check.frame:Show()
    end
end

function cebistracker:ImportRaid()
	self:AllItemsFalse()

	local raidPlayers = GetRaidPlayers()
	for name, raidPlayer in pairs(raidPlayers) do
        local add = true
        for _, player in pairs(playersDB) do
            if player.name == name then
                add = false
                break
            end
        end
        if(add) then
            table.insert(playersDB, raidPlayer)
        end
	end

	self:PopulatePlayers()
end

function cebistracker:OnEnable()
    self.f = AceGUI:Create("Window")
    self.f:Hide()
    self.f:EnableResize(false)
    self.f:SetTitle("<Casual Encounters> BiS Tracker")
    self.f:SetLayout("Flow")
    _G["cebistrackerFrame"] = self.f.frame
	table.insert(UISpecialFrames, "cebistrackerFrame")
	local iconDataBroker = LibStub("LibDataBroker-1.1"):NewDataObject("cebistrackerMinimapIcon", {
		type = "data source",
		text = "<Casual Encounters> BiS Tracker",
		label = "Casual Encounters> BiS Tracker",
		icon = "Interface\\GroupFrame\\UI-Group-MasterLooter",
		OnClick = function()
			if self.f:IsVisible() then
				self.f:Hide()
			else
				self.f:Show()
			end
		end,
	    OnTooltipShow = function(tooltip)
			tooltip:SetText("|cFFFF7D0A<Casual Encounters> BiS Tracker|r")
			tooltip:Show()
		end,
	})
	local minimapIcon = LibStub("LibDBIcon-1.0")
	minimapIcon:Register("cebistrackerMinimapIcon", iconDataBroker, ceMinimapDB)
    minimapIcon:Show()

    self.playerViews = AceGUI:Create("InlineGroup")
    self.playerViews:SetWidth(200)
    self.playerViews:SetTitle("Players")
    self.playerViews:SetLayout("Fill")

    self.importRaid = AceGUI:Create("Button")
    self.importRaid:SetText("Import Raid")
    self.importRaid:SetCallback("OnClick", function()self:ImportRaid() end)
    local r, g, b = self.importRaid.text:GetTextColor()
    self.importRaid.textColor = {}
    self.importRaid.textColor.r = r
    self.importRaid.textColor.g = g
    self.importRaid.textColor.b = b

    self.broadcast = AceGUI:Create("Button")
    self.broadcast:SetText("Broadcast Data")
    self.broadcast:SetCallback("OnClick", function()self:Broadcast() end)
    local r, g, b = self.broadcast.text:GetTextColor()
    self.broadcast.textColor = {}
    self.broadcast.textColor.r = r
    self.broadcast.textColor.g = g
    self.broadcast.textColor.b = b

    self.playerDropdownMenu = _G["cebistrackerDropdownMenu"]:New()
    self.playerDropdownMenu:AddItem("Delete", function ()
        table.remove(playersDB, self.playerDropdownMenu.clickedEntry)
        self:PopulatePlayers()
    end)
    self.players = AceGUI:Create("ScrollFrame")
    self.players:SetLayout("Flow")
    self.players.playerLabels = {}
    self.playerViews:AddChild(self.players)

    -- self.gearViews = AceGUI:Create("InlineGroup")
    -- self.gearViews:SetWidth(200)
    -- self.gearViews:SetTitle("BiS Tokens")
    -- self.gearViews:SetLayout("Fill")

    -- self.checkboxes = AceGUI:Create("ScrollFrame")
    -- self.checkboxes:SetLayout("Flow")
    -- self.gearViews:AddChild(self.checkboxes)

    self.gearLabel = AceGUI:Create("Label")
    self.gearLabel:SetText("Select a player")
    self.gearLabel:SetFont(DEFAULT_FONT, 12, "")

    for _, obj in ipairs(gearButtons) do
        obj.checkbox = AceGUI:Create("CheckBox")
        obj.checkbox:SetLabel(obj.displayName)
        obj.checkbox:SetImage(obj.icon)
        obj.checkbox:SetFullWidth(true)
        obj.checkbox.SetUserData(obj.checkbox, "objData", obj)
        obj.checkbox:SetCallback("OnValueChanged", function(checkbox, _, value)
            local obj = checkbox.userdata.objData
            local messageKey = "ADDCHECK"
            if value then
                selectedPlayer.items[obj.name] = value
            else
                table.removekey(selectedPlayer.items, obj.name)
                messageKey = "REMOVECHECK"
            end

            local permission = self:GetPermission()
            if permission then
                local message = {
                    key = messageKey,
                    sender = UnitName("player"),
                    player = selectedPlayer.name,
                    value = obj.name
                }
                self:SendComm(message)
            end
        end)
    end

    self.editRank = AceGUI:Create("Dropdown")
    self.editRank:SetWidth(170)
    self.editRank:SetLabel("Minimum Rank to Edit")
    local numGuildMembers = GetNumGuildMembers()
	for i = 1, numGuildMembers do
		local name, _, rankIndex, _, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
		if name then
			name = strsplit("-", name)
            if name == UnitName("player") then
                userRankIndex = rankIndex + 1
                break
            end
		end
	end
    local guildList = {"All Ranks"}
	for i = 1, GuildControlGetNumRanks() do
        table.insert(guildList, GuildControlGetRankName(i))
	end
    self.editRank:SetList(guildList)
    if not cbtConfigDB.editRank then
        cbtConfigDB.editRank = 1
    end
    self.editRank:SetValue(cbtConfigDB.editRank)
    self.editRank:SetCallback("OnValueChanged", function(_, _, value)
        if value == 1 then
            cbtConfigDB.editRank = 1
        elseif value - 1 < userRankIndex and not overrideMinRank then
            print("You cannot set a rank higher than your own")
            self.editRank:SetValue(cbtConfigDB.editRank)
        else
            cbtConfigDB.editRank = value
        end
        self:UpdatePermissions()
    end)
    self:UpdatePermissions()

    AceGUI:RegisterLayout("MainLayout", function ()
        self.playerViews:SetPoint("TOPLEFT", self.f.frame, "TOPLEFT", 10, -28)
        -- self.gearViews:SetPoint("TOPLEFT", self.playerViews.frame, "TOPRIGHT", 0, 0)
        self.importRaid:SetPoint("TOPLEFT", self.playerViews.frame, "BOTTOMLEFT", 0, 0)
        self.editRank:SetPoint("TOPLEFT", self.importRaid.frame, "TOPRIGHT", 5, 17)
        self.broadcast:SetPoint("TOPLEFT", self.importRaid.frame, "BOTTOMLEFT", 0, -5)
        self.f:SetWidth(400)
		self.f:SetHeight(585)

        self.playerViews:SetHeight(490)
        -- self.gearViews:SetHeight(520)
        self.gearLabel:SetPoint("TOPLEFT", self.playerViews.frame, "TOPRIGHT", 0, -5)
        for index, obj in ipairs(gearButtons) do
            obj.checkbox:SetPoint("TOPLEFT", self.playerViews.frame, "TOPRIGHT", 0, 0 - (index * 24))
        end

    end)
    self:PopulatePlayers()
    self.f:AddChild(self.playerViews)
    -- self.f:AddChild(self.gearViews)
    self.f:AddChild(self.importRaid)
    self.f:AddChild(self.editRank)
    self.f:AddChild(self.broadcast)
    self.f:AddChild(self.gearLabel)
    for _, obj in ipairs(gearButtons) do
        self.f:AddChild(obj.checkbox)
        obj.checkbox:SetDisabled(true)
    end


    self.f:SetLayout("MainLayout")
	self.f:DoLayout()

    self:RegisterComm("cebistracker", "OnCommReceived")
end

-- Slash Commands Functions
local SLASH_CMD_FUNCTIONS = {
	["CLEAR"] = function(args)
        print("Clearing all data")
        playersDB = {}
        cbtConfigDB = {
            editRank = 1,
        }
        overrideMinRank = true
        cebistracker.editRank:SetValue(1)
        overrideMinRank = false
        cebistracker:PopulatePlayers()
	end,
    ["SHOW"] = function (args)
        cebistracker.f:Show()
    end,
    ["HIDE"] = function (args)
        cebistracker.f:Hide()
    end,
    ["VERSION"] = function (args)
        versionsDict = {}
        versionsDict[GetAddOnMetadata("CEBiSTracker", "Version")] = "|c" .. cebistracker:GetMyClassColor() .. UnitName("player") .. "|r"
        local message = {
            key = "VERSION",
            sender = UnitName("player")
        }
        cebistracker:SendComm(message)
        C_Timer.After(1, function() 
            print("|cFFFF7D0ACEBiSTracker|r Versions in Use:")
            for version, users in pairs(versionsDict) do
                print("     |cFFFF7D0A" .. version .. "|r: " .. users)
            end
        end)

    end,
    ["HELP"] = function (args)
        print("Casual Encounter BIS Tracker Slash Commands:")
        print("|cFFFF7D0A/cbt clear|r - Clears all data")
        print("|cFFFF7D0A/cbt show|r - Shows the main window")
        print("|cFFFF7D0A/cbt hide|r - Hides the main window")
        print("|cFFFF7D0A/cbt version|r - Shows the version of CEBiSTracker in use by everyone in the raid")
    end,
}

SLASH_CBT1 = "/cebistracker"
SLASH_CBT2 = "/cbt"
SlashCmdList["CBT"] = function(message)
	local _, _, cmd, args = string.find(message:upper(), "%s?(%w+)%s?(.*)")
	if not SLASH_CMD_FUNCTIONS[cmd] then
		cmd = "HELP"
	end
	SLASH_CMD_FUNCTIONS[cmd](args)
end

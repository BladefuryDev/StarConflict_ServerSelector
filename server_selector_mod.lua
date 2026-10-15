-- ============================================================================
-- Star Conflict Server Selector Mod
-- Custom Community Server Manager with Dropdown, Add Server,
-- Context Menu (Right Click -> Set Default / Delete), and Default Auto-Load
-- ============================================================================

-- Visible records in the dropdown before vertical scrollbar activates (fits 720p to 4K cleanly)
if UI.Login_ServersComboBox then
	UI.Login_ServersComboBox.MAX_VISIBLE_RECORDS = 6
end

-- ----------------------------------------------------------------------------
-- UI.Login_AddServerBtn Window Definition
-- ----------------------------------------------------------------------------
UI.Login_AddServerBtn =
{
	def =
	{
		className	= "ButtonWnd",
		prototype	= "TextBtn2",

		props =
		{
			name		= "Login_AddServerBtn",
		},
	},

	textId = "",
}

function UI.Login_AddServerBtn:F_PostLoad()
	if UI.TextBtn and UI.TextBtn.F_PostLoad then
		UI.TextBtn.F_PostLoad( self )
	end
	if self.SetBtnText then
		self:SetBtnText( "Add Server" )
	elseif UI.Login_Btn and UI.Login_Btn.layers and self.SetText then
		self:SetText( "Add Server", UI.Login_Btn.layers.TEXT )
	end
end

-- ----------------------------------------------------------------------------
-- Context Menu & Slot Hook Lazy Initializers
-- ----------------------------------------------------------------------------
local l_cmHooksInstalled = false
function UI.LoginWnd:EnsureContextMenuHooks()
	if l_cmHooksInstalled then
		return
	end

	if UI.ContextMenu_SlotWnd then
		local orig_CM_UpdateForData = UI.ContextMenu_SlotWnd.UpdateForData
		UI.ContextMenu_SlotWnd.UpdateForData = function( self, data, bAnimated )
			if data and data.customText then
				self:Reset()
				local text = data.customText
				local metaTextLocator = "name"
				local mainEffect = UI:GetEffectFromLayer( self, self.layers.MAIN_EFFECT )
				if data.disable then
					if mainEffect then mainEffect:StartAnimation( "disable" ) end
				else
					if mainEffect then mainEffect:StartAnimation( "idle" ) end
				end
				self.metaText:InitFromLayer( self, self.layers.TEXT ) 
				self.metaTextPos = mainEffect and mainEffect:GetObjPos( metaTextLocator )
				self.metaText:SetText( text, true )
				self:UpdateEffects()
				return
			end
			if orig_CM_UpdateForData then
				orig_CM_UpdateForData( self, data, bAnimated )
			end
		end

		local orig_CM_Action = UI.ContextMenu_SlotWnd.Action
		UI.ContextMenu_SlotWnd.Action = function( self )
			local data = self:GetRecordData()
			if data and data.callback then
				data.callback( data )
				return
			end
			if orig_CM_Action then
				orig_CM_Action( self )
			end
		end

		l_cmHooksInstalled = true
	end
end

local l_slotHooksInstalled = false
function UI.LoginWnd:EnsureSlotHooks()
	if l_slotHooksInstalled then
		return
	end

	if UI.ComboBox1_ListSlot then
		local orig_Slot_RButtonDown = UI.ComboBox1_ListSlot.F_OnMouseRButtonDown
		UI.ComboBox1_ListSlot.F_OnMouseRButtonDown = function( self, mouseX, mouseY, wndThatReceivedInput )
			local list = (self.GetList and self:GetList()) or self.parentListWnd
			local comboBox = list and list.comboBox
			if comboBox == UI.Login_ServersComboBox then
				local data = self.GetRecordData and self:GetRecordData()
				if not data and list and list.Slot2RecordIdx and list.GetRecordData then
					local slotIdx = self.slotIdx or (self.GetSlot and self:GetSlot()) or 0
					local recordIdx = list:Slot2RecordIdx( slotIdx )
					if recordIdx and recordIdx ~= -1 then
						data = list:GetRecordData( recordIdx )
					end
				end
				if data and data.serverInfo then
					UI.LoginWnd:ShowServerContextMenu( data.serverInfo, mouseX, mouseY )
					return true
				end
			end
			if orig_Slot_RButtonDown then
				return orig_Slot_RButtonDown( self, mouseX, mouseY, wndThatReceivedInput )
			end
			return false
		end

		if UI.ComboBox_ListSlot then
			UI.ComboBox_ListSlot.F_OnMouseRButtonDown = UI.ComboBox1_ListSlot.F_OnMouseRButtonDown
		end

		l_slotHooksInstalled = true
	end
end

-- ----------------------------------------------------------------------------
-- Add Server Button Management
-- ----------------------------------------------------------------------------

function UI.LoginWnd:EnsureAddServerBtn()
	pcall(function()
		if not UI.Login_AddServerBtn or not UI.Login_AddServerBtn.IsChildOf then
			if UI.CreateWndFromTable then
				local btn = UI:CreateWndFromTable( "UI.Login_AddServerBtn" )
				if btn then
					UI.Login_AddServerBtn = btn
				end
			end
		end

		if UI.Login_AddServerBtn and UI.Login_AddServerBtn.IsChildOf then
			if not UI.Login_AddServerBtn:IsChildOf( self ) then
				self:AddChild( UI.Login_AddServerBtn )
			end
			if UI.Login_AddServerBtn.SetBtnText then
				UI.Login_AddServerBtn:SetBtnText( "Add Server" )
			elseif UI.Login_Btn and UI.Login_Btn.layers and UI.Login_AddServerBtn.SetText then
				UI.Login_AddServerBtn:SetText( "Add Server", UI.Login_Btn.layers.TEXT )
			end
			self:UpdateAddServerBtnPos()
		end
	end)
end

function UI.LoginWnd:UpdateAddServerBtnPos()
	pcall(function()
		if not UI.Login_AddServerBtn or not UI.Login_AddServerBtn.IsChildOf or not UI.Login_AddServerBtn:IsChildOf( self ) then
			return
		end

		local comboLeft = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetLeft and UI.Login_ServersComboBox:GetLeft()
		local comboTop = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetTop and UI.Login_ServersComboBox:GetTop()
		local comboWidth = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetWidth and UI.Login_ServersComboBox:GetWidth()
		local comboHeight = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetHeight and UI.Login_ServersComboBox:GetHeight()

		if not comboLeft or comboLeft <= 0 then
			if UI.Login_ServerNameEditWnd and UI.Login_ServerNameEditWnd.GetLeft then
				local snLeft = UI.Login_ServerNameEditWnd:GetLeft()
				if snLeft and snLeft > 0 then
					comboLeft = snLeft
				end
			end
			if not comboLeft or comboLeft <= 0 then
				comboLeft = 14
			end
		end

		if not comboTop or comboTop <= 0 then
			if UI.Login_ServerNameEditWnd and UI.Login_ServerNameEditWnd.GetTop then
				local snTop = UI.Login_ServerNameEditWnd:GetTop()
				if snTop and snTop > 30 then
					comboTop = snTop - 30
				end
			end
			if not comboTop or comboTop <= 0 then
				comboTop = 587
			end
		end

		-- In 1280x720 base coordinates, the dropdown arrow ends at X ~ 135 (width ~128).
		-- If comboWidth reported larger than 140, use the actual field width 128.
		if not comboWidth or comboWidth < 50 or comboWidth > 140 then
			comboWidth = 128
		end
		if not comboHeight or comboHeight < 16 or comboHeight > 40 then
			comboHeight = 22
		end

		UI.Login_AddServerBtn:SetLeft( comboLeft + comboWidth + 8 )
		UI.Login_AddServerBtn:SetTop( comboTop )
		UI.Login_AddServerBtn:SetWidth( 90 )
		UI.Login_AddServerBtn:SetHeight( comboHeight )

		if self.UpdateZOrder then
			self:UpdateZOrder()
		end
	end)
end

-- ----------------------------------------------------------------------------
-- Persistent Storage: Load & Save
-- ----------------------------------------------------------------------------
function UI.LoginWnd:LoadSavedServersData()
	self.savedServers = {}
	self.defaultServerAddress = nil

	local profile = _G.GetProfileTable and _G.GetProfileTable()
	if profile then
		if type( profile.sc_saved_servers ) == "table" then
			for _, s in ipairs( profile.sc_saved_servers ) do
				if type( s ) == "table" and s.address and s.address ~= "" then
					local port = s.port or self.DEFAULT_SERVER_PORT
					local full = string.format( "%s:%s", s.address, port )
					table.insert( self.savedServers, {
						address     = s.address,
						port        = port,
						fullAddress = full,
					})
				end
			end
		end
		if type( profile.sc_default_server ) == "string" and profile.sc_default_server ~= "" then
			self.defaultServerAddress = profile.sc_default_server
		end
	end

	-- Fallback file read if io is available
	if #self.savedServers == 0 and io and io.open then
		pcall(function()
			local f = io.open( "saved_servers.cfg", "r" )
			if f then
				for line in f:lines() do
					local defVal = string.match( line, "^default=(.*)$" )
					if defVal and defVal ~= "" then
						self.defaultServerAddress = defVal
					end
					local srvVal = string.match( line, "^server=(.*)$" )
					if srvVal and srvVal ~= "" then
						local addr = srvVal
						local prt = self.DEFAULT_SERVER_PORT
						local cPos = string.find( srvVal, ":" )
						if cPos then
							addr = string.sub( srvVal, 1, cPos - 1 )
							prt = string.sub( srvVal, cPos + 1 )
						end
						local full = string.format( "%s:%s", addr, prt )
						table.insert( self.savedServers, {
							address     = addr,
							port        = prt,
							fullAddress = full,
						})
					end
				end
				f:close()
			end
		end)
	end
end

function UI.LoginWnd:SaveSavedServersData()
	local profile = _G.GetProfileTable and _G.GetProfileTable()
	if profile then
		local rawSaved = {}
		for _, s in ipairs( self.savedServers or {} ) do
			table.insert( rawSaved, {
				address     = s.address,
				port        = s.port,
				fullAddress = s.fullAddress,
			})
		end
		profile.sc_saved_servers = rawSaved
		profile.sc_default_server = self.defaultServerAddress or ""
		if Profile and Profile.Save then
			Profile:Save()
		end
	end

	-- Fallback file write if io is available
	if io and io.open then
		pcall(function()
			local f = io.open( "saved_servers.cfg", "w" )
			if f then
				f:write( "default=" .. tostring( self.defaultServerAddress or "" ) .. "\n" )
				for _, s in ipairs( self.savedServers or {} ) do
					f:write( "server=" .. tostring( s.address ) .. ":" .. tostring( s.port or "3801" ) .. "\n" )
				end
				f:close()
			end
		end)
	end
end

-- ----------------------------------------------------------------------------
-- Build Server List
-- ----------------------------------------------------------------------------
function UI.LoginWnd:BuildServersList()
	if not self.savedServers then
		self:LoadSavedServersData()
	end

	local servers = {}

	-- 1. Localhost
	local isLocalhostDef = (self.defaultServerAddress == "localhost")
	table.insert( servers, {
		name        = "localhost",
		address     = "localhost",
		port        = "",
		fullAddress = "localhost",
		displayName = isLocalhostDef and "localhost [Default]" or "localhost",
		isLocalhost = true,
	})

	-- 2. Saved Servers
	for _, s in ipairs( self.savedServers ) do
		local isDef = (self.defaultServerAddress == s.fullAddress)
		local disp = isDef and string.format( "%s [Default]", s.fullAddress ) or s.fullAddress
		table.insert( servers, {
			name        = s.fullAddress,
			address     = s.address,
			port        = s.port or self.DEFAULT_SERVER_PORT,
			fullAddress = s.fullAddress,
			displayName = disp,
			isSaved     = true,
		})
	end

	-- 3. Custom Server option
	table.insert( servers, {
		name        = "server",
		address     = "",
		port        = self.DEFAULT_SERVER_PORT,
		fullAddress = "",
		displayName = "Custom Server...",
		isCustom    = true,
	})

	self.servers = servers
	self.defaultServers = servers
	return servers
end

-- ----------------------------------------------------------------------------
-- Server Actions
-- ----------------------------------------------------------------------------
function UI.LoginWnd:AddSavedServer( address, port )
	port = (port and port ~= "") and port or self.DEFAULT_SERVER_PORT
	local fullAddress = string.format( "%s:%s", address, port )

	local exists = false
	for _, s in ipairs( self.savedServers ) do
		if string.lower( s.fullAddress ) == string.lower( fullAddress ) then
			exists = true
			s.port = port
			break
		end
	end

	if not exists then
		table.insert( self.savedServers, {
			address     = address,
			port        = port,
			fullAddress = fullAddress,
		})
	end

	if not self.defaultServerAddress or self.defaultServerAddress == "" then
		self.defaultServerAddress = fullAddress
	end

	self:SaveSavedServersData()
	self:BuildServersList()
	self:UpdateServersComboBox()

	-- Select the newly added server
	for idx = 1, #self.servers do
		if string.lower( self.servers[ idx ].fullAddress or "" ) == string.lower( fullAddress ) then
			UI.Login_ServersComboBox:SelectRecord( idx )
			self:UpdateConfigAddressFromComboBox()
			self:UpdateServerAddressWnd()
			break
		end
	end
end

function UI.LoginWnd:SetDefaultServer( fullAddress )
	self.defaultServerAddress = fullAddress
	self:SaveSavedServersData()
	self:BuildServersList()
	self:UpdateServersComboBox()

	-- Re-select the default server
	for idx = 1, #self.servers do
		local s = self.servers[ idx ]
		if s.fullAddress == fullAddress or (s.isLocalhost and fullAddress == "localhost") then
			UI.Login_ServersComboBox:SelectRecord( idx )
			self:UpdateConfigAddressFromComboBox()
			self:UpdateServerAddressWnd()
			break
		end
	end

	if UI.Login_ServersComboBox and UI.Login_ServersComboBox.Close then
		UI.Login_ServersComboBox:Close()
	end
	UI:PlayGlobalSound( self.sounds.btnClick )
end

function UI.LoginWnd:DeleteSavedServer( fullAddress )
	local newSaved = {}
	for _, s in ipairs( self.savedServers or {} ) do
		if string.lower( s.fullAddress ) ~= string.lower( fullAddress ) then
			table.insert( newSaved, s )
		end
	end
	self.savedServers = newSaved

	if string.lower( self.defaultServerAddress or "" ) == string.lower( fullAddress ) then
		self.defaultServerAddress = "localhost"
	end

	self:SaveSavedServersData()
	self:BuildServersList()
	self:UpdateServersComboBox()

	if UI.Login_ServersComboBox and UI.Login_ServersComboBox.Close then
		UI.Login_ServersComboBox:Close()
	end
	UI:PlayGlobalSound( "sound/ui/cancel" )
end

function UI.LoginWnd:SelectCustomServerEntry()
	for idx = 1, #self.servers do
		if self.servers[ idx ].isCustom then
			UI.Login_ServersComboBox:SelectRecord( idx )
			self:UpdateConfigAddressFromComboBox()
			self:UpdateServerAddressWnd()
			break
		end
	end
end

function UI.LoginWnd:OnAddServer()
	local isFieldsVisible = UI.Login_ServerNameEditWnd:IsChildOf( self )

	-- If fields are not visible (e.g. on localhost), open custom server fields and focus
	if not isFieldsVisible then
		self:SelectCustomServerEntry()
		UI:SetKeyboardFocus( UI.Login_ServerNameEditWnd:GetUiHandle() )
		return
	end

	local address = UI.Login_ServerNameEditWnd:GetEditText()
	local port = UI.Login_ServerPortEditWnd:GetEditText()

	if address then
		address = string.gsub( address, "^%s*(.-)%s*$", "%1" )
	else
		address = ""
	end
	if port then
		port = string.gsub( port, "^%s*(.-)%s*$", "%1" )
	else
		port = ""
	end

	if UI:IsStrEmpty( address ) then
		UI:SetKeyboardFocus( UI.Login_ServerNameEditWnd:GetUiHandle() )
		return
	end

	if UI:IsStrEmpty( port ) then
		port = self.DEFAULT_SERVER_PORT
		UI.Login_ServerPortEditWnd:SetEditText( port )
	end

	-- Split if address contains a colon
	local colonPos = string.find( address, ":" )
	if colonPos then
		port = string.sub( address, colonPos + 1 )
		address = string.sub( address, 1, colonPos - 1 )
		UI.Login_ServerNameEditWnd:SetEditText( address )
		UI.Login_ServerPortEditWnd:SetEditText( port )
	end

	if string.lower( address ) == "localhost" then
		return
	end

	self:AddSavedServer( address, port )
	UI:PlayGlobalSound( self.sounds.btnClick )
end

-- ----------------------------------------------------------------------------
-- UpdateServersComboBox Override
-- ----------------------------------------------------------------------------
function UI.LoginWnd:UpdateServersComboBox()

	self:EnsureSlotHooks()
	self:EnsureContextMenuHooks()

	if not self:NeedServersComboBox() then
		UI.Login_ServersComboBox:UnlinkFromParent()
		if UI.Login_AddServerBtn and UI.Login_AddServerBtn.IsChildOf and UI.Login_AddServerBtn:IsChildOf( self ) then
			UI.Login_AddServerBtn:UnlinkFromParent()
		end
		self:UpdateServerAddressWnd()
		return
	end

	self:AddChild( UI.Login_ServersComboBox )

	self:BuildServersList()

	UI.Login_ServersComboBox:Reset()
	local maxVis = UI.Login_ServersComboBox.MAX_VISIBLE_RECORDS or 6
	if UI.Login_ServersComboBox.SetMaxVisibleRecords then
		UI.Login_ServersComboBox:SetMaxVisibleRecords( maxVis )
	elseif UI.Login_ServersComboBox.listWnd and UI.Login_ServersComboBox.listWnd.SetMaxSlots then
		UI.Login_ServersComboBox.listWnd:SetMaxSlots( maxVis )
	end
	local selRecordIdx = 1
	local configAddress = cvars.net_masterServerAddress

	-- Priority 1: Default server if configured
	local matchedDefaultIdx = nil
	if self.defaultServerAddress and self.defaultServerAddress ~= "" then
		for idx = 1, #self.servers do
			local sInfo = self.servers[ idx ]
			if sInfo.fullAddress == self.defaultServerAddress or (sInfo.isLocalhost and self.defaultServerAddress == "localhost") then
				matchedDefaultIdx = idx
				break
			end
		end
	end

	-- Priority 2: configAddress if valid remote address
	local matchedConfigIdx = nil
	if configAddress ~= "" and configAddress ~= "localhost" then
		for idx = 1, #self.servers do
			local sInfo = self.servers[ idx ]
			if sInfo.fullAddress == configAddress then
				matchedConfigIdx = idx
				break
			end
		end
	end

	if matchedDefaultIdx then
		selRecordIdx = matchedDefaultIdx
	elseif matchedConfigIdx then
		selRecordIdx = matchedConfigIdx
	elseif configAddress ~= "" and configAddress ~= "localhost" then
		for idx = 1, #self.servers do
			if self.servers[ idx ].isCustom then
				selRecordIdx = idx
				break
			end
		end
	end

	-- Populate records into combobox
	for idx = 1, #self.servers do
		local serverInfo = self.servers[ idx ]
		local data = {}
		data.serverInfo = serverInfo
		data.address    = serverInfo.address
		data.text       = serverInfo.displayName or serverInfo.name
		UI.Login_ServersComboBox:AddRecord( data )
	end

	UI.Login_ServersComboBox:SelectRecord( selRecordIdx )

	-- Update edit controls & cvars based on selected server
	local selServer = self.servers[ selRecordIdx ]
	if selServer then
		if selServer.isSaved then
			UI.Login_ServerNameEditWnd:SetEditText( selServer.address )
			UI.Login_ServerPortEditWnd:SetEditText( selServer.port or self.DEFAULT_SERVER_PORT )
			cvars.net_masterServerAddress = selServer.fullAddress
		elseif selServer.isCustom then
			local addr = configAddress
			local prt = self.DEFAULT_SERVER_PORT
			if addr ~= "" and addr ~= "localhost" then
				local delimiterPos = string.find( addr, ":" )
				if delimiterPos then
					addr = string.sub( addr, 1, delimiterPos - 1 )
					prt = string.sub( addr, delimiterPos + 1 )
				end
				UI.Login_ServerNameEditWnd:SetEditText( addr )
				UI.Login_ServerPortEditWnd:SetEditText( prt )
			else
				UI.Login_ServerNameEditWnd:SetEditText( "" )
				UI.Login_ServerPortEditWnd:SetEditText( self.DEFAULT_SERVER_PORT )
			end
		elseif selServer.isLocalhost then
			cvars.net_masterServerAddress = "localhost"
		end
	end

	self:UpdateServerAddressWnd()
	self:EnsureAddServerBtn()

end

-- ----------------------------------------------------------------------------
-- UpdateServerAddressWnd Override
-- ----------------------------------------------------------------------------
function UI.LoginWnd:UpdateServerAddressWnd()

	local selRecordIdx = UI.Login_ServersComboBox:GetSelectedRecord()
	local selServer = self.servers and self.servers[ selRecordIdx ]

	local bShowServerFields = self:NeedServersComboBox() and selServer and (selServer.isCustom or selServer.name == "server")

	if bShowServerFields then
		self:AddControl( UI.Login_ServerNameEditWnd, self.layers.MAIN_EFFECT, "server_name" )
		self:AddControl( UI.Login_ServerPortEditWnd, self.layers.MAIN_EFFECT, "server_port" )

		UI.Login_ServerNameEditWnd:UpdateDummyText()
		UI.Login_ServerPortEditWnd:UpdateDummyText()

		if UI.Login_AddServerBtn and UI.Login_AddServerBtn.SetBtnText then
			UI.Login_AddServerBtn:SetBtnText( "Save Server" )
		end
	else
		self:RemoveControl( UI.Login_ServerNameEditWnd, self.layers.MAIN_EFFECT )
		self:RemoveControl( UI.Login_ServerPortEditWnd, self.layers.MAIN_EFFECT )
		UI.Login_ServerNameEditWnd:SetLayerVisible( false, UI.Login_ServerNameEditWnd.layers.DUMMY_TEXT )
		UI.Login_ServerPortEditWnd:SetLayerVisible( false, UI.Login_ServerPortEditWnd.layers.DUMMY_TEXT )

		if UI.Login_AddServerBtn and UI.Login_AddServerBtn.SetBtnText then
			UI.Login_AddServerBtn:SetBtnText( "Add Server" )
		end
	end

	self:UpdateAddServerBtnPos()
	self:UpdateFocus()

end

-- ----------------------------------------------------------------------------
-- UpdateConfigAddress Overrides
-- ----------------------------------------------------------------------------
function UI.LoginWnd:UpdateConfigAddressFromComboBox()

	local selRecordIdx = UI.Login_ServersComboBox:GetSelectedRecord()
	if selRecordIdx == -1 or not self.servers then
		return
	end

	local serverInfo = self.servers[ selRecordIdx ]
	if not serverInfo then
		return
	end

	if serverInfo.isLocalhost then
		cvars.net_masterServerAddress = "localhost"
	elseif serverInfo.isSaved then
		cvars.net_masterServerAddress = serverInfo.fullAddress
	elseif serverInfo.isCustom or serverInfo.name == "server" then
		self:UpdateConfigAddressFromServerAddress()
	else
		cvars.net_masterServerAddress = serverInfo.address or ""
	end

end

function UI.LoginWnd:UpdateConfigAddressFromServerAddress()

	local selRecordIdx = UI.Login_ServersComboBox:GetSelectedRecord()
	local serverInfo = self.servers and self.servers[ selRecordIdx ]
	if not serverInfo or serverInfo.isLocalhost or serverInfo.isSaved then
		return
	end

	local address = UI.Login_ServerNameEditWnd:GetEditText()
	local port = UI.Login_ServerPortEditWnd:GetEditText()

	if not UI:IsStrEmpty( address ) and not UI:IsStrEmpty( port ) then
		address = string.format( "%s:%s", address, port )
	end

	cvars.net_masterServerAddress = address

end

-- ----------------------------------------------------------------------------
-- LoginWnd Event Hooks
-- ----------------------------------------------------------------------------

local orig_LoginWnd_OnMouseLButtonDown = UI.LoginWnd.F_OnMouseLButtonDown
function UI.LoginWnd:F_OnMouseLButtonDown( mouseX, mouseY, wndThatReceivedInput )
	local wnd = UI:GetUiObjByHandleT( wndThatReceivedInput )
	if wnd == UI.Login_AddServerBtn or (wnd and wnd.IsChildOf and wnd:IsChildOf( UI.Login_AddServerBtn )) then
		self:OnAddServer()
		return true
	end
	if orig_LoginWnd_OnMouseLButtonDown then
		return orig_LoginWnd_OnMouseLButtonDown( self, mouseX, mouseY, wndThatReceivedInput )
	end
	return false
end

local orig_LoginWnd_PosChanged = UI.LoginWnd.F_OnScreenPosChanged
function UI.LoginWnd:F_OnScreenPosChanged( oldScreenX, oldScreenY )
	if orig_LoginWnd_PosChanged then
		orig_LoginWnd_PosChanged( self, oldScreenX, oldScreenY )
	end
	self:UpdateAddServerBtnPos()
end

local orig_LoginWnd_Shutdown = UI.LoginWnd.F_Shutdown
function UI.LoginWnd:F_Shutdown()
	if UI.Login_AddServerBtn and UI.Login_AddServerBtn.IsChildOf and UI.Login_AddServerBtn:IsChildOf( self ) then
		UI.Login_AddServerBtn:UnlinkFromParent()
	end
	if orig_LoginWnd_Shutdown then
		orig_LoginWnd_Shutdown( self )
	end
end

local orig_LoginWnd_Reset = UI.LoginWnd.Reset
function UI.LoginWnd:Reset()
	if orig_LoginWnd_Reset then
		orig_LoginWnd_Reset( self )
	end
	if UI.Login_AddServerBtn and UI.Login_AddServerBtn.IsChildOf and UI.Login_AddServerBtn:IsChildOf( self ) then
		UI.Login_AddServerBtn:UnlinkFromParent()
	end
end

local orig_RequestServersList = UI.LoginWnd.RequestServersList
function UI.LoginWnd:RequestServersList()
	if orig_RequestServersList then
		orig_RequestServersList( self )
	end
	self:BuildServersList()
end

local orig_OnServerAddresses = UI.LoginWnd.MasterServer_OnServerAddresess
function UI.LoginWnd:MasterServer_OnServerAddresess( errcode, servers )
	self:BuildServersList()
	if orig_OnServerAddresses then
		orig_OnServerAddresses( self, errcode, servers )
	end
	self:BuildServersList()
end

-- ----------------------------------------------------------------------------
-- ShowServerContextMenu
-- ----------------------------------------------------------------------------

function UI.LoginWnd:ShowServerContextMenu( serverInfo, mouseX, mouseY )
	if not serverInfo or serverInfo.isCustom or serverInfo.name == "server" then
		return
	end

	self:EnsureContextMenuHooks()

	if not UI.ContextMenu then
		return
	end

	UI.ContextMenu:Clear()

	local titleName = serverInfo.displayName or serverInfo.name or ""
	titleName = string.gsub( titleName, "%s*%[Default%]", "" )
	if UI.ContextMenu.SetName then
		UI.ContextMenu:SetName( titleName )
	end

	local isLocalhost = serverInfo.isLocalhost
	local isDefault = (self.defaultServerAddress == serverInfo.fullAddress) or (isLocalhost and (self.defaultServerAddress == "localhost" or self.defaultServerAddress == "" or self.defaultServerAddress == nil))

	-- 1. Set as Default
	local defLabel = isDefault and "Default Server (Active)" or "Set as Default"
	UI.ContextMenu:AddRecord({
		customText = defLabel,
		disable    = isDefault,
		callback   = function()
			self:SetDefaultServer( isLocalhost and "localhost" or serverInfo.fullAddress )
		end,
	})

	-- 2. Delete Server (saved servers only)
	if serverInfo.isSaved then
		UI.ContextMenu:AddRecord({
			customText = "Delete Server",
			callback   = function()
				self:DeleteSavedServer( serverInfo.fullAddress )
			end,
		})
	end

	UI.ContextMenu:Show( mouseX, mouseY )
end

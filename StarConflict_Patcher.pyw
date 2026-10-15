# -*- coding: utf-8 -*-
"""
Star Conflict - Community Server Selector Patcher
Created by Alan Hexfury and Gemini.
Hexfury for UI development for the patcher interface and mod,
Gemini for tracing back all the function calls in the Star Conflict environment.
"""

import os
import sys
import shutil
import winreg
import ctypes
import threading
import json
import urllib.request
import urllib.error
import webbrowser
import tkinter as tk
from tkinter import filedialog, messagebox

APP_VERSION = "v1.1.1"
GITHUB_REPO = "BladefuryDev/StarConflict_ServerSelector"
GITHUB_RELEASES_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
GITHUB_PROJECT_URL = f"https://github.com/{GITHUB_REPO}"

def parse_version_tuple(v_str):
    if not v_str:
        return (0, 0, 0)
    clean = v_str.strip().lstrip('v').lstrip('V')
    parts = []
    for p in clean.split('.'):
        digits = ''.join(filter(str.isdigit, p))
        parts.append(int(digits) if digits else 0)
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)

def is_newer_version(remote_tag, local_tag):
    return parse_version_tuple(remote_tag) > parse_version_tuple(local_tag)

# Resolve base paths for both direct execution and PyInstaller bundled mode
if getattr(sys, 'frozen', False):
    APP_DIR = sys._MEIPASS
    SCRIPT_DIR = os.path.dirname(sys.executable)
else:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
    APP_DIR = SCRIPT_DIR

if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)
uilibs = os.path.join(SCRIPT_DIR, "UILibs")
if os.path.isdir(uilibs) and uilibs not in sys.path:
    sys.path.insert(0, uilibs)
if APP_DIR not in sys.path:
    sys.path.insert(0, APP_DIR)

import omega_ui as oui

MOD_BEGIN_MARKER = "-- BEGIN STAR CONFLICT SERVER SELECTOR MOD"
MOD_END_MARKER   = "-- END STAR CONFLICT SERVER SELECTOR MOD"

COMMON_PATHS = [
    r"G:\SteamLibrary\steamapps\common\star conflict",
    r"C:\Program Files (x86)\Steam\steamapps\common\star conflict",
    r"C:\Program Files\Steam\steamapps\common\star conflict",
    r"D:\SteamLibrary\steamapps\common\star conflict",
    r"E:\SteamLibrary\steamapps\common\star conflict",
    r"F:\SteamLibrary\steamapps\common\star conflict",
]

EMBEDDED_MOD_LUA = """-- ============================================================================
-- Star Conflict Server Selector Mod
-- Custom Community Server Manager with Dropdown, Add Server,
-- Context Menu (Right Click -> Set Default / Delete), and Default Auto-Load
-- Version 1.1.1: Live auto-update verification test
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
				f:write( "default=" .. tostring( self.defaultServerAddress or "" ) .. "\\n" )
				for _, s in ipairs( self.savedServers or {} ) do
					f:write( "server=" .. tostring( s.address ) .. ":" .. tostring( s.port or "3801" ) .. "\\n" )
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
"""

def get_resource_path(filename):
    """Finds a resource file in PyInstaller temp folder, current directory, or script directory."""
    candidates = [
        os.path.join(APP_DIR, filename),
        os.path.join(SCRIPT_DIR, filename),
        os.path.join(os.getcwd(), filename),
    ]
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    return None

def find_steam_libraries():
    """Discover Steam library paths from Windows Registry."""
    found = []
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam_path, _ = winreg.QueryValueEx(key, "SteamPath")
            if steam_path:
                steam_path = os.path.normpath(steam_path)
                found.append(os.path.join(steam_path, "steamapps", "common", "star conflict"))
                vdf = os.path.join(steam_path, "steamapps", "libraryfolders.vdf")
                if os.path.isfile(vdf):
                    with open(vdf, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if '"path"' in line:
                                parts = line.split('"path"')
                                if len(parts) > 1:
                                    lib = parts[1].replace('"', '').strip()
                                    found.append(os.path.join(os.path.normpath(lib), "steamapps", "common", "star conflict"))
    except Exception:
        pass
    return found

def normalize_game_dir(path):
    """Validates and normalizes candidate path to Star Conflict game root."""
    if not path:
        return None
    cand = os.path.normpath(os.path.abspath(path))
    # If pointed to loginwnd.lua directly
    if os.path.isfile(cand) and os.path.basename(cand).lower().startswith("loginwnd"):
        cand = os.path.abspath(os.path.join(cand, "..", "..", "..", ".."))
    # If pointed to data directory
    elif os.path.isdir(cand) and os.path.basename(cand).lower() == "data":
        cand = os.path.abspath(os.path.join(cand, ".."))

    target = os.path.join(cand, "data", "ui", "scripts", "windows", "loginwnd.lua")
    if os.path.isfile(target):
        return cand
    return None

def detect_game_dir(explicit_path=None):
    if explicit_path:
        norm = normalize_game_dir(explicit_path)
        if norm:
            return norm

    env_dir = os.environ.get("STAR_CONFLICT_DIR")
    if env_dir:
        norm = normalize_game_dir(env_dir)
        if norm:
            return norm

    for cand in COMMON_PATHS + find_steam_libraries():
        norm = normalize_game_dir(cand)
        if norm:
            return norm

    return None

def get_target_file(game_dir):
    return os.path.join(game_dir, "data", "ui", "scripts", "windows", "loginwnd.lua")

def get_backup_file(game_dir):
    return os.path.join(game_dir, "data", "ui", "scripts", "windows", "loginwnd.lua.orig")

def get_mod_code():
    """Prefers external server_selector_mod.lua if present, else fallback to embedded string."""
    ext_file = get_resource_path("server_selector_mod.lua")
    if ext_file and os.path.isfile(ext_file):
        try:
            with open(ext_file, "r", encoding="utf-8") as f:
                return f.read()
        except Exception:
            pass
    return EMBEDDED_MOD_LUA

def check_status(game_dir):
    if not game_dir:
        return {"exists": False, "installed": False, "has_backup": False, "target_file": "", "backup_file": ""}
    target = get_target_file(game_dir)
    backup = get_backup_file(game_dir)
    if not os.path.isfile(target):
        return {"exists": False, "installed": False, "has_backup": os.path.isfile(backup), "target_file": target, "backup_file": backup}

    try:
        with open(target, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        installed = (MOD_BEGIN_MARKER in content) and (MOD_END_MARKER in content)
    except Exception:
        installed = False

    return {
        "exists": True,
        "installed": installed,
        "has_backup": os.path.isfile(backup),
        "target_file": target,
        "backup_file": backup,
    }

def install_mod(game_dir):
    target = get_target_file(game_dir)
    backup = get_backup_file(game_dir)
    if not os.path.isfile(target):
        return False, f"Target file not found: {target}"

    try:
        with open(target, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        if MOD_BEGIN_MARKER in content:
            prefix = content.split(MOD_BEGIN_MARKER)[0].rstrip()
            suffix = ""
            if MOD_END_MARKER in content:
                suffix = content.split(MOD_END_MARKER)[1].lstrip("\r\n")
            content = (prefix + "\n\n" + suffix).strip() + "\n"

        if not os.path.isfile(backup):
            shutil.copy2(target, backup)

        mod_code = get_mod_code()
        mod_block = f"\n\n{MOD_BEGIN_MARKER}\n{mod_code.strip()}\n{MOD_END_MARKER}\n"
        new_content = content.rstrip() + mod_block

        with open(target, "w", encoding="utf-8") as f:
            f.write(new_content)

        return True, "Successfully installed Server Selector Mod! Backup preserved at loginwnd.lua.orig."
    except Exception as e:
        return False, f"Installation failed: {str(e)}"

def uninstall_mod(game_dir):
    target = get_target_file(game_dir)
    backup = get_backup_file(game_dir)
    if not os.path.isfile(target):
        return False, f"Target file not found: {target}"

    try:
        if os.path.isfile(backup):
            shutil.copy2(backup, target)
            return True, "Successfully restored original loginwnd.lua from clean backup."

        with open(target, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        if MOD_BEGIN_MARKER in content and MOD_END_MARKER in content:
            prefix = content.split(MOD_BEGIN_MARKER)[0].rstrip()
            suffix = content.split(MOD_END_MARKER)[1].lstrip("\r\n")
            cleaned = (prefix + "\n\n" + suffix).strip() + "\n"
            with open(target, "w", encoding="utf-8") as f:
                f.write(cleaned)
            return True, "Successfully stripped mod markers. Original loginwnd.lua restored."

        return True, "Mod was not installed. Game files are already clean."
    except Exception as e:
        return False, f"Restoration failed: {str(e)}"


class StarConflictPatcherApp:
    def __init__(self):
        self.icon_path = get_resource_path("star_conflict.ico")
        
        # Initialize Omega borderless window with taskbar presence
        self.root = oui.create_omega_window(
            title="Star Conflict · Server Selector Patcher",
            width=760,
            height=660
        )
        
        # Center the window on the active display
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = max(0, (sw - 760) // 2)
        y = max(0, (sh - 660) // 2)
        self.root.geometry(f"760x660+{x}+{y}")
        
        # Custom outer border for aesthetic definition
        self.outer_border = tk.Frame(self.root, bg=oui.Theme.ACCENT, padx=1, pady=1)
        self.outer_border.pack(fill=tk.BOTH, expand=True)

        if sys.platform == 'win32':
            try:
                ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("StarConflict.CommunityServerSelector.Patcher.1.1")
            except Exception:
                pass

        # Title bar
        self.title_bar = oui.OmegaTitleBar(
            self.outer_border,
            title="Star Conflict · Community Server Selector Patcher",
            border_width=1,
            border_color=oui.Theme.ACCENT,
            icon_path=self.icon_path,
            on_close=self.root.destroy
        )
        self.outer_border.bind("<ButtonPress-1>", self.title_bar.start_drag)

        # Main scrollable or padded body container
        self.container = tk.Frame(self.outer_border, bg=oui.Theme.BG, padx=22, pady=14)
        self.container.pack(fill=tk.BOTH, expand=True)

        self.game_dir = detect_game_dir()
        self.status = check_status(self.game_dir)
        self.how_it_works_window = None
        self.update_banner_frame = None
        self.header_frame = None

        self._build_header()
        self._build_diagnostic_panel()
        self._build_path_selector()
        self._build_action_section()
        self._build_status_banner()
        self._build_credits()
        self._build_footer()

        self.refresh_ui()
        self._start_update_check()

    def _build_header(self):
        hdr = tk.Frame(self.container, bg=oui.Theme.BG)
        hdr.pack(fill=tk.X, pady=(0, 10))
        self.header_frame = hdr

        title_box = tk.Frame(hdr, bg=oui.Theme.BG)
        title_box.pack(side=tk.LEFT)

        tk.Label(
            title_box,
            text="STAR CONFLICT",
            font=("Segoe UI", 16, "bold"),
            fg=oui.Theme.ACCENT,
            bg=oui.Theme.BG
        ).pack(anchor="w")

        tk.Label(
            title_box,
            text="Community Multi-Server Manager & Dropdown Patcher",
            font=("Segoe UI", 9),
            fg=oui.Theme.TEXT,
            bg=oui.Theme.BG
        ).pack(anchor="w", pady=(1, 0))

        # Version badge
        badge_box = tk.Frame(hdr, bg=oui.Theme.PANEL, padx=8, pady=4, highlightthickness=1, highlightbackground=oui.Theme.ACCENT)
        badge_box.pack(side=tk.RIGHT, pady=(4, 0))
        tk.Label(
            badge_box,
            text=f"{APP_VERSION} • Streamlined Release",
            font=("Segoe UI", 8, "bold"),
            fg=oui.Theme.ACCENT,
            bg=oui.Theme.PANEL
        ).pack()

        # Allow dragging window from header area as well
        for w in [hdr, title_box]:
            w.bind("<ButtonPress-1>", self.title_bar.start_drag)

    def _start_update_check(self):
        """Spawns a lightweight daemon thread to query GitHub API for releases without blocking the UI."""
        t = threading.Thread(target=self._check_for_updates_worker, daemon=True)
        t.start()

    def _check_for_updates_worker(self):
        try:
            req = urllib.request.Request(
                GITHUB_RELEASES_URL,
                headers={"User-Agent": "StarConflict-ServerSelector-Patcher"}
            )
            with urllib.request.urlopen(req, timeout=4) as response:
                if response.status == 200:
                    data = json.loads(response.read().decode("utf-8"))
                    remote_tag = data.get("tag_name", "").strip()
                    release_url = data.get("html_url", GITHUB_PROJECT_URL)
                    if is_newer_version(remote_tag, APP_VERSION):
                        self.root.after(0, lambda: self._show_update_banner(remote_tag, release_url))
        except Exception:
            # Silent fallback if offline, rate limited, or repo private
            pass

    def _show_update_banner(self, remote_tag, release_url):
        if self.update_banner_frame:
            return
        self.update_banner_frame = tk.Frame(
            self.container,
            bg="#0F172A",
            padx=12,
            pady=8,
            highlightthickness=1,
            highlightbackground="#F59E0B"
        )
        if self.header_frame:
            self.update_banner_frame.pack(fill=tk.X, after=self.header_frame, pady=(0, 10))
        else:
            self.update_banner_frame.pack(fill=tk.X, pady=(0, 10))

        msg_box = tk.Frame(self.update_banner_frame, bg="#0F172A")
        msg_box.pack(side=tk.LEFT, fill=tk.Y)

        tk.Label(
            msg_box,
            text=f"Update Available: {remote_tag} (Current: {APP_VERSION})",
            font=("Segoe UI", 9, "bold"),
            fg="#FCD34D",
            bg="#0F172A"
        ).pack(anchor="w")

        tk.Label(
            msg_box,
            text="A newer version of the patcher & mod is available on GitHub.",
            font=("Segoe UI", 8),
            fg="#94A3B8",
            bg="#0F172A"
        ).pack(anchor="w")

        btn_box = tk.Frame(self.update_banner_frame, bg="#0F172A")
        btn_box.pack(side=tk.RIGHT)

        oui.OmegaButton(
            btn_box,
            text="Download Update",
            command=lambda: webbrowser.open(release_url),
            width=130,
            height=28,
            corner_radius=5,
            bg_color="#D97706",
            hover_color="#F59E0B",
            parent_bg="#0F172A",
            tooltip="Open GitHub Release page to download latest .exe or .zip"
        ).pack(side=tk.LEFT, padx=(0, 6))

        oui.OmegaButton(
            btn_box,
            text="Dismiss",
            command=self.update_banner_frame.destroy,
            width=65,
            height=28,
            corner_radius=5,
            bg_color="#1E293B",
            hover_color="#334155",
            parent_bg="#0F172A"
        ).pack(side=tk.LEFT)

    def _build_diagnostic_panel(self):
        # Outer diagnostic card
        outer = tk.Frame(self.container, bg=oui.Theme.PANEL, padx=14, pady=10)
        outer.pack(fill=tk.X, pady=(0, 10))

        # Header of diagnostic card
        top_row = tk.Frame(outer, bg=oui.Theme.PANEL)
        top_row.pack(fill=tk.X, pady=(0, 6))

        tk.Label(
            top_row,
            text="SYSTEM & INSTALLATION DIAGNOSTICS",
            font=("Segoe UI", 10, "bold"),
            fg=oui.Theme.ACCENT,
            bg=oui.Theme.PANEL
        ).pack(side=tk.LEFT)

        self.diag_indicator = tk.Label(
            top_row,
            text="● INITIALIZING",
            font=("Segoe UI", 9, "bold"),
            fg=oui.Theme.DISABLED,
            bg=oui.Theme.PANEL
        )
        self.diag_indicator.pack(side=tk.RIGHT)

        # Diagnostic items table
        grid = tk.Frame(outer, bg=oui.Theme.PANEL)
        grid.pack(fill=tk.X)
        grid.columnconfigure(1, weight=1)

        # 1. Game directory
        tk.Label(grid, text="Detected Directory:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=0, column=0, sticky="w", pady=2)
        self.diag_path_lbl = tk.Label(grid, text="", font=("Consolas", 8), fg="#94A3B8", bg=oui.Theme.PANEL, anchor="w")
        self.diag_path_lbl.grid(row=0, column=1, sticky="ew", padx=(10, 0), pady=2)

        # 2. Target File
        tk.Label(grid, text="Target Script:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=1, column=0, sticky="w", pady=2)
        self.diag_target_lbl = tk.Label(grid, text="data/ui/scripts/windows/loginwnd.lua", font=("Consolas", 8), fg="#94A3B8", bg=oui.Theme.PANEL, anchor="w")
        self.diag_target_lbl.grid(row=1, column=1, sticky="ew", padx=(10, 0), pady=2)
        self.diag_target_badge = tk.Label(grid, text="[ CHECKING ]", font=("Segoe UI", 8, "bold"), fg=oui.Theme.DISABLED, bg=oui.Theme.PANEL)
        self.diag_target_badge.grid(row=1, column=2, sticky="e", pady=2)

        # 3. Mod State
        tk.Label(grid, text="Mod State:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=2, column=0, sticky="w", pady=2)
        self.diag_mod_badge = tk.Label(grid, text="[ CHECKING ]", font=("Segoe UI", 8, "bold"), fg=oui.Theme.DISABLED, bg=oui.Theme.PANEL, anchor="w")
        self.diag_mod_badge.grid(row=2, column=1, sticky="w", padx=(10, 0), pady=2)

        # 4. Backup State
        tk.Label(grid, text="Original Backup:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=3, column=0, sticky="w", pady=2)
        self.diag_backup_badge = tk.Label(grid, text="[ CHECKING ]", font=("Segoe UI", 8, "bold"), fg=oui.Theme.DISABLED, bg=oui.Theme.PANEL, anchor="w")
        self.diag_backup_badge.grid(row=3, column=1, sticky="w", padx=(10, 0), pady=2)

    def _build_path_selector(self):
        card = tk.Frame(self.container, bg=oui.Theme.PANEL, padx=14, pady=10)
        card.pack(fill=tk.X, pady=(0, 10))

        tk.Label(
            card,
            text="Game Directory (Specify if running multiple game installations):",
            font=("Segoe UI", 9, "bold"),
            fg=oui.Theme.TEXT,
            bg=oui.Theme.PANEL
        ).pack(anchor="w", pady=(0, 6))

        row = tk.Frame(card, bg=oui.Theme.PANEL)
        row.pack(fill=tk.X)

        # Gear Icon Button placed BEFORE the installation path
        self.gear_btn = oui.OmegaButton(
            row,
            text="⚙ Browse",
            command=self.browse_directory,
            width=90,
            height=30,
            corner_radius=6,
            bg_color=oui.Theme.BTN,
            hover_color=oui.Theme.BTN_HOVER,
            parent_bg=oui.Theme.PANEL,
            tooltip="Browse and specify your Star Conflict game directory"
        )
        self.gear_btn.pack(side=tk.LEFT, padx=(0, 8))

        # Path Entry container with sleek dark border
        entry_wrap = tk.Frame(row, bg=oui.Theme.TITLE_BAR, padx=8, pady=3, highlightthickness=1, highlightbackground=oui.Theme.DISABLED)
        entry_wrap.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))

        self.path_entry = tk.Entry(
            entry_wrap,
            bg=oui.Theme.TITLE_BAR,
            fg=oui.Theme.TEXT,
            insertbackground=oui.Theme.ACCENT,
            relief=tk.FLAT,
            font=("Consolas", 9)
        )
        self.path_entry.pack(fill=tk.X, expand=True)
        self.path_entry.bind("<Return>", lambda e: self.on_path_entered())
        self.path_entry.bind("<FocusOut>", lambda e: self.on_path_entered())

        # Auto-rescan button
        self.rescan_btn = oui.OmegaButton(
            row,
            text="↻ Rescan",
            command=self.auto_detect,
            width=80,
            height=30,
            corner_radius=6,
            bg_color=oui.Theme.PANEL,
            hover_color=oui.Theme.BTN,
            border_width=1,
            border_color=oui.Theme.DISABLED,
            parent_bg=oui.Theme.PANEL,
            tooltip="Auto-detect game from Steam libraries and Windows registry"
        )
        self.rescan_btn.pack(side=tk.LEFT)

    def _build_action_section(self):
        self.action_frame = tk.Frame(self.container, bg=oui.Theme.BG)
        self.action_frame.pack(fill=tk.X, pady=(6, 6))

    def _build_status_banner(self):
        self.banner_frame = tk.Frame(self.container, bg=oui.Theme.PANEL, padx=12, pady=8, highlightthickness=1, highlightbackground="#1E293B")
        self.banner_frame.pack(fill=tk.X, pady=(4, 8))

        self.banner_lbl = tk.Label(
            self.banner_frame,
            text="Checking game environment...",
            font=("Segoe UI", 9),
            fg=oui.Theme.ACCENT,
            bg=oui.Theme.PANEL
        )
        self.banner_lbl.pack()

    def _build_credits(self):
        cred_frame = tk.Frame(self.container, bg=oui.Theme.BG)
        cred_frame.pack(fill=tk.X, pady=(2, 6))

        tk.Label(
            cred_frame,
            text="Created by Alan Hexfury and Gemini",
            font=("Segoe UI", 9, "bold"),
            fg=oui.Theme.TEXT,
            bg=oui.Theme.BG
        ).pack()

        tk.Label(
            cred_frame,
            text="Hexfury for UI development for the patcher interface and mod • Gemini for tracing back all function calls in the Star Conflict environment",
            font=("Segoe UI", 8),
            fg="#94A3B8",
            bg=oui.Theme.BG
        ).pack(pady=(1, 0))

    def _build_footer(self):
        footer = tk.Frame(self.container, bg=oui.Theme.BG)
        footer.pack(fill=tk.X, side=tk.BOTTOM, pady=(4, 0))

        # How does this work? button
        self.how_btn = oui.OmegaButton(
            footer,
            text="ℹ How does this work?",
            command=self.open_how_it_works,
            width=185,
            height=32,
            corner_radius=6,
            bg_color=oui.Theme.PANEL,
            hover_color=oui.Theme.BTN,
            border_width=1,
            border_color=oui.Theme.ACCENT,
            parent_bg=oui.Theme.BG,
            tooltip="Detailed documentation on mod architecture, safety protections, and safe modification"
        )
        self.how_btn.pack(side=tk.LEFT)

        # GitHub repository button
        self.github_btn = oui.OmegaButton(
            footer,
            text="★ GitHub",
            command=lambda: webbrowser.open(GITHUB_PROJECT_URL),
            width=90,
            height=32,
            corner_radius=6,
            bg_color=oui.Theme.PANEL,
            hover_color=oui.Theme.BTN,
            border_width=1,
            border_color=oui.Theme.ACCENT,
            parent_bg=oui.Theme.BG,
            tooltip="Visit project repository on GitHub for source code, releases, and updates"
        )
        self.github_btn.pack(side=tk.LEFT, padx=(10, 0))

        # Exit button
        self.exit_btn = oui.OmegaButton(
            footer,
            text="✕ Exit",
            command=self.root.destroy,
            width=75,
            height=32,
            corner_radius=6,
            bg_color=oui.Theme.PANEL,
            hover_color=oui.Theme.DANGER,
            parent_bg=oui.Theme.BG
        )
        self.exit_btn.pack(side=tk.RIGHT)

    def refresh_ui(self):
        self.status = check_status(self.game_dir)
        
        # 1. Update Path Entry if needed
        cur_entry = self.path_entry.get().strip()
        expected = self.game_dir or ""
        if cur_entry != expected:
            self.path_entry.delete(0, tk.END)
            self.path_entry.insert(0, expected)

        # 2. Update Diagnostics
        if self.game_dir:
            self.diag_path_lbl.config(text=self.game_dir, fg="#94A3B8")
        else:
            self.diag_path_lbl.config(text="Directory not detected. Click '⚙ Browse' to specify.", fg=oui.Theme.DANGER)

        if self.status["exists"]:
            self.diag_target_badge.config(text="[ FOUND ]", fg=oui.Theme.SUCCESS)
        else:
            self.diag_target_badge.config(text="[ NOT FOUND ]", fg=oui.Theme.DANGER)

        if self.status["installed"]:
            self.diag_mod_badge.config(text="● INSTALLED & ACTIVE", fg=oui.Theme.ACCENT)
        elif self.status["exists"]:
            self.diag_mod_badge.config(text="○ NOT INSTALLED", fg="#94A3B8")
        else:
            self.diag_mod_badge.config(text="✕ TARGET SCRIPT MISSING", fg=oui.Theme.DANGER)

        if self.status["has_backup"]:
            self.diag_backup_badge.config(text="● PRESERVED (loginwnd.lua.orig)", fg=oui.Theme.SUCCESS)
        elif self.status["exists"]:
            self.diag_backup_badge.config(text="○ NONE (Will auto-backup on first install)", fg="#64748B")
        else:
            self.diag_backup_badge.config(text="—", fg="#64748B")

        if self.status["installed"]:
            self.diag_indicator.config(text="● MOD ACTIVE", fg=oui.Theme.ACCENT)
        elif self.status["exists"]:
            self.diag_indicator.config(text="● READY TO INSTALL", fg=oui.Theme.SUCCESS)
        else:
            self.diag_indicator.config(text="● GAME NOT FOUND", fg=oui.Theme.DANGER)

        # 3. Rebuild Action Buttons
        for w in self.action_frame.winfo_children():
            w.destroy()

        if not self.game_dir or not self.status["exists"]:
            btn = oui.OmegaButton(
                self.action_frame,
                text="⚙ Browse to Locate Star Conflict Directory...",
                command=self.browse_directory,
                width=340,
                height=38,
                corner_radius=8,
                bg_color=oui.Theme.BTN,
                hover_color=oui.Theme.BTN_HOVER,
                parent_bg=oui.Theme.BG,
                tooltip="Select the folder where Star Conflict is installed"
            )
            btn.pack(pady=4)
        elif not self.status["installed"]:
            btn = oui.OmegaButton(
                self.action_frame,
                text="⚡ Install Server Selector Mod",
                command=self.do_install,
                width=290,
                height=40,
                corner_radius=8,
                bg_color=oui.Theme.SUCCESS,
                hover_color=oui.Theme.SUCCESS_HOVER,
                parent_bg=oui.Theme.BG,
                tooltip="Backs up original loginwnd.lua and installs community server selector"
            )
            btn.pack(pady=4)
        else:
            row = tk.Frame(self.action_frame, bg=oui.Theme.BG)
            row.pack(pady=2)

            update_btn = oui.OmegaButton(
                row,
                text="↻ Reinstall / Update Mod",
                command=self.do_install,
                width=210,
                height=38,
                corner_radius=8,
                bg_color=oui.Theme.BTN,
                hover_color=oui.Theme.BTN_HOVER,
                parent_bg=oui.Theme.BG,
                tooltip="Re-applies the latest server selector mod code cleanly"
            )
            update_btn.pack(side=tk.LEFT, padx=6)

            uninst_btn = oui.OmegaButton(
                row,
                text="↺ Uninstall Mod (Restore Original)",
                command=self.do_uninstall,
                width=270,
                height=38,
                corner_radius=8,
                bg_color=oui.Theme.DANGER,
                hover_color=oui.Theme.DANGER_HOVER,
                parent_bg=oui.Theme.BG,
                tooltip="Restores clean original loginwnd.lua from backup"
            )
            uninst_btn.pack(side=tk.LEFT, padx=6)

    def set_banner(self, text, color=None):
        if color is None:
            color = oui.Theme.ACCENT
        self.banner_lbl.config(text=text, fg=color)

    def browse_directory(self):
        initial = self.game_dir if self.game_dir and os.path.isdir(self.game_dir) else "C:/"
        selected = filedialog.askdirectory(
            title="Select Star Conflict Installation Directory",
            initialdir=initial
        )
        if selected:
            norm = normalize_game_dir(selected)
            if norm:
                self.game_dir = norm
                self.set_banner("✔ Star Conflict directory verified successfully!", oui.Theme.SUCCESS)
            else:
                self.game_dir = selected
                self.set_banner("⚠ Warning: loginwnd.lua not found in data/ui/scripts/windows/.", oui.Theme.DANGER)
            self.refresh_ui()

    def on_path_entered(self):
        entered = self.path_entry.get().strip()
        if not entered:
            return
        norm = normalize_game_dir(entered)
        if norm:
            self.game_dir = norm
            self.set_banner("✔ Game folder updated and verified.", oui.Theme.SUCCESS)
        else:
            self.game_dir = entered
            self.set_banner("⚠ Directory specified does not contain data/ui/scripts/windows/loginwnd.lua.", oui.Theme.DANGER)
        self.refresh_ui()

    def auto_detect(self):
        detected = detect_game_dir()
        if detected:
            self.game_dir = detected
            self.set_banner("✔ Game directory auto-detected successfully!", oui.Theme.SUCCESS)
        else:
            self.set_banner("✕ Could not auto-detect Star Conflict. Please use '⚙ Browse'.", oui.Theme.DANGER)
        self.refresh_ui()

    def do_install(self):
        if not self.game_dir:
            self.set_banner("✕ Please specify a valid Star Conflict installation directory first.", oui.Theme.DANGER)
            return

        success, msg = install_mod(self.game_dir)
        if success:
            self.set_banner("✔ " + msg, oui.Theme.SUCCESS)
        else:
            self.set_banner("✕ " + msg, oui.Theme.DANGER)
        self.refresh_ui()

    def do_uninstall(self):
        if not self.game_dir:
            self.set_banner("✕ Please specify a valid Star Conflict directory first.", oui.Theme.DANGER)
            return

        success, msg = uninstall_mod(self.game_dir)
        if success:
            self.set_banner("✔ " + msg, oui.Theme.SUCCESS)
        else:
            self.set_banner("✕ " + msg, oui.Theme.DANGER)
        self.refresh_ui()

    def open_how_it_works(self):
        if self.how_it_works_window and tk.Toplevel.winfo_exists(self.how_it_works_window):
            self.how_it_works_window.lift()
            self.how_it_works_window.focus_force()
            return

        hw = tk.Toplevel(self.root)
        self.how_it_works_window = hw
        hw.title("Star Conflict · How Does This Work? (Safety & Architecture)")
        hw.geometry(f"730x650+{self.root.winfo_x() + 15}+{self.root.winfo_y() + 5}")
        hw.configure(bg=oui.Theme.BG)
        hw.overrideredirect(True)
        hw.attributes('-topmost', True)

        # Outer border
        bdr = tk.Frame(hw, bg=oui.Theme.ACCENT, padx=1, pady=1)
        bdr.pack(fill=tk.BOTH, expand=True)

        # Title bar
        oui.OmegaTitleBar(
            bdr,
            title="Star Conflict · How Does This Work? (Safety & Architecture)",
            border_width=1,
            border_color=oui.Theme.ACCENT,
            icon_path=self.icon_path,
            on_close=hw.destroy
        )

        # Scrollable area
        scroll = oui.OmegaScrollFrame(bdr, bg_color=oui.Theme.BG)
        scroll.pack(fill=tk.BOTH, expand=True)
        body = scroll.inner_frame

        # Section helper
        def make_section(title, subtitle=None):
            sec_card = tk.Frame(body, bg=oui.Theme.PANEL, padx=16, pady=12)
            sec_card.pack(fill=tk.X, padx=18, pady=(12, 0))
            tk.Label(
                sec_card,
                text=title,
                font=("Segoe UI", 11, "bold"),
                fg=oui.Theme.ACCENT,
                bg=oui.Theme.PANEL
            ).pack(anchor="w")
            if subtitle:
                tk.Label(
                    sec_card,
                    text=subtitle,
                    font=("Segoe UI", 8),
                    fg="#94A3B8",
                    bg=oui.Theme.PANEL
                ).pack(anchor="w", pady=(1, 6))
            return sec_card

        def add_bullet(parent, heading, desc):
            row = tk.Frame(parent, bg=oui.Theme.PANEL)
            row.pack(fill=tk.X, pady=3)
            tk.Label(row, text="•", font=("Segoe UI", 10, "bold"), fg=oui.Theme.ACCENT, bg=oui.Theme.PANEL).pack(side=tk.LEFT, anchor="n", padx=(0, 6))
            text_box = tk.Frame(row, bg=oui.Theme.PANEL)
            text_box.pack(side=tk.LEFT, fill=tk.X, expand=True)
            tk.Label(text_box, text=heading, font=("Segoe UI", 9, "bold"), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL, justify="left").pack(anchor="w")
            tk.Label(text_box, text=desc, font=("Segoe UI", 8), fg="#CBD5E1", bg=oui.Theme.PANEL, wraplength=640, justify="left").pack(anchor="w")

        # 1. Safety
        s1 = make_section("1 · USER SAFETY & CLIENT INTEGRITY (FIRST PRIORITY)", "Engine-safe client modifications designed for zero risk")
        add_bullet(
            s1,
            "Zero Executable or Binary Modifications",
            "This patcher NEVER touches game executables (game.exe), engine DLLs, memory, or network protocols. It operates strictly on the client-side plaintext script data/ui/scripts/windows/loginwnd.lua."
        )
        add_bullet(
            s1,
            "Automatic Clean Backup Protection",
            "Before modifying a single byte, the patcher copies your untouched original loginwnd.lua to loginwnd.lua.orig. If a clean backup already exists, it is permanently preserved."
        )
        add_bullet(
            s1,
            "Strict Boundary Isolation",
            "All injected mod code is enclosed between explicit markers (-- BEGIN STAR CONFLICT SERVER SELECTOR MOD and -- END ...). No other game routines or assets are altered."
        )
        add_bullet(
            s1,
            "Complete One-Click Restoration",
            "Clicking 'Uninstall Mod' instantly restores the untouched loginwnd.lua.orig backup back over loginwnd.lua, leaving zero residual traces."
        )

        # 2. How it works
        s2 = make_section("2 · HOW THE MOD WORKS UNDER THE HOOD", "Reverse-engineered UI hooks and multi-server architecture")
        add_bullet(
            s2,
            "Dropdown Server Selector Overhaul",
            "Hooks into UI.LoginWnd:Init() and UI.LoginWnd:UpdateForData(). Expands UI.Login_ServersComboBox.MAX_VISIBLE_RECORDS to 8 and repurposes the native server combobox to display Localhost and all saved community servers in a unified list."
        )
        add_bullet(
            s2,
            "Streamlined Interface & Decluttering",
            "Automatically detects when a saved server or localhost is selected and hides redundant server name and port textboxes, eliminating overlapping text fields and old remnants."
        )
        add_bullet(
            s2,
            "Multi-Server Persistence Engine",
            "Saves server configurations directly using the engine's built-in GetProfileTable() with a resilient disk fallback to saved_servers.cfg in your Star Conflict user profile directory. Your servers survive game updates."
        )
        add_bullet(
            s2,
            "Right-Click Context Menu",
            "Hooks UI.ContextMenu_SlotWnd to provide a context menu on saved servers. Right-click any server to 'Set as Default' or 'Delete Server'."
        )
        add_bullet(
            s2,
            "Default Auto-Selection (No Auto-Join)",
            "On game startup, the mod automatically selects your chosen default server. It never auto-joins; the pilot retains full control to review credentials and hit [Play] manually."
        )

        # 3. Community encouragement
        s3 = make_section("3 · COMMUNITY MODDING & OPEN ARCHITECTURE", "An open invitation to explore, learn, and build together")
        add_bullet(
            s3,
            "Encouragement to Explore & Modify",
            "Now that community servers are alive, Star Conflict's Lua environment offers huge potential for custom UI modding, HUD enhancements, and diagnostic tools. You are encouraged to inspect server_selector_mod.lua and tailor it to your needs!"
        )

        # 4. Attribution
        s4 = make_section("4 · DEVELOPER ATTRIBUTION & CREDITS", "Created by Alan Hexfury and Gemini")
        add_bullet(
            s4,
            "Alan Hexfury",
            "UI development and UX design for the patcher interface and community server selector mod."
        )
        add_bullet(
            s4,
            "Gemini",
            "Static and dynamic reverse-engineering, Lua decompilation analysis, and tracing engine function calls in the Star Conflict environment."
        )

        # 5. Open Source Repository
        s5 = make_section("5 • OPEN SOURCE REPOSITORY & RELEASES", "Source code, release downloads, and issue tracker")
        add_bullet(
            s5,
            "GitHub Repository",
            f"Hosted at: {GITHUB_PROJECT_URL}\nReleases provide standalone .exe and portable .zip distributions. Feel free to inspect, star, submit issues, or fork!"
        )
        gh_btn_frame = tk.Frame(s5, bg=oui.Theme.PANEL)
        gh_btn_frame.pack(fill=tk.X, pady=(6, 2))
        oui.OmegaButton(
            gh_btn_frame,
            text="★ Open GitHub Repository in Browser",
            command=lambda: webbrowser.open(GITHUB_PROJECT_URL),
            width=260,
            height=30,
            corner_radius=6,
            bg_color=oui.Theme.BTN,
            hover_color=oui.Theme.BTN_HOVER,
            parent_bg=oui.Theme.PANEL
        ).pack(anchor="w")

        # Close button at bottom of dialog
        close_frame = tk.Frame(body, bg=oui.Theme.BG)
        close_frame.pack(fill=tk.X, padx=18, pady=16)

        close_btn = oui.OmegaButton(
            close_frame,
            text="✕ Close Window",
            command=hw.destroy,
            width=140,
            height=32,
            corner_radius=6,
            bg_color=oui.Theme.PANEL,
            hover_color=oui.Theme.BTN,
            border_width=1,
            border_color=oui.Theme.ACCENT,
            parent_bg=oui.Theme.BG
        )
        close_btn.pack(side=tk.RIGHT)


def main():
    app = StarConflictPatcherApp()
    app.root.mainloop()

if __name__ == "__main__":
    main()

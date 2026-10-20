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

APP_VERSION = "v1.2.0"
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

EMBEDDED_MOD_LUA = r"""-- ============================================================================
-- Star Conflict Server Selector Mod
-- Server Panel for the login screen, built from the game's own login widgets
-- Features:
--   * Server panel drawn like the native drop-down field (black fill + 1px #383C41
--     hairline), header line in the login screen's own label palette and fonts
--   * 3 Action Buttons (Add / Save, Set Default, Delete) built on the native
--     login_simpleBtn effect (idle / over / press / select / disable), scaled to
--     their slot with effect:SetScale like chatwnd.lua does
--   * Native Tooltips (EffectButtonWnd:SetTooltipData -> UI.tooltipTypes.TEXT_LARGE)
--   * Native Color-Coded ComboBox1 Records (data.color)
--   * Layout authored in the login screen's 1280x720 .sanim space so it scales with
--     the native controls (720p / 1080p / 1440p / 4K)
--   * Auto-Hide Underlying Controls When Dropdown List Expands
--   * Right-Click Context Menu & Profile Persistence (.prfl via GetProfileTable / Profile:Save)
--     (the game's Lua has no io library, so there is no file-based fallback)
-- Version 1.3.0
-- ============================================================================

-- Visible records in the dropdown before vertical scrollbar activates (fits 720p to 4K cleanly)
if UI.Login_ServersComboBox then
	UI.Login_ServersComboBox.MAX_VISIBLE_RECORDS = 6
end

-- ----------------------------------------------------------------------------
-- Native login screen palette & metrics
-- Colors are taken from the login .sanim files (login_main, drop_down_input,
-- drop_down_list, login_univer_btn); metrics are in login_main's base_res space.
-- ----------------------------------------------------------------------------
local SS_STYLE =
{
	LOGIN_RES      = { x = 1280, y = 720 },

	COL_LABEL      = 0xFFCCCCCC,	-- login_main "status_server" / "version"
	COL_LIST_TEXT  = 0xFF88B5FF,	-- drop_down_list "line_N"
	COL_DIM        = 0xFF878787,	-- drop_down_input "simple_color"
	COL_GOLD       = 0xFFFFD200,	-- login_univer_btn "color_1"
	COL_WARNING    = 0xFFFF9100,	-- login_main "warning"
	COL_WHITE      = 0xFFFFFFFF,
	COL_PLATE      = 0xE6000000,	-- drop-down field fill (black)
	COL_BORDER     = 0xFF383C41,	-- drop-down field 1px hairline
	COL_BORDER_ACT = 0xFF6A93B5,	-- drop_down_input "select_color"

	BTN_EFFECT     = "login_simpleBtn",	-- login_univer_btn.sanim (Options / Start Server)
	HEADER_FONT    = "VerySmall",

	PAD_X          = 8,
	PAD_TOP        = 4,
	PAD_BOTTOM     = 8,
	HEADER_H       = 22,
	GAP_COMBO      = 8,
	GAP_BTN        = 6,
	GAP_ROW        = 8,
	BTN_ADD_W      = 84,
	BTN_DEFAULT_W  = 104,
	BTN_DELETE_W   = 84,

	-- login_univer_btn.sanim is authored 135x24 (aspect ~5.6); a measured size outside
	-- this band is a not-yet-initialised effect and is ignored until the next frame
	BTN_ASPECT_MIN = 3,
	BTN_ASPECT_MAX = 12,
	-- Hard limits so a bad measurement can never blow a button up over the screen
	BTN_SCALE_MIN  = 0.25,
	BTN_SCALE_MAX  = 2.5,
}

-- Layer count of the EffectButtonWnd base (MAIN_EFFECT + DEBUG), same as loginwnd's l_effectBtnNumLayers
local SS_BTN_BASE_LAYERS = UI:GetTableLength( UI.EffectButtonWnd.layers )

local function SX( v )
	return UI:XTo1024x768( v, SS_STYLE.LOGIN_RES )
end

local function SY( v )
	return UI:YTo1024x768( v, SS_STYLE.LOGIN_RES )
end

-- ----------------------------------------------------------------------------
-- Safe Font Resolver Helper
-- Eliminates Lua colon syntax pitfalls; falls back to "Small" if the pattern is unknown
-- ----------------------------------------------------------------------------
local function SafeGetFont( fontName )
	local names = { fontName or "Small", "Small" }
	for _, name in ipairs( names ) do
		if UI and UI.GetFontByPatternName then
			local h = UI:GetFontByPatternName( name )
			if h and h ~= FONT.INVALID_FONT_HANDLE then
				return h
			end
		end
		if _G and _G.ObtainFont then
			local h = _G.ObtainFont( name )
			if h and h ~= FONT.INVALID_FONT_HANDLE then
				return h
			end
		end
	end
	return FONT.INVALID_FONT_HANDLE
end

local function MeasureTextW( str, hFont )
	if _G.MeasureText and str and str ~= "" and hFont then
		local dummyRect = UI:Quat( 0, 0, 10000, 10000 )
		local res = _G.MeasureText( str, hFont, dummyRect, FONT.TF_SINGLELINE + FONT.TF_NOCLIP, dummyRect )
		if res and res.z and res.z > 0 then
			return res.z
		end
	end
	return SX( string.len( str or "" ) * 6 )
end

-- ----------------------------------------------------------------------------
-- Action Buttons (Add / Save, Set Default, Delete)
-- Built on the native Login_Btn layers / login_simpleBtn effect so they share the look, animations
-- and hover sound of the login screen's Options / Start Server / Forgot buttons.
-- ----------------------------------------------------------------------------

-- Per-instance effectInfo tables (never mutate the shared Login_Btn table)
local SS_BTN_ANIMS_NORMAL =
{
	main =
	{
		animationIdle     = "idle",
		animationSelect   = "over",
		animationPressed  = "press",
		animationDisabled = "disable",
	},
}

-- "Toggled" look for an active state (e.g. the selected server is already the default)
local SS_BTN_ANIMS_TOGGLED =
{
	main =
	{
		animationIdle     = "select",
		animationSelect   = "over_select",
		animationPressed  = "press",
		animationDisabled = "disable",
	},
}

local function CreateServerActionBtnTable( wndName, defaultLabel )
	-- Same layers as the native Login_Btn, minus its "self" SIZE link: that link makes
	-- the window adopt the effect's authored 135x24 size, so the buttons could not be
	-- sized to fit beside the dropdown. FitEffectToSize scales the effect instead.
	local t =
	{
		def =
		{
			className = "ButtonWnd",
			prototype = "EffectButtonWnd",

			props =
			{
				name        = wndName,
				selectSound = UI.LoginWnd.sounds and UI.LoginWnd.sounds.btnMouseOver or "",
				clickSound  = "",	-- actions play their own confirm / cancel sounds
			},

			layers =
			{
				numLayers = SS_BTN_BASE_LAYERS + 1,

				-- MAIN_EFFECT
				{
					layerType  = UI.LAYER_EFFECT,
					layerStyle = UI.WLS_RESIZABLE,
					main       = true,

					effects =
					{{
						defName          = SS_STYLE.BTN_EFFECT,
						defaultAnimation = "idle",

						links =
						{
							{
								objName    = "value",
								layer      = "UI." .. wndName .. ".layers.TEXT",
								animParams = UI.EffectAnimParams.SIZE + UI.EffectAnimParams.POS + UI.EffectAnimParams.ALIGNMENT + UI.EffectAnimParams.COLOR + UI.EffectAnimParams.ALPHA + UI.EffectAnimParams.FONT + UI.EffectAnimParams.BLEND,
							},
						}
					}}
				},

				-- TEXT
				{
					id = SS_BTN_BASE_LAYERS,

					layerType    = UI.LAYER_TEXT,
					formatInfoSz = { 1, 1 },
					formatFlags  = FONT.TF_NOCLIP + FONT.TF_SINGLELINE,
					font         = { fontName = "Small" },
				},
			},
		},

		layers =
		{
			MAIN_EFFECT = 0,
			DEBUG       = 1,
			TEXT        = SS_BTN_BASE_LAYERS,
		},

		effectInfo       = SS_BTN_ANIMS_NORMAL,
		buttonText       = defaultLabel,
		baseSize         = nil,
		isActionDisabled = false,
		isToggled        = false,
	}

	function t:F_PostLoad()
		if UI.EffectButtonWnd and UI.EffectButtonWnd.F_PostLoad then
			UI.EffectButtonWnd.F_PostLoad( self )
		end
		-- Do not measure the effect here: right after creation it can still report a
		-- placeholder size, which made the buttons scale up to cover the login screen.
		self.baseSize = nil
		self:SetBtnText( self.buttonText or defaultLabel )
	end

	-- Measures the effect's authored size, accepting only a button-shaped answer.
	-- Must return a fresh table { x, y }, NOT UI:Vec2(...): UI:Vec2 hands out one of
	-- 20 ring-buffered scratch userdata in UI.tempBufs.bufV2, which wraps around after
	-- 20 calls anywhere in the UI and overwrites stored references in place.
	function t:MeasureEffectBase( effect )
		local size = effect:GetObjSize( "self" )
		if not size or not size.x or not size.y or size.x <= 0 or size.y <= 0 then
			return nil
		end
		-- Rel units are anisotropic and the engine's .sanim unit conversion is not
		-- documented, so accept the size if either its pixel or its Rel aspect looks
		-- like the authored button; a square placeholder fails both
		local pxW = size.x * UI.rel2Abs_x
		local pxH = size.y * UI.rel2Abs_y
		local function IsButtonAspect( a )
			return a >= SS_STYLE.BTN_ASPECT_MIN and a <= SS_STYLE.BTN_ASPECT_MAX
		end
		if pxH < 8 or not ( IsButtonAspect( pxW / pxH ) or IsButtonAspect( size.x / size.y ) ) then
			return nil
		end
		return { x = size.x, y = size.y }
	end

	-- Stretches the native effect to the window. Safe to call every frame: it
	-- re-measures until the effect reports a sane size, clamps the scale, and only
	-- touches the effect when the scale actually differs.
	function t:UpdateEffectScale()
		local effect = UI:GetEffectFromLayer( self, self.layers.MAIN_EFFECT )
		if not effect then
			return
		end
		if not self.baseSize then
			self.baseSize = self:MeasureEffectBase( effect )
			if not self.baseSize then
				return
			end
		end

		local function Clamp( v )
			return math.max( SS_STYLE.BTN_SCALE_MIN, math.min( SS_STYLE.BTN_SCALE_MAX, v ) )
		end
		local sx = Clamp( self:GetWidth() / self.baseSize.x )
		local sy = Clamp( self:GetHeight() / self.baseSize.y )

		local cur = effect:GetScale()
		if not cur or math.abs( cur.x - sx ) > 0.001 or math.abs( cur.y - sy ) > 0.001 then
			effect:SetScale( UI:Vec2( sx, sy ) )
		end
	end

	function t:F_Draw( x0, y0, width, height, clipX0, clipY0, clipWidth, clipHeight )
		pcall( self.UpdateEffectScale, self )
		self:Draw( UI:Quat( x0, y0, width, height ), UI:Quat( clipX0, clipY0, clipWidth, clipHeight ) )
	end

	-- Sets the window rect; the effect follows via UpdateEffectScale
	function t:SetFrameRect( left, top, width, height )
		self:SetLeft( left )
		self:SetTop( top )
		self:SetWidth( width )
		self:SetHeight( height )
		self:UpdateEffectScale()
	end

	function t:SetBtnText( str )
		self.buttonText = str or ""
		if self.w and self.SetText and self.layers and self.layers.TEXT then
			self:SetText( self.buttonText, self.layers.TEXT )
		end
	end

	-- Applies label, enabled/toggled state and tooltip in one go.
	-- Disabled buttons use WS_GRAYED (not WS_DISABLE) so they stay hoverable
	-- and can still explain themselves through the tooltip.
	function t:ApplyActionState( label, bDisabled, bToggled, caption, tooltip )
		self:SetBtnText( label )

		self.isActionDisabled = bDisabled and true or false
		self.isToggled        = (bToggled and not bDisabled) and true or false
		self.effectInfo       = self.isToggled and SS_BTN_ANIMS_TOGGLED or SS_BTN_ANIMS_NORMAL

		if self.w then
			if self.isActionDisabled then
				self:AddStyle( UI.WS_GRAYED )
			else
				self:RemoveStyle( UI.WS_GRAYED )
			end
			if self.UpdateEffectAnimation then
				self:UpdateEffectAnimation()
			end
		end

		if UI.tooltipTypes and UI.tooltipTypes.TEXT_LARGE and tooltip and tooltip ~= "" then
			self.tooltipData =
			{
				tooltipType = UI.tooltipTypes.TEXT_LARGE,	-- field name used by the game's tooltip code
				caption   = caption or "Server Selector",
				text      = tooltip,
			}
		else
			self.tooltipData = nil
		end
	end

	return t
end

UI.Login_AddServerBtn     = CreateServerActionBtnTable( "Login_AddServerBtn",     "Add" )
UI.Login_DefaultServerBtn = CreateServerActionBtnTable( "Login_DefaultServerBtn", "Set Default" )
UI.Login_DeleteServerBtn  = CreateServerActionBtnTable( "Login_DeleteServerBtn",  "Delete" )

-- ----------------------------------------------------------------------------
-- Server Panel (UI.Login_ServerDockWnd)
-- Drawn like the native drop-down field: black fill + 1px #383C41 hairline
-- (Targem's own DrawFocusFrame pattern from effecttreepreviewwnd.lua), so the
-- border stays 1 physical pixel at any panel size and resolution.
-- Header: "Server | <status> | N saved" in the login label palette
-- ----------------------------------------------------------------------------
UI.Login_ServerDockWnd =
{
	def =
	{
		className = "Wnd",
		props =
		{
			name  = "Login_ServerDockWnd",
			style = UI.WS_NOT_MOUSE_REACT + UI.WS_NOT_KB_REACT,
		},
		layers =
		{
			-- 0: Field fill
			{
				layerType  = UI.LAYER_TEXTURE,
				layerStyle = UI.WLS_RESIZABLE,
				texture    = "white",
				color      = SS_STYLE.COL_PLATE,
			},
			-- 1: Owner-drawn hairline border + header line
			{
				layerType    = UI.LAYER_TEXT,
				layerStyle   = UI.WLS_OWNERDRAW + UI.WLS_RESIZABLE,
				font         = { fontName = SS_STYLE.HEADER_FONT },
				formatFlags  = FONT.TF_LEFT + FONT.TF_VCENTER + FONT.TF_SINGLELINE + FONT.TF_NOCLIP,
				formatInfoSz = { 1, 1 },
				color        = SS_STYLE.COL_LABEL,
			},
		},
	},
	layers =
	{
		PLATE   = 0,
		OVERLAY = 1,
	},
	headerTitle  = "Server",
	statusText   = "Localhost",
	statusColor  = SS_STYLE.COL_LABEL,
	countText    = "",
	isCustomOpen = false,
}

function UI.Login_ServerDockWnd:UpdateHeaderTelemetry( selServer, isDefault, savedCount, bShowServerFields )
	-- Border lights up in the native selection blue while the custom endpoint fields are open
	self.isCustomOpen = bShowServerFields and true or false

	if bShowServerFields or (selServer and selServer.isCustom) then
		self.statusText  = "Custom"
		self.statusColor = SS_STYLE.COL_WARNING
	elseif isDefault then
		self.statusText  = "Default"
		self.statusColor = SS_STYLE.COL_GOLD
	elseif selServer and selServer.isSaved then
		self.statusText  = "Saved"
		self.statusColor = SS_STYLE.COL_LIST_TEXT
	else
		self.statusText  = "Localhost"
		self.statusColor = SS_STYLE.COL_LABEL
	end

	self.countText = string.format( "%d saved", savedCount or 0 )
end

function UI.Login_ServerDockWnd:F_DrawLayer( x0, y0, width, height, clipX0, clipY0, clipW, clipH, layerIdx )
	if layerIdx ~= self.layers.OVERLAY then
		return
	end

	pcall(function()
		local layerAlpha = ( UI.GetAlpha and UI:GetAlpha( self:GetColor( self.layers.OVERLAY ) ) or 255 ) / 255
		if layerAlpha <= 0 then
			return
		end
		local function ApplyAlpha( c )
			if layerAlpha >= 0.999 or not UI.GetAlpha or not UI.SetAlpha then
				return c
			end
			return UI:SetAlpha( c, math.floor( UI:GetAlpha( c ) * layerAlpha + 0.5 ) )
		end

		-- 1. 1px hairline border
		local hTex = UI:GetTex( "white" )
		if UI.drawer and UI.drawer.DrawImagedRect and hTex and hTex ~= UI.INVALID_RESOURCE_HANDLE then
			local px  = UI:XToRel( 1 )
			local py  = UI:YToRel( 1 )
			local col = ApplyAlpha( self.isCustomOpen and SS_STYLE.COL_BORDER_ACT or SS_STYLE.COL_BORDER )

			UI.drawer:DrawImagedRect( x0, y0, width, py, clipX0, clipY0, clipW, clipH, hTex, col, 0, 0, 1, 1, false )
			UI.drawer:DrawImagedRect( x0, y0 + height - py, width, py, clipX0, clipY0, clipW, clipH, hTex, col, 0, 0, 1, 1, false )
			UI.drawer:DrawImagedRect( x0, y0 + py, px, height - py * 2, clipX0, clipY0, clipW, clipH, hTex, col, 0, 0, 1, 1, false )
			UI.drawer:DrawImagedRect( x0 + width - px, y0 + py, px, height - py * 2, clipX0, clipY0, clipW, clipH, hTex, col, 0, 0, 1, 1, false )
		end

		-- 2. Header line
		if not _G.UI_DrawText then
			return
		end
		local hFont = SafeGetFont( SS_STYLE.HEADER_FONT )
		if not hFont or hFont == FONT.INVALID_FONT_HANDLE then
			return
		end

		local flags = FONT.TF_LEFT + FONT.TF_VCENTER + FONT.TF_SINGLELINE + FONT.TF_NOCLIP
		local lineY = y0 + SY( SS_STYLE.PAD_TOP )
		local lineH = SY( SS_STYLE.HEADER_H - SS_STYLE.PAD_TOP * 2 )
		local gapX  = SX( 6 )
		local x     = x0 + SX( SS_STYLE.PAD_X )

		local parts =
		{
			{ self.headerTitle or "Server", SS_STYLE.COL_LABEL },
			{ "|",                          SS_STYLE.COL_DIM },
			{ self.statusText or "",        self.statusColor or SS_STYLE.COL_LABEL },
		}
		if self.countText and self.countText ~= "" then
			table.insert( parts, { "|",            SS_STYLE.COL_DIM } )
			table.insert( parts, { self.countText, SS_STYLE.COL_DIM } )
		end

		UI.drawer:EndUiDrawing()
		for _, part in ipairs( parts ) do
			local str = part[1]
			if str ~= "" then
				local w = MeasureTextW( str, hFont )
				_G.UI_DrawText( str, hFont, UI:Quat( x, lineY, w, lineH ), ApplyAlpha( part[2] ), 0, flags, UI:Quat( clipX0, clipY0, clipW, clipH ) )
				x = x + w + gapX
			end
		end
		UI.drawer:BeginUiDrawing()
	end)
end

-- ----------------------------------------------------------------------------
-- Context Menu, Slot & Dropdown State Hook Lazy Initializers
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

local l_comboStateHookInstalled = false
function UI.LoginWnd:EnsureComboStateHook()
	if l_comboStateHookInstalled or not UI.Login_ServersComboBox then
		return
	end

	local orig_SetState = UI.Login_ServersComboBox.SetState
	if orig_SetState then
		UI.Login_ServersComboBox.SetState = function( comboSelf, state, bForce )
			orig_SetState( comboSelf, state, bForce )
			if UI.LoginWnd and UI.LoginWnd.SyncDropdownOverlapVisibility then
				UI.LoginWnd:SyncDropdownOverlapVisibility()
			end
		end
		l_comboStateHookInstalled = true
	end
end

-- Hides underlying edit boxes & patch label while the combobox list popup is open
function UI.LoginWnd:SyncDropdownOverlapVisibility()
	pcall(function()
		if not UI.Login_ServersComboBox or not UI.Login_ServersComboBox.IsOpen then
			return
		end
		local bOpen = UI.Login_ServersComboBox:IsOpen()
		local hideFlags = UI.WS_NOT_DRAW + UI.WS_NOT_MOUSE_REACT

		if UI.Login_ServerNameEditWnd and UI.Login_ServerNameEditWnd.w then
			if bOpen then
				UI.Login_ServerNameEditWnd:AddStyle( hideFlags )
			else
				UI.Login_ServerNameEditWnd:RemoveStyle( hideFlags )
			end
		end

		if UI.Login_ServerPortEditWnd and UI.Login_ServerPortEditWnd.w then
			if bOpen then
				UI.Login_ServerPortEditWnd:AddStyle( hideFlags )
			else
				UI.Login_ServerPortEditWnd:RemoveStyle( hideFlags )
			end
		end

		if self.SetLayerVisible and self.layers and self.layers.PATCH_NAME then
			self:SetLayerVisible( not bOpen, self.layers.PATCH_NAME )
		end
	end)
end

-- ----------------------------------------------------------------------------
-- Server Dock & Action Buttons Instantiation + Resolution-Adaptive Layout
-- ----------------------------------------------------------------------------
function UI.LoginWnd:EnsureServerDockControls()
	pcall(function()
		local function EnsureSingleWnd( tableKey )
			local wnd = UI[ tableKey ]
			if not wnd or not wnd.w or not wnd.IsChildOf then
				if UI.CreateWndFromTable then
					local created = UI:CreateWndFromTable( "UI." .. tableKey )
					if created then
						UI[ tableKey ] = created
						wnd = created
					end
				end
			end
			if wnd and wnd.IsChildOf and not wnd:IsChildOf( self ) then
				self:AddChild( wnd )
			end
			return wnd
		end

		EnsureSingleWnd( "Login_ServerDockWnd" )
		EnsureSingleWnd( "Login_AddServerBtn" )
		EnsureSingleWnd( "Login_DefaultServerBtn" )
		EnsureSingleWnd( "Login_DeleteServerBtn" )

		self:UpdateServerDockLayout()
	end)
end

-- Keep backward-compatible alias in case external hooks call EnsureAddServerBtn / UpdateAddServerBtnPos
function UI.LoginWnd:EnsureAddServerBtn()
	self:EnsureServerDockControls()
end

function UI.LoginWnd:UpdateAddServerBtnPos()
	self:UpdateServerDockLayout()
end

function UI.LoginWnd:UpdateServerDockLayout()
	pcall(function()
		if not self:NeedServersComboBox() then
			return
		end

		if not UI.Login_AddServerBtn or not UI.Login_AddServerBtn.w or not UI.Login_AddServerBtn:IsChildOf( self ) then
			return
		end

		local function IsLinked( t )
			return t and t.w and t.IsChildOf and t:IsChildOf( self )
		end

		-- 1. Query exact combobox origin & closed bar dimensions via stateBtn
		local comboLeft = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetLeft and UI.Login_ServersComboBox:GetLeft()
		local comboTop  = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetTop and UI.Login_ServersComboBox:GetTop()

		-- Fallback: drop_down_main locator in login_main.sanim
		if not comboLeft or comboLeft <= 0 then
			comboLeft = SX( 14 )
		end
		if not comboTop or comboTop <= 0 then
			comboTop = SY( 587 )
		end

		local stateBtn  = UI.Login_ServersComboBox and UI.Login_ServersComboBox.stateBtn
		local barWidth  = stateBtn and stateBtn.GetWidth and stateBtn:GetWidth()
		local barHeight = stateBtn and stateBtn.GetHeight and stateBtn:GetHeight()

		-- Fallback: drop_down_input is 258x25 in login space
		if not barWidth or barWidth < 50 or barWidth > 400 then
			barWidth = SX( 258 )
		end
		if not barHeight or barHeight < 10 or barHeight > 60 then
			barHeight = SY( 25 )
		end

		-- 2. Action buttons on the dropdown row, same height as the dropdown bar
		local buttons =
		{
			{ UI.Login_AddServerBtn,     SX( SS_STYLE.BTN_ADD_W ) },
			{ UI.Login_DefaultServerBtn, SX( SS_STYLE.BTN_DEFAULT_W ) },
			{ UI.Login_DeleteServerBtn,  SX( SS_STYLE.BTN_DELETE_W ) },
		}

		local btnLeft   = comboLeft + barWidth + SX( SS_STYLE.GAP_COMBO )
		local rightEdge = comboLeft + barWidth
		for _, entry in ipairs( buttons ) do
			local btn, btnWidth = entry[1], entry[2]
			if IsLinked( btn ) then
				btn:SetFrameRect( btnLeft, comboTop, btnWidth, barHeight )
				rightEdge = btnLeft + btnWidth
				btnLeft   = rightEdge + SX( SS_STYLE.GAP_BTN )
			end
		end

		-- 3. Custom endpoint row (host + port) under the dropdown
		local rowBottom = comboTop + barHeight

		if IsLinked( UI.Login_ServerNameEditWnd ) then
			local snLeft   = comboLeft
			local snTop    = comboTop + barHeight + SY( SS_STYLE.GAP_ROW )
			local snWidth  = UI.Login_ServerNameEditWnd:GetWidth()
			local snHeight = UI.Login_ServerNameEditWnd:GetHeight()

			if not snWidth or snWidth <= 20 then
				snWidth = barWidth
			end
			if not snHeight or snHeight <= 8 then
				snHeight = barHeight
			end

			UI.Login_ServerNameEditWnd:SetLeft( snLeft )
			UI.Login_ServerNameEditWnd:SetTop( snTop )

			if IsLinked( UI.Login_ServerPortEditWnd ) then
				local spLeft = math.max( comboLeft + barWidth + SX( SS_STYLE.GAP_COMBO ), snLeft + snWidth + SX( SS_STYLE.GAP_COMBO ) )
				UI.Login_ServerPortEditWnd:SetLeft( spLeft )
				UI.Login_ServerPortEditWnd:SetTop( snTop )
				rightEdge = math.max( rightEdge, spLeft + (UI.Login_ServerPortEditWnd:GetWidth() or 0) )
			end

			rowBottom = snTop + snHeight
		end

		-- 4. Size the server panel around header + controls
		if IsLinked( UI.Login_ServerDockWnd ) then
			local dockLeft   = math.max( SX( 2 ), comboLeft - SX( SS_STYLE.PAD_X ) )
			local dockTop    = math.max( SY( 2 ), comboTop - SY( SS_STYLE.HEADER_H ) )
			local dockWidth  = (rightEdge + SX( SS_STYLE.PAD_X )) - dockLeft
			local dockHeight = (rowBottom + SY( SS_STYLE.PAD_BOTTOM )) - dockTop

			UI.Login_ServerDockWnd:SetLeft( dockLeft )
			UI.Login_ServerDockWnd:SetTop( dockTop )
			UI.Login_ServerDockWnd:SetWidth( dockWidth )
			UI.Login_ServerDockWnd:SetHeight( dockHeight )

			-- Keep the panel strictly behind all controls (first position in child list)
			-- and chain the controls in front of it: Panel -> ComboBox -> Buttons -> Edit fields
			self:MoveChildToFirstPosition( UI.Login_ServerDockWnd )
			local prevWnd = UI.Login_ServerDockWnd
			local chain =
			{
				UI.Login_ServersComboBox,
				UI.Login_AddServerBtn,
				UI.Login_DefaultServerBtn,
				UI.Login_DeleteServerBtn,
				UI.Login_ServerNameEditWnd,
				UI.Login_ServerPortEditWnd,
			}
			for _, wnd in ipairs( chain ) do
				if IsLinked( wnd ) then
					self:MoveChildAfter( wnd, prevWnd )
					prevWnd = wnd
				end
			end
		end

		-- 5. Sync button labels, states, tooltips, and panel header
		self:SyncServerActionStates()
		self:SyncDropdownOverlapVisibility()

		if self.UpdateZOrder then
			self:UpdateZOrder()
		end
	end)
end

function UI.LoginWnd:SyncServerActionStates()
	pcall(function()
		local selRecordIdx = UI.Login_ServersComboBox and UI.Login_ServersComboBox.GetSelectedRecord and UI.Login_ServersComboBox:GetSelectedRecord() or 1
		local selServer = self.servers and self.servers[ selRecordIdx ]
		local bShowServerFields = self:NeedServersComboBox() and selServer and (selServer.isCustom or selServer.name == "server")

		local defAddr = self.defaultServerAddress
		local isCurrentDefault = false
		if selServer then
			if selServer.isLocalhost then
				isCurrentDefault = (defAddr == "localhost" or defAddr == nil or defAddr == "")
			elseif selServer.isSaved then
				isCurrentDefault = (defAddr ~= nil and string.lower( defAddr ) == string.lower( selServer.fullAddress or "" ))
			end
		end

		-- 1. Add / Save
		if UI.Login_AddServerBtn and UI.Login_AddServerBtn.ApplyActionState then
			if bShowServerFields then
				UI.Login_AddServerBtn:ApplyActionState( "Save", false, false,
					"Save Community Server",
					"Save the entered Host/IP and Port to your persistent server list and select it immediately." )
			else
				UI.Login_AddServerBtn:ApplyActionState( "Add", false, false,
					"Add New Server",
					"Open the custom server fields to enter and save a new community server IP:Port." )
			end
		end

		-- 2. Set Default / Default
		if UI.Login_DefaultServerBtn and UI.Login_DefaultServerBtn.ApplyActionState then
			if bShowServerFields then
				UI.Login_DefaultServerBtn:ApplyActionState( "Set Default", true, false,
					"Set Default Server",
					"Save this custom server first to mark it as your auto-selected default server." )
			elseif isCurrentDefault then
				UI.Login_DefaultServerBtn:ApplyActionState( "Default", false, true,
					"Active Default Server",
					"This server is your default and is selected automatically when the game starts." )
			else
				UI.Login_DefaultServerBtn:ApplyActionState( "Set Default", false, false,
					"Set as Default Server",
					"Make the selected server your default on game startup." )
			end
		end

		-- 3. Delete
		if UI.Login_DeleteServerBtn and UI.Login_DeleteServerBtn.ApplyActionState then
			local canDelete = selServer and selServer.isSaved and true or false
			if canDelete then
				UI.Login_DeleteServerBtn:ApplyActionState( "Delete", false, false,
					"Delete Saved Server",
					string.format( "Remove %s from your saved server list.", tostring( selServer.fullAddress or "" ) ) )
			else
				UI.Login_DeleteServerBtn:ApplyActionState( "Delete", true, false,
					"Delete Saved Server",
					"Select a saved server in the dropdown to remove it (built-in entries cannot be deleted)." )
			end
		end

		-- 4. Panel header
		if UI.Login_ServerDockWnd and UI.Login_ServerDockWnd.UpdateHeaderTelemetry then
			local savedCount = self.savedServers and #self.savedServers or 0
			UI.Login_ServerDockWnd:UpdateHeaderTelemetry( selServer, isCurrentDefault, savedCount, bShowServerFields )
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
		local isDef = (self.defaultServerAddress ~= nil and string.lower( self.defaultServerAddress ) == string.lower( s.fullAddress ))
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
-- Server Actions (+ ADD / SAVE, SET DEF, DEL)
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
		if (s.fullAddress and string.lower( s.fullAddress ) == string.lower( fullAddress ))
			or (s.isLocalhost and fullAddress == "localhost") then
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

	-- If fields are not visible (e.g. on localhost or saved server), open custom server drawer & focus
	if not isFieldsVisible then
		self:SelectCustomServerEntry()
		UI:SetKeyboardFocus( UI.Login_ServerNameEditWnd:GetUiHandle() )
		UI:PlayGlobalSound( self.sounds.btnClick )
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

function UI.LoginWnd:OnSetDefaultCurrentServer()
	local selRecordIdx = UI.Login_ServersComboBox and UI.Login_ServersComboBox:GetSelectedRecord() or -1
	local selServer = self.servers and self.servers[ selRecordIdx ]
	if not selServer or selServer.isCustom or selServer.name == "server" then
		return
	end
	local targetAddr = selServer.isLocalhost and "localhost" or selServer.fullAddress
	if targetAddr and targetAddr ~= "" then
		self:SetDefaultServer( targetAddr )
	end
end

function UI.LoginWnd:OnDeleteCurrentServer()
	local selRecordIdx = UI.Login_ServersComboBox and UI.Login_ServersComboBox:GetSelectedRecord() or -1
	local selServer = self.servers and self.servers[ selRecordIdx ]
	if not selServer or not selServer.isSaved or not selServer.fullAddress then
		return
	end
	self:DeleteSavedServer( selServer.fullAddress )
end

-- ----------------------------------------------------------------------------
-- UpdateServersComboBox Override (With Native Record Color-Coding)
-- ----------------------------------------------------------------------------
function UI.LoginWnd:UpdateServersComboBox()

	self:EnsureSlotHooks()
	self:EnsureContextMenuHooks()
	self:EnsureComboStateHook()

	if not self:NeedServersComboBox() then
		UI.Login_ServersComboBox:UnlinkFromParent()
		local function UnlinkIfChild( w )
			if w and w.IsChildOf and w:IsChildOf( self ) then
				w:UnlinkFromParent()
			end
		end
		UnlinkIfChild( UI.Login_ServerDockWnd )
		UnlinkIfChild( UI.Login_AddServerBtn )
		UnlinkIfChild( UI.Login_DefaultServerBtn )
		UnlinkIfChild( UI.Login_DeleteServerBtn )
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
			if (sInfo.fullAddress and string.lower( sInfo.fullAddress ) == string.lower( self.defaultServerAddress ))
				or (sInfo.isLocalhost and self.defaultServerAddress == "localhost") then
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
			if sInfo.fullAddress and string.lower( sInfo.fullAddress ) == string.lower( configAddress ) then
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

	-- Populate records into combobox with native EffectComboBoxWnd color-coding (data.color)
	for idx = 1, #self.servers do
		local serverInfo = self.servers[ idx ]
		local isDef = (self.defaultServerAddress and serverInfo.fullAddress and string.lower( self.defaultServerAddress ) == string.lower( serverInfo.fullAddress ))
			or (serverInfo.isLocalhost and self.defaultServerAddress == "localhost")

		local recordColor
		if serverInfo.isCustom then
			recordColor = SS_STYLE.COL_WARNING    -- Custom Server... (login "warning" orange)
		elseif isDef then
			recordColor = SS_STYLE.COL_GOLD       -- Active default (login button gold)
		elseif serverInfo.isSaved then
			recordColor = SS_STYLE.COL_WHITE      -- Saved servers
		else
			recordColor = SS_STYLE.COL_LIST_TEXT  -- Localhost (native list line blue)
		end

		local data =
		{
			serverInfo = serverInfo,
			address    = serverInfo.address,
			text       = serverInfo.displayName or serverInfo.name,
			color      = recordColor,
		}
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

	self:EnsureServerDockControls()
	self:UpdateServerAddressWnd()

end

-- ----------------------------------------------------------------------------
-- UpdateServerAddressWnd Override (Unlinks server_port from fixed 720p locator)
-- ----------------------------------------------------------------------------
function UI.LoginWnd:UpdateServerAddressWnd()

	local selRecordIdx = UI.Login_ServersComboBox:GetSelectedRecord()
	local selServer = self.servers and self.servers[ selRecordIdx ]

	local bShowServerFields = self:NeedServersComboBox() and selServer and (selServer.isCustom or selServer.name == "server")

	if bShowServerFields then
		self:AddControl( UI.Login_ServerNameEditWnd, self.layers.MAIN_EFFECT, "server_name" )
		self:AddControl( UI.Login_ServerPortEditWnd, self.layers.MAIN_EFFECT, "server_port" )

		-- Unlink both fields from static .sanim locators so UpdateServerDockLayout
		-- can position them cleanly without 1440p/4K overlap
		pcall(function()
			local effect = UI:GetEffectFromLayer( self, self.layers.MAIN_EFFECT )
			if effect and effect.UnlinkWnd then
				effect:UnlinkWnd( UI.Login_ServerNameEditWnd:GetUiHandle(), "" )
				effect:UnlinkWnd( UI.Login_ServerPortEditWnd:GetUiHandle(), "" )
			end
		end)

		UI.Login_ServerNameEditWnd:UpdateDummyText()
		UI.Login_ServerPortEditWnd:UpdateDummyText()
	else
		self:RemoveControl( UI.Login_ServerNameEditWnd, self.layers.MAIN_EFFECT )
		self:RemoveControl( UI.Login_ServerPortEditWnd, self.layers.MAIN_EFFECT )
		UI.Login_ServerNameEditWnd:SetLayerVisible( false, UI.Login_ServerNameEditWnd.layers.DUMMY_TEXT )
		UI.Login_ServerPortEditWnd:SetLayerVisible( false, UI.Login_ServerPortEditWnd.layers.DUMMY_TEXT )
	end

	self:UpdateServerDockLayout()
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

	self:SyncServerActionStates()

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
	if wnd then
		if wnd == UI.Login_AddServerBtn or (wnd.IsChildOf and wnd:IsChildOf( UI.Login_AddServerBtn )) then
			self:OnAddServer()
			return true
		end
		if wnd == UI.Login_DefaultServerBtn or (wnd.IsChildOf and wnd:IsChildOf( UI.Login_DefaultServerBtn )) then
			if not UI.Login_DefaultServerBtn.isActionDisabled then
				self:OnSetDefaultCurrentServer()
			end
			return true
		end
		if wnd == UI.Login_DeleteServerBtn or (wnd.IsChildOf and wnd:IsChildOf( UI.Login_DeleteServerBtn )) then
			if not UI.Login_DeleteServerBtn.isActionDisabled then
				self:OnDeleteCurrentServer()
			end
			return true
		end
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
	self:UpdateServerDockLayout()
end

-- Resolution change / windowed resize: the engine resets the device and recomputes
-- UI.screenWidth/Height, but nothing re-runs our layout, so sizes computed with SX/SY
-- for the old resolution would stay (too big or too small, and the buttons' cached
-- effect base size goes stale). Watch the screen size every frame and redo the layout
-- when it changes. State lives in table fields: no new chunk-level locals (Lua's
-- 200-local limit is shared with loginwnd.lua).
UI.LoginWnd.ssPrevNewFrame = UI.LoginWnd.F_OnNewFrame
function UI.LoginWnd:F_OnNewFrame( hSender, dt_sys, dt_game )
	local prev = UI.LoginWnd.ssPrevNewFrame
	if prev then
		prev( self, hSender, dt_sys, dt_game )
	end
	local w, h = UI.screenWidth, UI.screenHeight
	if self.ssScreenW ~= w or self.ssScreenH ~= h then
		local first = self.ssScreenW == nil
		self.ssScreenW, self.ssScreenH = w, h
		if not first then
			pcall(function()
				for _, key in ipairs( { "Login_AddServerBtn", "Login_DefaultServerBtn", "Login_DeleteServerBtn" } ) do
					if UI[ key ] then
						UI[ key ].baseSize = nil    -- re-measure the effect at the new resolution
					end
				end
				self:UpdateServerDockLayout()
			end)
		end
	end
end

local orig_LoginWnd_Shutdown = UI.LoginWnd.F_Shutdown
function UI.LoginWnd:F_Shutdown()
	local function UnlinkIfChild( w )
		if w and w.IsChildOf and w:IsChildOf( self ) then
			w:UnlinkFromParent()
		end
	end
	UnlinkIfChild( UI.Login_ServerDockWnd )
	UnlinkIfChild( UI.Login_AddServerBtn )
	UnlinkIfChild( UI.Login_DefaultServerBtn )
	UnlinkIfChild( UI.Login_DeleteServerBtn )
	if orig_LoginWnd_Shutdown then
		orig_LoginWnd_Shutdown( self )
	end
end

local orig_LoginWnd_Reset = UI.LoginWnd.Reset
function UI.LoginWnd:Reset()
	if orig_LoginWnd_Reset then
		orig_LoginWnd_Reset( self )
	end
	local function UnlinkIfChild( w )
		if w and w.IsChildOf and w:IsChildOf( self ) then
			w:UnlinkFromParent()
		end
	end
	UnlinkIfChild( UI.Login_ServerDockWnd )
	UnlinkIfChild( UI.Login_AddServerBtn )
	UnlinkIfChild( UI.Login_DefaultServerBtn )
	UnlinkIfChild( UI.Login_DeleteServerBtn )
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
-- ShowServerContextMenu (Right-Click Menu on Dropdown Slots)
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
	local isDefault = (self.defaultServerAddress and serverInfo.fullAddress and string.lower( self.defaultServerAddress ) == string.lower( serverInfo.fullAddress ))
		or (isLocalhost and (self.defaultServerAddress == "localhost" or self.defaultServerAddress == "" or self.defaultServerAddress == nil))

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

# ----------------------------------------------------------------------------
# Mods managed by this patcher. Every mod is one or more marker-delimited blocks
# appended to loginwnd.lua, so several mods can be installed side by side and each
# one installs / uninstalls without touching the others.
# ----------------------------------------------------------------------------

def _read_ui_overhaul_file(name):
    path = get_resource_path(os.path.join("ui_overhaul", name))
    if not path:
        raise FileNotFoundError(f"ui_overhaul/{name} is missing next to the patcher")
    with open(path, "r", encoding="utf-8") as f:
        return f.read()

MODS = [
    {
        "id": "server_selector",
        "name": "Server Selector",
        "tagline": "ESSENTIAL",
        "summary": "Save, switch and auto-select community servers right from the login screen.",
        "features": [
            "Server dropdown with localhost, saved servers and a custom entry",
            "Add Server button, right-click Set as Default / Delete",
            "Saved in your pilot profile; default server loads on launch (never auto-joins)",
        ],
        # (begin marker, end marker, source loader, source already contains the markers?)
        "blocks": [(MOD_BEGIN_MARKER, MOD_END_MARKER, get_mod_code, False)],
    },
    {
        "id": "ui_overhaul",
        "name": "UI Overhaul",
        "tagline": "FLAVOR & COMFORT",
        "summary": "Animated login screen, built on TweenService: a Roblox-style animation library for screen replacements.",
        "features": [
            "Login intro: side buttons slide in, login fields fade in",
            "Patch name gently pulses; side buttons nudge on hover",
            "TweenService library for other mods (easing styles, repeat, reverse, delay)",
        ],
        "blocks": [
            ("-- BEGIN TWEENSERVICE", "-- END TWEENSERVICE",
             lambda: _read_ui_overhaul_file("tweenservice.lua"), True),
            ("-- BEGIN LOGIN_TWEEN_DEMO", "-- END LOGIN_TWEEN_DEMO",
             lambda: _read_ui_overhaul_file("login_tween_demo.lua"), True),
        ],
    },
]
MODS_BY_ID = {m["id"]: m for m in MODS}


def _read_target_text(target):
    """loginwnd.lua as text with \\n line endings, plus how to write it back (BOM, CRLF)."""
    with open(target, "rb") as f:
        raw = f.read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = (raw[3:] if bom else raw).decode("utf-8", errors="replace")
    return text.replace("\r\n", "\n"), bom, b"\r\n" in raw


def _write_target_text(target, text, bom, crlf):
    data = text.replace("\n", "\r\n") if crlf else text
    with open(target, "wb") as f:
        f.write((b"\xef\xbb\xbf" if bom else b"") + data.encode("utf-8"))


def _strip_block(text, begin, end):
    i = text.find(begin)
    if i < 0:
        return text, False
    j = text.find(end, i)
    if j < 0:
        raise ValueError(f"'{begin}' has no matching '{end}' in loginwnd.lua")
    return text[:i].rstrip() + "\n" + text[j + len(end):].lstrip("\n"), True


def _block_text(block):
    begin, end, loader, has_markers = block
    src = loader().replace("\r\n", "\n").strip()
    if has_markers:
        if not (src.startswith(begin) and src.endswith(end)):
            raise ValueError(f"mod source must start with '{begin}' and end with '{end}'")
        return src
    return f"{begin}\n{src}\n{end}"


def _validate_lua(text):
    """(ok, note). Compiles with Lua 5.1 when lupa is available (also catches Lua's
    200-local limit, shared with loginwnd.lua); otherwise checks block balance."""
    try:
        import lupa.lua51 as lua51
        rt = lua51.LuaRuntime(encoding="latin-1")
        check = rt.eval("function(s) local f, e = loadstring(s, '=loginwnd.lua'); return f ~= nil, e end")
        ok, err = check(text.encode("utf-8").decode("latin-1"))
        return bool(ok), (err or "")
    except ImportError:
        pass
    except Exception as e:
        return False, str(e)
    import re
    s = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    s = re.sub(r"\[\[.*?\]\]", "", s, flags=re.S)
    s = re.sub(r"--[^\n]*", "", s)
    s = re.sub(r'"(\\.|[^"\\\n])*"', '""', s)
    s = re.sub(r"'(\\.|[^'\\\n])*'", "''", s)
    s = re.sub(r"\belseif\b.*?\bthen\b", "", s, flags=re.S)
    depth = 0
    for t in re.findall(r"\b(function|then|do|repeat|until|end)\b", s):
        depth += 1 if t in ("function", "then", "do", "repeat") else -1
        if depth < 0:
            return False, "unbalanced 'end'"
    return depth == 0, ("" if depth == 0 else "unclosed block")


def mod_state(content, mod):
    """'installed' | 'partial' | 'none'"""
    found = [b[0] in content and b[1] in content for b in mod["blocks"]]
    return "installed" if all(found) else ("partial" if any(found) else "none")


def check_status(game_dir):
    empty = {"exists": False, "installed": False, "has_backup": False, "target_file": "",
             "backup_file": "", "mods": {m["id"]: "none" for m in MODS}}
    if not game_dir:
        return empty
    target = get_target_file(game_dir)
    backup = get_backup_file(game_dir)
    status = dict(empty, target_file=target, backup_file=backup, has_backup=os.path.isfile(backup))
    if not os.path.isfile(target):
        return status
    try:
        content, _, _ = _read_target_text(target)
        status["mods"] = {m["id"]: mod_state(content, m) for m in MODS}
    except Exception:
        pass
    status["exists"] = True
    status["installed"] = status["mods"]["server_selector"] == "installed"
    return status


def install_mod(game_dir, mod_id="server_selector"):
    mod = MODS_BY_ID[mod_id]
    target = get_target_file(game_dir)
    backup = get_backup_file(game_dir)
    if not os.path.isfile(target):
        return False, f"Target file not found: {target}"
    try:
        content, bom, crlf = _read_target_text(target)
        for begin, end, _, _ in reversed(mod["blocks"]):
            content, _ = _strip_block(content, begin, end)
        blocks = [_block_text(b) for b in mod["blocks"]]
        new_content = content.rstrip() + "\n\n" + "\n\n".join(blocks) + "\n"
        ok, err = _validate_lua(new_content)
        if not ok:
            return False, f"{mod['name']} was not installed: the patched script would not load ({err}). No files were changed."
        if not os.path.isfile(backup):
            shutil.copy2(target, backup)
        _write_target_text(target, new_content, bom, crlf)
        return True, f"Installed {mod['name']}. Clean backup preserved at loginwnd.lua.orig."
    except Exception as e:
        return False, f"Installation failed: {str(e)}"


def uninstall_mod(game_dir, mod_id="server_selector"):
    """Removes only this mod's blocks; other installed mods stay."""
    mod = MODS_BY_ID[mod_id]
    target = get_target_file(game_dir)
    if not os.path.isfile(target):
        return False, f"Target file not found: {target}"
    try:
        content, bom, crlf = _read_target_text(target)
        found = False
        for begin, end, _, _ in reversed(mod["blocks"]):
            content, f = _strip_block(content, begin, end)
            found = found or f
        if not found:
            return True, f"{mod['name']} was not installed. Nothing changed."
        ok, err = _validate_lua(content)
        if not ok:
            return False, f"Removal aborted: the script would not load afterwards ({err}). No files were changed."
        _write_target_text(target, content.rstrip() + "\n", bom, crlf)
        return True, f"Removed {mod['name']}. Other mods were left untouched."
    except Exception as e:
        return False, f"Removal failed: {str(e)}"


def restore_original(game_dir):
    """Copies loginwnd.lua.orig back over loginwnd.lua (removes every mod)."""
    target, backup = get_target_file(game_dir), get_backup_file(game_dir)
    if not os.path.isfile(backup):
        return False, "No loginwnd.lua.orig backup found."
    try:
        shutil.copy2(backup, target)
        return True, "Restored the original loginwnd.lua from backup. All mods removed."
    except Exception as e:
        return False, f"Restore failed: {str(e)}"


class StarConflictPatcherApp:
    def __init__(self):
        self.icon_path = get_resource_path("star_conflict.ico")
        
        # Initialize Omega borderless window with taskbar presence
        self.root = oui.create_omega_window(
            title="Star Conflict · Community Mod Patcher",
            width=760,
            height=760
        )
        
        # Center the window on the active display
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = max(0, (sw - 760) // 2)
        y = max(0, (sh - 760) // 2)
        self.root.geometry(f"760x760+{x}+{y}")
        
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
            title="Star Conflict · Community Mod Patcher",
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
        self._build_mod_tabs()
        self._build_path_selector()
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
            text="Community Mod Patcher · Server Selector & UI Overhaul",
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

        # 3. Installed mods (summary; details live in the mod tabs below)
        tk.Label(grid, text="Installed Mods:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=2, column=0, sticky="w", pady=2)
        self.diag_mod_badge = tk.Label(grid, text="[ CHECKING ]", font=("Segoe UI", 8, "bold"), fg=oui.Theme.DISABLED, bg=oui.Theme.PANEL, anchor="w")
        self.diag_mod_badge.grid(row=2, column=1, sticky="w", padx=(10, 0), pady=2)

        # 4. Backup State
        tk.Label(grid, text="Original Backup:", font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL).grid(row=3, column=0, sticky="w", pady=2)
        self.diag_backup_badge = tk.Label(grid, text="[ CHECKING ]", font=("Segoe UI", 8, "bold"), fg=oui.Theme.DISABLED, bg=oui.Theme.PANEL, anchor="w")
        self.diag_backup_badge.grid(row=3, column=1, sticky="w", padx=(10, 0), pady=2)
        self.restore_link = tk.Label(grid, text="↺ Restore original", font=("Segoe UI", 8, "underline"),
                                     fg="#94A3B8", bg=oui.Theme.PANEL, cursor="hand2")
        self.restore_link.bind("<Button-1>", lambda e: self.do_restore_original())
        self.restore_link.bind("<Enter>", lambda e: self.restore_link.config(fg=oui.Theme.DANGER))
        self.restore_link.bind("<Leave>", lambda e: self.restore_link.config(fg="#94A3B8"))
        oui.ToolTip(self.restore_link, "Copy loginwnd.lua.orig back over loginwnd.lua, removing ALL mods")

    # ------------------------------------------------------------------ mod tabs
    def _build_mod_tabs(self):
        """Tab strip (one tab per mod) directly under the diagnostics, then the selected mod's card."""
        wrap = tk.Frame(self.container, bg=oui.Theme.BG)
        wrap.pack(fill=tk.X, pady=(0, 10))

        strip = tk.Frame(wrap, bg=oui.Theme.BG)
        strip.pack(fill=tk.X)
        self.mod_tabs = {}
        for mod in MODS:
            tab = tk.Frame(strip, bg=oui.Theme.BG, cursor="hand2")
            tab.pack(side=tk.LEFT, padx=(0, 4))
            body = tk.Frame(tab, bg=oui.Theme.BG, padx=14, pady=6)
            body.pack(fill=tk.X)
            name = tk.Label(body, text=mod["name"].upper(), font=("Segoe UI", 9, "bold"), bg=oui.Theme.BG, fg="#94A3B8")
            name.pack(side=tk.LEFT)
            dot = tk.Label(body, text="", font=("Segoe UI", 9, "bold"), bg=oui.Theme.BG, fg=oui.Theme.SUCCESS)
            dot.pack(side=tk.LEFT, padx=(6, 0))
            bar = tk.Frame(tab, height=2, bg=oui.Theme.BG)
            bar.pack(fill=tk.X)
            for w in (tab, body, name, dot):
                w.bind("<Button-1>", lambda e, mid=mod["id"]: self.select_mod_tab(mid))
                w.bind("<Enter>", lambda e, mid=mod["id"]: self._hover_tab(mid, True))
                w.bind("<Leave>", lambda e, mid=mod["id"]: self._hover_tab(mid, False))
            self.mod_tabs[mod["id"]] = {"tab": tab, "body": body, "name": name, "dot": dot, "bar": bar}

        self.mod_card = tk.Frame(wrap, bg=oui.Theme.PANEL, padx=14, pady=10)
        self.mod_card.pack(fill=tk.X)
        self.selected_mod = MODS[0]["id"]

    def _hover_tab(self, mod_id, inside):
        if mod_id != self.selected_mod:
            self.mod_tabs[mod_id]["name"].config(fg=oui.Theme.TEXT if inside else "#94A3B8")

    def select_mod_tab(self, mod_id):
        self.selected_mod = mod_id
        self.refresh_ui()

    def _style_tabs(self):
        for mid, t in self.mod_tabs.items():
            active = mid == self.selected_mod
            bg = oui.Theme.PANEL if active else oui.Theme.BG
            for key in ("tab", "body", "name", "dot"):
                t[key].config(bg=bg)
            t["name"].config(fg=oui.Theme.ACCENT if active else "#94A3B8")
            t["bar"].config(bg=oui.Theme.ACCENT if active else oui.Theme.BG)
            state = self.status["mods"].get(mid, "none")
            t["dot"].config(text={"installed": "●", "partial": "◐"}.get(state, ""),
                            fg=oui.Theme.SUCCESS if state == "installed" else "#F59E0B")

    def _render_mod_card(self):
        for w in self.mod_card.winfo_children():
            w.destroy()
        mod = MODS_BY_ID[self.selected_mod]
        state = self.status["mods"].get(mod["id"], "none")

        top = tk.Frame(self.mod_card, bg=oui.Theme.PANEL)
        top.pack(fill=tk.X)
        tk.Label(top, text=mod["name"].upper(), font=("Segoe UI", 10, "bold"), fg=oui.Theme.ACCENT,
                 bg=oui.Theme.PANEL).pack(side=tk.LEFT)
        tk.Label(top, text=f"  {mod['tagline']}", font=("Segoe UI", 8, "bold"), fg="#64748B",
                 bg=oui.Theme.PANEL).pack(side=tk.LEFT, pady=(2, 0))
        if not self.status["exists"]:
            txt, col = "✕ TARGET SCRIPT MISSING", oui.Theme.DANGER
        else:
            txt, col = {"installed": ("● INSTALLED & ACTIVE", oui.Theme.ACCENT),
                        "partial": ("◐ PARTIALLY INSTALLED (reinstall to repair)", "#F59E0B")}.get(
                state, ("○ NOT INSTALLED", "#94A3B8"))
        tk.Label(top, text=txt, font=("Segoe UI", 8, "bold"), fg=col, bg=oui.Theme.PANEL).pack(side=tk.RIGHT)

        tk.Label(self.mod_card, text=mod["summary"], font=("Segoe UI", 9), fg=oui.Theme.TEXT, bg=oui.Theme.PANEL,
                 wraplength=680, justify="left").pack(anchor="w", pady=(4, 2))
        for feat in mod["features"]:
            tk.Label(self.mod_card, text="•  " + feat, font=("Segoe UI", 8), fg="#CBD5E1", bg=oui.Theme.PANEL,
                     justify="left").pack(anchor="w")

        # sources available?
        missing = None
        try:
            for b in mod["blocks"]:
                _block_text(b)
        except Exception as e:
            missing = str(e)
        if missing:
            tk.Label(self.mod_card, text="⚠ " + missing, font=("Segoe UI", 8, "bold"), fg="#F59E0B",
                     bg=oui.Theme.PANEL).pack(anchor="w", pady=(6, 0))

        actions = tk.Frame(self.mod_card, bg=oui.Theme.PANEL)
        actions.pack(pady=(10, 2))
        self.action_frame = actions
        if not self.game_dir or not self.status["exists"]:
            oui.OmegaButton(actions, text="⚙ Browse to Locate Star Conflict Directory...", command=self.browse_directory,
                            width=340, height=38, corner_radius=8, bg_color=oui.Theme.BTN, hover_color=oui.Theme.BTN_HOVER,
                            parent_bg=oui.Theme.PANEL, tooltip="Select the folder where Star Conflict is installed").pack()
        elif state == "none":
            if not missing:
                oui.OmegaButton(actions, text=f"⚡ Install {mod['name']}", command=lambda: self.do_install(mod["id"]),
                                width=260, height=40, corner_radius=8, bg_color=oui.Theme.SUCCESS,
                                hover_color=oui.Theme.SUCCESS_HOVER, parent_bg=oui.Theme.PANEL,
                                tooltip="Backs up the original loginwnd.lua (once) and adds this mod next to any others").pack()
        else:
            if not missing:
                oui.OmegaButton(actions, text="↻ Reinstall / Update", command=lambda: self.do_install(mod["id"]),
                                width=190, height=38, corner_radius=8, bg_color=oui.Theme.BTN, hover_color=oui.Theme.BTN_HOVER,
                                parent_bg=oui.Theme.PANEL, tooltip="Re-applies the latest code for this mod").pack(side=tk.LEFT, padx=6)
            oui.OmegaButton(actions, text=f"↺ Uninstall {mod['name']}", command=lambda: self.do_uninstall(mod["id"]),
                            width=230, height=38, corner_radius=8, bg_color=oui.Theme.DANGER,
                            hover_color=oui.Theme.DANGER_HOVER, parent_bg=oui.Theme.PANEL,
                            tooltip="Removes only this mod's code; other mods stay installed").pack(side=tk.LEFT, padx=6)

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

        installed = [m["name"] for m in MODS if self.status["mods"].get(m["id"]) == "installed"]
        partial = [m["name"] for m in MODS if self.status["mods"].get(m["id"]) == "partial"]
        if not self.status["exists"]:
            self.diag_mod_badge.config(text="✕ TARGET SCRIPT MISSING", fg=oui.Theme.DANGER)
        elif installed or partial:
            txt = "● " + ", ".join(installed) + (("  ◐ partial: " + ", ".join(partial)) if partial else "")
            self.diag_mod_badge.config(text=txt.replace("●  ◐", "◐"), fg=oui.Theme.ACCENT)
        else:
            self.diag_mod_badge.config(text="○ NONE", fg="#94A3B8")

        if self.status["has_backup"]:
            self.diag_backup_badge.config(text="● PRESERVED (loginwnd.lua.orig)", fg=oui.Theme.SUCCESS)
            self.restore_link.grid(row=3, column=2, sticky="e", pady=2)
        else:
            self.restore_link.grid_remove()
            if self.status["exists"]:
                self.diag_backup_badge.config(text="○ NONE (Will auto-backup on first install)", fg="#64748B")
            else:
                self.diag_backup_badge.config(text="—", fg="#64748B")

        if not self.status["exists"]:
            self.diag_indicator.config(text="● GAME NOT FOUND", fg=oui.Theme.DANGER)
        elif installed:
            n = len(installed)
            self.diag_indicator.config(text=f"● {n} MOD{'S' if n > 1 else ''} ACTIVE", fg=oui.Theme.ACCENT)
        else:
            self.diag_indicator.config(text="● READY TO INSTALL", fg=oui.Theme.SUCCESS)

        # 3. Mod tabs + selected mod card (with its action buttons)
        self._style_tabs()
        self._render_mod_card()

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

    def do_install(self, mod_id=None):
        if not self.game_dir:
            self.set_banner("✕ Please specify a valid Star Conflict installation directory first.", oui.Theme.DANGER)
            return
        success, msg = install_mod(self.game_dir, mod_id or self.selected_mod)
        self.set_banner(("✔ " if success else "✕ ") + msg, oui.Theme.SUCCESS if success else oui.Theme.DANGER)
        self.refresh_ui()

    def do_uninstall(self, mod_id=None):
        if not self.game_dir:
            self.set_banner("✕ Please specify a valid Star Conflict directory first.", oui.Theme.DANGER)
            return
        success, msg = uninstall_mod(self.game_dir, mod_id or self.selected_mod)
        self.set_banner(("✔ " if success else "✕ ") + msg, oui.Theme.SUCCESS if success else oui.Theme.DANGER)
        self.refresh_ui()

    def do_restore_original(self):
        if not self.game_dir:
            return
        if not messagebox.askyesno(
                "Restore original loginwnd.lua",
                "This copies loginwnd.lua.orig back over loginwnd.lua and removes ALL mods.\n\n"
                "If the game was updated since the backup was made, the backup may be older than the "
                "game's current file; prefer uninstalling mods one by one in that case.\n\nContinue?",
                parent=self.root):
            return
        success, msg = restore_original(self.game_dir)
        self.set_banner(("✔ " if success else "✕ ") + msg, oui.Theme.SUCCESS if success else oui.Theme.DANGER)
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
            "Each mod's code is enclosed between its own explicit markers (e.g. -- BEGIN STAR CONFLICT SERVER SELECTOR MOD / -- END ...), so mods sit side by side. Before writing, the patched script is checked so a broken file is never saved. No other game routines or assets are altered."
        )
        add_bullet(
            s1,
            "Independent Uninstall & Full Restore",
            "Uninstalling a mod removes only that mod's block, leaving the others working. '↺ Restore original' (next to the backup status) copies loginwnd.lua.orig back and removes every mod at once."
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
            "Saves server configurations to your pilot profile using the engine's built-in GetProfileTable() and Profile:Save(), immediately after every change. Your saved servers and default choice survive restarts."
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

        # 2b. UI Overhaul
        s2b = make_section("2b · UI OVERHAUL (FLAVOR & COMFORT)", "Optional second mod: animation and screen replacements")
        add_bullet(
            s2b,
            "TweenService",
            "A Roblox-style animation library written in plain Lua (TweenInfo, easing styles, repeat, reverse, delay, Completed events). It runs on the login window's per-frame update, so no engine changes are needed."
        )
        add_bullet(
            s2b,
            "Animated Login",
            "On opening the login screen the side buttons slide in one after another, the login fields fade in, the patch name pulses, and side buttons nudge on hover. Functionally nothing changes; it is purely visual and works alongside the Server Selector."
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

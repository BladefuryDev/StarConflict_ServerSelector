-- ============================================================================
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

-- BEGIN LOGIN_TWEEN_DEMO
-- ============================================================================
-- Demo: cinematic animated login screen + Golden Play Button ("Remember Me"
-- Quick-Play mode) built on TweenService.
--
-- Features:
-- * Boot sequence: smoothly fades in from pure black while the space background
--   starts slightly zoomed in (1.10x, centered) and smoothly zooms out to 1.0x.
-- * Quick-Play / Remember Me mode:
--   - Initializes with the classic MMO Golden Play Button (UI.Login_SteamLogInBtn,
--     login_enter_2.sanim) and "Welcome, #Username# | Click here to change."
--     beneath it whenever saved account information ("Remember me") exists.
--   - Checking "Remember me" on the login form minimizes the input fields into
--     "Welcome, #Username# | Click here to change." and lets the Golden Play
--     Button appear with a responsive slide-down and fade-in animation.
--   - Clicking "Welcome, #Username# | Click here to change." smoothly expands
--     back to the E-mail / Password form for switching accounts.
-- * Side menu buttons & Golden Play Button grow slightly on hover.
-- ============================================================================
do
	local TS = TweenService
	if not TS then return end

	local LW = UI.LoginWnd
	local demo = {
		played          = false,
		isMinimized     = false,
		pendingMinimize = false,
		tweens          = {},
		authTweens      = {},
		hover           = {},
	}
	LoginTweenDemo = demo

	local SIDE = { "UI.Login_OptionsBtn", "UI.Login_StartServerBtn", "UI.Login_SiteBtn", "UI.Login_CreditsBtn",
	               "UI.Login_LicenseBtn", "UI.Login_PrivacyPolicyBtn", "UI.Login_TermsOfUseBtn", "UI.Login_QuitBtn" }
	local FORM_FIELDS = { "UI.Login_AccountEditWnd", "UI.Login_PasswordEditWnd",
	                      "UI.Login_RememberCheckBox", "UI.Login_LogInBtn",
	                      "UI.Login_ForgetBtn", "UI.Login_RegisterBtn" }
	local SERVER_UI = { "UI.Login_ServerDockWnd", "UI.Login_ServersComboBox", "UI.Login_AddServerBtn",
	                    "UI.Login_DefaultServerBtn", "UI.Login_DeleteServerBtn", "UI.Login_ServerNameEditWnd",
	                    "UI.Login_ServerPortEditWnd", "UI.NewsWnd" }
	local TEXT_LAYERS = { LW.layers.BUILD_VERSION, LW.layers.WARNING, LW.layers.SERVER_STATUS,
	                      LW.layers.STEAM_LOGIN_TIP, LW.layers.ARC_LOGIN_TIP }
	local EDIT_FIELDS = { "Login_AccountEditWnd", "Login_PasswordEditWnd",
	                      "Login_ServerNameEditWnd", "Login_ServerPortEditWnd",
	                      "Login_TwoStepAuthorisation_KeyEditWnd" }

	local GOLD, WHITE, BLACK = 0xFFFFD200, 0xFFFFFFFF, 0xFF000000
	local COLOR_BIT      = UI.EffectAnimParams.COLOR
	local BG_ZOOM_START  = 1.10    -- initial centered zoom on the background artwork
	local BG_ZOOM_TIME   = 1.60    -- smooth zoom-out duration (s)
	local BG_FADE_TIME   = 0.90    -- fade-in from black duration (s)
	local UI_START_DELAY = 0.35    -- beat before UI menu elements begin loading in (s)
	local HOVER_TIME     = 0.075   -- snappy hover duration (s)
	local HOVER_SCALE    = 1.04    -- subtle 4% grow from the button's centre
	local PLAY_HOVER_SCL = 1.05    -- golden play button hover scale factor

	local function log( fmt, ... ) if sys and sys.log then pcall( sys.log, "LoginTweenDemo: " .. fmt, ... ) end end

	local RES_720 = { x = 1280, y = 720 }
	local function SX( v ) return UI:XTo1024x768( v, RES_720 ) end
	local function SY( v ) return UI:YTo1024x768( v, RES_720 ) end
	local PLAY_HOVER_LIFT = SY( 4 )    -- golden play button pure vertical lift on hover (no horizontal shift)

	local function wndByName( name )
		local ok, t = pcall( UI.GetValByName, UI, name )
		return ( ok and t and t.w and t:IsOnScreen() ) and t or nil
	end

	local function wndAny( name )
		local ok, t = pcall( UI.GetValByName, UI, name )
		return ( ok and t and t.w ) and t or nil
	end

	-- Calls the handler the window inherits from its prototype. The login windows get their
	-- prototype (setmetatable, UI:InheritWnd) only when they are created, after this file has
	-- run, so a hook installed here must not capture "prev = ew.F_..." (that is nil now) and
	-- would otherwise replace the native EffectEditWnd focus handling outright.
	local function protoCall( self, name, ... )
		local mt = getmetatable( self )
		local proto = mt and mt.__index
		local f = type( proto ) == "table" and proto[ name ]
		if type( f ) == "function" then return f( self, ... ) end
	end

	local function getEditFieldFromWnd( wnd )
		if not wnd then return nil end
		for _, key in ipairs( EDIT_FIELDS ) do
			local ew = UI[ key ]
			if ew and ew.w then
				if wnd == ew or ( wnd.IsChildOf and wnd:IsChildOf( ew ) ) then
					return ew
				end
			end
		end
		return nil
	end

	local function screenRect( w )   -- plain numbers: GetRect / ToScreen return ring-buffered Quats
		local r = w:GetRect()
		local p = w:GetParent()
		if p then r = p:ToScreen( r ) end
		return r.x, r.y, r.z, r.w
	end

	-- E-mail / Password plus the Server Selector's name / port fields, in Tab order
	local TAB_ORDER = { "Login_AccountEditWnd", "Login_PasswordEditWnd",
	                    "Login_ServerNameEditWnd", "Login_ServerPortEditWnd" }
	local function visibleFields()
		local out = {}
		if demo.isMinimized then return out end
		for _, key in ipairs( TAB_ORDER ) do
			local ew = UI[ key ]
			if ew and ew.w and ew:IsOnScreen() and ew:IsChildOf( LW ) then out[ #out + 1 ] = ew end
		end
		return out
	end

	local function editFieldAt( mx, my )
		for _, ew in ipairs( visibleFields() ) do
			local x, y, w, h = screenRect( ew )
			if mx >= x and mx <= x + w and my >= y and my <= y + h then return ew end
		end
		return nil
	end

	local function refreshEditGlow()   -- the field frame plays "select" only while it has focus
		for _, key in ipairs( EDIT_FIELDS ) do
			local ew = UI[ key ]
			if ew and ew.w and ew.UpdateMainAnimation then pcall( ew.UpdateMainAnimation, ew ) end
		end
	end

	-- Takes keyboard focus off the fields but keeps it on the login window, so Tab and
	-- Enter still reach LoginWnd:HandleKey (with no focus at all, keys go nowhere).
	function demo.ParkFocus()
		if getEditFieldFromWnd( UI:GetUiObjByHandleT( UI:GetKeyboardFocus() ) ) then
			UI:SetKeyboardFocus( LW:GetUiHandle() )
			LW:ResetFocus()
		end
	end

	-- Tab / Shift+Tab: next / previous visible field (vanilla only toggles E-mail <-> Password)
	function demo.FocusNextField( backwards )
		local fields = visibleFields()
		if #fields == 0 then return false end
		local cur = UI:GetKeyboardFocus()
		local at = 0
		for i, ew in ipairs( fields ) do
			if ew:GetUiHandle() == cur then at = i end
		end
		local step = backwards and -1 or 1
		local nxt = ( at == 0 ) and ( backwards and #fields or 1 ) or ( ( at - 1 + step ) % #fields + 1 )
		UI:SetKeyboardFocus( fields[ nxt ]:GetUiHandle() )
		return true
	end

	local function shiftHeld()
		return _G.Input_IsKeyPressed and UI.Keys.KEY_SHIFT and _G.Input_IsKeyPressed( UI.Keys.KEY_SHIFT ) or false
	end

	local function mainEffect() return UI:GetEffectFromLayer( LW, LW.layers.MAIN_EFFECT ) end

	-- -------------------------------------------------------------------------
	-- Font & Text Measurement Helpers for UI.Login_WelcomeBarBtn
	-- -------------------------------------------------------------------------
	local function safeFont( fontName )
		for _, name in ipairs( { fontName or "Small", "Small" } ) do
			if UI and UI.GetFontByPatternName then
				local h = UI:GetFontByPatternName( name )
				if h and h ~= FONT.INVALID_FONT_HANDLE then return h end
			end
			if _G and _G.ObtainFont then
				local h = _G.ObtainFont( name )
				if h and h ~= FONT.INVALID_FONT_HANDLE then return h end
			end
		end
		return FONT.INVALID_FONT_HANDLE
	end

	local function measureTextW( str, hFont )
		if _G.MeasureText and str and str ~= "" and hFont then
			local dummy = UI:Quat( 0, 0, 10000, 10000 )
			local res = _G.MeasureText( str, hFont, dummy, FONT.TF_SINGLELINE + FONT.TF_NOCLIP, dummy )
			if res and res.z and res.z > 0 then return res.z end
		end
		return SX( string.len( str or "" ) * 6.5 )
	end

	local function currentUsername()
		local accWnd = UI.Login_AccountEditWnd
		local acc = ( accWnd and accWnd.GetEditText and accWnd:GetEditText() ) or ""
		if acc == "" then
			local prof = _G.GetProfileTable and _G.GetProfileTable()
			acc = ( prof and prof.lastAccount ) or ""
		end
		return acc
	end

	-- -------------------------------------------------------------------------
	-- UI.Login_WelcomeBarBtn ("Welcome, #Username# | Click here to change.")
	-- Placed directly beneath the Golden Play Button (UI.Login_SteamLogInBtn)
	-- -------------------------------------------------------------------------
	UI.Login_WelcomeBarBtn = {
		def = {
			className = "Wnd",
			props = {
				name  = "Login_WelcomeBarBtn",
				style = UI.WS_NOT_KB_REACT,
			},
			layers = {
				-- 0: Base transparent plate
				{
					layerType  = UI.LAYER_TEXTURE,
					layerStyle = UI.WLS_RESIZABLE,
					texture    = "white",
					color      = 0x00000000,
				},
				-- 1: Owner-drawn text and accents
				{
					layerType    = UI.LAYER_TEXT,
					layerStyle   = UI.WLS_OWNERDRAW + UI.WLS_RESIZABLE,
					font         = { fontName = "Small" },
					formatFlags  = ( FONT.TF_HCENTER or 2 ) + ( FONT.TF_VCENTER or 32 ) + FONT.TF_SINGLELINE + FONT.TF_NOCLIP,
					formatInfoSz = { 1, 1 },
					color        = 0xFFFFFFFF,
				},
			},
		},
		layers = {
			PLATE   = 0,
			OVERLAY = 1,
		},
		hoverMix = 0,
		isOver   = false,
		lastOver = false,
	}

	function UI.Login_WelcomeBarBtn:BuildRuns( hm )
		local uname = currentUsername()
		if uname == "" then uname = "Pilot" end
		return {
			{ "Welcome, ",              TS.LerpColor( 0xFFD4DCE8, 0xFFF2F6FC, hm ), false },
			{ uname,                    TS.LerpColor( 0xFFFFB424, 0xFFFFDF58, hm ), false },
			{ "  |  ",                  0xFF6B778A,                                 false },
			{ "Click here to change.",  TS.LerpColor( 0xFF88B5FF, 0xFFFFDA02, hm ), true  },
		}
	end

	function UI.Login_WelcomeBarBtn:MeasureTotalWidth()
		local hFont = safeFont( "Small" )
		local runs = self:BuildRuns( 0 )
		local totalW = 0
		for _, r in ipairs( runs ) do
			totalW = totalW + measureTextW( r[ 1 ], hFont )
		end
		return totalW, hFont
	end

	function UI.Login_WelcomeBarBtn:F_OnMouseIn()
		self.isOver = true
		if self.hoverTween then self.hoverTween:Cancel() end
		self.hoverTween = TS:Create( self, TweenInfo.new( 0.09, "Quad", "Out" ), { hoverMix = 1 } )
		if self.hoverTween then self.hoverTween:Play() end
	end

	function UI.Login_WelcomeBarBtn:F_OnMouseOut()
		self.isOver = false
		if self.hoverTween then self.hoverTween:Cancel() end
		self.hoverTween = TS:Create( self, TweenInfo.new( 0.09, "Quad", "Out" ), { hoverMix = 0 } )
		if self.hoverTween then self.hoverTween:Play() end
	end

	function UI.Login_WelcomeBarBtn:F_OnMouseLButtonDown( mouseX, mouseY )
		demo.ExpandToForm( true, false )
		return true
	end

	function UI.Login_WelcomeBarBtn:F_DrawLayer( x0, y0, width, height, clipX0, clipY0, clipW, clipH, layerIdx )
		local overlayIdx = ( self.layers and self.layers.OVERLAY ) or 1
		if layerIdx ~= overlayIdx then return end
		local ok, err = pcall( function()
			local layerAlpha = ( UI.GetAlpha and UI:GetAlpha( self:GetColor( overlayIdx ) ) or 255 ) / 255
			if layerAlpha <= 0.005 then return end

			local function applyAlpha( c )
				if layerAlpha >= 0.999 or not UI.GetAlpha or not UI.SetAlpha then return c end
				return UI:SetAlpha( c, math.floor( UI:GetAlpha( c ) * layerAlpha + 0.5 ) )
			end

			local hm = self.hoverMix or 0
			local hFont = safeFont( "Small" )
			if not hFont or hFont == FONT.INVALID_FONT_HANDLE then return end

			local runs = self:BuildRuns( hm )
			local widths, totalW = {}, 0
			for i, r in ipairs( runs ) do
				local w = measureTextW( r[ 1 ], hFont )
				widths[ i ] = w
				totalW = totalW + w
			end

			local padX  = SX( 12 )
			local pillW = math.min( width, totalW + padX * 2 )
			local pillX = x0 + ( width - pillW ) * 0.5
			local px    = UI:XToRel( 1 )
			local py    = UI:YToRel( 1 )

			local curX  = x0 + ( width - totalW ) * 0.5
			local linkX, linkW = curX, 0
			for i, r in ipairs( runs ) do
				if r[ 3 ] then linkX, linkW = curX, widths[ i ] end
				curX = curX + widths[ i ]
			end

			-- 1. All sprite graphics: pill background, top/bottom accent hairlines, and underline
			local hTex = UI:GetTex( "white" )
			if UI.drawer and UI.drawer.DrawImagedRect and hTex and hTex ~= UI.INVALID_RESOURCE_HANDLE then
				local bgCol   = applyAlpha( TS.LerpColor( 0x7206080E, 0xAA0C1322, hm ) )
				local lineCol = applyAlpha( TS.LerpColor( 0x356480A6, 0x98FFBA24, hm ) )
				local ulCol   = applyAlpha( TS.LerpColor( 0x4888B5FF, 0xECFFDA02, hm ) )
				local ulW     = linkW * ( 0.85 + 0.15 * hm )
				local ulX     = linkX + ( linkW - ulW ) * 0.5

				UI.drawer:DrawImagedRect( pillX, y0, pillW, height, clipX0, clipY0, clipW, clipH, hTex, bgCol, 0, 0, 1, 1, false )
				UI.drawer:DrawImagedRect( pillX, y0, pillW, py, clipX0, clipY0, clipW, clipH, hTex, lineCol, 0, 0, 1, 1, false )
				UI.drawer:DrawImagedRect( pillX, y0 + height - py, pillW, py, clipX0, clipY0, clipW, clipH, hTex, lineCol, 0, 0, 1, 1, false )
				UI.drawer:DrawImagedRect( ulX, y0 + height - py * 3, ulW, py, clipX0, clipY0, clipW, clipH, hTex, ulCol, 0, 0, 1, 1, false )
			end

			-- 2. Flush sprite batch, render multi-run colored text, and restore drawer batch
			if not _G.UI_DrawText then return end
			local flags = FONT.TF_LEFT + FONT.TF_VCENTER + FONT.TF_SINGLELINE + FONT.TF_NOCLIP
			curX = x0 + ( width - totalW ) * 0.5

			UI.drawer:EndUiDrawing()
			for i, r in ipairs( runs ) do
				local str, col = r[ 1 ], r[ 2 ]
				local w = widths[ i ]
				_G.UI_DrawText( str, hFont, UI:Quat( curX, y0, w + px * 2, height ), applyAlpha( col ), 0, flags, UI:Quat( clipX0, clipY0, clipW, clipH ) )
				curX = curX + w
			end
			UI.drawer:BeginUiDrawing()
		end )
		if not ok then log( "WelcomeBar DrawLayer error: %s", tostring( err ) ) end
	end

	local function ensureWelcomeBar()
		local wnd = UI.Login_WelcomeBarBtn
		if not wnd or not wnd.w or not wnd.IsChildOf then
			if UI.CreateWndFromTable then
				local created = UI:CreateWndFromTable( "UI.Login_WelcomeBarBtn" )
				if created then
					UI.Login_WelcomeBarBtn = created
					wnd = created
				end
			end
		end
		return wnd
	end

	-- -------------------------------------------------------------------------
	-- UI.Login_TypingCursor
	-- Custom blinking typing cursor tied directly to keyboard focus
	-- -------------------------------------------------------------------------
	UI.Login_TypingCursor = {
		def = {
			className = "Wnd",
			props = {
				name  = "Login_TypingCursor",
				style = UI.WS_NOT_MOUSE_REACT + UI.WS_NOT_KB_REACT + ( UI.WS_SKIP_OPEN or 0 ) + ( UI.WS_DISABLE_ONSHOW_EFFECT or 0 ) + ( UI.WS_DISABLE_ONHIDE_EFFECT or 0 ),
			},
			layers = {
				{
					layerType  = UI.LAYER_TEXTURE,
					layerStyle = UI.WLS_RESIZABLE,
					texture    = "white",
					color      = 0xFFFFFFFF,
				},
			},
		},
		layers = {
			BAR = 0,
		},
	}

	local cursorState = {
		wnd      = nil,
		timer    = 0,
		lastPos  = -1,
		lastText = "",
		visible  = false,
	}
	demo.cursorState = cursorState

	local function ensureCustomCursor()
		local cur = UI.Login_TypingCursor
		if not cur or not cur.w or not cur.IsChildOf then
			if UI.CreateWndFromTable then
				local created = UI:CreateWndFromTable( "UI.Login_TypingCursor" )
				if created then
					UI.Login_TypingCursor = created
					cur = created
				end
			end
		end
		if cur and cur.AddStyle then
			pcall( function()
				cur:AddStyle( UI.WS_NOT_MOUSE_REACT )
				cur:AddStyle( UI.WS_NOT_KB_REACT )
			end )
		end
		return cur
	end

	local function hideCustomCursor()
		local cur = ensureCustomCursor()
		if cur and cur.w then
			TS:Set( cur, { Transparency = 1 } )
			cur:SetLeft( -10000 )
			cur:SetTop( -10000 )
		end
		cursorState.timer = 0
		cursorState.visible = false
	end

	local function updateCustomCursor( dt )
		local curFocus = UI.GetKeyboardFocus and UI:GetKeyboardFocus()
		if not curFocus or curFocus == UI.INVALID_UI_HANDLE or demo.isMinimized then
			hideCustomCursor()
			return
		end

		local obj = UI.GetUiObjByHandleT and UI:GetUiObjByHandleT( curFocus )
		local activeEw = getEditFieldFromWnd( obj )
		if not activeEw or not activeEw.w or not activeEw:IsOnScreen() then
			hideCustomCursor()
			return
		end

		-- Keep the native caret hidden; ours replaces it (see the SetLayerVisible hook below)
		if activeEw.layers and activeEw.layers.CURSOR then
			pcall( function() activeEw:SetLayerVisible( false, activeEw.layers.CURSOR ) end )
		end

		-- While text is selected the caret is hidden, like the native one
		local selStart = ( activeEw.GetSelStart and activeEw:GetSelStart() ) or -1
		local selEnd = ( activeEw.GetSelEnd and activeEw:GetSelEnd() ) or -1
		if selStart ~= -1 and selEnd ~= -1 and selStart ~= selEnd then
			hideCustomCursor()
			return
		end

		local curWnd = ensureCustomCursor()
		if not curWnd or not curWnd.w then return end

		if not curWnd:IsChildOf( LW ) then
			LW:AddChild( curWnd )
		end

		local fx, fy, fw, fh = screenRect( activeEw )
		local lw = LW:ToScreen( UI:Quat( 0, 0, 0, 0 ) )
		local ox, oy = lw.x, lw.y

		-- The engine keeps the CURSOR layer at the exact, pixel-snapped caret: after autoscroll,
		-- in the font the .sanim link really draws with, over the password mask (decompiled
		-- EditWnd, TYPING_AUDIT.md 1.2). Measuring the text ourselves put the bar inside the last glyph.
		local caretX
		if activeEw.layers and activeEw.layers.CURSOR then
			local ok, x = pcall( function() return activeEw:ToScreen( activeEw:GetLayerRect( activeEw.layers.CURSOR ) ).x end )
			if ok then caretX = x end
		end
		if not caretX then
			local cpos = ( activeEw.GetCursorPos and activeEw:GetCursorPos() ) or 0   -- characters before the caret
			local draw = ( activeEw.GetDrawText and activeEw:GetDrawText() ) or ""
			caretX = fx + SX( 3.5 ) + measureTextW( string.sub( draw, 1, cpos ), safeFont( "Small" ) )
		end

		local curW = SX( 1.6 )
		local curH = SY( 13 )
		local curX = caretX + UI:XToRel( 1 )   -- one pixel clear of the last glyph's outline
		local curY = fy + ( fh - curH ) * 0.5
		curX = math.max( fx, math.min( curX, fx + fw - curW ) )

		-- Restart the blink on every caret move or edit, so the bar stays solid while typing
		local text = ( activeEw.GetEditText and activeEw:GetEditText() ) or ""
		local cpos = activeEw.GetCursorPos and activeEw:GetCursorPos()
		if cpos ~= cursorState.lastPos or text ~= cursorState.lastText or activeEw ~= cursorState.wnd then
			cursorState.lastPos = cpos
			cursorState.lastText = text
			cursorState.wnd = activeEw
			cursorState.timer = 0
		else
			cursorState.timer = cursorState.timer + ( dt or 0.033 )
			if cursorState.timer >= 1.0 then
				cursorState.timer = cursorState.timer - 1.0
			end
		end

		local showBar = ( cursorState.timer < 0.53 )

		curWnd:SetLeft( curX - ox )
		curWnd:SetTop( curY - oy )
		curWnd:SetWidth( curW )
		curWnd:SetHeight( curH )

		TS:Set( curWnd, { Transparency = showBar and 0 or 1 } )
		cursorState.visible = showBar
	end

	-- -------------------------------------------------------------------------
	-- Background Zoom & Color State
	-- -------------------------------------------------------------------------
	local function setBgState( s, col )
		local px, py = 512 * ( 1 - s ), 384 * ( 1 - s )
		for _, layer in ipairs( { LW.layers.BG_EFFECT, LW.layers.BG2_EFFECT } ) do
			local eff = UI:GetEffectFromLayer( LW, layer )
			if eff then
				eff:SetScale( UI:Vec2( s, s ) )
				eff:SetPos( UI:Vec2( px, py ) )
				eff:SetColor( col )
				eff:SetAlpha( 255 )
			end
		end
	end

	demo.bg = {
		Scale = 1,
		Color = WHITE,
		OnChanged = function( self )
			setBgState( self.Scale, self.Color )
		end,
	}

	-- -------------------------------------------------------------------------
	-- Locator Links Capture (must run at script load while LoginWnd.def exists)
	-- -------------------------------------------------------------------------
	local function readLinks()
		demo.wndLinks, demo.layerLinks = {}, {}
		local def = rawget( LW, "def" )
		if type( def ) ~= "table" then return false end
		for _, layer in ipairs( def.layers or {} ) do
			if layer.main and layer.effects then
				for _, eff in ipairs( layer.effects ) do
					for _, l in ipairs( eff.links or {} ) do
						if l.wnd then
							demo.wndLinks[ l.wnd ] = { objName = l.objName, params = l.animParams }
						elseif l.layer then
							local ok, idx = pcall( UI.GetValByName, UI, l.layer )
							if ok and idx then demo.layerLinks[ idx ] = { objName = l.objName, params = l.animParams } end
						end
					end
				end
			end
		end
		return true
	end
	if not readLinks() then log( "LoginWnd.def missing at load; animations disabled" ) end

	local function unlinkWnd( name, w )
		local eff = mainEffect()
		if eff and demo.wndLinks[ name ] and w and w.w then eff:UnlinkWnd( w:GetUiHandle(), "" ) end
	end

	local function relinkWnd( name, w )
		local eff, link = mainEffect(), demo.wndLinks[ name ]
		if eff and link and w and w.w then eff:LinkWnd( w:GetUiHandle(), link.objName, link.params ) end
	end

	local function track( tw )
		if tw then demo.tweens[ #demo.tweens + 1 ] = tw; tw:Play() end
		return tw
	end

	local function trackAuth( tw )
		if tw then demo.authTweens[ #demo.authTweens + 1 ] = tw; tw:Play() end
		return tw
	end

	local function cancelAuthTweens()
		for _, tw in ipairs( demo.authTweens ) do
			if tw.PlaybackState == "Playing" or tw.PlaybackState == "Delayed" then tw:Cancel() end
		end
		demo.authTweens = {}
	end

	-- -------------------------------------------------------------------------
	-- Hover Scale Hook (for SIDE buttons and UI.Login_SteamLogInBtn)
	-- -------------------------------------------------------------------------
	local function hoverBridge( w ) return RbxUI and RbxUI.Bridge and RbxUI.Bridge( w ) end

	-- Ends a hover at once (Scale 1, no lift; the button goes back to its locator) before
	-- other code moves the button itself.
	local function resetHover( w )
		local b = w and hoverBridge( w )
		demo.hover[ w ] = nil
		if b then TS:CancelAll( b ); b:ResetTransform() end
	end
	demo.ResetHover = resetHover

	-- Hover grows the button from its centre (AnchorPoint 0.5, 0.5) and optionally lifts it.
	-- RbxUI's bridge does the pivot maths: effects scale about the window's top-left corner,
	-- which is why a plain effect Scale made the Play button grow towards the right.
	local function hookHover( name, w, customScale, verticalLift )
		if not w or w.__demoHover then return end
		local b = hoverBridge( w )
		if not b then return end
		w.__demoHover = true
		b.AnchorPoint = Vector2.new( 0.5, 0.5 )
		local scaleTarget = customScale or HOVER_SCALE
		local prev = w.UpdateEffectAnimation
		w.UpdateEffectAnimation = function( self, ... )
			if prev then prev( self, ... ) end
			if not demo.played or not self.__demoReady then return end
			local over = self:GetMouseState() ~= UI.MOUSE_OUT
			if over == ( demo.hover[ self ] == true ) then return end
			demo.hover[ self ] = over or nil
			local goal = over and { Scale = scaleTarget, Translation = Vector2.new( 0, -( verticalLift or 0 ) ) }
			                   or { Scale = 1, Translation = Vector2.new( 0, 0 ) }
			local tw = TS:Create( b, TweenInfo.new( HOVER_TIME, "Quad", "Out" ), goal )
			if tw then tw:Play() end
		end
	end

	-- -------------------------------------------------------------------------
	-- Golden Play Button & Welcome Bar Layout + Mounting Helpers
	-- -------------------------------------------------------------------------
	function demo.GetPlayBtnRestRect()
		local btn = UI.Login_SteamLogInBtn
		local bx = btn and btn.w and btn:GetLeft() or 0
		local by = btn and btn.w and btn:GetTop() or 0
		local bw = btn and btn.w and btn:GetWidth() or 0
		local bh = btn and btn.w and btn:GetHeight() or 0
		if bw <= 10 or bh <= 8 then
			bw = SX( 150 )
			bh = SY( 40 )
		end
		if bx <= 0 or by <= 0 then
			bx = 512 - bw * 0.5
			by = SY( 603.127 )
		end
		return bx, by, bw, bh
	end

	function demo.UpdateWelcomeBarLayout( refBx, refBy, refBw, refBh )
		local wb = ensureWelcomeBar()
		if not wb or not wb.w then return 0, 0, 0, 0 end
		local bx, by, bw, bh = refBx, refBy, refBw, refBh
		if not bx then
			if demo.playBtnRest then
				bx, by, bw, bh = demo.playBtnRest[ 1 ], demo.playBtnRest[ 2 ], demo.playBtnRest[ 3 ], demo.playBtnRest[ 4 ]
			else
				bx, by, bw, bh = demo.GetPlayBtnRestRect()
			end
		end
		local textW = wb:MeasureTotalWidth()
		local ww = math.max( bw + SX( 110 ), textW + SX( 28 ) )
		local wh = SY( 22 )
		local wx = ( bx + bw * 0.5 ) - ww * 0.5
		local wy = by + bh + SY( 6 )
		wb:SetLeft( wx )
		wb:SetTop( wy )
		wb:SetWidth( ww )
		wb:SetHeight( wh )
		demo.welcomeRest = { wx, wy, ww, wh }
		return wx, wy, ww, wh
	end

	local function mountFormControls( show )
		if show then
			LW:AddControl( UI.Login_AccountEditWnd,  LW.layers.ACCOUNT_EFFECT,  LW.effectInfo.account.editWndLocator )
			LW:AddControl( UI.Login_PasswordEditWnd, LW.layers.PASSWORD_EFFECT, LW.effectInfo.password.editWndLocator )
			LW:AddControl( UI.Login_RememberCheckBox, LW.layers.MAIN_EFFECT,    LW.effectInfo.main.rememberCheckBoxLocator )
			LW:AddControl( UI.Login_LogInBtn,         LW.layers.MAIN_EFFECT,    LW.effectInfo.main.logInBtnLocator )
			LW:SetLayerVisible( true, LW.layers.ACCOUNT_LABEL )
			LW:SetLayerVisible( true, LW.layers.PASSWORD_LABEL )
			for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
				local eff = UI:GetEffectFromLayer( LW, layer )
				if eff then TS:Set( eff, { Transparency = 0 } ) end
			end
			for _, name in ipairs( FORM_FIELDS ) do
				local w = wndAny( name )
				if w then TS:Set( w, { Transparency = 0 } ) end
			end
		else
			LW:RemoveControl( UI.Login_AccountEditWnd,   LW.layers.ACCOUNT_EFFECT )
			LW:RemoveControl( UI.Login_PasswordEditWnd,  LW.layers.PASSWORD_EFFECT )
			LW:RemoveControl( UI.Login_ForgetBtn,        LW.layers.MAIN_EFFECT )
			LW:RemoveControl( UI.Login_RegisterBtn,      LW.layers.MAIN_EFFECT )
			LW:RemoveControl( UI.Login_RememberCheckBox, LW.layers.MAIN_EFFECT )
			LW:RemoveControl( UI.Login_LogInBtn,         LW.layers.MAIN_EFFECT )
			LW:SetLayerVisible( false, LW.layers.ACCOUNT_LABEL )
			LW:SetLayerVisible( false, LW.layers.PASSWORD_LABEL )
		end
	end

	local function mountQuickPlayControls( show )
		local playBtn = UI.Login_SteamLogInBtn
		local wb = ensureWelcomeBar()
		if show then
			if playBtn and playBtn.w then
				resetHover( playBtn )
				LW:AddControl( playBtn, LW.layers.MAIN_EFFECT, LW.effectInfo.main.steamLogInBtnLocator )
				playBtn:SetText( "Play", playBtn.layers.TEXT )
				playBtn:Enable( LW.waitMode == LW.waitModes.NONE )
				if playBtn.UpdateEffectAnimation then playBtn:UpdateEffectAnimation() end
				hookHover( "UI.Login_SteamLogInBtn", playBtn, PLAY_HOVER_SCL, PLAY_HOVER_LIFT )
				local bx, by, bw, bh = demo.GetPlayBtnRestRect()
				demo.playBtnRest = { bx, by, bw, bh }
			end
			if wb and wb.w then
				if not wb:IsChildOf( LW ) then LW:AddChild( wb ) end
				demo.UpdateWelcomeBarLayout()
			end
		else
			if playBtn and playBtn.w then
				resetHover( playBtn )
				playBtn:SetText( "^login_btnLogin", playBtn.layers.TEXT )
				LW:RemoveControl( playBtn, LW.layers.MAIN_EFFECT )
			end
			if wb and wb.w and wb:IsChildOf( LW ) then
				wb:UnlinkFromParent()
			end
		end
	end

	local function hasRememberedAccount()
		if LW:IsSteamAccount() or LW:IsArcAccount() then return false end
		local cb = UI.Login_RememberCheckBox
		local checked = cb and cb.IsChecked and cb:IsChecked()
		local acc = currentUsername()
		return ( checked and acc ~= "" ) and true or false
	end

	-- -------------------------------------------------------------------------
	-- Minimize Form -> Golden Play Button + Welcome Bar
	-- -------------------------------------------------------------------------
	function demo.MinimizeToPlayBtn( animated )
		if LW:IsSteamAccount() or LW:IsArcAccount() then return end
		cancelAuthTweens()
		demo.isMinimized     = true
		demo.pendingMinimize = false
		demo.ParkFocus()   -- the fields are about to hide; typing must not go into them

		local playBtn = UI.Login_SteamLogInBtn
		local wb      = ensureWelcomeBar()

		if not animated then
			mountFormControls( false )
			mountQuickPlayControls( true )
			local tr = demo.played and 0 or 1
			if playBtn and playBtn.w then
				playBtn.__demoReady = demo.played
				TS:Set( playBtn, { Transparency = tr } )
				if demo.played then
					relinkWnd( "UI.Login_SteamLogInBtn", playBtn )
				else
					unlinkWnd( "UI.Login_SteamLogInBtn", playBtn )
				end
				playBtn:SetText( "Play", playBtn.layers.TEXT )
			end
			if wb and wb.w then
				TS:Set( wb, { Transparency = tr } )
			end
			LW:UpdateLogInBtn()
			return
		end

		-- 1. Smoothly fade & collapse out the form controls
		for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
			local eff = UI:GetEffectFromLayer( LW, layer )
			if eff then
				trackAuth( TS:Create( eff, TweenInfo.new( 0.18, "Quad", "In" ), { Transparency = 1 } ) )
			end
		end
		LW:SetLayerVisible( false, LW.layers.ACCOUNT_LABEL )
		LW:SetLayerVisible( false, LW.layers.PASSWORD_LABEL )

		for _, name in ipairs( FORM_FIELDS ) do
			local w = wndByName( name )
			if w then
				unlinkWnd( name, w )
				local y = w:GetTop()
				trackAuth( TS:Create( w, TweenInfo.new( 0.18, "Quad", "In" ), { Top = y + SY( 10 ), Transparency = 1 } ) )
			end
		end

		-- 2. Mount Golden Play Button & Welcome Bar, then slide down + fade in
		mountQuickPlayControls( true )
		LW:UpdateLogInBtn()

		if playBtn and playBtn.w then
			playBtn.__demoReady = false
			local bx, by, bw, bh = demo.GetPlayBtnRestRect()
			demo.playBtnRest = { bx, by, bw, bh }
			unlinkWnd( "UI.Login_SteamLogInBtn", playBtn )
			playBtn:SetText( "Play", playBtn.layers.TEXT )

			TS:Set( playBtn, { Left = bx, Top = by - SY( 24 ), Transparency = 1 } )

			local slidePlay = trackAuth( TS:Create( playBtn, TweenInfo.new( 0.42, "Back", "Out", 0, false, 0.08 ), { Top = by } ) )
			trackAuth( TS:Create( playBtn, TweenInfo.new( 0.28, "Sine", "Out", 0, false, 0.08 ), { Transparency = 0 } ) )
			if slidePlay then
				slidePlay.Completed:Connect( function( state )
					if demo.isMinimized then
						playBtn.__demoReady = true
						relinkWnd( "UI.Login_SteamLogInBtn", playBtn )
						playBtn:SetText( "Play", playBtn.layers.TEXT )
						mountFormControls( false )
					end
				end )
			end
		end

		if wb and wb.w then
			local wx, wy = demo.UpdateWelcomeBarLayout()
			TS:Set( wb, { Left = wx, Top = wy - SY( 14 ), Transparency = 1 } )
			trackAuth( TS:Create( wb, TweenInfo.new( 0.38, "Cubic", "Out", 0, false, 0.15 ), { Top = wy } ) )
			trackAuth( TS:Create( wb, TweenInfo.new( 0.28, "Sine",  "Out", 0, false, 0.15 ), { Transparency = 0 } ) )
		end
	end

	-- -------------------------------------------------------------------------
	-- Expand Back to E-mail / Password Form ("Click here to change.")
	-- -------------------------------------------------------------------------
	function demo.ExpandToForm( animated, focusPassword )
		if LW:IsSteamAccount() or LW:IsArcAccount() then return end
		cancelAuthTweens()
		demo.isMinimized     = false
		demo.pendingMinimize = false

		if UI.Login_RememberCheckBox and UI.Login_RememberCheckBox.Check then
			UI.Login_RememberCheckBox:Check( false )
		end
		pcall( function() LW:ClearSavedAuthorizationData() end )

		local playBtn = UI.Login_SteamLogInBtn
		local wb      = UI.Login_WelcomeBarBtn

		if not animated then
			mountQuickPlayControls( false )
			mountFormControls( true )
			LW:UpdateLogInBtn()
			LW:UpdateFocus()
			return
		end

		-- 1. Slide up & fade out the Golden Play Button and Welcome Bar
		if playBtn and playBtn.w and playBtn:IsChildOf( LW ) then
			playBtn.__demoReady = false
			resetHover( playBtn )
			unlinkWnd( "UI.Login_SteamLogInBtn", playBtn )
			local by = playBtn:GetTop()
			local hidePlay = trackAuth( TS:Create( playBtn, TweenInfo.new( 0.18, "Quad", "In" ), { Top = by - SY( 18 ), Transparency = 1 } ) )
			if hidePlay then
				hidePlay.Completed:Connect( function()
					if not demo.isMinimized then mountQuickPlayControls( false ) end
				end )
			end
		end
		if wb and wb.w and wb:IsChildOf( LW ) then
			local wy = wb:GetTop()
			trackAuth( TS:Create( wb, TweenInfo.new( 0.16, "Quad", "In" ), { Top = wy - SY( 12 ), Transparency = 1 } ) )
		end

		-- 2. Mount and slide down / fade in the E-mail & Password form
		mountFormControls( true )
		LW:UpdateLogInBtn()

		for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
			local eff = UI:GetEffectFromLayer( LW, layer )
			if eff then
				TS:Set( eff, { Transparency = 1 } )
				trackAuth( TS:Create( eff, TweenInfo.new( 0.28, "Cubic", "Out", 0, false, 0.10 ), { Transparency = 0 } ) )
			end
		end

		for i, name in ipairs( FORM_FIELDS ) do
			local w = wndByName( name )
			if w then
				relinkWnd( name, w )
				local restY = w:GetTop()
				local d = 0.08 + 0.025 * i
				if name == "UI.Login_LogInBtn" or name == "UI.Login_RememberCheckBox" then
					unlinkWnd( name, w )
					TS:Set( w, { Top = restY - SY( 10 ), Transparency = 1 } )
					local sl = trackAuth( TS:Create( w, TweenInfo.new( 0.28, "Cubic", "Out", 0, false, d ), { Top = restY } ) )
					if sl then
						sl.Completed:Connect( function()
							if not demo.isMinimized then relinkWnd( name, w ) end
						end )
					end
					trackAuth( TS:Create( w, TweenInfo.new( 0.24, "Sine", "Out", 0, false, d ), { Transparency = 0 } ) )
				else
					TS:Set( w, { Transparency = 1 } )
					trackAuth( TS:Create( w, TweenInfo.new( 0.28, "Cubic", "Out", 0, false, d ), { Transparency = 0 } ) )
				end
			end
		end

		local targetEw = nil
		if focusPassword and UI.Login_PasswordEditWnd and UI.Login_PasswordEditWnd.w then
			targetEw = UI.Login_PasswordEditWnd
		elseif UI.Login_AccountEditWnd and UI.Login_AccountEditWnd.w then
			targetEw = UI.Login_AccountEditWnd
		end

		if targetEw then
			UI:SetKeyboardFocus( targetEw:GetUiHandle() )   -- native focus selects the text
		else
			LW:UpdateFocus()
		end
	end

	-- -------------------------------------------------------------------------
	-- Patch Name Pulse & Intro Boot Sequence
	-- -------------------------------------------------------------------------
	local function startPatchPulse( patch )
		if demo.pulse then demo.pulse:Cancel() end
		TS:Set( patch, { Color = WHITE } )
		demo.pulse = TS:Create( patch, TweenInfo.new( 1.2, "Sine", "InOut", -1, true ), { Color = GOLD } )
		demo.pulse:Play()
	end

	function demo.PlayIntro()
		demo.played = true
		demo.tweens = {}
		demo.screen = { UI.screenWidth, UI.screenHeight }
		if not next( demo.wndLinks ) then return end   -- no locators known: leave the screen as is

		-- 0. Cinematic background: fade in from pure black while smoothly zooming out
		TS:Set( demo.bg, { Scale = BG_ZOOM_START, Color = BLACK } )
		track( TS:Create( demo.bg, TweenInfo.new( BG_FADE_TIME, "Sine",  "Out" ), { Color = WHITE } ) )
		track( TS:Create( demo.bg, TweenInfo.new( BG_ZOOM_TIME, "Cubic", "Out" ), { Scale = 1 } ) )

		-- UI chrome (top-left logo + bottom dark bar) and status/version text layers
		local bg3 = UI:GetEffectFromLayer( LW, LW.layers.BG3_EFFECT )
		if bg3 then
			TS:Set( bg3, { Transparency = 1 } )
			track( TS:Create( bg3, TweenInfo.new( 0.55, "Sine", "Out", 0, false, UI_START_DELAY ), { Transparency = 0 } ) )
		end
		for _, layer in ipairs( TEXT_LAYERS ) do
			if layer then
				local lyr = TS:Layer( LW, layer )
				TS:Set( lyr, { Transparency = 1 } )
				track( TS:Create( lyr, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.05 ), { Transparency = 0 } ) )
			end
		end

		-- 1. side buttons: from 160 Rel units right of their slot, staggered after UI_START_DELAY; re-linked on arrival
		local n = 0
		for _, name in ipairs( SIDE ) do
			local w = wndByName( name )
			if w then
				w.__demoReady = false
				unlinkWnd( name, w )
				local x = w:GetLeft()
				TS:Set( w, { Left = x + 160, Transparency = 1 } )
				local delay = UI_START_DELAY + 0.05 + 0.055 * n
				local slide = track( TS:Create( w, TweenInfo.new( 0.6, "Back", "Out", 0, false, delay ), { Left = x } ) )
				slide.Completed:Connect( function() w.__demoReady = true; relinkWnd( name, w ) end )   -- also on Cancel
				track( TS:Create( w, TweenInfo.new( 0.3, "Quad", "Out", 0, false, delay ), { Transparency = 0 } ) )
				n = n + 1
			end
		end

		-- 2. Authorization area: either Minimized Quick-Play (Golden Play Button + Welcome Bar)
		--    or Expanded Form (Account, Password, Remember Me, Log In)
		if demo.isMinimized then
			mountFormControls( false )
			mountQuickPlayControls( true )
			local playBtn = UI.Login_SteamLogInBtn
			local wb      = ensureWelcomeBar()
			if playBtn and playBtn.w and playBtn:IsChildOf( LW ) then
				playBtn.__demoReady = false
				local bx, by, bw, bh = demo.GetPlayBtnRestRect()
				demo.playBtnRest = { bx, by, bw, bh }
				unlinkWnd( "UI.Login_SteamLogInBtn", playBtn )
				playBtn:SetText( "Play", playBtn.layers.TEXT )

				-- Transparency goes through RbxUI's native bridge, which also fades the
				-- link-coloured "Play" label (the engine ignores alpha on that layer)
				TS:Set( playBtn, { Left = bx, Top = by - SY( 26 ), Transparency = 1 } )

				-- Entrance staggered alongside menu items, dropping in last
				local d = UI_START_DELAY + 0.48
				local sl = track( TS:Create( playBtn, TweenInfo.new( 0.48, "Back", "Out", 0, false, d ), { Top = by } ) )
				track( TS:Create( playBtn, TweenInfo.new( 0.32, "Sine", "Out", 0, false, d ), { Transparency = 0 } ) )
				if sl then
					sl.Completed:Connect( function()
						if demo.isMinimized then
							playBtn.__demoReady = true
							relinkWnd( "UI.Login_SteamLogInBtn", playBtn )
							playBtn:SetText( "Play", playBtn.layers.TEXT )
						end
					end )
				end
			end
			if wb and wb.w and wb:IsChildOf( LW ) then
				local wx, wy = demo.UpdateWelcomeBarLayout()
				TS:Set( wb, { Left = wx, Top = wy - SY( 14 ), Transparency = 1 } )
				local d = UI_START_DELAY + 0.60
				track( TS:Create( wb, TweenInfo.new( 0.40, "Cubic", "Out", 0, false, d ), { Top = wy } ) )
				track( TS:Create( wb, TweenInfo.new( 0.30, "Sine",  "Out", 0, false, d ), { Transparency = 0 } ) )
			end
		else
			for i, name in ipairs( FORM_FIELDS ) do
				local w = wndByName( name )
				if w then
					TS:Set( w, { Transparency = 1 } )
					track( TS:Create( w, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.15 + 0.04 * i ), { Transparency = 0 } ) )
				end
			end
			for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
				local eff = UI:GetEffectFromLayer( LW, layer )
				if eff then
					TS:Set( eff, { Transparency = 1 } )
					track( TS:Create( eff, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.15 ), { Transparency = 0 } ) )
				end
			end
		end

		-- Server Selector dock/controls fade in
		for i, name in ipairs( SERVER_UI ) do
			local w = wndByName( name )
			if w then
				TS:Set( w, { Transparency = 1 } )
				track( TS:Create( w, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.12 + 0.03 * i ), { Transparency = 0 } ) )
			end
		end

		-- 3. patch name fade-in + pulse: re-link the layer without COLOR so the engine keeps placing it
		local eff, pn = mainEffect(), LW.layers.PATCH_NAME
		local link = demo.layerLinks[ pn ]
		if eff and link and math.floor( link.params / COLOR_BIT ) % 2 == 1 then
			local ok = pcall( eff.UnlinkLayer, eff, LW:GetUiHandle(), pn )
			if ok then
				eff:LinkLayer( LW:GetUiHandle(), pn, link.objName, link.params - COLOR_BIT )
				local patch = TS:Layer( LW, pn )
				TS:Set( patch, { Color = 0x00FFFFFF } )
				local fade = track( TS:Create( patch, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.05 ), { Color = WHITE } ) )
				if fade then
					fade.Completed:Connect( function( state )
						if state == "Completed" then startPatchPulse( patch ) end
					end )
				else
					startPatchPulse( patch )
				end
			else
				log( "UnlinkLayer unavailable; patch-name pulse skipped" )
			end
		end
	end

	-- Screen size changed while something was mid-animation: finish everything at once
	-- and hand every window back to its link.
	function demo.SnapToLinks()
		for _, tw in ipairs( demo.tweens ) do
			if tw.PlaybackState == "Playing" or tw.PlaybackState == "Delayed" then tw:Cancel() end
		end
		demo.tweens = {}
		cancelAuthTweens()
		TS:CancelAll( demo.bg )
		TS:Set( demo.bg, { Scale = 1, Color = WHITE } )

		local bg3 = UI:GetEffectFromLayer( LW, LW.layers.BG3_EFFECT )
		if bg3 then TS:CancelAll( bg3 ); TS:Set( bg3, { Transparency = 0 } ) end
		for _, layer in ipairs( TEXT_LAYERS ) do
			if layer then
				local lyr = TS:Layer( LW, layer )
				TS:CancelAll( lyr )
				TS:Set( lyr, { Transparency = 0 } )
			end
		end

		for _, name in ipairs( SIDE ) do
			local w = wndByName( name )
			if w then
				w.__demoReady = true
				resetHover( w )
				TS:CancelAll( w )
				TS:Set( w, { Transparency = 0 } )
				relinkWnd( name, w )
			end
		end

		if demo.isMinimized then
			mountFormControls( false )
			mountQuickPlayControls( true )
			local playBtn = UI.Login_SteamLogInBtn
			if playBtn and playBtn.w then
				playBtn.__demoReady = true
				resetHover( playBtn )
				TS:CancelAll( playBtn )
				TS:Set( playBtn, { Transparency = 0 } )
				relinkWnd( "UI.Login_SteamLogInBtn", playBtn )
				playBtn:SetText( "Play", playBtn.layers.TEXT )
				local bx, by, bw, bh = demo.GetPlayBtnRestRect()
				demo.playBtnRest = { bx, by, bw, bh }
			end
			local wb = UI.Login_WelcomeBarBtn
			if wb and wb.w then
				TS:CancelAll( wb )
				TS:Set( wb, { Transparency = 0 } )
				demo.UpdateWelcomeBarLayout()
			end
		else
			mountQuickPlayControls( false )
			mountFormControls( true )
			for _, name in ipairs( FORM_FIELDS ) do
				local w = wndByName( name )
				if w then TS:CancelAll( w ); TS:Set( w, { Transparency = 0 } ); relinkWnd( name, w ) end
			end
			for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
				local eff = UI:GetEffectFromLayer( LW, layer )
				if eff then TS:CancelAll( eff ); TS:Set( eff, { Transparency = 0 } ) end
			end
		end

		for _, name in ipairs( SERVER_UI ) do
			local w = wndByName( name )
			if w then TS:CancelAll( w ); TS:Set( w, { Transparency = 0 } ) end
		end
		if LW.layers.PATCH_NAME and demo.layerLinks[ LW.layers.PATCH_NAME ] then
			local patch = TS:Layer( LW, LW.layers.PATCH_NAME )
			if not demo.pulse or demo.pulse.PlaybackState ~= "Playing" then
				startPatchPulse( patch )
			end
		end
		demo.hover = {}
	end

	-- -------------------------------------------------------------------------
	-- Hooks on UI.LoginWnd for Quick-Play / Remember Me Integration
	-- -------------------------------------------------------------------------
	local prevUpdateAuth = LW.UpdateAuthorizationControls
	LW.UpdateAuthorizationControls = function( self, ... )
		if prevUpdateAuth then prevUpdateAuth( self, ... ) end
		if not self:IsSteamAccount() and not self:IsArcAccount() then
			if hasRememberedAccount() then
				if demo.played then
					demo.MinimizeToPlayBtn( false )
				else
					demo.isMinimized = true
				end
			else
				demo.isMinimized = false
				mountQuickPlayControls( false )
			end
		end
	end

	local prevRestoreUiState = LW.RestoreUiState
	LW.RestoreUiState = function( self, ... )
		if prevRestoreUiState then prevRestoreUiState( self, ... ) end
		if not self:IsSteamAccount() and not self:IsArcAccount() then
			if hasRememberedAccount() then
				if demo.played then
					demo.MinimizeToPlayBtn( false )
				else
					demo.isMinimized = true
				end
			else
				demo.isMinimized = false
				mountQuickPlayControls( false )
			end
		end
	end

	local prevUpdateLogInBtn = LW.UpdateLogInBtn
	LW.UpdateLogInBtn = function( self, ... )
		if prevUpdateLogInBtn then prevUpdateLogInBtn( self, ... ) end
		if demo.isMinimized and UI.Login_SteamLogInBtn and UI.Login_SteamLogInBtn.w then
			-- Keep the Golden Play Button bright, clickable, and labeled "Play" in Quick-Play mode
			UI.Login_SteamLogInBtn:Enable( self.waitMode == self.waitModes.NONE )
			UI.Login_SteamLogInBtn:SetText( "Play", UI.Login_SteamLogInBtn.layers.TEXT )
		end
	end

	local prevOnRemember = LW.OnRememberAccount
	LW.OnRememberAccount = function( self, ... )
		if prevOnRemember then prevOnRemember( self, ... ) end
		local cb = UI.Login_RememberCheckBox
		if cb and cb.IsChecked and cb:IsChecked() then
			if currentUsername() ~= "" then
				self:SaveAuthorizationData()
				demo.MinimizeToPlayBtn( true )
			else
				demo.pendingMinimize = true
			end
		else
			demo.pendingMinimize = false
		end
	end

	local prevOnLogIn = LW.OnLogIn
	LW.OnLogIn = function( self, ... )
		if demo.isMinimized and not self:IsUsingSteamAccount() and not self:IsUsingArcAccount() then
			local status = self:GetLoginStatus()
			if status == self.loginStatuses.EMPTY_PASSWORD then
				demo.ExpandToForm( true, true )
				return
			elseif status == self.loginStatuses.EMPTY_ACCOUNT then
				demo.ExpandToForm( true, false )
				return
			end
		end
		if not self:IsUsingSteamAccount() and not self:IsUsingArcAccount() then
			if UI.Login_RememberCheckBox and UI.Login_RememberCheckBox.IsChecked and UI.Login_RememberCheckBox:IsChecked() then
				self:SaveAuthorizationData()
			end
		end
		if prevOnLogIn then return prevOnLogIn( self, ... ) end
	end

	-- Typing is left to the engine (TYPING_AUDIT.md): the native EffectEditWnd handlers select
	-- the text on focus, clear it on blur and place the caret on a second click. The hooks below
	-- only add click-away, Tab order and Quick-Play, and always run the inherited handler.

	-- A focused field reports every mouse-down (EV_MOUSE_BUTTON_DOWN); vanilla answers a miss
	-- with ResetFocus. When the click landed outside every field, also take focus off the field.
	local prevOnEditMiss = LW.OnEditMissMouse
	LW.OnEditMissMouse = function( self, editWnd, ... )
		local res
		if prevOnEditMiss then res = prevOnEditMiss( self, editWnd, ... ) end
		local mx, my = UI:GetMouseX(), UI:GetMouseY()
		if not editFieldAt( mx, my ) then demo.ParkFocus() end
		return res
	end

	local prevOnTab = LW.OnTab
	LW.OnTab = function( self, ... )
		if self.waitMode == self.waitModes.NONE then
			if demo.isMinimized then return true end   -- the fields are hidden in Quick-Play
			if demo.FocusNextField( shiftHeld() ) then return true end
		end
		if prevOnTab then return prevOnTab( self, ... ) end
	end

	local prevLButtonDown = LW.F_OnMouseLButtonDown
	LW.F_OnMouseLButtonDown = function( self, mouseX, mouseY, wndThatReceivedInput )
		local wnd = UI:GetUiObjByHandleT( wndThatReceivedInput )
		if wnd and UI.Login_WelcomeBarBtn and ( wnd == UI.Login_WelcomeBarBtn or ( wnd.IsChildOf and wnd:IsChildOf( UI.Login_WelcomeBarBtn ) ) ) then
			demo.ExpandToForm( true, false )
			return true
		end
		if prevLButtonDown then return prevLButtonDown( self, mouseX, mouseY, wndThatReceivedInput ) end
		return false
	end

	for _, editKey in ipairs( EDIT_FIELDS ) do
		local ew = UI[ editKey ]
		if ew then
			ew.F_OnLostKeyboardFocus = function( self, ... )
				local res = protoCall( self, "F_OnLostKeyboardFocus", ... )
				if demo.pendingMinimize then demo.minimizeCheck = true end   -- decided next frame
				return res
			end

			-- Tab is handled here rather than relying on the key bubbling up to LoginWnd
			ew.F_OnKeyboardKeyDown = function( self, key, wndThatReceivedInput )
				if key == UI.Keys.KEY_TAB and getEditFieldFromWnd( self ) and LW:IsOnScreen()
				   and LW.waitMode == LW.waitModes.NONE and demo.FocusNextField( shiftHeld() ) then
					return true
				end
				return protoCall( self, "F_OnKeyboardKeyDown", key, wndThatReceivedInput )
			end

			-- CursorTwinkle (effecteditwnd.lua) re-shows the native caret on every loop and every
			-- keystroke; on the login fields the custom caret replaces it, so keep it hidden.
			ew.SetLayerVisible = function( self, bVisible, layerIdx, ... )
				if self.layers and layerIdx == self.layers.CURSOR then bVisible = false end
				return protoCall( self, "SetLayerVisible", bVisible, layerIdx, ... )
			end
		end
	end

	-- Remember-me ticked before the form was filled: minimize once focus has left the form
	-- with both fields filled (not on every field switch, which collapsed the form mid-edit).
	local function checkPendingMinimize()
		if not demo.minimizeCheck then return end
		demo.minimizeCheck = false
		if not demo.pendingMinimize or demo.isMinimized then return end
		if getEditFieldFromWnd( UI:GetUiObjByHandleT( UI:GetKeyboardFocus() ) ) then return end
		local pass = ( UI.Login_PasswordEditWnd and UI.Login_PasswordEditWnd:GetEditText() ) or ""
		if currentUsername() ~= "" and pass ~= "" then
			LW:SaveAuthorizationData()
			demo.MinimizeToPlayBtn( true )
		end
	end

	-- -------------------------------------------------------------------------
	-- Frame Tick, Hover Poll for WelcomeBarBtn, and Lifecycle Hooks
	-- -------------------------------------------------------------------------
	TS:Attach( LW )
	local prevFrame = LW.F_OnNewFrame
	local function start()
		if not LW:IsSteamAccount() and not LW:IsArcAccount() and hasRememberedAccount() then
			demo.isMinimized = true
		end
		demo.PlayIntro()
		for _, name in ipairs( SIDE ) do
			local w = wndByName( name )
			if w then hookHover( name, w, HOVER_SCALE ) end
		end
		if UI.Login_SteamLogInBtn and UI.Login_SteamLogInBtn.w then
			hookHover( "UI.Login_SteamLogInBtn", UI.Login_SteamLogInBtn, PLAY_HOVER_SCL, PLAY_HOVER_LIFT )
		end
	end

	LW.F_OnNewFrame = function( self, hSender, dt_sys, dt_game )
		if prevFrame then prevFrame( self, hSender, dt_sys, dt_game ) end
		if not demo.played then
			demo.played = true
			local ok, err = pcall( start )
			if not ok then log( "intro failed: %s", tostring( err ) ) end
		elseif demo.screen and ( demo.screen[ 1 ] ~= UI.screenWidth or demo.screen[ 2 ] ~= UI.screenHeight ) then
			demo.screen = { UI.screenWidth, UI.screenHeight }
			local ok, err = pcall( demo.SnapToLinks )
			if not ok then log( "resize handling failed: %s", tostring( err ) ) end
		end

		-- Poll hover state on UI.Login_WelcomeBarBtn for smooth hover transitions
		local wb = UI.Login_WelcomeBarBtn
		if demo.isMinimized and wb and wb.w and wb:IsOnScreen() then
			local over = wb.isOver or ( wb.GetMouseState and wb:GetMouseState() ~= UI.MOUSE_OUT ) or false
			if over ~= wb.lastOver then
				wb.lastOver = over
				if wb.hoverTween then wb.hoverTween:Cancel() end
				wb.hoverTween = TS:Create( wb, TweenInfo.new( 0.09, "Quad", "Out" ), { hoverMix = over and 1 or 0 } )
				if wb.hoverTween then wb.hoverTween:Play() end
			end
		end

		-- Focus changed (click, Tab, park): settle the field frames' select / deselect glow
		local focus = UI:GetKeyboardFocus()
		if focus ~= demo.lastFocus then
			demo.lastFocus = focus
			refreshEditGlow()
		end
		checkPendingMinimize()

		-- Drive custom blinking typing cursor tied directly to keyboard focus
		updateCustomCursor( dt_sys )
	end

	-- Sync owner-drawn warningMetaText ("Retrieving server list") with the WARNING layer's alpha
	local prevDrawLayer = LW.F_DrawLayer
	LW.F_DrawLayer = function( self, x0, y0, width, height, clipX0, clipY0, clipWidth, clipHeight, layerIdx )
		if layerIdx == self.layers.WARNING and self.warningMetaText and self.warningMetaText.SetAlpha and UI.GetAlpha then
			local a = UI:GetAlpha( self:GetColor( self.layers.WARNING ) )
			if a <= 0 then return end
			self.warningMetaText:SetAlpha( a )
		end
		if prevDrawLayer then return prevDrawLayer( self, x0, y0, width, height, clipX0, clipY0, clipWidth, clipHeight, layerIdx ) end
	end

	-- Replay next time the login screen opens
	local prevHide = LW.F_OnAfterHideFromScreen
	LW.F_OnAfterHideFromScreen = function( self, ... )
		hideCustomCursor()
		if demo.played then pcall( demo.SnapToLinks ) end
		demo.played = false
		if prevHide then return prevHide( self, ... ) end
	end
end
-- END LOGIN_TWEEN_DEMO

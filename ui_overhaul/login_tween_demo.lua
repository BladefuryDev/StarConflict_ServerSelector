-- BEGIN LOGIN_TWEEN_DEMO
-- ============================================================================
-- Demo: cinematic animated login screen built on TweenService (append after
-- tweenservice.lua to data/ui/scripts/windows/loginwnd.lua, or in scui:
--   python -m scui run examples/login_tween_demo.json
--       --mod mods/tweenservice.lua --mod mods/login_tween_demo.lua --out-dir shots)
--
-- Boot sequence:
-- * Smoothly fades in from pure black (seamless handoff from the initial loading
--   screen with the loading circle) while the space background starts slightly
--   zoomed in (1.10x, centered) and smoothly zooms out to 1.0x.
-- * Shortly after the fade/zoom begins, the UI chrome (top-left logo & bottom bar),
--   login fields, Server Selector dock/buttons, and staggered right-hand menu
--   column animate in.
-- * "Legacy of the Precursors" fades in and then pulses between white and login
--   accent gold.
-- * Side buttons grow slightly on hover (via UpdateEffectAnimation, a Lua-to-Lua
--   call, so it works no matter how the engine dispatches F_ callbacks).
--
-- Layout rule: windows and layers are placed by locators in login_main.sanim
-- (links on LoginWnd's MAIN_EFFECT), which the engine re-applies for every screen
-- size. To animate one we unlink it, and we re-link it as soon as the animation ends,
-- so resolution changes and windowed resizes keep working natively. If the screen
-- size changes mid-animation, everything snaps back to its links and resting state.
-- ============================================================================
do
	local TS = TweenService
	if not TS then return end

	local LW = UI.LoginWnd
	local demo = { played = false, tweens = {}, hover = {} }
	LoginTweenDemo = demo

	local SIDE = { "UI.Login_OptionsBtn", "UI.Login_StartServerBtn", "UI.Login_SiteBtn", "UI.Login_CreditsBtn",
	               "UI.Login_LicenseBtn", "UI.Login_PrivacyPolicyBtn", "UI.Login_TermsOfUseBtn", "UI.Login_QuitBtn" }
	local FIELDS = { "UI.Login_AccountEditWnd", "UI.Login_PasswordEditWnd", "UI.Login_RememberCheckBox", "UI.Login_LogInBtn",
	                 "UI.Login_ForgetBtn", "UI.Login_RegisterBtn", "UI.Login_SteamLogInBtn", "UI.Login_ArcLogInBtn" }
	local SERVER_UI = { "UI.Login_ServerDockWnd", "UI.Login_ServersComboBox", "UI.Login_AddServerBtn",
	                    "UI.Login_DefaultServerBtn", "UI.Login_DeleteServerBtn", "UI.Login_ServerNameEditWnd",
	                    "UI.Login_ServerPortEditWnd", "UI.NewsWnd" }
	local TEXT_LAYERS = { LW.layers.BUILD_VERSION, LW.layers.WARNING, LW.layers.SERVER_STATUS,
	                      LW.layers.STEAM_LOGIN_TIP, LW.layers.ARC_LOGIN_TIP }

	local GOLD, WHITE, BLACK = 0xFFFFD200, 0xFFFFFFFF, 0xFF000000
	local COLOR_BIT      = UI.EffectAnimParams.COLOR
	local BG_ZOOM_START  = 1.10    -- initial centered zoom on the background artwork
	local BG_ZOOM_TIME   = 1.60    -- smooth zoom-out duration (s)
	local BG_FADE_TIME   = 0.90    -- fade-in from black duration (s)
	local UI_START_DELAY = 0.35    -- beat before UI menu elements begin loading in (s)
	local HOVER_TIME     = 0.075   -- half of the original 0.15s hover duration
	local HOVER_SCALE    = 1.04    -- subtle 4% grow from the button's centre

	local function log( fmt, ... ) if sys and sys.log then pcall( sys.log, "LoginTweenDemo: " .. fmt, ... ) end end

	local function wndByName( name )
		local ok, t = pcall( UI.GetValByName, UI, name )
		return ( ok and t and t.w and t:IsOnScreen() ) and t or nil
	end

	local function mainEffect() return UI:GetEffectFromLayer( LW, LW.layers.MAIN_EFFECT ) end

	-- Applies centered scale (around Rel 512, 384) and color tint to the background
	-- artwork layers (BG_EFFECT and BG2_EFFECT). Using opaque black tint (0xFF000000)
	-- at t=0 rather than alpha=0 guarantees the 3D scene behind LoginWnd never bleeds
	-- through during the fade-in from black.
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

	-- The main effect's links, read from LoginWnd's own def:
	--   demo.wndLinks[ "UI.Login_OptionsBtn" ] = { objName = "btn_2_3", params = POS }
	--   demo.layerLinks[ layerIdx ]            = { objName = "version1", params = ... }
	-- Must run at script load: the engine drops UI.LoginWnd.def once the window is
	-- built (reading it later fails with "attempt to index field 'def' (a nil value)").
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
		if eff and demo.wndLinks[ name ] then eff:UnlinkWnd( w:GetUiHandle(), "" ) end
	end

	local function relinkWnd( name, w )
		local eff, link = mainEffect(), demo.wndLinks[ name ]
		if eff and link and w.w then eff:LinkWnd( w:GetUiHandle(), link.objName, link.params ) end
	end

	local function track( tw )
		if tw then demo.tweens[ #demo.tweens + 1 ] = tw; tw:Play() end
		return tw
	end

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

		-- 2. login fields, Server Selector dock/controls, and slot backgrounds fade in shortly after
		--    (capture child window base alphas before setting ACCOUNT_EFFECT / PASSWORD_EFFECT alpha to 0)
		for i, name in ipairs( FIELDS ) do
			local w = wndByName( name )
			if w then
				TS:Set( w, { Transparency = 1 } )
				track( TS:Create( w, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.15 + 0.04 * i ), { Transparency = 0 } ) )
			end
		end
		for i, name in ipairs( SERVER_UI ) do
			local w = wndByName( name )
			if w then
				TS:Set( w, { Transparency = 1 } )
				track( TS:Create( w, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.12 + 0.03 * i ), { Transparency = 0 } ) )
			end
		end
		for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
			local eff = UI:GetEffectFromLayer( LW, layer )
			if eff then
				TS:Set( eff, { Transparency = 1 } )
				track( TS:Create( eff, TweenInfo.new( 0.5, "Sine", "Out", 0, false, UI_START_DELAY + 0.15 ), { Transparency = 0 } ) )
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
				TS:CancelAll( w )
				local eff = UI:GetEffectFromLayer( w, w.layers.MAIN_EFFECT )
				if eff then TS:CancelAll( eff ); TS:Set( eff, { Scale = 1 } ) end
				TS:Set( w, { Transparency = 0 } )
				relinkWnd( name, w )
			end
		end
		for _, name in ipairs( FIELDS ) do
			local w = wndByName( name )
			if w then TS:CancelAll( w ); TS:Set( w, { Transparency = 0 } ) end
		end
		for _, name in ipairs( SERVER_UI ) do
			local w = wndByName( name )
			if w then TS:CancelAll( w ); TS:Set( w, { Transparency = 0 } ) end
		end
		for _, layer in ipairs( { LW.layers.ACCOUNT_EFFECT, LW.layers.PASSWORD_EFFECT } ) do
			local eff = UI:GetEffectFromLayer( LW, layer )
			if eff then TS:CancelAll( eff ); TS:Set( eff, { Transparency = 0 } ) end
		end
		if LW.layers.PATCH_NAME and demo.layerLinks[ LW.layers.PATCH_NAME ] then
			local patch = TS:Layer( LW, LW.layers.PATCH_NAME )
			if not demo.pulse or demo.pulse.PlaybackState ~= "Playing" then
				startPatchPulse( patch )
			end
		end
		demo.hover = {}
	end

	-- hover grow for the side buttons: unlinked only while hovered or easing back
	local function hookHover( name, w )
		if w.__demoHover then return end
		w.__demoHover = true
		local prev = w.UpdateEffectAnimation
		w.UpdateEffectAnimation = function( self, ... )
			if prev then prev( self, ... ) end
			if not demo.played or not self.__demoReady then return end
			local eff = UI:GetEffectFromLayer( self, self.layers.MAIN_EFFECT )
			if not eff then return end
			local over = self:GetMouseState() ~= UI.MOUSE_OUT
			local h = demo.hover[ self ]
			if over and ( not h or h.back ) then
				if not h then
					unlinkWnd( name, self )
					h = { x = self:GetLeft(), y = self:GetTop(), w = self:GetWidth(), h = self:GetHeight() }
					demo.hover[ self ] = h
				else
					if h.backPos then h.backPos:Cancel() end
					if h.backScale then h.backScale:Cancel() end
					h.back = nil
				end
				local dx = h.w * ( HOVER_SCALE - 1 ) * 0.5
				local dy = h.h * ( HOVER_SCALE - 1 ) * 0.5
				local info = TweenInfo.new( HOVER_TIME, "Quad", "Out" )
				h.twPos   = TS:Create( self, info, { Left = h.x - dx, Top = h.y - dy } )
				h.twScale = TS:Create( eff,  info, { Scale = HOVER_SCALE } )
				h.twPos:Play()
				h.twScale:Play()
			elseif not over and h and not h.back then
				h.back = true
				local info = TweenInfo.new( HOVER_TIME, "Quad", "Out" )
				h.backPos   = TS:Create( self, info, { Left = h.x, Top = h.y } )
				h.backScale = TS:Create( eff,  info, { Scale = 1 } )
				h.backPos.Completed:Connect( function( state )
					if state == "Completed" and demo.hover[ self ] == h then
						demo.hover[ self ] = nil
						TS:Set( eff, { Scale = 1 } )
						relinkWnd( name, self )
					end
				end )
				h.backPos:Play()
				h.backScale:Play()
			end
		end
	end

	-- drive TweenService from the login window and start the intro on its first frame
	TS:Attach( LW )
	local prevFrame = LW.F_OnNewFrame
	local function start()
		demo.PlayIntro()
		for _, name in ipairs( SIDE ) do
			local w = wndByName( name )
			if w then hookHover( name, w ) end
		end
	end
	LW.F_OnNewFrame = function( self, hSender, dt_sys, dt_game )
		-- the login's own frame logic (server status, timers) always runs first
		if prevFrame then prevFrame( self, hSender, dt_sys, dt_game ) end
		if not demo.played then
			demo.played = true      -- never retried every frame if something fails
			local ok, err = pcall( start )
			if not ok then log( "intro failed: %s", tostring( err ) ) end
		elseif demo.screen and ( demo.screen[ 1 ] ~= UI.screenWidth or demo.screen[ 2 ] ~= UI.screenHeight ) then
			demo.screen = { UI.screenWidth, UI.screenHeight }
			local ok, err = pcall( demo.SnapToLinks )
			if not ok then log( "resize handling failed: %s", tostring( err ) ) end
		end
	end

	-- sync owner-drawn warningMetaText ("Retrieving server list") with the WARNING layer's alpha
	local prevDrawLayer = LW.F_DrawLayer
	LW.F_DrawLayer = function( self, x0, y0, width, height, clipX0, clipY0, clipWidth, clipHeight, layerIdx )
		if layerIdx == self.layers.WARNING and self.warningMetaText and self.warningMetaText.SetAlpha and UI.GetAlpha then
			local a = UI:GetAlpha( self:GetColor( self.layers.WARNING ) )
			if a <= 0 then return end
			self.warningMetaText:SetAlpha( a )
		end
		if prevDrawLayer then return prevDrawLayer( self, x0, y0, width, height, clipX0, clipY0, clipWidth, clipHeight, layerIdx ) end
	end

	-- replay next time the login screen opens
	local prevHide = LW.F_OnAfterHideFromScreen
	LW.F_OnAfterHideFromScreen = function( self, ... )
		if demo.played then pcall( demo.SnapToLinks ) end
		demo.played = false
		if prevHide then return prevHide( self, ... ) end
	end
end
-- END LOGIN_TWEEN_DEMO

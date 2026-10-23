-- BEGIN TWEENSERVICE
-- ============================================================================
-- TweenService for Star Conflict UI mods (Lua 5.1, no C++ changes needed).
-- Modelled on Roblox's TweenService:
--
--   local info  = TweenInfo.new( 0.4, "Quad", "Out" )            -- time (s), style, direction,
--                                                                -- repeatCount, reverses, delayTime
--   local tween = TweenService:Create( UI.Login_LogInBtn, info, { Left = 300, Transparency = 0 } )
--   tween.Completed:Connect( function( state ) ... end )
--   tween:Play()            -- also :Pause(), :Cancel(), :Destroy(); tween.PlaybackState
--
-- Driving it: the game has no global tick for mods, so tweens advance from a
-- window's per-frame callback. TweenService:Attach( UI.LoginWnd ) chains
-- F_OnNewFrame( hSender, dt_sys, dt_game ) (dt in seconds) and adds
-- WS_UPDATE_IF_VISIBLE so the engine calls it while the window is on screen.
-- Or call TweenService:Step( dt ) yourself.
--
-- Targets and properties (add your own via TweenService.Adapters):
--   window table (UI.SomeWnd)   Left Top Width Height (Rel units, 1024x768 space),
--                               Position {x, y} or Vec2, Size {x, y} or Vec2, Rect (Quat),
--                               Transparency 0..1 (all layers, their effects, and child windows)
--   TweenService:Layer( wnd, idx )  Color (ARGB), Transparency, Left Top Width Height (layer rect)
--   effect userdata             Scale (number or Vec2), Alpha (0..255, the engine's unit), Transparency 0..1, Color, AnimTime
--   plain Lua table             any numeric / colour / {x, y} field (like Roblox NumberValue);
--                               an optional `OnChanged( t )` field is called after each step
-- Values: numbers, ARGB colours (props whose name contains "Color"), Vec2 / Quat
-- userdata, and tables of numbers.
-- ============================================================================
do
	local TS = TweenService or {}
	TweenService = TS
	TS.active = {}                      -- playing / delayed tweens
	TS.version = "1.0"

	local floor, cos, sin, pi, sqrt, abs = math.floor, math.cos, math.sin, math.pi, math.sqrt, math.abs

	local function log( fmt, ... )
		if sys and sys.log then pcall( sys.log, "TweenService: " .. fmt, ... ) end
	end

	-- ------------------------------------------------------------- enums
	local Enum_ = {
		EasingStyle = { Linear = "Linear", Sine = "Sine", Quad = "Quad", Cubic = "Cubic", Quart = "Quart",
		                Quint = "Quint", Exponential = "Exponential", Circular = "Circular", Back = "Back",
		                Elastic = "Elastic", Bounce = "Bounce" },
		EasingDirection = { In = "In", Out = "Out", InOut = "InOut" },
		PlaybackState = { Begin = "Begin", Delayed = "Delayed", Playing = "Playing", Paused = "Paused",
		                  Completed = "Completed", Cancelled = "Cancelled" },
	}
	TS.Enum = Enum_
	if Enum == nil then Enum = Enum_ end

	-- ------------------------------------------------------------- easing
	local function bounceOut( t )
		if t < 1 / 2.75 then return 7.5625 * t * t
		elseif t < 2 / 2.75 then t = t - 1.5 / 2.75; return 7.5625 * t * t + 0.75
		elseif t < 2.5 / 2.75 then t = t - 2.25 / 2.75; return 7.5625 * t * t + 0.9375
		else t = t - 2.625 / 2.75; return 7.5625 * t * t + 0.984375 end
	end
	-- "In" forms; Out(t) = 1 - In(1 - t); InOut mirrors In over each half
	local easeIn = {
		Linear      = function( t ) return t end,
		Sine        = function( t ) return 1 - cos( t * pi / 2 ) end,
		Quad        = function( t ) return t * t end,
		Cubic       = function( t ) return t * t * t end,
		Quart       = function( t ) return t * t * t * t end,
		Quint       = function( t ) return t * t * t * t * t end,
		Exponential = function( t ) return t == 0 and 0 or 2 ^ ( 10 * ( t - 1 ) ) end,
		Circular    = function( t ) return 1 - sqrt( 1 - t * t ) end,
		Back        = function( t ) local s = 1.70158; return t * t * ( ( s + 1 ) * t - s ) end,
		Elastic     = function( t )
			if t == 0 or t == 1 then return t end
			local p = 0.3
			return -( 2 ^ ( 10 * ( t - 1 ) ) ) * sin( ( t - 1 - p / 4 ) * ( 2 * pi ) / p )
		end,
		Bounce      = function( t ) return 1 - bounceOut( 1 - t ) end,
	}
	TS.Easing = easeIn

	function TS:GetValue( alpha, style, direction )
		local f = easeIn[ style or "Quad" ] or easeIn.Quad
		alpha = alpha < 0 and 0 or ( alpha > 1 and 1 or alpha )
		direction = direction or "Out"
		if direction == "In" then return f( alpha )
		elseif direction == "Out" then return 1 - f( 1 - alpha )
		else
			if alpha < 0.5 then return f( alpha * 2 ) / 2 end
			return 1 - f( ( 1 - alpha ) * 2 ) / 2
		end
	end

	-- ------------------------------------------------------------- TweenInfo
	TweenInfo = TweenInfo or {}
	function TweenInfo.new( time, style, direction, repeatCount, reverses, delayTime )
		return {
			Time = time or 1, EasingStyle = style or "Quad", EasingDirection = direction or "Out",
			RepeatCount = repeatCount or 0, Reverses = reverses and true or false, DelayTime = delayTime or 0,
		}
	end

	-- ------------------------------------------------------------- signals
	local function newSignal()
		local s = { handlers = {} }
		function s:Connect( fn )
			local h = { fn = fn }
			self.handlers[ #self.handlers + 1 ] = h
			return { Disconnect = function() h.fn = nil end }
		end
		function s:Once( fn )
			local conn
			conn = self:Connect( function( ... )
				if conn then conn:Disconnect() end
				if fn then fn( ... ) end
			end )
			return conn
		end
		function s:Fire( ... )
			for i = 1, #self.handlers do
				local f = self.handlers[ i ].fn
				if f then
					local ok, err = pcall( f, ... )
					if not ok then log( "handler error: %s", tostring( err ) ) end
				end
			end
		end
		return s
	end

	-- ------------------------------------------------------------- values
	local TWO32 = 4294967296
	local function u32( c ) c = floor( c or 0 ) % TWO32; return c end
	local function lerpColor( a, b, t )
		a, b = u32( a ), u32( b )
		local out, m = 0, 16777216
		for _ = 1, 4 do
			local ca, cb = floor( a / m ) % 256, floor( b / m ) % 256
			out = out + floor( ca + ( cb - ca ) * t + 0.5 ) * m
			m = m / 256
		end
		return out
	end
	TS.LerpColor = lerpColor

	local function isUserdataVec( v ) return type( v ) == "userdata" and v.x ~= nil end
	local function lerpValue( a, b, t, isColor )
		local ta = type( a )
		local tb = type( b )
		if ta == "table" and type( a.Lerp ) == "function" then return a:Lerp( b, t ) end
		if isColor then return lerpColor( a, b, t ) end
		if ta == "number" and tb == "number" then return a + ( b - a ) * t end
		if isUserdataVec( a ) or isUserdataVec( b ) or ( ta == "table" and a.x ~= nil ) or ( tb == "table" and b.x ~= nil ) or ( ta == "number" and isUserdataVec( b ) ) or ( tb == "number" and isUserdataVec( a ) ) then
			local ax, ay
			if ta == "number" then
				ax, ay = a, a
			elseif ta == "table" then
				ax, ay = a.x or a[ 1 ] or 0, a.y or a[ 2 ] or 0
			else
				ax, ay = a.x or 0, a.y or 0
			end

			local bx, by
			if tb == "number" then
				bx, by = b, b
			elseif tb == "table" then
				bx, by = b.x or b[ 1 ] or 0, b.y or b[ 2 ] or 0
			else
				bx, by = b.x or 0, b.y or 0
			end

			local x, y = ax + ( bx - ax ) * t, ay + ( by - ay ) * t
			local hasZ, az = pcall( function() return a.z end )
			if hasZ and az ~= nil then
				local bz = ( tb == "number" and b ) or ( tb == "table" and ( b.z or b[ 3 ] ) ) or ( isUserdataVec( b ) and b.z ) or 0
				local bw = ( tb == "number" and b ) or ( tb == "table" and ( b.w or b[ 4 ] ) ) or ( isUserdataVec( b ) and b.w ) or 0
				local okW, aw = pcall( function() return a.w end )
				return UI:Quat( x, y, az + ( bz - az ) * t, ( okW and aw or 0 ) + ( bw - ( okW and aw or 0 ) ) * t )
			end
			return UI:Vec2( x, y )
		end
		if ta == "number" then return a + ( ( tonumber( b ) or a ) - a ) * t end
		if ta == "table" then
			local out = {}
			for k, v in pairs( a ) do out[ k ] = v + ( ( b[ k ] or v ) - v ) * t end
			return out
		end
		return t < 1 and a or b
	end

	-- ------------------------------------------------------------- adapters
	-- An adapter answers get( target, prop ) / set( target, prop, value ) for targets it
	-- accepts( target ). First match wins; register more with TweenService:AddAdapter( a, priority ).
	TS.Adapters = TS.Adapters or {}

	function TS:AddAdapter( adapter, first )
		if first then table.insert( self.Adapters, 1, adapter ) else self.Adapters[ #self.Adapters + 1 ] = adapter end
	end

	local function isWnd( t ) return type( t ) == "table" and t.w ~= nil and type( t.GetLeft ) == "function" end

	-- window transparency: captured base alpha per layer, applied to layers, effects, children
	local wndAlphaBase = setmetatable( {}, { __mode = "k" } )
	local function eachChild( wnd, fn )
		local c = wnd.GetFirstChild and wnd:GetFirstChild()
		while c do fn( c ); c = c:GetNextSibling() end
	end
	local function captureAlpha( wnd )
		local base = wndAlphaBase[ wnd ]
		if base then return base end
		base = { layers = {}, effects = {}, t = 0 }
		local n = wnd:GetNumLayers() or 0
		for i = 0, n - 1 do
			local a = floor( u32( wnd:GetColor( i ) ) / 16777216 )
			base.layers[ i ] = a > 0 and a or 255
			local eff = UI.GetEffectFromLayer and UI:GetEffectFromLayer( wnd, i )
			if eff then
				local ea = eff:GetAlpha() or 255
				base.effects[ i ] = ea > 0 and ea or 255
			end
		end
		wndAlphaBase[ wnd ] = base
		return base
	end
	local function setWndTransparency( wnd, tr )
		local base = captureAlpha( wnd )
		base.t = tr
		local keep = 1 - tr
		for i, a in pairs( base.layers ) do
			local c = u32( wnd:GetColor( i ) )
			wnd:SetColor( ( c % 16777216 ) + floor( a * keep + 0.5 ) * 16777216, i )
		end
		for i, a in pairs( base.effects ) do
			local eff = UI:GetEffectFromLayer( wnd, i )
			if eff then eff:SetAlpha( floor( a * keep + 0.5 ) ) end
		end
		eachChild( wnd, function( c ) setWndTransparency( c, tr ) end )
	end

	local wndProps = {
		Left   = { get = function( w ) return w:GetLeft() end,   set = function( w, v ) w:SetLeft( v ) end },
		Top    = { get = function( w ) return w:GetTop() end,    set = function( w, v ) w:SetTop( v ) end },
		Width  = { get = function( w ) return w:GetWidth() end,  set = function( w, v ) w:SetWidth( v ) end },
		Height = { get = function( w ) return w:GetHeight() end, set = function( w, v ) w:SetHeight( v ) end },
		Position = { get = function( w ) return UI:Vec2( w:GetLeft(), w:GetTop() ) end,
		             set = function( w, v ) w:SetLeft( v.x ); w:SetTop( v.y ) end },
		Size   = { get = function( w ) return UI:Vec2( w:GetWidth(), w:GetHeight() ) end,
		           set = function( w, v ) w:SetWidth( v.x ); w:SetHeight( v.y ) end },
		Rect   = { get = function( w ) return w:GetRect() end, set = function( w, v ) w:SetRect( v ) end },
		Transparency = { get = function( w ) return ( wndAlphaBase[ w ] or { t = 0 } ).t end,
		                 set = setWndTransparency },
		hoverMix = { get = function( w ) return w.hoverMix or 0 end,
		             set = function( w, v ) w.hoverMix = v end },
	}
	TS:AddAdapter( {
		name = "window", props = wndProps,
		accepts = isWnd,
		get = function( w, p )
			local d = wndProps[ p ]
			if d then return d.get( w ) end
			return w[ p ]
		end,
		set = function( w, p, v )
			local d = wndProps[ p ]
			if d then d.set( w, v ) else w[ p ] = v end
		end,
	} )

	-- layer proxy: TweenService:Layer( wnd, idx )
	function TS:Layer( wnd, idx ) return { __tweenLayer = true, wnd = wnd, idx = idx } end
	local layerProps = {
		Color = { get = function( l ) return u32( l.wnd:GetColor( l.idx ) ) end,
		          set = function( l, v ) l.wnd:SetColor( v, l.idx ) end },
		Transparency = {
			get = function( l ) return 1 - floor( u32( l.wnd:GetColor( l.idx ) ) / 16777216 ) / 255 end,
			set = function( l, v )
				local c = u32( l.wnd:GetColor( l.idx ) )
				l.wnd:SetColor( ( c % 16777216 ) + floor( ( 1 - v ) * 255 + 0.5 ) * 16777216, l.idx )
			end },
	}
	for i, p in ipairs( { "Left", "Top", "Width", "Height" } ) do
		local field = ( { "x", "y", "z", "w" } )[ i ]
		layerProps[ p ] = {
			get = function( l ) return l.wnd:GetLayerRect( l.idx )[ field ] end,
			set = function( l, v )
				local r = l.wnd:GetLayerRect( l.idx )
				local q = { x = r.x, y = r.y, z = r.z, w = r.w }
				q[ field ] = v
				l.wnd:SetLayerRect( UI:Quat( q.x, q.y, q.z, q.w ), l.idx )
			end }
	end
	TS:AddAdapter( {
		name = "layer", props = layerProps,
		accepts = function( t ) return type( t ) == "table" and t.__tweenLayer end,
		get = function( l, p ) local d = layerProps[ p ]; return d and d.get( l ) end,
		set = function( l, p, v ) local d = layerProps[ p ]; if d then d.set( l, v ) end end,
	} )

	-- effects (.sanim instances from UI:GetEffectFromLayer)
	local effProps = {
		Scale = { get = function( e ) return e:GetScale() end,
		          set = function( e, v ) if type( v ) == "number" then v = UI:Vec2( v, v ) end; e:SetScale( v ) end },
		Position = { get = function( e ) return e:GetPos() end,
		             set = function( e, v ) e:SetPos( UI:Vec2( v.x, v.y ) ) end },
		-- the engine's effect alpha is 0..255 (game scripts: mainEffect:SetAlpha( alpha * 255 ))
		Alpha = { get = function( e ) return e:GetAlpha() end, set = function( e, v ) e:SetAlpha( floor( v + 0.5 ) ) end },
		Transparency = { get = function( e ) return 1 - ( e:GetAlpha() or 255 ) / 255 end,
		                 set = function( e, v ) e:SetAlpha( floor( ( 1 - v ) * 255 + 0.5 ) ) end },
		Color = { get = function( e ) return u32( e:GetColor() ) end, set = function( e, v ) e:SetColor( v ) end },
		AnimTime = { get = function( e ) return e:GetAnimationTime() end,
		             set = function( e, v ) e:SetAnimationTimeAndUpdate( v ) end },
	}
	TS:AddAdapter( {
		name = "effect", props = effProps,
		accepts = function( t ) return type( t ) == "userdata" and t.SetScale ~= nil and t.GetObjPos ~= nil end,
		get = function( e, p ) local d = effProps[ p ]; return d and d.get( e ) end,
		set = function( e, p, v ) local d = effProps[ p ]; if d then d.set( e, v ) end end,
	} )

	-- plain tables (last: matches anything table-like)
	TS:AddAdapter( {
		name = "table",
		accepts = function( t ) return type( t ) == "table" end,
		get = function( t, p ) return t[ p ] end,
		set = function( t, p, v ) t[ p ] = v end,
		after = function( t ) if type( t.OnChanged ) == "function" then t:OnChanged() end end,
	} )

	local function adapterFor( target )
		for _, a in ipairs( TS.Adapters ) do
			if a.accepts( target ) then return a end
		end
		return nil
	end

	-- ------------------------------------------------------------- tweens
	local Tween = {}
	Tween.__index = Tween

	-- UI:Vec2 / UI:Quat return ring-buffered userdata from UI.tempBufs (20 slots), so
	-- anything kept across frames must copy out its components first.
	local function copyVec( v )
		if isUserdataVec( v ) then
			local ok, z = pcall( function() return v.z end )
			if ok and z ~= nil then
				local okW, w = pcall( function() return v.w end )
				return { x = v.x, y = v.y, z = z, w = okW and w or 0 }
			end
			return { x = v.x, y = v.y }
		end
		return v
	end

	function TS:Create( target, info, goals )
		local adapter = adapterFor( target )
		if not adapter then
			log( "Create: unsupported target %s", tostring( target ) )
			return nil
		end
		local g = {}
		for p, v in pairs( goals or {} ) do
			if adapter.props and not adapter.props[ p ] then
				if type( target ) == "table" and ( target[ p ] ~= nil or type( v ) == "number" ) then
					g[ p ] = copyVec( v )
				else
					log( "Create: %s has no tweenable property %s", adapter.name, tostring( p ) )
				end
			else
				g[ p ] = copyVec( v )
			end
		end
		local tw = setmetatable( {
			Instance = target, TweenInfo = info or TweenInfo.new(), goals = g,
			adapter = adapter, PlaybackState = "Begin", elapsed = 0, cycle = 0, delay = 0,
			Completed = newSignal(), Changed = newSignal(),
		}, Tween )
		return tw
	end

	local function removeActive( tw )
		for i = #TS.active, 1, -1 do
			if TS.active[ i ] == tw then table.remove( TS.active, i ) end
		end
	end

	function Tween:Play()
		if self.PlaybackState == "Playing" or self.PlaybackState == "Delayed" then return end
		if self.PlaybackState ~= "Paused" then
			-- a new tween takes over the properties it shares with tweens already running
			for _, other in ipairs( TS.active ) do
				if other ~= self and other.Instance == self.Instance then
					for p in pairs( self.goals ) do other.goals[ p ] = nil end
				end
			end
			self.from = {}
			for p in pairs( self.goals ) do self.from[ p ] = copyVec( self.adapter.get( self.Instance, p ) ) end
			self.elapsed, self.cycle = 0, 0
			self.delay = self.TweenInfo.DelayTime or 0
		end
		self.PlaybackState = self.delay > 0 and "Delayed" or "Playing"
		removeActive( self )
		TS.active[ #TS.active + 1 ] = self
	end

	function Tween:Pause()
		if self.PlaybackState == "Playing" or self.PlaybackState == "Delayed" then
			self.PlaybackState = "Paused"
			removeActive( self )
		end
	end

	function Tween:Cancel()
		removeActive( self )
		self.PlaybackState = "Cancelled"
		self.elapsed = 0
		self.Completed:Fire( "Cancelled" )
	end

	function Tween:Destroy()
		removeActive( self )
		self.Completed.handlers, self.Changed.handlers = {}, {}
	end

	function Tween:apply( alpha )
		local info, a = self.TweenInfo, self.adapter
		local k = TS:GetValue( alpha, info.EasingStyle, info.EasingDirection )
		for p, goal in pairs( self.goals ) do
			local from = self.from[ p ]
			if from ~= nil then
				local isColor = type( p ) == "string" and string.find( p, "Color" ) ~= nil
				local ok, err = pcall( a.set, self.Instance, p, lerpValue( from, goal, k, isColor ) )
				if not ok then log( "set %s failed: %s", tostring( p ), tostring( err ) ) end
			end
		end
		if a.after then pcall( a.after, self.Instance ) end
		self.Changed:Fire( alpha )
	end

	-- returns false when finished
	function Tween:step( dt )
		local info = self.TweenInfo
		if self.delay > 0 then
			self.delay = self.delay - dt
			if self.delay > 0 then return true end
			dt = -self.delay
			self.delay = 0
			self.PlaybackState = "Playing"
		end
		local time = info.Time > 0 and info.Time or 1e-6
		local cycleLen = info.Reverses and time * 2 or time
		self.elapsed = self.elapsed + dt
		local done = false
		while self.elapsed >= cycleLen do
			if info.RepeatCount >= 0 and self.cycle >= info.RepeatCount then
				done = true
				break
			end
			self.cycle = self.cycle + 1
			self.elapsed = self.elapsed - cycleLen
			if ( info.DelayTime or 0 ) > 0 then
				-- hold the end of this cycle, wait, then start the next one from the beginning
				self:apply( info.Reverses and 0 or 1 )
				self.delay = info.DelayTime
				self.elapsed = 0
				self.PlaybackState = "Delayed"
				return true
			end
		end
		if done then
			self:apply( info.Reverses and 0 or 1 )
			self.PlaybackState = "Completed"
			self.Completed:Fire( "Completed" )
			return false
		end
		local t = self.elapsed
		if info.Reverses and t > time then t = cycleLen - t end
		self:apply( t / time )
		return true
	end

	-- ------------------------------------------------------------- driving
	function TS:Step( dt )
		dt = dt or 0
		local list = {}
		for i = 1, #self.active do list[ i ] = self.active[ i ] end
		for _, tw in ipairs( list ) do
			if tw.PlaybackState == "Playing" or tw.PlaybackState == "Delayed" then
				local ok, alive = pcall( tw.step, tw, dt )
				if not ok then
					log( "step error: %s", tostring( alive ) )
					alive = false
				end
				if not alive then removeActive( tw ) end
			end
		end
	end

	-- Chains wnd.F_OnNewFrame so the engine drives TweenService every frame while
	-- wnd is on screen. Safe to call more than once.
	function TS:Attach( wnd )
		if not wnd or wnd.__tweenAttached then return end
		wnd.__tweenAttached = true
		local prev = wnd.F_OnNewFrame
		wnd.F_OnNewFrame = function( self_, hSender, dt_sys, dt_game )
			if type( prev ) == "function" then prev( self_, hSender, dt_sys, dt_game ) end
			TS:Step( dt_sys or 0 )
		end
		-- before the object phase wnd.w is nil; then the window's own def must carry the style
		if wnd.w and wnd.AddStyle and UI.WS_UPDATE_IF_VISIBLE then wnd:AddStyle( UI.WS_UPDATE_IF_VISIBLE ) end
	end

	-- Sets properties immediately (no animation), through the same adapters.
	function TS:Set( target, props )
		local a = adapterFor( target )
		if not a then return end
		for p, v in pairs( props ) do pcall( a.set, target, p, v ) end
		if a.after then pcall( a.after, target ) end
	end

	-- Stops every running tween on target (optionally only those touching `prop`).
	function TS:CancelAll( target, prop )
		for i = #self.active, 1, -1 do
			local tw = self.active[ i ]
			if tw.Instance == target and ( prop == nil or tw.goals[ prop ] ~= nil ) then tw:Cancel() end
		end
	end

	-- Convenience: create + play
	function TS:Tween( target, time, goals, style, direction )
		local tw = self:Create( target, TweenInfo.new( time, style, direction ), goals )
		if tw then tw:Play() end
		return tw
	end
end
-- END TWEENSERVICE

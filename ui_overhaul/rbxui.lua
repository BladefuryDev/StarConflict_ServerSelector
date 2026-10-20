-- BEGIN RBXUI
-- ============================================================================
-- RbxUI for Star Conflict (Lua 5.1)
-- A Roblox-style retained GUI & DataType toolkit built on top of Star Conflict's
-- immediate-mode UI.drawer, _G.UI_DrawText, UI.ButtonWnd hitboxes, and TweenService.
--
-- Reference: Roblox Creator Documentation (GuiObject, ScreenGui, UIListLayout,
-- UIGridLayout, UIPadding, UIStroke, UICorner, UIScale, UIGradient, UDim2, Color3,
-- Vector2, RBXScriptSignal, Instance.new).
--
-- Exported Globals (and inside _G.RbxUI):
--   Instance, UDim, UDim2, Vector2, Rect, Color3,
--   ColorSequence, ColorSequenceKeypoint, NumberSequence, NumberSequenceKeypoint,
--   Enum (merged with TweenService.Enum), RbxUI
-- ============================================================================
do
	local floor, ceil, abs, min, max = math.floor, math.ceil, math.abs, math.min, math.max
	local sqrt, sin, cos, atan2 = math.sqrt, math.sin, math.cos, math.atan2
	local type, pairs, ipairs, tostring, tonumber = type, pairs, ipairs, tostring, tonumber
	local setmetatable, getmetatable, rawget, rawset = setmetatable, getmetatable, rawget, rawset
	local tinsert, tremove, tsort = table.insert, table.remove, table.sort
	local sformat, ssub, sgsub, slower = string.format, string.sub, string.gsub, string.lower

	local RbxUI = _G.RbxUI or {}
	_G.RbxUI = RbxUI
	RbxUI._VERSION = "1.0.0"

	local function clamp( x, lo, hi )
		if x < lo then return lo elseif x > hi then return hi else return x end
	end
	local function round( x ) return floor( x + 0.5 ) end

	-- =========================================================================
	-- 1. Core Data Types (UDim, UDim2, Vector2, Rect, NumberRange, Color3, Sequences)
	-- =========================================================================
	local UDim, UDim2, Vector2, Rect, NumberRange, Color3
	local ColorSequenceKeypoint, ColorSequence, NumberSequenceKeypoint, NumberSequence

	do
		-- ----------------------------- UDim
		UDim = {}
		UDim.__index = UDim
		function UDim.new( scale, offset )
			return setmetatable( { Scale = tonumber( scale ) or 0, Offset = tonumber( offset ) or 0 }, UDim )
		end
		function UDim:__add( b ) return UDim.new( self.Scale + b.Scale, self.Offset + b.Offset ) end
		function UDim:__sub( b ) return UDim.new( self.Scale - b.Scale, self.Offset - b.Offset ) end
		function UDim:__eq( b ) return type( b ) == "table" and self.Scale == b.Scale and self.Offset == b.Offset end
		function UDim:__tostring() return sformat( "%g, %d", self.Scale, round( self.Offset ) ) end
		function UDim:Lerp( goal, alpha )
			return UDim.new(
				self.Scale + ( goal.Scale - self.Scale ) * alpha,
				self.Offset + ( goal.Offset - self.Offset ) * alpha
			)
		end

		-- ----------------------------- UDim2
		UDim2 = {}
		function UDim2:__index( k )
			if k == "Width" then return self.X
			elseif k == "Height" then return self.Y end
			return UDim2[ k ]
		end
		function UDim2.new( a, b, c, d )
			if type( a ) == "table" and a.Scale ~= nil then
				return setmetatable( {
					X = UDim.new( a.Scale, a.Offset ),
					Y = type( b ) == "table" and UDim.new( b.Scale, b.Offset ) or UDim.new( 0, 0 ),
				}, UDim2 )
			end
			return setmetatable( {
				X = UDim.new( a or 0, b or 0 ),
				Y = UDim.new( c or 0, d or 0 ),
			}, UDim2 )
		end
		function UDim2.fromScale( xs, ys ) return UDim2.new( xs or 0, 0, ys or 0, 0 ) end
		function UDim2.fromOffset( xo, yo ) return UDim2.new( 0, xo or 0, 0, yo or 0 ) end
		function UDim2:__add( b ) return UDim2.new( self.X + b.X, self.Y + b.Y ) end
		function UDim2:__sub( b ) return UDim2.new( self.X - b.X, self.Y - b.Y ) end
		function UDim2:__eq( b ) return type( b ) == "table" and self.X == b.X and self.Y == b.Y end
		function UDim2:__tostring() return sformat( "{%s}, {%s}", tostring( self.X ), tostring( self.Y ) ) end
		function UDim2:Lerp( goal, alpha )
			return UDim2.new( self.X:Lerp( goal.X, alpha ), self.Y:Lerp( goal.Y, alpha ) )
		end

		-- ----------------------------- Vector2
		Vector2 = {}
		function Vector2:__index( k )
			if k == "x" then return self.X
			elseif k == "y" then return self.Y
			elseif k == "Magnitude" then return sqrt( self.X * self.X + self.Y * self.Y )
			elseif k == "Unit" then
				local m = sqrt( self.X * self.X + self.Y * self.Y )
				return m > 1e-9 and Vector2.new( self.X / m, self.Y / m ) or Vector2.new( 0, 0 )
			end
			return Vector2[ k ]
		end
		function Vector2.new( x, y )
			return setmetatable( { X = tonumber( x ) or 0, Y = tonumber( y ) or 0 }, Vector2 )
		end
		function Vector2:__add( b ) return Vector2.new( self.X + b.X, self.Y + b.Y ) end
		function Vector2:__sub( b ) return Vector2.new( self.X - b.X, self.Y - b.Y ) end
		function Vector2:__mul( b )
			if type( b ) == "number" then return Vector2.new( self.X * b, self.Y * b ) end
			if type( self ) == "number" then return Vector2.new( self * b.X, self * b.Y ) end
			return Vector2.new( self.X * b.X, self.Y * b.Y )
		end
		function Vector2:__div( b )
			if type( b ) == "number" then return Vector2.new( self.X / b, self.Y / b ) end
			return Vector2.new( self.X / b.X, self.Y / b.Y )
		end
		function Vector2:__unm() return Vector2.new( -self.X, -self.Y ) end
		function Vector2:__eq( b ) return type( b ) == "table" and self.X == b.X and self.Y == b.Y end
		function Vector2:__tostring() return sformat( "%g, %g", self.X, self.Y ) end
		function Vector2:Lerp( goal, alpha )
			return Vector2.new(
				self.X + ( goal.X - self.X ) * alpha,
				self.Y + ( goal.Y - self.Y ) * alpha
			)
		end
		function Vector2:Dot( b ) return self.X * b.X + self.Y * b.Y end
		function Vector2:Cross( b ) return self.X * b.Y - self.Y * b.X end
		function Vector2:Abs() return Vector2.new( abs( self.X ), abs( self.Y ) ) end
		function Vector2:Ceil() return Vector2.new( ceil( self.X ), ceil( self.Y ) ) end
		function Vector2:Floor() return Vector2.new( floor( self.X ), floor( self.Y ) ) end
		function Vector2:Min( ... )
			local x, y = self.X, self.Y
			for i = 1, select( "#", ... ) do
				local v = select( i, ... )
				if v.X < x then x = v.X end
				if v.Y < y then y = v.Y end
			end
			return Vector2.new( x, y )
		end
		function Vector2:Max( ... )
			local x, y = self.X, self.Y
			for i = 1, select( "#", ... ) do
				local v = select( i, ... )
				if v.X > x then x = v.X end
				if v.Y > y then y = v.Y end
			end
			return Vector2.new( x, y )
		end
		Vector2.zero  = Vector2.new( 0, 0 )
		Vector2.one   = Vector2.new( 1, 1 )
		Vector2.xAxis = Vector2.new( 1, 0 )
		Vector2.yAxis = Vector2.new( 0, 1 )

		-- ----------------------------- Rect
		Rect = {}
		function Rect:__index( k )
			if k == "Width" then return self.Max.X - self.Min.X
			elseif k == "Height" then return self.Max.Y - self.Min.Y end
			return Rect[ k ]
		end
		function Rect.new( a, b, c, d )
			if type( a ) == "table" and a.X ~= nil then
				return setmetatable( {
					Min = Vector2.new( a.X, a.Y ),
					Max = type( b ) == "table" and Vector2.new( b.X, b.Y ) or Vector2.new( 0, 0 ),
				}, Rect )
			end
			return setmetatable( {
				Min = Vector2.new( a or 0, b or 0 ),
				Max = Vector2.new( c or 0, d or 0 ),
			}, Rect )
		end
		function Rect:__tostring()
			return sformat( "%g, %g, %g, %g", self.Min.X, self.Min.Y, self.Max.X, self.Max.Y )
		end

		-- ----------------------------- Color3
		Color3 = {}
		Color3.__index = Color3
		function Color3.new( r, g, b )
			return setmetatable( {
				R = clamp( tonumber( r ) or 0, 0, 1 ),
				G = clamp( tonumber( g ) or 0, 0, 1 ),
				B = clamp( tonumber( b ) or 0, 0, 1 ),
			}, Color3 )
		end
		function Color3.fromRGB( r, g, b )
			return Color3.new( ( tonumber( r ) or 0 ) / 255, ( tonumber( g ) or 0 ) / 255, ( tonumber( b ) or 0 ) / 255 )
		end
		function Color3.fromHSV( h, s, v )
			h = ( tonumber( h ) or 0 ) % 1
			s = clamp( tonumber( s ) or 0, 0, 1 )
			v = clamp( tonumber( v ) or 0, 0, 1 )
			if s <= 0 then return Color3.new( v, v, v ) end
			local i = floor( h * 6 )
			local f = h * 6 - i
			local p = v * ( 1 - s )
			local q = v * ( 1 - s * f )
			local t = v * ( 1 - s * ( 1 - f ) )
			i = i % 6
			if i == 0 then return Color3.new( v, t, p )
			elseif i == 1 then return Color3.new( q, v, p )
			elseif i == 2 then return Color3.new( p, v, t )
			elseif i == 3 then return Color3.new( p, q, v )
			elseif i == 4 then return Color3.new( t, p, v )
			else return Color3.new( v, p, q ) end
		end
		function Color3.fromHex( hex )
			hex = sgsub( tostring( hex or "" ), "^#", "" )
			if #hex == 3 then
				local r = tonumber( ssub( hex, 1, 1 ) .. ssub( hex, 1, 1 ), 16 ) or 0
				local g = tonumber( ssub( hex, 2, 2 ) .. ssub( hex, 2, 2 ), 16 ) or 0
				local b = tonumber( ssub( hex, 3, 3 ) .. ssub( hex, 3, 3 ), 16 ) or 0
				return Color3.fromRGB( r, g, b )
			end
			if #hex == 8 then hex = ssub( hex, 3, 8 ) end -- allow AARRGGBB
			local r = tonumber( ssub( hex, 1, 2 ), 16 ) or 0
			local g = tonumber( ssub( hex, 3, 4 ), 16 ) or 0
			local b = tonumber( ssub( hex, 5, 6 ), 16 ) or 0
			return Color3.fromRGB( r, g, b )
		end
		function Color3.fromARGB( argb )
			if type( argb ) ~= "number" then return Color3.new( 1, 1, 1 ) end
			if argb < 0 then argb = argb + 4294967296 end
			local r = floor( argb / 65536 ) % 256
			local g = floor( argb / 256 ) % 256
			local b = floor( argb ) % 256
			return Color3.fromRGB( r, g, b )
		end
		function Color3:Lerp( goal, alpha )
			return Color3.new(
				self.R + ( goal.R - self.R ) * alpha,
				self.G + ( goal.G - self.G ) * alpha,
				self.B + ( goal.B - self.B ) * alpha
			)
		end
		function Color3:ToHSV()
			local r, g, b = self.R, self.G, self.B
			local mx, mn = max( r, g, b ), min( r, g, b )
			local d = mx - mn
			local h, s, v = 0, ( mx == 0 and 0 or d / mx ), mx
			if d > 1e-9 then
				if mx == r then h = ( ( g - b ) / d ) % 6
				elseif mx == g then h = ( b - r ) / d + 2
				else h = ( r - g ) / d + 4 end
				h = h / 6
			end
			return h, s, v
		end
		function Color3:ToHex()
			return sformat( "%02X%02X%02X", round( self.R * 255 ), round( self.G * 255 ), round( self.B * 255 ) )
		end
		function Color3:ToARGB( transparency )
			local a = round( clamp( 1 - ( tonumber( transparency ) or 0 ), 0, 1 ) * 255 )
			local r = round( clamp( self.R, 0, 1 ) * 255 )
			local g = round( clamp( self.G, 0, 1 ) * 255 )
			local b = round( clamp( self.B, 0, 1 ) * 255 )
			return a * 16777216 + r * 65536 + g * 256 + b
		end
		function Color3:__eq( b )
			return type( b ) == "table" and abs( self.R - b.R ) < 1e-6 and abs( self.G - b.G ) < 1e-6 and abs( self.B - b.B ) < 1e-6
		end
		function Color3:__tostring() return sformat( "%g, %g, %g", self.R, self.G, self.B ) end

		-- ----------------------------- ColorSequence & NumberSequence & NumberRange
		NumberRange = {}
		NumberRange.__index = NumberRange
		function NumberRange.new( a, b )
			local mn = tonumber( a ) or 0
			local mx = b ~= nil and ( tonumber( b ) or mn ) or mn
			return setmetatable( { Min = mn, Max = mx }, NumberRange )
		end
		function NumberRange:Lerp( goal, alpha )
			return NumberRange.new(
				self.Min + ( goal.Min - self.Min ) * alpha,
				self.Max + ( goal.Max - self.Max ) * alpha
			)
		end
		function NumberRange:Clamp( x ) return clamp( x, self.Min, self.Max ) end
		function NumberRange:Map( t ) return self.Min + ( self.Max - self.Min ) * clamp( t, 0, 1 ) end
		function NumberRange:__eq( b ) return type( b ) == "table" and self.Min == b.Min and self.Max == b.Max end
		function NumberRange:__tostring() return sformat( "%g %g", self.Min, self.Max ) end

		ColorSequenceKeypoint = {}
		ColorSequenceKeypoint.__index = ColorSequenceKeypoint
		function ColorSequenceKeypoint.new( t, c )
			return setmetatable( { Time = clamp( tonumber( t ) or 0, 0, 1 ), Value = c or Color3.new( 1, 1, 1 ) }, ColorSequenceKeypoint )
		end

		ColorSequence = {}
		ColorSequence.__index = ColorSequence
		function ColorSequence.new( a, b )
			local kps
			if type( a ) == "table" and a.R ~= nil then
				local c1 = ( type( b ) == "table" and b.R ~= nil ) and b or a
				kps = { ColorSequenceKeypoint.new( 0, a ), ColorSequenceKeypoint.new( 1, c1 ) }
			elseif type( a ) == "table" and a.Keypoints then
				kps = a.Keypoints
			elseif type( a ) == "table" then
				if a[ 1 ] and a[ 1 ].R ~= nil then
					kps = {}
					local n = #a
					for i = 1, n do
						kps[ i ] = ColorSequenceKeypoint.new( n > 1 and ( i - 1 ) / ( n - 1 ) or 0, a[ i ] )
					end
				else
					kps = a
				end
			else
				local c = Color3.new( 1, 1, 1 )
				kps = { ColorSequenceKeypoint.new( 0, c ), ColorSequenceKeypoint.new( 1, c ) }
			end
			return setmetatable( { Keypoints = kps }, ColorSequence )
		end
		function ColorSequence.fromColors( ... )
			local args = { ... }
			if #args == 1 and type( args[ 1 ] ) == "table" and args[ 1 ].R == nil then args = args[ 1 ] end
			local n = #args
			if n == 0 then return ColorSequence.new( Color3.new( 1, 1, 1 ) ) end
			if n == 1 then return ColorSequence.new( args[ 1 ] ) end
			local kps = {}
			for i = 1, n do
				kps[ i ] = ColorSequenceKeypoint.new( ( i - 1 ) / ( n - 1 ), args[ i ] )
			end
			return ColorSequence.new( kps )
		end
		function ColorSequence:Eval( t )
			t = clamp( tonumber( t ) or 0, 0, 1 )
			local kps = self.Keypoints
			if not kps or #kps == 0 then return Color3.new( 1, 1, 1 ) end
			if #kps == 1 or t <= kps[ 1 ].Time then return kps[ 1 ].Value end
			for i = 1, #kps - 1 do
				local k0, k1 = kps[ i ], kps[ i + 1 ]
				if t >= k0.Time and t <= k1.Time then
					local span = k1.Time - k0.Time
					local alpha = span > 1e-6 and ( t - k0.Time ) / span or 0
					return k0.Value:Lerp( k1.Value, alpha )
				end
			end
			return kps[ #kps ].Value
		end
		function ColorSequence:Lerp( goal, alpha )
			if type( goal ) == "table" and goal.R ~= nil then goal = ColorSequence.new( goal ) end
			if type( goal ) ~= "table" or not goal.Eval then return self end
			local times = { 0, 1 }
			local seen = { [ 0 ] = true, [ 1 ] = true }
			local function addTimes( seq )
				for _, kp in ipairs( seq.Keypoints or {} ) do
					local tm = round( kp.Time * 1000 ) / 1000
					if not seen[ tm ] then seen[ tm ] = true; times[ #times + 1 ] = tm end
				end
			end
			addTimes( self ); addTimes( goal )
			tsort( times )
			local out = {}
			for i, tm in ipairs( times ) do
				out[ i ] = ColorSequenceKeypoint.new( tm, self:Eval( tm ):Lerp( goal:Eval( tm ), alpha ) )
			end
			return ColorSequence.new( out )
		end

		NumberSequenceKeypoint = {}
		NumberSequenceKeypoint.__index = NumberSequenceKeypoint
		function NumberSequenceKeypoint.new( t, v, env )
			return setmetatable( {
				Time = clamp( tonumber( t ) or 0, 0, 1 ),
				Value = tonumber( v ) or 0,
				Envelope = tonumber( env ) or 0,
			}, NumberSequenceKeypoint )
		end

		NumberSequence = {}
		NumberSequence.__index = NumberSequence
		function NumberSequence.new( a, b )
			local kps
			if type( a ) == "number" then
				local v1 = type( b ) == "number" and b or a
				kps = { NumberSequenceKeypoint.new( 0, a ), NumberSequenceKeypoint.new( 1, v1 ) }
			elseif type( a ) == "table" and a.Min ~= nil and a.Max ~= nil then
				kps = { NumberSequenceKeypoint.new( 0, a.Min ), NumberSequenceKeypoint.new( 1, a.Max ) }
			elseif type( a ) == "table" and a.Keypoints then
				kps = a.Keypoints
			elseif type( a ) == "table" then
				if type( a[ 1 ] ) == "number" then
					kps = {}
					local n = #a
					for i = 1, n do
						kps[ i ] = NumberSequenceKeypoint.new( n > 1 and ( i - 1 ) / ( n - 1 ) or 0, a[ i ] )
					end
				else
					kps = a
				end
			else
				kps = { NumberSequenceKeypoint.new( 0, 0 ), NumberSequenceKeypoint.new( 1, 0 ) }
			end
			return setmetatable( { Keypoints = kps }, NumberSequence )
		end
		function NumberSequence.fromValues( ... )
			local args = { ... }
			if #args == 1 and type( args[ 1 ] ) == "table" then args = args[ 1 ] end
			return NumberSequence.new( args )
		end
		function NumberSequence.fromAlpha( ... )
			local args = { ... }
			if #args == 1 and type( args[ 1 ] ) == "table" then args = args[ 1 ] end
			local n = #args
			if n == 0 then return NumberSequence.new( 0 ) end
			local vals = {}
			for i = 1, n do
				local a = tonumber( args[ i ] ) or 1
				if a > 1 then a = a / 255 end -- support both 0..1 and 0..255 alpha!
				vals[ i ] = clamp( 1 - a, 0, 1 )
			end
			if n == 1 then return NumberSequence.new( vals[ 1 ] ) end
			return NumberSequence.new( vals )
		end
		function NumberSequence.crossfade( progress, softness, reverse )
			local p = clamp( tonumber( progress ) or 0, 0, 1 )
			local s = max( 0.001, tonumber( softness ) or 0.25 )
			-- At p=0: fully transparent (1). At p=1: fully opaque (0).
			local edge0 = clamp( p * ( 1 + s ) - s, 0, 1 )
			local edge1 = clamp( p * ( 1 + s ), 0, 1 )
			local tVis, tHid = 0, 1
			if reverse then tVis, tHid = 1, 0 end
			if p <= 0.0001 then return NumberSequence.new( tHid ) end
			if p >= 0.9999 then return NumberSequence.new( tVis ) end
			local kps = {}
			if edge0 > 0.001 then kps[ #kps + 1 ] = NumberSequenceKeypoint.new( 0, tVis ) end
			kps[ #kps + 1 ] = NumberSequenceKeypoint.new( edge0, tVis )
			if edge1 > edge0 + 0.001 then
				kps[ #kps + 1 ] = NumberSequenceKeypoint.new( edge1, tHid )
			else
				kps[ #kps + 1 ] = NumberSequenceKeypoint.new( min( 1, edge0 + 0.001 ), tHid )
			end
			if edge1 < 0.999 then kps[ #kps + 1 ] = NumberSequenceKeypoint.new( 1, tHid ) end
			return NumberSequence.new( kps )
		end
		function NumberSequence:Eval( t )
			t = clamp( tonumber( t ) or 0, 0, 1 )
			local kps = self.Keypoints
			if not kps or #kps == 0 then return 0 end
			if #kps == 1 or t <= kps[ 1 ].Time then return kps[ 1 ].Value end
			for i = 1, #kps - 1 do
				local k0, k1 = kps[ i ], kps[ i + 1 ]
				if t >= k0.Time and t <= k1.Time then
					local span = k1.Time - k0.Time
					local alpha = span > 1e-6 and ( t - k0.Time ) / span or 0
					return k0.Value + ( k1.Value - k0.Value ) * alpha
				end
			end
			return kps[ #kps ].Value
		end
		function NumberSequence:Lerp( goal, alpha )
			if type( goal ) == "number" then goal = NumberSequence.new( goal ) end
			if type( goal ) ~= "table" or not goal.Eval then return self end
			local times = { 0, 1 }
			local seen = { [ 0 ] = true, [ 1 ] = true }
			local function addTimes( seq )
				for _, kp in ipairs( seq.Keypoints or {} ) do
					local tm = round( kp.Time * 1000 ) / 1000
					if not seen[ tm ] then seen[ tm ] = true; times[ #times + 1 ] = tm end
				end
			end
			addTimes( self ); addTimes( goal )
			tsort( times )
			local out = {}
			for i, tm in ipairs( times ) do
				local v0, v1 = self:Eval( tm ), goal:Eval( tm )
				out[ i ] = NumberSequenceKeypoint.new( tm, v0 + ( v1 - v0 ) * alpha )
			end
			return NumberSequence.new( out )
		end
	end

	-- =========================================================================
	-- 2. Enum (Merged with TweenService.Enum)
	-- =========================================================================
	local Enum = ( _G.TweenService and _G.TweenService.Enum ) or _G.Enum or {}
	local function defEnum( group, tbl )
		Enum[ group ] = Enum[ group ] or {}
		for k, v in pairs( tbl ) do Enum[ group ][ k ] = v end
	end

	defEnum( "FillDirection", { Horizontal = "Horizontal", Vertical = "Vertical" } )
	defEnum( "HorizontalAlignment", { Left = "Left", Center = "Center", Right = "Right" } )
	defEnum( "VerticalAlignment", { Top = "Top", Center = "Center", Bottom = "Bottom" } )
	defEnum( "SortOrder", { LayoutOrder = "LayoutOrder", Name = "Name", Custom = "Custom" } )
	defEnum( "SizeConstraint", { RelativeXY = "RelativeXY", RelativeXX = "RelativeXX", RelativeYY = "RelativeYY" } )
	defEnum( "AutomaticSize", { None = "None", X = "X", Y = "Y", XY = "XY" } )
	defEnum( "TextXAlignment", { Left = "Left", Center = "Center", Right = "Right" } )
	defEnum( "TextYAlignment", { Top = "Top", Center = "Center", Bottom = "Bottom" } )
	defEnum( "ScaleType", { Stretch = "Stretch", Slice = "Slice", Tile = "Tile", Fit = "Fit", Crop = "Crop" } )
	defEnum( "ApplyStrokeMode", { Contextual = "Contextual", Border = "Border" } )
	defEnum( "LineJoinMode", { Round = "Round", Bevel = "Bevel", Miter = "Miter" } )
	defEnum( "BorderMode", { Outline = "Outline", Middle = "Middle", Inset = "Inset" } )
	defEnum( "ZIndexBehavior", { Sibling = "Sibling", Global = "Global" } )
	defEnum( "AspectType", { FitWithinMaxSize = "FitWithinMaxSize", ScaleWithParentSize = "ScaleWithParentSize" } )
	defEnum( "DominantAxis", { Width = "Width", Height = "Height" } )
	defEnum( "StartCorner", { TopLeft = "TopLeft", TopRight = "TopRight", BottomLeft = "BottomLeft", BottomRight = "BottomRight" } )
	defEnum( "ScrollingDirection", { X = "X", Y = "Y", XY = "XY" } )
	defEnum( "GuiState", { Idle = "Idle", Hover = "Hover", Press = "Press", NonInteractable = "NonInteractable" } )
	defEnum( "UserInputType", { MouseButton1 = "MouseButton1", MouseButton2 = "MouseButton2", MouseMovement = "MouseMovement", MouseWheel = "MouseWheel" } )
	defEnum( "UserInputState", { Begin = "Begin", Change = "Change", End = "End" } )
	defEnum( "Font", {
		-- Native Star Conflict fonts
		VerySmall   = "VerySmall",
		Small       = "Small",
		SmallBold   = "SmallBold",
		Medium      = "Medium",
		MediumBold  = "MediumBold",
		Large       = "Large",
		LargeBold   = "LargeBold",
		Header1     = "Header1",
		Header2     = "Header2",
		Header3     = "Header3",
		CombatLog   = "CombatLog",
		Digital     = "Digital",
		-- Roblox Font aliases mapped to the closest Star Conflict font
		Legacy         = "Small",
		SourceSans     = "Small",
		SourceSansBold = "SmallBold",
		Gotham         = "Small",
		GothamMedium   = "Medium",
		GothamSemibold = "SmallBold",
		GothamBold     = "MediumBold",
		GothamBlack    = "LargeBold",
		SciFi          = "Header2",
		Code           = "CombatLog",
		Arcade         = "Digital",
	} )

	-- =========================================================================
	-- 3. RBXScriptSignal & RBXScriptConnection
	-- =========================================================================
	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable( { _list = {} }, Signal )
	end

	function Signal:Connect( fn )
		local list = self._list
		local conn = { Connected = true, _fn = fn }
		function conn:Disconnect()
			if not self.Connected then return end
			self.Connected = false
			for i = #list, 1, -1 do
				if list[ i ] == self then tremove( list, i ); break end
			end
		end
		conn.disconnect = conn.Disconnect
		list[ #list + 1 ] = conn
		return conn
	end
	Signal.connect = Signal.Connect

	function Signal:Once( fn )
		local conn
		conn = self:Connect( function( ... )
			if conn then conn:Disconnect() end
			fn( ... )
		end )
		return conn
	end

	function Signal:Fire( ... )
		local snap = {}
		for i, c in ipairs( self._list ) do snap[ i ] = c end
		for _, c in ipairs( snap ) do
			if c.Connected and c._fn then
				local ok, err = pcall( c._fn, ... )
				if not ok and _G.log then pcall( _G.log, "[RbxUI Signal] " .. tostring( err ) ) end
			end
		end
	end

	function Signal:DisconnectAll()
		for _, c in ipairs( self._list ) do c.Connected = false end
		self._list = {}
	end

	-- =========================================================================
	-- 4. Instance Hierarchy & Class System
	-- =========================================================================
	local Classes = {}
	local ClassParents = {}
	local NextInstanceId = 0

	local function registerClass( name, parentName, defaults, initFn )
		ClassParents[ name ] = parentName
		Classes[ name ] = {
			name = name,
			parent = parentName,
			defaults = defaults or {},
			init = initFn,
		}
	end

	local function isClassA( className, targetClass )
		local cur = className
		while cur do
			if cur == targetClass then return true end
			cur = ClassParents[ cur ]
		end
		return false
	end

	local InstanceMethods = {}

	function InstanceMethods:IsA( className )
		return isClassA( self.ClassName, className )
	end

	function InstanceMethods:GetChildren()
		local out = {}
		for i, c in ipairs( self._children ) do out[ i ] = c end
		return out
	end

	function InstanceMethods:GetDescendants()
		local out = {}
		local function walk( node )
			for _, c in ipairs( node._children ) do
				out[ #out + 1 ] = c
				walk( c )
			end
		end
		walk( self )
		return out
	end

	function InstanceMethods:FindFirstChild( name, recursive )
		for _, c in ipairs( self._children ) do
			if c.Name == name then return c end
		end
		if recursive then
			for _, c in ipairs( self._children ) do
				local found = c:FindFirstChild( name, true )
				if found then return found end
			end
		end
		return nil
	end

	function InstanceMethods:FindFirstChildOfClass( className )
		for _, c in ipairs( self._children ) do
			if c.ClassName == className then return c end
		end
		return nil
	end

	function InstanceMethods:FindFirstChildWhichIsA( className, recursive )
		for _, c in ipairs( self._children ) do
			if c:IsA( className ) then return c end
		end
		if recursive then
			for _, c in ipairs( self._children ) do
				local found = c:FindFirstChildWhichIsA( className, true )
				if found then return found end
			end
		end
		return nil
	end

	function InstanceMethods:FindFirstAncestor( name )
		local p = self._props.Parent
		while p do
			if p.Name == name then return p end
			p = p._props and p._props.Parent
		end
		return nil
	end

	function InstanceMethods:FindFirstAncestorOfClass( className )
		local p = self._props.Parent
		while p do
			if p.ClassName == className then return p end
			p = p._props and p._props.Parent
		end
		return nil
	end

	function InstanceMethods:FindFirstAncestorWhichIsA( className )
		local p = self._props.Parent
		while p do
			if p.IsA and p:IsA( className ) then return p end
			p = p._props and p._props.Parent
		end
		return nil
	end

	function InstanceMethods:GetFullName()
		local parts = { self.Name }
		local p = self._props.Parent
		while p do
			tinsert( parts, 1, p.Name )
			p = p._props and p._props.Parent
		end
		return table.concat( parts, "." )
	end

	function InstanceMethods:GetPropertyChangedSignal( prop )
		local sigs = self._propSignals
		if not sigs[ prop ] then sigs[ prop ] = Signal.new() end
		return sigs[ prop ]
	end

	function InstanceMethods:SetAttribute( name, val )
		self._attributes[ name ] = val
		self.AttributeChanged:Fire( name )
	end

	function InstanceMethods:GetAttribute( name )
		return self._attributes[ name ]
	end

	function InstanceMethods:GetAttributes()
		local out = {}
		for k, v in pairs( self._attributes ) do out[ k ] = v end
		return out
	end

	function InstanceMethods:ClearAllChildren()
		local snap = self:GetChildren()
		for _, c in ipairs( snap ) do c:Destroy() end
	end

	function InstanceMethods:Destroy()
		if self._destroyed then return end
		self.Destroying:Fire()
		self._destroyed = true
		if self._cleanupHitbox then self:_cleanupHitbox() end
		if self._unmountScreenGui then self:_unmountScreenGui() end
		self.Parent = nil
		local snap = self:GetChildren()
		for _, c in ipairs( snap ) do c:Destroy() end
		for _, sig in pairs( self._signals ) do sig:DisconnectAll() end
		for _, sig in pairs( self._propSignals ) do sig:DisconnectAll() end
	end

	local Instance = {}
	function Instance.fromExisting( src )
		return src and src:Clone() or nil
	end

	function InstanceMethods:Clone()
		if not self.Archivable then return nil end
		local copy = Instance.new( self.ClassName )
		for k, v in pairs( self._props ) do
			if k ~= "Parent" and k ~= "ClassName" then
				if type( v ) == "table" and type( v.Lerp ) == "function" then
					copy._props[ k ] = v:Lerp( v, 0 )
				else
					copy._props[ k ] = v
				end
			end
		end
		for k, v in pairs( self._attributes ) do copy._attributes[ k ] = v end
		for _, c in ipairs( self._children ) do
			local cc = c:Clone()
			if cc then cc.Parent = copy end
		end
		return copy
	end

	local function setParentInternal( inst, newParent )
		local oldParent = inst._props.Parent
		if oldParent == newParent then return end
		if oldParent and oldParent._children then
			for i = #oldParent._children, 1, -1 do
				if oldParent._children[ i ] == inst then
					tremove( oldParent._children, i )
					break
				end
			end
			oldParent.ChildRemoved:Fire( inst )
		end
		inst._props.Parent = newParent
		if newParent and newParent._children then
			newParent._children[ #newParent._children + 1 ] = inst
			newParent.ChildAdded:Fire( inst )
		end
		inst.AncestryChanged:Fire( inst, newParent )
		for _, desc in ipairs( inst:GetDescendants() ) do
			desc.AncestryChanged:Fire( inst, newParent )
		end
	end

	local InstanceMT = {}
	function InstanceMT:__index( k )
		local props = rawget( self, "_props" )
		if props and props[ k ] ~= nil then return props[ k ] end
		local sigs = rawget( self, "_signals" )
		if sigs and sigs[ k ] ~= nil then return sigs[ k ] end
		local m = InstanceMethods[ k ]
		if m ~= nil then return m end
		-- Roblox allows indexing children by Name when no property/method matches
		local children = rawget( self, "_children" )
		if children then
			for i = 1, #children do
				if children[ i ]._props.Name == k then return children[ i ] end
			end
		end
		return nil
	end

	function InstanceMT:__newindex( k, v )
		if k == "ClassName" then return end
		if k == "Parent" then
			setParentInternal( self, v )
			local ps = self._propSignals.Parent
			if ps then ps:Fire() end
			self._signals.Changed:Fire( "Parent" )
			return
		end
		local props = rawget( self, "_props" )
		local old = props[ k ]
		if old == v then return end
		props[ k ] = v
		local ps = self._propSignals[ k ]
		if ps then ps:Fire() end
		if isClassA( props.ClassName, "ValueBase" ) and k == "Value" then
			self._signals.Changed:Fire( v )
		else
			self._signals.Changed:Fire( k )
		end
	end

	function InstanceMT:__tostring()
		return self._props.Name or self._props.ClassName
	end

	local function collectDefaults( className, out )
		local p = ClassParents[ className ]
		if p then collectDefaults( p, out ) end
		local def = Classes[ className ] and Classes[ className ].defaults
		if def then
			for k, v in pairs( def ) do
				if type( v ) == "function" then
					out[ k ] = v()
				else
					out[ k ] = v
				end
			end
		end
	end

	local function runInits( className, inst )
		local p = ClassParents[ className ]
		if p then runInits( p, inst ) end
		local init = Classes[ className ] and Classes[ className ].init
		if init then init( inst ) end
	end

	function Instance.new( className, parent )
		local cls = Classes[ className ]
		if not cls then
			error( "[RbxUI] Unknown Instance class '" .. tostring( className ) .. "'", 2 )
		end
		NextInstanceId = NextInstanceId + 1
		local props = {
			Name = className,
			ClassName = className,
			Archivable = true,
			Parent = nil,
		}
		collectDefaults( className, props )

		local sigs = {
			Changed          = Signal.new(),
			ChildAdded       = Signal.new(),
			ChildRemoved     = Signal.new(),
			AncestryChanged  = Signal.new(),
			AttributeChanged = Signal.new(),
			Destroying       = Signal.new(),
		}

		local inst = setmetatable( {
			__rbxInstance = true,
			_id           = NextInstanceId,
			_props        = props,
			_signals      = sigs,
			_propSignals  = {},
			_children     = {},
			_attributes   = {},
			_destroyed    = false,
		}, InstanceMT )

		runInits( className, inst )
		if parent then inst.Parent = parent end
		return inst
	end

	-- =========================================================================
	-- 5. Class Definitions (GuiBase2d, GuiObject, Frame, Labels, Buttons,
	--    ScrollingFrame, CanvasGroup, Modifiers, ValueBase)
	-- =========================================================================
	do
		registerClass( "Instance", nil, {} )
		registerClass( "GuiBase2d", "Instance", {
			AbsolutePosition = function() return Vector2.new( 0, 0 ) end,
			AbsoluteSize     = function() return Vector2.new( 0, 0 ) end,
			AbsoluteRotation = 0,
		} )

		registerClass( "LayerCollector", "GuiBase2d", {
			Enabled        = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		} )

		registerClass( "ScreenGui", "LayerCollector", {
			DisplayOrder        = 0,
			IgnoreGuiInset      = true,
			ReferenceResolution = false, -- nil/false = 1024x768 Rel space; or Vector2.new(1280, 720) / Vector2.new(1920, 1080)
			HostWnd             = false, -- nil/false = UI.LoginWnd
		}, function( self )
			RbxUI._registerScreenGui( self )
		end )

		registerClass( "GuiObject", "GuiBase2d", {
			Position               = function() return UDim2.new( 0, 0, 0, 0 ) end,
			Size                   = function() return UDim2.new( 0, 100, 0, 100 ) end,
			AnchorPoint            = function() return Vector2.new( 0, 0 ) end,
			Rotation               = 0,
			Visible                = true,
			ZIndex                 = 1,
			LayoutOrder            = 0,
			Active                 = false,
			ClipsDescendants       = false,
			AutomaticSize          = Enum.AutomaticSize.None,
			SizeConstraint         = Enum.SizeConstraint.RelativeXY,
			BackgroundColor3       = function() return Color3.fromRGB( 255, 255, 255 ) end,
			BackgroundTransparency = 0,
			BorderColor3           = function() return Color3.fromRGB( 27, 42, 53 ) end,
			BorderSizePixel        = 0,
			BorderMode             = Enum.BorderMode.Outline,
			GuiState               = Enum.GuiState.Idle,
		}, function( self )
			local s = self._signals
			s.MouseEnter         = Signal.new()
			s.MouseLeave         = Signal.new()
			s.MouseMoved         = Signal.new()
			s.MouseWheelForward  = Signal.new()
			s.MouseWheelBackward = Signal.new()
			s.InputBegan         = Signal.new()
			s.InputEnded         = Signal.new()
			s.GuiStateChanged    = Signal.new()
		end )

		registerClass( "Frame", "GuiObject", {} )

		registerClass( "CanvasGroup", "GuiObject", {
			GroupColor3       = function() return Color3.new( 1, 1, 1 ) end,
			GroupTransparency = 0,
		} )

		registerClass( "ScrollingFrame", "GuiObject", {
			CanvasSize                 = function() return UDim2.new( 0, 0, 2, 0 ) end,
			CanvasPosition             = function() return Vector2.new( 0, 0 ) end,
			ScrollBarThickness         = 6,
			ScrollBarImageColor3       = function() return Color3.fromRGB( 120, 165, 220 ) end,
			ScrollBarImageTransparency = 0.25,
			ScrollingDirection         = Enum.ScrollingDirection.Y,
			ScrollingEnabled           = true,
			AutomaticCanvasSize        = Enum.AutomaticSize.None,
			Active                     = true,
			ClipsDescendants           = true,
		} )

		registerClass( "TextLabel", "GuiObject", {
			Text                   = "Label",
			TextColor3             = function() return Color3.fromRGB( 235, 235, 235 ) end,
			TextTransparency       = 0,
			TextStrokeColor3       = function() return Color3.fromRGB( 0, 0, 0 ) end,
			TextStrokeTransparency = 1,
			Font                   = Enum.Font.Small,
			TextSize               = 14,
			TextXAlignment         = Enum.TextXAlignment.Center,
			TextYAlignment         = Enum.TextYAlignment.Center,
			TextWrapped            = false,
			RichText               = false,
			MaxVisibleGraphemes    = -1,
			TextBounds             = function() return Vector2.new( 0, 0 ) end,
		} )

		registerClass( "GuiButton", "GuiObject", {
			Active          = true,
			AutoButtonColor = true,
			Modal           = false,
			Selected        = false,
		}, function( self )
			local s = self._signals
			s.Activated         = Signal.new()
			s.MouseButton1Click = Signal.new()
			s.MouseButton1Down  = Signal.new()
			s.MouseButton1Up    = Signal.new()
			s.MouseButton2Click = Signal.new()
			s.MouseButton2Down  = Signal.new()
			s.MouseButton2Up    = Signal.new()
		end )

		registerClass( "TextButton", "GuiButton", {
			Text                   = "Button",
			TextColor3             = function() return Color3.fromRGB( 240, 240, 240 ) end,
			TextTransparency       = 0,
			TextStrokeColor3       = function() return Color3.fromRGB( 0, 0, 0 ) end,
			TextStrokeTransparency = 1,
			Font                   = Enum.Font.Small,
			TextSize               = 14,
			TextXAlignment         = Enum.TextXAlignment.Center,
			TextYAlignment         = Enum.TextYAlignment.Center,
			TextWrapped            = false,
			RichText               = false,
			MaxVisibleGraphemes    = -1,
			TextBounds             = function() return Vector2.new( 0, 0 ) end,
			HoverColor3            = false, -- optional override on hover
			PressColor3            = false, -- optional override on press
		} )

		registerClass( "ImageLabel", "GuiObject", {
			Image             = "white",
			ImageColor3       = function() return Color3.new( 1, 1, 1 ) end,
			ImageTransparency = 0,
			ImageRectOffset   = function() return Vector2.new( 0, 0 ) end,
			ImageRectSize     = function() return Vector2.new( 0, 0 ) end,
			ScaleType         = Enum.ScaleType.Stretch,
			SliceCenter       = function() return Rect.new( 0, 0, 0, 0 ) end,
		} )

		registerClass( "ImageButton", "GuiButton", {
			Image             = "white",
			HoverImage        = "",
			PressedImage      = "",
			ImageColor3       = function() return Color3.new( 1, 1, 1 ) end,
			ImageTransparency = 0,
			ImageRectOffset   = function() return Vector2.new( 0, 0 ) end,
			ImageRectSize     = function() return Vector2.new( 0, 0 ) end,
			ScaleType         = Enum.ScaleType.Stretch,
			SliceCenter       = function() return Rect.new( 0, 0, 0, 0 ) end,
		} )

		-- Layout & Appearance Modifiers
		registerClass( "UIBase", "Instance", {} )
		registerClass( "UIComponent", "UIBase", {} )
		registerClass( "UILayout", "UIComponent", {} )

		registerClass( "UIListLayout", "UILayout", {
			FillDirection       = Enum.FillDirection.Vertical,
			Padding             = function() return UDim.new( 0, 0 ) end,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment   = Enum.VerticalAlignment.Top,
			SortOrder           = Enum.SortOrder.LayoutOrder,
			AbsoluteContentSize = function() return Vector2.new( 0, 0 ) end,
		} )

		registerClass( "UIGridLayout", "UILayout", {
			CellSize              = function() return UDim2.new( 0, 100, 0, 100 ) end,
			CellPadding           = function() return UDim2.new( 0, 5, 0, 5 ) end,
			FillDirection         = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 0,
			HorizontalAlignment   = Enum.HorizontalAlignment.Left,
			VerticalAlignment     = Enum.VerticalAlignment.Top,
			SortOrder             = Enum.SortOrder.LayoutOrder,
			StartCorner           = Enum.StartCorner.TopLeft,
			AbsoluteContentSize   = function() return Vector2.new( 0, 0 ) end,
		} )

		registerClass( "UIPadding", "UIComponent", {
			PaddingTop    = function() return UDim.new( 0, 0 ) end,
			PaddingBottom = function() return UDim.new( 0, 0 ) end,
			PaddingLeft   = function() return UDim.new( 0, 0 ) end,
			PaddingRight  = function() return UDim.new( 0, 0 ) end,
		} )

		registerClass( "UIStroke", "UIComponent", {
			Color           = function() return Color3.fromRGB( 255, 255, 255 ) end,
			Thickness       = 1,
			Transparency    = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			LineJoinMode    = Enum.LineJoinMode.Round,
			Enabled         = true,
		} )

		registerClass( "UICorner", "UIComponent", {
			CornerRadius = function() return UDim.new( 0, 8 ) end,
		} )

		registerClass( "UIScale", "UIComponent", {
			Scale = 1,
		} )

		registerClass( "UIConstraint", "UIComponent", {} )
		registerClass( "UISizeConstraint", "UIConstraint", {
			MinSize = function() return Vector2.new( 0, 0 ) end,
			MaxSize = function() return Vector2.new( 1e9, 1e9 ) end,
		} )

		registerClass( "UIAspectRatioConstraint", "UIConstraint", {
			AspectRatio  = 1,
			AspectType   = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		} )

		registerClass( "UIGradient", "UIComponent", {
			Color        = function() return ColorSequence.new( Color3.new( 1, 1, 1 ) ) end,
			Transparency = function() return NumberSequence.new( 0 ) end,
			Rotation     = 0,
			Offset       = function() return Vector2.new( 0, 0 ) end,
			Enabled      = true,
		} )

		-- Value Objects
		registerClass( "ValueBase", "Instance", {} )
		registerClass( "NumberValue",  "ValueBase", { Value = 0 } )
		registerClass( "IntValue",     "ValueBase", { Value = 0 } )
		registerClass( "BoolValue",    "ValueBase", { Value = false } )
		registerClass( "StringValue",  "ValueBase", { Value = "" } )
		registerClass( "Color3Value",  "ValueBase", { Value = function() return Color3.new( 1, 1, 1 ) end } )
		registerClass( "Vector2Value", "ValueBase", { Value = function() return Vector2.new( 0, 0 ) end } )
		registerClass( "UDim2Value",   "ValueBase", { Value = function() return UDim2.new( 0, 0, 0, 0 ) end } )
		registerClass( "ObjectValue",  "ValueBase", { Value = false } )
	end

	-- Convenience method on UIPadding
	function InstanceMethods:SetPadding( udim )
		if type( udim ) == "number" then udim = UDim.new( 0, udim ) end
		self.PaddingTop    = UDim.new( udim.Scale, udim.Offset )
		self.PaddingBottom = UDim.new( udim.Scale, udim.Offset )
		self.PaddingLeft   = UDim.new( udim.Scale, udim.Offset )
		self.PaddingRight  = UDim.new( udim.Scale, udim.Offset )
	end

	-- =========================================================================
	-- 6. TweenService Integration & GuiObject:TweenPosition / TweenSize
	-- =========================================================================
	do
		local TS = _G.TweenService
		if TS and TS.AddAdapter then
			TS:AddAdapter( {
				name = "rbxInstance",
				accepts = function( t ) return type( t ) == "table" and t.__rbxInstance == true end,
				get = function( t, p ) return t[ p ] end,
				set = function( t, p, v ) t[ p ] = v end,
			}, true )
		end

		local function resolveEnum( group, val, default )
			if val == nil then return default end
			if type( val ) == "string" then return ( Enum[ group ] and Enum[ group ][ val ] ) or val end
			return val
		end

		local activeGuiTweens = setmetatable( {}, { __mode = "k" } )

		local function runGuiTween( guiObj, slot, goal, dir, style, duration, override, callback )
			local ts = _G.TweenService
			if not ts then return false end
			local cur = activeGuiTweens[ guiObj ] and activeGuiTweens[ guiObj ][ slot ]
			if cur and cur.PlaybackState == Enum.PlaybackState.Playing then
				if not override then return false end
				cur:Cancel()
			end
			local info = _G.TweenInfo.new(
				tonumber( duration ) or 1.0,
				resolveEnum( "EasingStyle", style, Enum.EasingStyle.Quad ),
				resolveEnum( "EasingDirection", dir, Enum.EasingDirection.Out )
			)
			local tw = ts:Create( guiObj, info, goal )
			if type( callback ) == "function" then
				tw.Completed:Once( function( state ) callback( state ) end )
			end
			activeGuiTweens[ guiObj ] = activeGuiTweens[ guiObj ] or {}
			activeGuiTweens[ guiObj ][ slot ] = tw
			tw:Play()
			return true
		end

		function InstanceMethods:TweenPosition( endPos, easingDirection, easingStyle, time, override, callback )
			return runGuiTween( self, "pos", { Position = endPos }, easingDirection, easingStyle, time, override, callback )
		end

		function InstanceMethods:TweenSize( endSize, easingDirection, easingStyle, time, override, callback )
			return runGuiTween( self, "size", { Size = endSize }, easingDirection, easingStyle, time, override, callback )
		end

		function InstanceMethods:TweenSizeAndPosition( endSize, endPos, easingDirection, easingStyle, time, override, callback )
			return runGuiTween( self, "both", { Size = endSize, Position = endPos }, easingDirection, easingStyle, time, override, callback )
		end
	end

	-- =========================================================================
	-- 7. Layout Engine (UDim2 resolution, UIPadding, UIScale, Constraints,
	--    UIListLayout, UIGridLayout, AutomaticSize, ScrollingFrame)
	-- =========================================================================
	local computeLayoutTree

	do
		local function getDirectModifiers( node )
			local mods = { strokes = {} }
			for _, c in ipairs( node._children ) do
				local cn = c._props.ClassName
				if cn == "UIPadding" then mods.padding = c
				elseif cn == "UIListLayout" or cn == "UIGridLayout" then mods.layout = c
				elseif cn == "UIScale" then mods.scale = c
				elseif cn == "UICorner" then mods.corner = c
				elseif cn == "UISizeConstraint" then mods.sizeConstraint = c
				elseif cn == "UIAspectRatioConstraint" then mods.aspect = c
				elseif cn == "UIGradient" and c._props.Enabled then mods.gradient = c
				elseif cn == "UIStroke" and c._props.Enabled then mods.strokes[ #mods.strokes + 1 ] = c end
			end
			return mods
		end

		local function getScaleFactor( node, mods )
			local s = ( mods.scale and tonumber( mods.scale._props.Scale ) ) or 1
			return s
		end

		local function resolveSizeUDim2( sizeUDim2, sizeConstraint, parentW, parentH, oxScale, oyScale )
			local refX, refY = parentW, parentH
			if sizeConstraint == Enum.SizeConstraint.RelativeXX then
				refY = parentW
			elseif sizeConstraint == Enum.SizeConstraint.RelativeYY then
				refX = parentH
			end
			local w = sizeUDim2.X.Scale * refX + sizeUDim2.X.Offset * oxScale
			local h = sizeUDim2.Y.Scale * refY + sizeUDim2.Y.Offset * oyScale
			return w, h
		end

		local function applyConstraints( w, h, mods, oxScale, oyScale )
			if mods.aspect then
				local ar = max( 1e-4, tonumber( mods.aspect._props.AspectRatio ) or 1 )
				local dom = mods.aspect._props.DominantAxis
				local at  = mods.aspect._props.AspectType
				if at == Enum.AspectType.FitWithinMaxSize then
					if w / max( 1e-4, h ) > ar then w = h * ar else h = w / ar end
				else
					if dom == Enum.DominantAxis.Width then h = w / ar else w = h * ar end
				end
			end
			if mods.sizeConstraint then
				local mn = mods.sizeConstraint._props.MinSize
				local mx = mods.sizeConstraint._props.MaxSize
				w = clamp( w, mn.X * oxScale, mx.X * oxScale )
				h = clamp( h, mn.Y * oyScale, mx.Y * oyScale )
			end
			return w, h
		end

		local function resolvePaddingRect( x, y, w, h, pad, oxScale, oyScale )
			if not pad then return x, y, w, h, 0, 0, 0, 0 end
			local pl = pad._props.PaddingLeft.Scale * w + pad._props.PaddingLeft.Offset * oxScale
			local pr = pad._props.PaddingRight.Scale * w + pad._props.PaddingRight.Offset * oxScale
			local pt = pad._props.PaddingTop.Scale * h + pad._props.PaddingTop.Offset * oyScale
			local pb = pad._props.PaddingBottom.Scale * h + pad._props.PaddingBottom.Offset * oyScale
			return x + pl, y + pt, max( 0, w - pl - pr ), max( 0, h - pt - pb ), pl, pt, pr, pb
		end

		local function sortGuiChildren( list, sortOrder )
			if sortOrder == Enum.SortOrder.Name then
				tsort( list, function( a, b )
					if a.node._props.Name ~= b.node._props.Name then
						return a.node._props.Name < b.node._props.Name
					end
					return a.idx < b.idx
				end )
			else
				tsort( list, function( a, b )
					local la, lb = a.node._props.LayoutOrder or 0, b.node._props.LayoutOrder or 0
					if la ~= lb then return la < lb end
					return a.idx < b.idx
				end )
			end
		end

		local function resolveFontName( f )
			if type( f ) == "string" and Enum.Font[ f ] then return Enum.Font[ f ] end
			return f or "Small"
		end

		local function safeGetFont( fontName )
			local names = { fontName or "Small", "Small" }
			for _, name in ipairs( names ) do
				if UI and UI.GetFontByPatternName then
					local h = UI:GetFontByPatternName( name )
					if h and h ~= FONT.INVALID_FONT_HANDLE then return h end
				end
				if _G and _G.ObtainFont then
					local h = _G.ObtainFont( name )
					if h and h ~= FONT.INVALID_FONT_HANDLE then return h end
				end
			end
			return FONT and FONT.INVALID_FONT_HANDLE or nil
		end
		RbxUI._safeGetFont = safeGetFont

		local function measureNodeText( node, maxW )
			local txt = tostring( node._props.Text or "" )
			if txt == "" then return 0, 0 end
			local font = resolveFontName( node._props.Font )
			local hFont = safeGetFont( font )
			if _G.MeasureText and hFont and hFont ~= ( FONT and FONT.INVALID_FONT_HANDLE ) then
				local dummy = UI:Quat( 0, 0, maxW and maxW > 0 and maxW or 10000, 10000 )
				local flags = ( FONT and FONT.TF_NOCLIP or 0 ) + ( node._props.TextWrapped and ( FONT and FONT.TF_WORDBREAK or 0 ) or ( FONT and FONT.TF_SINGLELINE or 0 ) )
				local ok, q = pcall( _G.MeasureText, txt, hFont, dummy, flags, dummy )
				if ok and q and q.z and q.z > 0 then
					return q.z, q.w
				end
			end
			return #txt * 6, 16
		end

		computeLayoutTree = function( node, parentX, parentY, parentW, parentH, oxScale, oyScale, inheritedScale )
			local p = node._props
			local mods = getDirectModifiers( node )
			node._mods = mods
			local scale = ( inheritedScale or 1 ) * getScaleFactor( node, mods )
			local sx, sy = oxScale * scale, oyScale * scale

			local w, h
			if node._layoutOverrideSize then
				w, h = node._layoutOverrideSize.X, node._layoutOverrideSize.Y
			else
				w, h = resolveSizeUDim2( p.Size, p.SizeConstraint, parentW, parentH, sx, sy )
			end
			w, h = applyConstraints( w, h, mods, sx, sy )

			-- AutomaticSize from TextBounds if TextLabel / TextButton
			local auto = p.AutomaticSize
			if p.Text ~= nil then
				local tw, th = measureNodeText( node, w )
				p.TextBounds = Vector2.new( tw / max( 1e-4, sx ), th / max( 1e-4, sy ) )
				if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then w = max( w, tw + 8 * sx ) end
				if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then h = max( h, th + 4 * sy ) end
			end

			local x, y
			if node._layoutOverridePos then
				x, y = node._layoutOverridePos.X, node._layoutOverridePos.Y
			else
				local pos = p.Position
				local ap  = p.AnchorPoint
				x = parentX + pos.X.Scale * parentW + pos.X.Offset * sx - ap.X * w
				y = parentY + pos.Y.Scale * parentH + pos.Y.Offset * sy - ap.Y * h
			end

			p.AbsolutePosition = Vector2.new( x, y )
			p.AbsoluteSize     = Vector2.new( w, h )
			p.AbsoluteRotation = p.Rotation or 0

			-- Inner content rect after UIPadding + ScrollingFrame canvas offset
			local cx, cy, cw, ch, pl, pt, pr, pb = resolvePaddingRect( x, y, w, h, mods.padding, sx, sy )
			if p.ClassName == "ScrollingFrame" then
				local cs = p.CanvasSize
				local canvasW = max( cw, cs.X.Scale * w + cs.X.Offset * sx )
				local canvasH = max( ch, cs.Y.Scale * h + cs.Y.Offset * sy )
				node._canvasW, node._canvasH = canvasW, canvasH
				local cpos = p.CanvasPosition
				cx = cx - cpos.X * sx
				cy = cy - cpos.Y * sy
				cw = canvasW
				ch = canvasH
			end

			-- Gather visible GuiObject children
			local guiChildren = {}
			for i, c in ipairs( node._children ) do
				if c:IsA( "GuiObject" ) then
					c._layoutOverridePos  = nil
					c._layoutOverrideSize = nil
					if c._props.Visible then
						guiChildren[ #guiChildren + 1 ] = { node = c, idx = i }
					end
				end
			end

			local layout = mods.layout
			if layout and layout._props.ClassName == "UIListLayout" then
				local lp = layout._props
				sortGuiChildren( guiChildren, lp.SortOrder )
				local isVert = ( lp.FillDirection == Enum.FillDirection.Vertical )
				local padPx = isVert
					and ( lp.Padding.Scale * ch + lp.Padding.Offset * sy )
					or  ( lp.Padding.Scale * cw + lp.Padding.Offset * sx )

				-- First pass: compute child sizes
				local totalMain, maxCross = 0, 0
				for i, item in ipairs( guiChildren ) do
					local c = item.node
					local cm = getDirectModifiers( c )
					local cs = scale * getScaleFactor( c, cm )
					local cw_i, ch_i = resolveSizeUDim2( c._props.Size, c._props.SizeConstraint, cw, ch, oxScale * cs, oyScale * cs )
					cw_i, ch_i = applyConstraints( cw_i, ch_i, cm, oxScale * cs, oyScale * cs )
					item.w, item.h = cw_i, ch_i
					if isVert then
						totalMain = totalMain + ch_i
						if cw_i > maxCross then maxCross = cw_i end
					else
						totalMain = totalMain + cw_i
						if ch_i > maxCross then maxCross = ch_i end
					end
				end
				if #guiChildren > 1 then totalMain = totalMain + padPx * ( #guiChildren - 1 ) end
				lp.AbsoluteContentSize = isVert
					and Vector2.new( maxCross / max( 1e-4, sx ), totalMain / max( 1e-4, sy ) )
					or  Vector2.new( totalMain / max( 1e-4, sx ), maxCross / max( 1e-4, sy ) )

				-- AutomaticSize on container from UIListLayout
				if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then
					if isVert then
						h = totalMain + pt + pb
						p.AbsoluteSize = Vector2.new( w, h )
						ch = totalMain
					end
				end
				if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then
					if not isVert then
						w = totalMain + pl + pr
						p.AbsoluteSize = Vector2.new( w, h )
						cw = totalMain
					end
				end

				local startMain = 0
				if isVert then
					if lp.VerticalAlignment == Enum.VerticalAlignment.Center then startMain = ( ch - totalMain ) * 0.5
					elseif lp.VerticalAlignment == Enum.VerticalAlignment.Bottom then startMain = ch - totalMain end
				else
					if lp.HorizontalAlignment == Enum.HorizontalAlignment.Center then startMain = ( cw - totalMain ) * 0.5
					elseif lp.HorizontalAlignment == Enum.HorizontalAlignment.Right then startMain = cw - totalMain end
				end

				local cursor = startMain
				for _, item in ipairs( guiChildren ) do
					local c = item.node
					local iw, ih = item.w, item.h
					local ix, iy
					if isVert then
						iy = cy + cursor
						if lp.HorizontalAlignment == Enum.HorizontalAlignment.Center then ix = cx + ( cw - iw ) * 0.5
						elseif lp.HorizontalAlignment == Enum.HorizontalAlignment.Right then ix = cx + cw - iw
						else ix = cx end
						cursor = cursor + ih + padPx
					else
						ix = cx + cursor
						if lp.VerticalAlignment == Enum.VerticalAlignment.Center then iy = cy + ( ch - ih ) * 0.5
						elseif lp.VerticalAlignment == Enum.VerticalAlignment.Bottom then iy = cy + ch - ih
						else iy = cy end
						cursor = cursor + iw + padPx
					end
					c._layoutOverridePos  = Vector2.new( ix, iy )
					c._layoutOverrideSize = Vector2.new( iw, ih )
					computeLayoutTree( c, cx, cy, cw, ch, oxScale, oyScale, scale )
				end

			elseif layout and layout._props.ClassName == "UIGridLayout" then
				local gp = layout._props
				sortGuiChildren( guiChildren, gp.SortOrder )
				local cellW = gp.CellSize.X.Scale * cw + gp.CellSize.X.Offset * sx
				local cellH = gp.CellSize.Y.Scale * ch + gp.CellSize.Y.Offset * sy
				local padX  = gp.CellPadding.X.Scale * cw + gp.CellPadding.X.Offset * sx
				local padY  = gp.CellPadding.Y.Scale * ch + gp.CellPadding.Y.Offset * sy
				local maxCells = gp.FillDirectionMaxCells or 0
				local isHoriz = ( gp.FillDirection == Enum.FillDirection.Horizontal )
				local cols
				if isHoriz then
					cols = maxCells > 0 and maxCells or max( 1, floor( ( cw + padX ) / max( 1, cellW + padX ) ) )
				else
					local rows = maxCells > 0 and maxCells or max( 1, floor( ( ch + padY ) / max( 1, cellH + padY ) ) )
					cols = max( 1, ceil( #guiChildren / rows ) )
				end
				local totalRows = ceil( #guiChildren / max( 1, cols ) )
				local usedCols  = min( #guiChildren, cols )
				local gridW = usedCols > 0 and ( usedCols * cellW + ( usedCols - 1 ) * padX ) or 0
				local gridH = totalRows > 0 and ( totalRows * cellH + ( totalRows - 1 ) * padY ) or 0
				gp.AbsoluteContentSize = Vector2.new( gridW / max( 1e-4, sx ), gridH / max( 1e-4, sy ) )

				local ox, oy = 0, 0
				if gp.HorizontalAlignment == Enum.HorizontalAlignment.Center then ox = ( cw - gridW ) * 0.5
				elseif gp.HorizontalAlignment == Enum.HorizontalAlignment.Right then ox = cw - gridW end
				if gp.VerticalAlignment == Enum.VerticalAlignment.Center then oy = ( ch - gridH ) * 0.5
				elseif gp.VerticalAlignment == Enum.VerticalAlignment.Bottom then oy = ch - gridH end

				for idx, item in ipairs( guiChildren ) do
					local c = item.node
					local r = floor( ( idx - 1 ) / cols )
					local col = ( idx - 1 ) % cols
					local ix = cx + ox + col * ( cellW + padX )
					local iy = cy + oy + r * ( cellH + padY )
					c._layoutOverridePos  = Vector2.new( ix, iy )
					c._layoutOverrideSize = Vector2.new( cellW, cellH )
					computeLayoutTree( c, cx, cy, cw, ch, oxScale, oyScale, scale )
				end

			else
				for _, item in ipairs( guiChildren ) do
					computeLayoutTree( item.node, cx, cy, cw, ch, oxScale, oyScale, scale )
				end
			end
		end
	end

	-- =========================================================================
	-- 8. Immediate-Mode Renderer (UI.drawer, _G.UI_DrawText, Clipping, Strokes,
	--    Corners, Gradients, CanvasGroup Tint & Transparency)
	-- =========================================================================
	local drawScreenGuiTree

	do
		local function getTextAlignFlags( xa, ya, wrapped )
			if not FONT then return 0 end
			local f = FONT.TF_NOCLIP or 0
			if xa == Enum.TextXAlignment.Left then f = f + ( FONT.TF_LEFT or 0 )
			elseif xa == Enum.TextXAlignment.Right then f = f + ( FONT.TF_RIGHT or 0 )
			else f = f + ( FONT.TF_HCENTER or 0 ) end

			if ya == Enum.TextYAlignment.Top then f = f + ( FONT.TF_TOP or 0 )
			elseif ya == Enum.TextYAlignment.Bottom then f = f + ( FONT.TF_BOTTOM or 0 )
			else f = f + ( FONT.TF_VCENTER or 0 ) end

			if wrapped then f = f + ( FONT.TF_WORDBREAK or 0 )
			else f = f + ( FONT.TF_SINGLELINE or 0 ) end
			return f
		end

		local function combineTransparency( t1, t2 )
			return 1 - ( 1 - clamp( tonumber( t1 ) or 0, 0, 1 ) ) * ( 1 - clamp( tonumber( t2 ) or 0, 0, 1 ) )
		end

		local function tintColor( c, tint )
			if not tint then return c end
			return Color3.new( c.R * tint.R, c.G * tint.G, c.B * tint.B )
		end

		local function intersectClip( clip, x, y, w, h )
			if not clip then return { x1 = x, y1 = y, x2 = x + w, y2 = y + h } end
			local x1 = max( clip.x1, x )
			local y1 = max( clip.y1, y )
			local x2 = min( clip.x2, x + w )
			local y2 = min( clip.y2, y + h )
			return { x1 = x1, y1 = y1, x2 = max( x1, x2 ), y2 = max( y1, y2 ) }
		end

		local texCache = {}
		local function getTexHandle( name )
			name = ( name and name ~= "" ) and name or "white"
			local h = texCache[ name ]
			if h ~= nil then return h end
			if UI and UI.GetTex then
				h = UI:GetTex( name )
				if not h or h == UI.INVALID_RESOURCE_HANDLE then
					h = UI:GetTex( "white" )
				end
				texCache[ name ] = h
				return h
			end
			return nil
		end

		local function drawClippedRectUV( x, y, w, h, argb, frameName, clip, u0, v0, u1, v1 )
			if w <= 0 or h <= 0 or not UI or not UI.drawer or not UI.drawer.DrawImagedRect then return end
			local cx1, cy1, cx2, cy2 = 0, 0, 1024, 768
			if clip then
				cx1, cy1, cx2, cy2 = clip.x1, clip.y1, clip.x2, clip.y2
				if x + w <= cx1 or x >= cx2 or y + h <= cy1 or y >= cy2 then return end
			end
			local hTex = getTexHandle( frameName )
			if hTex and hTex ~= UI.INVALID_RESOURCE_HANDLE then
				UI.drawer:DrawImagedRect( x, y, w, h, cx1, cy1, max( 0, cx2 - cx1 ), max( 0, cy2 - cy1 ), hTex, argb, u0 or 0, v0 or 0, u1 or 1, v1 or 1, false )
			end
		end

		local function drawClippedRect( x, y, w, h, argb, frameName, clip )
			drawClippedRectUV( x, y, w, h, argb, frameName, clip, 0, 0, 1, 1 )
		end

		local function evalGradientAt( grad, u, v, baseColor, baseTrans, groupTint, groupTrans )
			local gp = grad._props
			local cseq = gp.Color
			local tseq = gp.Transparency
			local rot  = ( tonumber( gp.Rotation ) or 0 ) * ( math.pi / 180 )
			local off  = gp.Offset or Vector2.zero
			local dx   = ( u - 0.5 ) - ( off.X or 0 )
			local dy   = ( v - 0.5 ) - ( off.Y or 0 )
			local ca, sa = cos( rot ), sin( rot )
			local denom = max( 1e-4, abs( ca ) + abs( sa ) )
			local t = clamp( ( dx * ca + dy * sa ) / denom + 0.5, 0, 1 )

			local gc
			if type( cseq ) == "table" then
				if cseq.Eval then gc = cseq:Eval( t )
				elseif cseq.R ~= nil then gc = cseq
				elseif cseq[ 1 ] and cseq[ 1 ].R ~= nil then
					gc = ColorSequence.new( cseq ):Eval( t )
				else gc = Color3.new( 1, 1, 1 ) end
			else
				gc = Color3.new( 1, 1, 1 )
			end

			local gt
			if type( tseq ) == "number" then
				gt = tseq
			elseif type( tseq ) == "table" then
				if tseq.Eval then gt = tseq:Eval( t )
				elseif tseq.Map then gt = tseq:Map( t )
				elseif type( tseq[ 1 ] ) == "number" then
					gt = NumberSequence.new( tseq ):Eval( t )
				else gt = 0 end
			else
				gt = 0
			end

			local col = tintColor( Color3.new( baseColor.R * gc.R, baseColor.G * gc.G, baseColor.B * gc.B ), groupTint )
			local tr  = combineTransparency( combineTransparency( baseTrans, gt ), groupTrans )
			return col, tr
		end

		local function cornerInsetAtY( relY, h, r )
			if r <= 0.5 then return 0 end
			if relY < r then
				local dy = r - relY
				return r - sqrt( max( 0, r * r - dy * dy ) )
			elseif relY > h - r then
				local dy = relY - ( h - r )
				return r - sqrt( max( 0, r * r - dy * dy ) )
			end
			return 0
		end

		local function cornerInsetAtX( relX, w, r )
			if r <= 0.5 then return 0 end
			if relX < r then
				local dx = r - relX
				return r - sqrt( max( 0, r * r - dx * dx ) )
			elseif relX > w - r then
				local dx = relX - ( w - r )
				return r - sqrt( max( 0, r * r - dx * dx ) )
			end
			return 0
		end

		local function drawRoundedOrChamferedRect( x, y, w, h, r, argb, clip )
			if r <= 0.5 then
				drawClippedRect( x, y, w, h, argb, "white", clip )
				return
			end
			r = min( r, min( w, h ) * 0.5 )
			drawClippedRect( x + r, y, w - 2 * r, h, argb, "white", clip )
			drawClippedRect( x, y + r, r, h - 2 * r, argb, "white", clip )
			drawClippedRect( x + w - r, y + r, r, h - 2 * r, argb, "white", clip )
			local steps = max( 2, min( 6, floor( r ) ) )
			for i = 1, steps do
				local t0 = ( i - 1 ) / steps
				local t1 = i / steps
				local ym = ( t0 + t1 ) * 0.5
				local dy = 1 - ym
				local inset = r * ( 1 - sqrt( max( 0, 1 - dy * dy ) ) )
				local bh = ( r / steps )
				local ty = y + ( i - 1 ) * bh
				local by = y + h - i * bh
				drawClippedRect( x + inset, ty, r - inset, bh + 0.35, argb, "white", clip )
				drawClippedRect( x + w - r, ty, r - inset, bh + 0.35, argb, "white", clip )
				drawClippedRect( x + inset, by, r - inset, bh + 0.35, argb, "white", clip )
				drawClippedRect( x + w - r, by, r - inset, bh + 0.35, argb, "white", clip )
			end
		end

		local function snapRelX( rx )
			if UI and UI.RelToX and UI.XToRel then
				return UI:XToRel( floor( UI:RelToX( rx ) + 0.5 ) )
			end
			return rx
		end

		local function snapRelY( ry )
			if UI and UI.RelToY and UI.YToRel then
				return UI:YToRel( floor( UI:RelToY( ry ) + 0.5 ) )
			end
			return ry
		end

		local function drawGradientRect( x, y, w, h, grad, baseColor, baseTrans, groupTint, groupTrans, clip, radius, frameName )
			radius = min( tonumber( radius ) or 0, min( w, h ) * 0.5 )
			frameName = ( frameName and frameName ~= "" ) and frameName or "white"
			local rot = ( tonumber( grad._props.Rotation ) or 0 ) % 360
			local ca, sa = abs( cos( rot * math.pi / 180 ) ), abs( sin( rot * math.pi / 180 ) )
			local isDiagonal = ( ca > 0.18 and sa > 0.18 )
			local isVert = ( sa >= ca )
			local reqBands = tonumber( grad._props.Bands ) or 0

			if isDiagonal and frameName == "white" then
				local gx = reqBands > 0 and reqBands or clamp( floor( w / 6 ), 12, 24 )
				local gy = reqBands > 0 and reqBands or clamp( floor( h / 6 ), 12, 24 )
				for iy = 1, gy do
					local v0, v1 = ( iy - 1 ) / gy, iy / gy
					local vm = ( v0 + v1 ) * 0.5
					local by0 = snapRelY( y + v0 * h )
					local by1 = snapRelY( y + v1 * h )
					local bh  = by1 - by0
					if bh > 0 then
						local insetX = cornerInsetAtY( vm * h, h, radius )
						local minX = snapRelX( x + insetX )
						local maxX = snapRelX( x + w - insetX )
						for ix = 1, gx do
							local u0, u1 = ( ix - 1 ) / gx, ix / gx
							local um = ( u0 + u1 ) * 0.5
							local bx0 = max( minX, snapRelX( x + u0 * w ) )
							local bx1 = min( maxX, snapRelX( x + u1 * w ) )
							if bx1 > bx0 then
								local col, tr = evalGradientAt( grad, um, vm, baseColor, baseTrans, groupTint, groupTrans )
								if tr < 0.999 then
									drawClippedRect( bx0, by0, bx1 - bx0, bh, col:ToARGB( tr ), "white", clip )
								end
							end
						end
					end
				end
				return
			end

			local bands = reqBands > 0 and reqBands or clamp( floor( ( isVert and h or w ) / 2 ), 24, 64 )
			for i = 1, bands do
				local t0 = ( i - 1 ) / bands
				local t1 = i / bands
				local tm = ( t0 + t1 ) * 0.5
				local u = isVert and 0.5 or tm
				local v = isVert and tm or 0.5
				local col, tr = evalGradientAt( grad, u, v, baseColor, baseTrans, groupTint, groupTrans )
				if tr < 0.999 then
					local argb = col:ToARGB( tr )
					if isVert then
						local by0 = snapRelY( y + t0 * h )
						local by1 = snapRelY( y + t1 * h )
						local bh  = by1 - by0
						if bh > 0 then
							local inset = cornerInsetAtY( tm * h, h, radius )
							local bx0 = snapRelX( x + inset )
							local bx1 = snapRelX( x + w - inset )
							local bw  = bx1 - bx0
							if bw > 0 then
								local u0 = w > 0 and ( inset / w ) or 0
								local u1 = w > 0 and ( 1 - inset / w ) or 1
								drawClippedRectUV( bx0, by0, bw, bh, argb, frameName, clip, u0, t0, u1, t1 )
							end
						end
					else
						local bx0 = snapRelX( x + t0 * w )
						local bx1 = snapRelX( x + t1 * w )
						local bw  = bx1 - bx0
						if bw > 0 then
							local inset = cornerInsetAtX( tm * w, w, radius )
							local by0 = snapRelY( y + inset )
							local by1 = snapRelY( y + h - inset )
							local bh  = by1 - by0
							if bh > 0 then
								local v0 = h > 0 and ( inset / h ) or 0
								local v1 = h > 0 and ( 1 - inset / h ) or 1
								drawClippedRectUV( bx0, by0, bw, bh, argb, frameName, clip, t0, v0, t1, v1 )
							end
						end
					end
				end
			end
		end

		local function drawBorderStroke( x, y, w, h, thick, argb, clip, grad, baseColor, baseTrans, groupTint, groupTrans )
			if thick <= 0 or w <= 0 or h <= 0 then return end
			local px = ( UI and UI.XToRel and UI:XToRel( 1 ) ) or 1
			local py = ( UI and UI.YToRel and UI:YToRel( 1 ) ) or 1
			local tx = max( px, thick )
			local ty = max( py, thick )
			if grad then
				drawGradientRect( x, y, w, ty, grad, baseColor, baseTrans, groupTint, groupTrans, clip, 0, "white" )
				drawGradientRect( x, y + h - ty, w, ty, grad, baseColor, baseTrans, groupTint, groupTrans, clip, 0, "white" )
				drawGradientRect( x, y + ty, tx, max( 0, h - 2 * ty ), grad, baseColor, baseTrans, groupTint, groupTrans, clip, 0, "white" )
				drawGradientRect( x + w - tx, y + ty, tx, max( 0, h - 2 * ty ), grad, baseColor, baseTrans, groupTint, groupTrans, clip, 0, "white" )
				return
			end
			drawClippedRect( x, y, w, ty, argb, "white", clip )
			drawClippedRect( x, y + h - ty, w, ty, argb, "white", clip )
			drawClippedRect( x, y + ty, tx, max( 0, h - 2 * ty ), argb, "white", clip )
			drawClippedRect( x + w - tx, y + ty, tx, max( 0, h - 2 * ty ), argb, "white", clip )
		end

		local function drawNodeSelf( node, oxScale, oyScale, groupTint, groupTrans, clip )
			local p = node._props
			local mods = node._mods or {}
			local pos  = p.AbsolutePosition
			local size = p.AbsoluteSize
			local x, y, w, h = pos.X, pos.Y, size.X, size.Y
			if w <= 0 or h <= 0 then return end
			if clip and ( x + w <= clip.x1 or x >= clip.x2 or y + h <= clip.y1 or y >= clip.y2 ) then
				return
			end

			local radius = 0
			if mods.corner then
				local cr = mods.corner._props.CornerRadius
				radius = cr.Scale * min( w, h ) + cr.Offset * min( oxScale, oyScale )
			end

			-- Background Color & Button AutoButtonColor state modulation
			local bgTrans = combineTransparency( p.BackgroundTransparency, groupTrans )
			if bgTrans < 0.999 then
				local bgCol = p.BackgroundColor3
				if node:IsA( "GuiButton" ) and p.AutoButtonColor then
					if p.GuiState == Enum.GuiState.Press then
						bgCol = ( type( p.PressColor3 ) == "table" and p.PressColor3 ) or bgCol:Lerp( Color3.new( 0, 0, 0 ), 0.25 )
					elseif p.GuiState == Enum.GuiState.Hover then
						bgCol = ( type( p.HoverColor3 ) == "table" and p.HoverColor3 ) or bgCol:Lerp( Color3.new( 1, 1, 1 ), 0.14 )
					end
				end
				if mods.gradient then
					drawGradientRect( x, y, w, h, mods.gradient, bgCol, p.BackgroundTransparency, groupTint, groupTrans, clip, radius, "white" )
				else
					local finalBg = tintColor( bgCol, groupTint ):ToARGB( bgTrans )
					drawRoundedOrChamferedRect( x, y, w, h, radius, finalBg, clip )
				end
			end

			-- Legacy BorderSizePixel
			local bsp = tonumber( p.BorderSizePixel ) or 0
			if bsp > 0 and bgTrans < 0.999 then
				local bt = bsp * min( oxScale, oyScale )
				local bc = tintColor( p.BorderColor3, groupTint ):ToARGB( bgTrans )
				if p.BorderMode == Enum.BorderMode.Outline then
					drawBorderStroke( x - bt, y - bt, w + 2 * bt, h + 2 * bt, bt, bc, clip )
				else
					drawBorderStroke( x, y, w, h, bt, bc, clip )
				end
			end

			-- ImageLabel / ImageButton (with full UIGradient color + alpha crossfade UV slice support)
			if p.Image ~= nil and p.Image ~= "" then
				local imgTrans = combineTransparency( p.ImageTransparency, groupTrans )
				if imgTrans < 0.999 then
					local frameName = p.Image
					if node:IsA( "ImageButton" ) then
						if p.GuiState == Enum.GuiState.Press and p.PressedImage ~= "" then
							frameName = p.PressedImage
						elseif p.GuiState == Enum.GuiState.Hover and p.HoverImage ~= "" then
							frameName = p.HoverImage
						end
					end
					if mods.gradient then
						drawGradientRect( x, y, w, h, mods.gradient, p.ImageColor3, p.ImageTransparency, groupTint, groupTrans, clip, radius, frameName )
					else
						local imgCol = tintColor( p.ImageColor3, groupTint ):ToARGB( imgTrans )
						drawClippedRect( x, y, w, h, imgCol, frameName, clip )
					end
				end
			end

			-- UIStroke (Border mode, supports child UIGradient on the UIStroke or parent UIGradient)
			if mods.strokes then
				for _, st in ipairs( mods.strokes ) do
					local sp = st._props
					local isTextTarget = ( p.Text ~= nil )
					if not isTextTarget or sp.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
						local stTrans = combineTransparency( sp.Transparency, groupTrans )
						if stTrans < 0.999 then
							local thick = max( 0.75, ( tonumber( sp.Thickness ) or 1 ) * min( oxScale, oyScale ) )
							local stGrad = st:FindFirstChildOfClass( "UIGradient" )
							if stGrad and not stGrad._props.Enabled then stGrad = nil end
							local stArgb = tintColor( sp.Color, groupTint ):ToARGB( stTrans )
							drawBorderStroke( x, y, w, h, thick, stArgb, clip, stGrad, sp.Color, sp.Transparency, groupTint, groupTrans )
						end
					end
				end
			end

			-- TextLabel / TextButton (supports UIGradient color + alpha crossfade across text!)
			if p.Text ~= nil and tostring( p.Text ) ~= "" and _G.UI_DrawText then
				local txtTrans = combineTransparency( p.TextTransparency, groupTrans )
				if txtTrans < 0.999 then
					local tx, ty, tw, th = x, y, w, h
					if mods.padding then
						local pad = mods.padding._props
						local pl = pad.PaddingLeft.Scale * w + pad.PaddingLeft.Offset * oxScale
						local pr = pad.PaddingRight.Scale * w + pad.PaddingRight.Offset * oxScale
						local pt = pad.PaddingTop.Scale * h + pad.PaddingTop.Offset * oyScale
						local pb = pad.PaddingBottom.Scale * h + pad.PaddingBottom.Offset * oyScale
						tx, ty, tw, th = x + pl, y + pt, max( 0, w - pl - pr ), max( 0, h - pt - pb )
					end
					if not clip or ( tx + tw > clip.x1 and tx < clip.x2 and ty + th > clip.y1 and ty < clip.y2 ) then
						local txt = tostring( p.Text )
						local maxG = tonumber( p.MaxVisibleGraphemes ) or -1
						if maxG >= 0 and maxG < #txt then txt = ssub( txt, 1, maxG ) end
						local fontName = ( type( p.Font ) == "string" and Enum.Font[ p.Font ] ) or p.Font or "Small"
						local hFont = RbxUI._safeGetFont( fontName )
						if hFont and hFont ~= ( FONT and FONT.INVALID_FONT_HANDLE ) then
							local flags = getTextAlignFlags( p.TextXAlignment, p.TextYAlignment, p.TextWrapped )
							local cx1, cy1, cx2, cy2 = 0, 0, 1024, 768
							if clip then cx1, cy1, cx2, cy2 = clip.x1, clip.y1, clip.x2, clip.y2 end

							local strokeTrans = p.TextStrokeTransparency
							local strokeCol   = p.TextStrokeColor3
							if mods.strokes then
								for _, st in ipairs( mods.strokes ) do
									if st._props.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
										strokeTrans = st._props.Transparency
										strokeCol   = st._props.Color
									end
								end
							end

							if UI.drawer and UI.drawer.EndUiDrawing then UI.drawer:EndUiDrawing() end
							local effStrokeTrans = combineTransparency( strokeTrans, groupTrans )
							if effStrokeTrans < 0.999 then
								local sArgb = tintColor( strokeCol, groupTint ):ToARGB( effStrokeTrans )
								local d = ( UI and UI.XToRel and UI:XToRel( 1 ) ) or 1
								_G.UI_DrawText( txt, hFont, UI:Quat( tx + d, ty + d, tw, th ), sArgb, 0, flags, UI:Quat( cx1, cy1, max( 0, cx2 - cx1 ), max( 0, cy2 - cy1 ) ) )
							end

							local textGrad = mods.gradient
							if textGrad and p.BackgroundTransparency < 0.999 then
								-- If the node has a background, only slice text when the gradient has non-zero transparency (e.g. alpha crossfade)
								local tseq = textGrad._props.Transparency
								local hasAlphaGrad = ( type( tseq ) == "table" and tseq.Eval and ( tseq:Eval( 0 ) > 0.01 or tseq:Eval( 0.5 ) > 0.01 or tseq:Eval( 1 ) > 0.01 ) )
								if not hasAlphaGrad then textGrad = nil end
							end

							if textGrad then
								-- Slice text clip rect into pixel-snapped bands for smooth color/alpha text gradient
								local rot = ( tonumber( textGrad._props.Rotation ) or 0 ) % 360
								local isVert = ( abs( sin( rot * math.pi / 180 ) ) >= abs( cos( rot * math.pi / 180 ) ) )
								local bands = 16
								local useGradColor = ( p.BackgroundTransparency >= 0.999 )
								local baseTxtCol = p.TextColor3
								for i = 1, bands do
									local t0 = ( i - 1 ) / bands
									local t1 = i / bands
									local tm = ( t0 + t1 ) * 0.5
									local col, tr = evalGradientAt( textGrad, isVert and 0.5 or tm, isVert and tm or 0.5, baseTxtCol, p.TextTransparency, groupTint, groupTrans )
									if not useGradColor then
										col = tintColor( baseTxtCol, groupTint )
									end
									if tr < 0.999 then
										local bx1, by1, bx2, by2 = cx1, cy1, cx2, cy2
										if isVert then
											by1 = max( cy1, snapRelY( ty + t0 * th ) )
											by2 = min( cy2, snapRelY( ty + t1 * th ) )
										else
											bx1 = max( cx1, snapRelX( tx + t0 * tw ) )
											bx2 = min( cx2, snapRelX( tx + t1 * tw ) )
										end
										if bx2 > bx1 and by2 > by1 then
											_G.UI_DrawText( txt, hFont, UI:Quat( tx, ty, tw, th ), col:ToARGB( tr ), 0, flags, UI:Quat( bx1, by1, bx2 - bx1, by2 - by1 ) )
										end
									end
								end
							else
								local tArgb = tintColor( p.TextColor3, groupTint ):ToARGB( txtTrans )
								_G.UI_DrawText( txt, hFont, UI:Quat( tx, ty, tw, th ), tArgb, 0, flags, UI:Quat( cx1, cy1, max( 0, cx2 - cx1 ), max( 0, cy2 - cy1 ) ) )
							end
							if UI.drawer and UI.drawer.BeginUiDrawing then UI.drawer:BeginUiDrawing() end
						end
					end
				end
			end

			-- ScrollingFrame scrollbar indicator
			if p.ClassName == "ScrollingFrame" then
				local ch = node._canvasH or h
				if ch > h + 1 then
					local sbThick = ( tonumber( p.ScrollBarThickness ) or 6 ) * oxScale
					local sbTrans = combineTransparency( p.ScrollBarImageTransparency, groupTrans )
					if sbTrans < 0.999 and sbThick > 0 then
						local ratio = clamp( h / ch, 0.08, 1 )
						local thumbH = max( 12 * oyScale, h * ratio )
						local maxScroll = max( 1, ( ch - h ) / max( 1e-4, oyScale ) )
						local scrollT = clamp( p.CanvasPosition.Y / maxScroll, 0, 1 )
						local thumbY = y + ( h - thumbH ) * scrollT
						local sbArgb = tintColor( p.ScrollBarImageColor3, groupTint ):ToARGB( sbTrans )
						drawClippedRect( x + w - sbThick - 1, thumbY, sbThick, thumbH, sbArgb, "white", clip )
					end
				end
			end
		end

		local function drawNodeRecursive( node, oxScale, oyScale, groupTint, groupTrans, clip )
			local p = node._props
			if not p.Visible then return end

			if p.ClassName == "CanvasGroup" then
				groupTint  = tintColor( p.GroupColor3, groupTint )
				groupTrans = combineTransparency( groupTrans, p.GroupTransparency )
				if groupTrans >= 0.999 then return end
			end

			drawNodeSelf( node, oxScale, oyScale, groupTint, groupTrans, clip )

			local childClip = clip
			if p.ClipsDescendants then
				local pos, sz = p.AbsolutePosition, p.AbsoluteSize
				childClip = intersectClip( clip, pos.X, pos.Y, sz.X, sz.Y )
			end

			local guiChildren = {}
			for i, c in ipairs( node._children ) do
				if c:IsA( "GuiObject" ) and c._props.Visible then
					guiChildren[ #guiChildren + 1 ] = { node = c, idx = i, z = c._props.ZIndex or 1 }
				end
			end
			tsort( guiChildren, function( a, b )
				if a.z ~= b.z then return a.z < b.z end
				return a.idx < b.idx
			end )

			for _, item in ipairs( guiChildren ) do
				drawNodeRecursive( item.node, oxScale, oyScale, groupTint, groupTrans, childClip )
			end
		end

		drawScreenGuiTree = function( screenGui, oxScale, oyScale )
			local children = {}
			for i, c in ipairs( screenGui._children ) do
				if c:IsA( "GuiObject" ) and c._props.Visible then
					children[ #children + 1 ] = { node = c, idx = i, z = c._props.ZIndex or 1 }
				end
			end
			tsort( children, function( a, b )
				if a.z ~= b.z then return a.z < b.z end
				return a.idx < b.idx
			end )
			for _, item in ipairs( children ) do
				drawNodeRecursive( item.node, oxScale, oyScale, nil, 0, nil )
			end
		end
	end

	-- =========================================================================
	-- 9. ScreenGui Mounting & Interactive Hitbox ButtonWnd Synchronizer
	-- =========================================================================
	do
		local ScreenGuis = {}
		RbxUI.ScreenGuis = ScreenGuis

		local function getScaleFactors( screenGui )
			local ref = screenGui._props.ReferenceResolution
			if type( ref ) == "table" and ref.X and ref.X > 0 and ref.Y and ref.Y > 0 then
				if UI and UI.XTo1024x768 and UI.YTo1024x768 then
					local r = { x = ref.X, y = ref.Y }
					return UI:XTo1024x768( 1, r ), UI:YTo1024x768( 1, r )
				end
				return 1024 / ref.X, 768 / ref.Y
			end
			return 1, 1
		end

		local function isAncestorVisible( node, screenGui )
			local cur = node
			while cur and cur ~= screenGui do
				if cur._props and cur._props.Visible == false then return false end
				cur = cur._props and cur._props.Parent
			end
			return cur == screenGui and screenGui._props.Enabled ~= false
		end

		local function setGuiState( node, newState )
			local old = node._props.GuiState
			if old ~= newState then
				node._props.GuiState = newState
				node._signals.GuiStateChanged:Fire( newState, old )
			end
		end

		local function ensureHitboxWnd( node, hostCanvas )
			if node._hitWnd and node._hitWnd.w and node._hitHost == hostCanvas then return node._hitWnd end
			local wndName = "RbxHit_" .. tostring( node._id )
			if not UI[ wndName ] or not UI[ wndName ].w then
				local tbl = {
					def = {
						className = "ButtonWnd",
						props = {
							name  = wndName,
							style = ( UI.WS_SKIP_OPEN or 0 ) + ( UI.WS_DISABLE_ONSHOW_EFFECT or 0 ) + ( UI.WS_DISABLE_ONHIDE_EFFECT or 0 ),
						},
						layers = {},
					},
				}

				tbl.F_OnMouseIn = function()
					setGuiState( node, Enum.GuiState.Hover )
					local mx = ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					local my = ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					node._signals.MouseEnter:Fire( mx, my )
					node._signals.InputBegan:Fire( {
						UserInputType  = Enum.UserInputType.MouseMovement,
						UserInputState = Enum.UserInputState.Begin,
						Position       = Vector2.new( mx, my ),
					} )
				end

				tbl.F_OnMouseOut = function()
					setGuiState( node, Enum.GuiState.Idle )
					local mx = ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					local my = ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					node._signals.MouseLeave:Fire( mx, my )
					node._signals.InputEnded:Fire( {
						UserInputType  = Enum.UserInputType.MouseMovement,
						UserInputState = Enum.UserInputState.End,
						Position       = Vector2.new( mx, my ),
					} )
				end

				tbl.F_OnMouseMove = function( _, mx, my )
					mx = mx or ( UI.GetMouseX and UI:GetMouseX() ) or 0
					my = my or ( UI.GetMouseY and UI:GetMouseY() ) or 0
					node._signals.MouseMoved:Fire( mx, my )
				end

				tbl.F_OnMouseLButtonDown = function( _, mx, my )
					mx = mx or ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					my = my or ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					setGuiState( node, Enum.GuiState.Press )
					if node._signals.MouseButton1Down then node._signals.MouseButton1Down:Fire( mx, my ) end
					node._signals.InputBegan:Fire( {
						UserInputType  = Enum.UserInputType.MouseButton1,
						UserInputState = Enum.UserInputState.Begin,
						Position       = Vector2.new( mx, my ),
					} )
					return true
				end

				tbl.F_OnMouseLButtonUp = function( _, mx, my )
					mx = mx or ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					my = my or ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					setGuiState( node, Enum.GuiState.Hover )
					if node._signals.MouseButton1Up then node._signals.MouseButton1Up:Fire( mx, my ) end
					node._signals.InputEnded:Fire( {
						UserInputType  = Enum.UserInputType.MouseButton1,
						UserInputState = Enum.UserInputState.End,
						Position       = Vector2.new( mx, my ),
					} )
					return true
				end

				tbl.F_OnMouseLButtonClick = function()
					if node._signals.MouseButton1Click then node._signals.MouseButton1Click:Fire() end
					if node._signals.Activated then node._signals.Activated:Fire() end
					return true
				end

				tbl.F_OnMouseRButtonDown = function( _, mx, my )
					mx = mx or ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					my = my or ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					if node._signals.MouseButton2Down then node._signals.MouseButton2Down:Fire( mx, my ) end
					if node._signals.MouseButton2Click then node._signals.MouseButton2Click:Fire() end
					node._signals.InputBegan:Fire( {
						UserInputType  = Enum.UserInputType.MouseButton2,
						UserInputState = Enum.UserInputState.Begin,
						Position       = Vector2.new( mx, my ),
					} )
					return true
				end

				tbl.F_OnMouseRButtonUp = function( _, mx, my )
					mx = mx or ( UI.GetMouseX and UI:GetMouseX() ) or node._props.AbsolutePosition.X
					my = my or ( UI.GetMouseY and UI:GetMouseY() ) or node._props.AbsolutePosition.Y
					if node._signals.MouseButton2Up then node._signals.MouseButton2Up:Fire( mx, my ) end
					node._signals.InputEnded:Fire( {
						UserInputType  = Enum.UserInputType.MouseButton2,
						UserInputState = Enum.UserInputState.End,
						Position       = Vector2.new( mx, my ),
					} )
					return true
				end

				tbl.F_OnMouseWheel = function( _, delta )
					local mx = ( UI.GetMouseX and UI:GetMouseX() ) or 0
					local my = ( UI.GetMouseY and UI:GetMouseY() ) or 0
					if ( tonumber( delta ) or 0 ) > 0 then
						node._signals.MouseWheelForward:Fire( mx, my )
					else
						node._signals.MouseWheelBackward:Fire( mx, my )
					end
					local sf = node:IsA( "ScrollingFrame" ) and node or node:FindFirstAncestorOfClass( "ScrollingFrame" )
					if sf and sf._props.ScrollingEnabled then
						local ch = sf._canvasH or sf._props.AbsoluteSize.Y
						local sh = sf._props.AbsoluteSize.Y
						local maxY = max( 0, ch - sh )
						local cur = sf._props.CanvasPosition
						local step = ( tonumber( delta ) or 0 ) > 0 and -28 or 28
						sf.CanvasPosition = Vector2.new( cur.X, clamp( cur.Y + step, 0, maxY ) )
						return true
					end
					return false
				end

				UI[ wndName ] = tbl
				if UI.CreateWndFromTable then
					local created = UI:CreateWndFromTable( "UI." .. wndName )
					if created then UI[ wndName ] = created end
				end
			end
			local hw = UI[ wndName ]
			if not hw or not hw.w then return nil end
			if hw.IsChildOf and not hw:IsChildOf( hostCanvas ) then
				hostCanvas:AddChild( hw )
			end
			node._hitWnd  = hw
			node._hitHost = hostCanvas

			function node:_cleanupHitbox()
				if self._hitWnd then
					pcall( function()
						if self._hitWnd.UnlinkFromParent then self._hitWnd:UnlinkFromParent() end
					end )
					self._hitWnd = nil
				end
			end

			return hw
		end

		local function setChildWndActive( wnd, active )
			if not wnd or not wnd.w then return end
			local hideFlags = ( UI.WS_NOT_DRAW or 0 ) + ( UI.WS_NOT_MOUSE_REACT or 0 )
			if active then
				if wnd.RemoveStyle then wnd:RemoveStyle( hideFlags ) end
			else
				if wnd.AddStyle then wnd:AddStyle( hideFlags ) end
			end
		end

		local function syncHitboxes( screenGui, hostCanvas )
			for _, desc in ipairs( screenGui:GetDescendants() ) do
				if desc:IsA( "GuiObject" ) then
					local wantsHit = ( desc:IsA( "GuiButton" ) or desc._props.Active == true )
					local vis = wantsHit and isAncestorVisible( desc, screenGui )
					if vis then
						local hw = ensureHitboxWnd( desc, hostCanvas )
						if hw then
							local pos = desc._props.AbsolutePosition
							local sz  = desc._props.AbsoluteSize
							hw:SetRect( UI:Quat( pos.X, pos.Y, max( 1, sz.X ), max( 1, sz.Y ) ) )
							setChildWndActive( hw, true )
						end
					elseif desc._hitWnd then
						setChildWndActive( desc._hitWnd, false )
					end
				end
			end
		end

		function InstanceMethods:UpdateLayout()
			local sg = self:IsA( "ScreenGui" ) and self or self:FindFirstAncestorOfClass( "ScreenGui" )
			if not sg then return end
			local ox, oy = getScaleFactors( sg )
			sg._props.AbsolutePosition = Vector2.new( 0, 0 )
			sg._props.AbsoluteSize     = Vector2.new( 1024, 768 )
			for _, c in ipairs( sg._children ) do
				if c:IsA( "GuiObject" ) and c._props.Visible then
					c._layoutOverridePos  = nil
					c._layoutOverrideSize = nil
					computeLayoutTree( c, 0, 0, 1024, 768, ox, oy, 1 )
				end
			end
			if sg._canvasWnd then
				syncHitboxes( sg, sg._canvasWnd )
			end
		end

		local function ensureScreenGuiMounted( sg )
			if sg._destroyed then return end
			local host = sg._props.HostWnd or ( type( sg._props.Parent ) == "table" and sg._props.Parent.w and sg._props.Parent ) or UI.LoginWnd
			if not host or not UI or not UI.CreateWndFromTable then return end

			if sg._canvasWnd and sg._canvasWnd.w and sg._mountedHost == host then
				if sg._canvasWnd.IsChildOf and not sg._canvasWnd:IsChildOf( host ) then
					host:AddChild( sg._canvasWnd )
				end
				return sg._canvasWnd
			end

			local wndName = "RbxScreenGui_" .. tostring( sg._id )
			if not UI[ wndName ] or not UI[ wndName ].w then
				local tbl = {
					def = {
						className = "Wnd",
						props = {
							name  = wndName,
							style = ( UI.WS_NOT_MOUSE_REACT or 0 ) + ( UI.WS_NOT_KB_REACT or 0 ) + ( UI.WS_UPDATE_IF_VISIBLE or 0 ) + ( UI.WS_SKIP_OPEN or 0 ) + ( UI.WS_DISABLE_ONSHOW_EFFECT or 0 ) + ( UI.WS_DISABLE_ONHIDE_EFFECT or 0 ),
						},
						layers = {
							{
								layerType    = UI.LAYER_TEXT,
								layerStyle   = ( UI.WLS_OWNERDRAW or 0 ) + ( UI.WLS_RESIZABLE or 0 ),
								font         = { fontName = "Small" },
								formatFlags  = ( FONT and FONT.TF_LEFT or 0 ) + ( FONT and FONT.TF_VCENTER or 0 ) + ( FONT and FONT.TF_SINGLELINE or 0 ) + ( FONT and FONT.TF_NOCLIP or 0 ),
								formatInfoSz = { 1, 1 },
								color        = 0xFFFFFFFF,
							},
						},
					},
				}
				tbl.F_OnNewFrame = function()
					if sg._destroyed or not sg._props.Enabled then
						return
					end
					sg:UpdateLayout()
				end
				tbl.F_DrawLayer = function( _, x0, y0, width, height, clipX0, clipY0, clipW, clipH, layerIdx )
					if ( layerIdx and layerIdx ~= 0 ) or sg._destroyed or not sg._props.Enabled then return end
					sg:UpdateLayout()
					local ox, oy = getScaleFactors( sg )
					drawScreenGuiTree( sg, ox, oy )
				end
				UI[ wndName ] = tbl
				local created = UI:CreateWndFromTable( "UI." .. wndName )
				if created then UI[ wndName ] = created end
			end

			local cw = UI[ wndName ]
			if not cw or not cw.w then return nil end
			if cw.IsChildOf and not cw:IsChildOf( host ) then
				host:AddChild( cw )
			end
			cw:SetRect( UI:Quat( 0, 0, 1024, 768 ) )
			sg._canvasWnd   = cw
			sg._mountedHost = host

			function sg:_unmountScreenGui()
				if self._canvasWnd then
					pcall( function()
						if self._canvasWnd.UnlinkFromParent then self._canvasWnd:UnlinkFromParent() end
					end )
					self._canvasWnd = nil
				end
				for i = #ScreenGuis, 1, -1 do
					if ScreenGuis[ i ] == self then tremove( ScreenGuis, i ) end
				end
			end

			return cw
		end

		function RbxUI._registerScreenGui( sg )
			ScreenGuis[ #ScreenGuis + 1 ] = sg
			ensureScreenGuiMounted( sg )
		end

		-- Hook HostWnd (UI.LoginWnd) F_Show / F_Shutdown / Reset so ScreenGuis mount & clean up cleanly
		local LW = UI and UI.LoginWnd
		if LW and not LW.__rbxHooked then
			LW.__rbxHooked = true
			local prevShow = LW.F_Show
			function LW:F_Show( bShow, bImmediate )
				if prevShow then prevShow( self, bShow, bImmediate ) end
				if bShow then
					for _, sg in ipairs( ScreenGuis ) do
						if not sg._destroyed then
							ensureScreenGuiMounted( sg )
							sg:UpdateLayout()
						end
					end
				end
			end

			local prevShutdown = LW.F_Shutdown
			function LW:F_Shutdown()
				for _, sg in ipairs( ScreenGuis ) do
					if sg._canvasWnd and sg._canvasWnd.IsChildOf and sg._canvasWnd:IsChildOf( self ) then
						sg._canvasWnd:UnlinkFromParent()
					end
				end
				if prevShutdown then prevShutdown( self ) end
			end

			local prevReset = LW.Reset
			function LW:Reset()
				if prevReset then prevReset( self ) end
				for _, sg in ipairs( ScreenGuis ) do
					if sg._canvasWnd and sg._canvasWnd.IsChildOf and sg._canvasWnd:IsChildOf( self ) then
						sg._canvasWnd:UnlinkFromParent()
					end
				end
			end
		end
	end

	-- =========================================================================
	-- 10. Crossfade & Gradient Wipe Helper + Exports on RbxUI and _G
	-- =========================================================================
	-- RbxUI.Crossfade( fromGui, toGui, duration, directionAngle, softness, easingStyle, callback )
	-- Smoothly crossfades from `fromGui` to `toGui` over `duration` seconds.
	--   * If `directionAngle` is nil/false: performs a uniform alpha crossfade
	--     (using GroupTransparency on CanvasGroups, ImageTransparency on ImageLabels,
	--      or BackgroundTransparency/TextTransparency on Frames/Labels).
	--   * If `directionAngle` is a number (e.g. 0 = Left->Right, 90 = Top->Bottom,
	--     180 = Right->Left, 270 = Bottom->Top, 45 = Diagonal): attaches or reuses a
	--     UIGradient on both elements and animates an alpha gradient wipe across them!
	function RbxUI.Crossfade( fromGui, toGui, duration, directionAngle, softness, easingStyle, callback )
		local ts = _G.TweenService
		duration = tonumber( duration ) or 0.5
		softness = tonumber( softness ) or 0.30
		local style = easingStyle or Enum.EasingStyle.Sine

		if toGui then toGui.Visible = true end

		if directionAngle ~= nil and directionAngle ~= false and ts then
			local function collectGrads( rootObj )
				local list = {}
				if not rootObj then return list end
				local function addFor( obj )
					local g = obj:FindFirstChildOfClass( "UIGradient" )
					local created = false
					if not g then
						g = Instance.new( "UIGradient", obj )
						created = true
					end
					g.Enabled  = true
					g.Rotation = tonumber( directionAngle ) or 0
					list[ #list + 1 ] = { grad = g, created = created }
				end
				addFor( rootObj )
				for _, d in ipairs( rootObj:GetDescendants() ) do
					if d:IsA( "GuiObject" ) then addFor( d ) end
				end
				return list
			end
			local gFromList = collectGrads( fromGui )
			local gToList   = collectGrads( toGui )
			local driver = { t = 0 }
			function driver:OnChanged()
				local p = self.t
				local seqFrom = NumberSequence.crossfade( 1 - p, softness, true )
				local seqTo   = NumberSequence.crossfade( p,     softness, false )
				for _, item in ipairs( gFromList ) do item.grad.Transparency = seqFrom end
				for _, item in ipairs( gToList )   do item.grad.Transparency = seqTo   end
			end
			driver:OnChanged()
			local tw = ts:Create( driver, _G.TweenInfo.new( duration, style, Enum.EasingDirection.InOut ), { t = 1 } )
			tw.Completed:Once( function( state )
				if state == Enum.PlaybackState.Completed then
					if fromGui then fromGui.Visible = false end
					for _, item in ipairs( gFromList ) do
						if item.created then item.grad:Destroy() else item.grad.Transparency = NumberSequence.new( 0 ) end
					end
					for _, item in ipairs( gToList ) do
						if item.created then item.grad:Destroy() else item.grad.Transparency = NumberSequence.new( 0 ) end
					end
				end
				if type( callback ) == "function" then callback( state ) end
			end )
			tw:Play()
			return tw
		end

		-- Uniform alpha crossfade
		local function propFor( obj )
			if not obj then return "BackgroundTransparency" end
			if obj.ClassName == "CanvasGroup" then return "GroupTransparency"
			elseif obj:IsA( "ImageLabel" ) or obj:IsA( "ImageButton" ) then return "ImageTransparency"
			elseif obj:IsA( "TextLabel" ) and obj.BackgroundTransparency >= 0.999 then return "TextTransparency"
			else return "BackgroundTransparency" end
		end
		if ts then
			local info = _G.TweenInfo.new( duration, style, Enum.EasingDirection.InOut )
			local twFrom, twTo
			if fromGui then
				local pf = propFor( fromGui )
				twFrom = ts:Create( fromGui, info, { [ pf ] = 1 } )
				twFrom:Play()
			end
			if toGui then
				local pt = propFor( toGui )
				toGui[ pt ] = 1
				twTo = ts:Create( toGui, info, { [ pt ] = 0 } )
				twTo.Completed:Once( function( state )
					if state == Enum.PlaybackState.Completed and fromGui then
						fromGui.Visible = false
					end
					if type( callback ) == "function" then callback( state ) end
				end )
				twTo:Play()
			end
			return twTo or twFrom
		end
		return nil
	end

	RbxUI.Instance               = Instance
	RbxUI.UDim                   = UDim
	RbxUI.UDim2                  = UDim2
	RbxUI.Vector2                = Vector2
	RbxUI.Rect                   = Rect
	RbxUI.NumberRange            = NumberRange
	RbxUI.Color3                 = Color3
	RbxUI.ColorRange             = ColorSequence
	RbxUI.ColorSequence          = ColorSequence
	RbxUI.ColorSequenceKeypoint  = ColorSequenceKeypoint
	RbxUI.NumberSequence         = NumberSequence
	RbxUI.NumberSequenceKeypoint = NumberSequenceKeypoint
	RbxUI.Enum                   = Enum
	RbxUI.Signal                 = Signal

	_G.Instance               = Instance
	_G.UDim                   = UDim
	_G.UDim2                  = UDim2
	_G.Vector2                = Vector2
	_G.Rect                   = Rect
	_G.NumberRange            = NumberRange
	_G.Color3                 = Color3
	_G.ColorRange             = ColorSequence
	_G.ColorSequence          = ColorSequence
	_G.ColorSequenceKeypoint  = ColorSequenceKeypoint
	_G.NumberSequence         = NumberSequence
	_G.NumberSequenceKeypoint = NumberSequenceKeypoint
	_G.Enum                   = Enum
end
-- END RBXUI

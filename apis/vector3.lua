
local function add( self, o )
    return vector.new(
        self.x + o.x,
        self.y + o.y,
        self.z + o.z
    )
end

local function sub( self, o )
    return vector.new(
        self.x - o.x,
        self.y - o.y,
        self.z - o.z
    )
end

local function mul( self, m )
    return vector.new(
        self.x * m,
        self.y * m,
        self.z * m
    )
end

local function div( self, m )
    return vector.new(
        self.x / m,
        self.y / m,
        self.z / m
    )
end

local function unm( self )
    return vector.new(
        -self.x,
        -self.y,
        -self.z
    )
end

local function dot( self, o )
    return self.x*o.x + self.y*o.y + self.z*o.z
end

local function cross( self, o )
    return vector.new(
        self.y*o.z - self.z*o.y,
        self.z*o.x - self.x*o.z,
        self.x*o.y - self.y*o.x
    )
end

local function length( self )
    return math.sqrt( self.x*self.x + self.y*self.y + self.z*self.z )
end

local function normalize( self )
    return self:mul( 1 / self:length() )
end

local function round( self, nTolerance )
    nTolerance = nTolerance or 1.0
    return vector.new(
        math.floor( (self.x + (nTolerance * 0.5)) / nTolerance ) * nTolerance,
        math.floor( (self.y + (nTolerance * 0.5)) / nTolerance ) * nTolerance,
        math.floor( (self.z + (nTolerance * 0.5)) / nTolerance ) * nTolerance
    )
end

local function tostring( self )
    return self.x..","..self.y..","..self.z
end

local vmetatable = {
	__add = add,
	__sub = sub,
	__mul = mul,
	__div = div,
	__unm = unm,
	__tostring = tostring,
}

function new( x, y, z )
	local v = {
		x = tonumber(x) or 0,
		y = tonumber(y) or 0,
		z = tonumber(z) or 0
	}
	setmetatable( v, vmetatable )
	return v
end

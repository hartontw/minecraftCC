
local Vector2 = {}

function Vector2.new(x,y)
  local base = Struct.new()
  local v = class.extend("Vector2", base)
  
  v.public.x = 0
  v.public.y = 0
  
  function v.public.protected_set:Set(x, y)
    if hasFields(x, "x", "y") then
      y, x = x.y, x.x
    end
    self.x = initNumber(x)
    self.y = initNumber(y)
  end
  
  v:Set(x, y)
  
  function v.public.protected_set:ToString()
    --return "x: "..self.x.."; y: "..self.y
    for k, v in pairs(self.base) do
      print(k)
    end
    return ""
  end
  
  function v.public.protected_set:sqrMagnitude()
    return Vector2.SqrMagnitude(self)
  end
  
  function v.public.protected_set:magnitude()
    return Vector2.Magnitude(self)
  end
  
  function v.public.protected_set:normalized()
    return self / self:magnitude()
  end
  
  function v.public.protected_set:rotated(deg)
    local rad = math.rad(deg)
    local cos = math.cos(rad);
    local sin = math.sin(rad);
    return Vector2.new(cos*self.x - sin*self.y, sin*self.x + cos*self.y);
  end
  
  function v.public.protected_set:atan2()
    return math.atan2(self.y, self.x)
  end
  
  function v.public.protected_set:dot(o)
    return self.x*o.x + self.y*o.y
  end
  
  function v.protected:__add(o)
    if hasFields(o, "x", "y") then
      return Vector2.new(self.x+o.x, self.y+o.y)
    end
    return self.base.add(self, o)
  end
  
  function v.protected:__sub(o)
    if hasFields(o, "x", "y") then
      return Vector2.new(self.x-o.x, self.y-o.y)
    end
    return self.base.sub(self, o)
  end
  
  function v.protected:__mul(o)
    if isNumber(o) then
      return Vector2.new(self.x*o, self.y*o)
    end
    return self.base.mul(self, o)
  end
  
  function v.protected:__div(o)
    if isNumber(o) then
      return Vector2.new(self.x/o, self.y/o)
    end
    return self.base.div(self, o)
  end
  
  function v.protected:__unm()
    return Vector2.new(-self.x, -self.y)
  end
  
  --[[
  function Vector2:ToVector3()
    return Vector3.new_Vector3(self.x, self.y, 0)
  end
  --]]
  
  return class.init(v)
end

--STATIC
function Vector2.Dot(a, b)
  return a.x*b.x + a.y*b.y
end

function Vector2.Normalize(a)
  if not a.normalized then
    a = Vector2.new(a.x, a.y)
  end
  return a:normalized()
end

function Vector2.SqrMagnitude(a)
  return a.x*a.x + a.y*a.y
end

function Vector2.Magnitude(a)
  return math.sqrt(Vector2.SqrMagnitude(a))
end

function Vector2.Distance(a, b)
  local dx = b.x - a.x
  local dy = b.y - a.y
  local v = {x=dx, y=dy}
  return Vector2.Magnitude(v)
end

function Vector2.Max(a, b)
  return math.max(Vector2.SqrMagnitude(a), Vector2.SqrMagnitude(b))
end

function Vector2.Min(a, b)
  return math.min(Vector2.SqrMagnitude(a), Vector2.SqrMagnitude(b))
end

function Vector2.Lerp(a, b, t)
  if t < 0 then
    if not isType(a, "Vector2") then
      a = Vector2.new(a.x, a.y)
    end
    return a
  end
  
  if t > 1 then
    if not isType(b, "Vector2") then
      b = Vector2.new(b.x, b.y)
    end
    return b
  end
  
  local x = a.x + (b.x-a.x)*t
  local y = a.y + (b.y-a.y)*t   
  
  return Vector2.new(x, y)
end

function Vector2.Angle(a, b)
  local c = Vector2.Dot(a, b)
  local u = c.x+c.y+c.z
  local d = Vector2.Magnitude(a) * Vector2.Magnitude(b)
  return math.deg(u/d)
end

function Vector2.SignedAngle(a, b)
  local rad = math.atan2(b.y,b.x) - math.atan2(a.y, a.x)
  return math.deg(rad)
end

function Vector2.Project(a, b)
  return Vector2.Normalize(b) * Vector2.Dot(a,b)
end

function Vector2.Reflect(a, n)
  if not isType(a, "Vector2") then
    a = Vector2.new(a.x, a.y)
  end
  return a - 2 * a:dot(Vector2.Normalize(n))
end
--[[
Vector2.zero = Vector2.new(0, 0)
Vector2.one = Vector2.new(1, 1)
Vector2.right = Vector2.new(1, 0)
Vector2.left = Vector2.new(-1, 0)
Vector2.up = Vector2.new(0, 1)
Vector2.down = Vector2.new(0, -1)
--]]
return Vector2
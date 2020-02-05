local _mt, _ = {}, {}
setmetatable(_, _mt)

local function skip1(f)
  return function(x, _, ...)
    return f(x, ...)
  end
end

function _.expect(arg, t, v)
  assert(type(arg) == 'number')
  if t == 'value' then
    if v == nil then
      local n = debug and debug.getinfo(2, 'n').name or "<no name info>"
      return error(('%s: bad argument #%d (got nil)'):format(n, arg))
    end
  elseif type(v) ~= t then
    local n = debug and debug.getinfo(2, 'n').name or "<no name info>"
    return error(('%s: bad argument #%d (expected %s, got %s)'):format(n, arg, t, type(v)))
  end
end

function _.partial(f, ...)
  _.expect(1, 'function', f)
  local args = table.pack(...)
  return function(...)
    local args2, actual = table.pack(...), { }
    for i = 1, args.n do
      actual[i] = args[i]
    end
    for i = 1, args2.n do
      actual[args.n + i] = args2[i]
    end
    return f(table.unpack(actual, 1, args.n + args2.n))
  end
end

function _.map_with_key(tab, f)
  _.expect(1, 'table', tab)
  _.expect(2, 'function', f)
  local out = {}
  for k, v in pairs(tab) do
    local k, v = f(k, v)
    out[k] = v
  end
  return out
end

function _.reduce_with_index(tab, f, z)
  _.expect(1, 'table', tab)
  _.expect(2, 'function', f)
  _.expect(3, 'value', z)
  local out = z
  for i = 1, #tab do
    out = f(out, i, tab[i])
  end
  return out
end

function _.reduce(tab, f, z)
  return _.reduce_with_index(tab, skip1(f), z)
end

function _.reduce_right(t, f, z)
  _.expect(1, 'table', t)
  _.expect(2, 'function', f)

  local len = #t

  local function go(k, i)
    if i > len then
      return k(z)
    else
      return go(function(r) return k(f(t[i], r)) end, i + 1)
    end
  end

  return go(function(x) return x end, 1)
end

function _.apply(f, t)
  _.expect(1, 'function', f)
  _.expect(2, 'table', t)
  return f(table.unpack(t, 1, #t))
end

function _.clone(value)
  if type(value) == 'table' then
    local copy = {}
    for k, v in pairs(value) do
      copy[k] = v
    end
    return copy
  end
  return value
end

function _.map(t1, f, ...)
  _.expect(1, 'table', t1)
  _.expect(2, 'function', f)
  return _.flat_map(t1, function(...) return { (f(...)) } end, ...)
end

function _.zip(...)
  local args = table.pack(...)
  for i = 1, args.n do
    _.expect(1, 'table', args[i])
  end
  return _.map(args[1], function(...) return {...} end, table.unpack(args, 2, args.n))
end

function _.push(t, ...)
  _.expect(1, 'table', t)
  local args = table.pack(...)
  for i = 1, args.n do
    table.insert(t, args[i])
  end
  return t
end

function _.intersperse(t, x)
  _.expect(1, 'table', t)
  local out = {}
  for i = 1, #t, 1 do
    _.push(out, t[i], x)
  end
  return out
end

function _.flatten(t)
  _.expect(1, 'table', t)
  local out, li = {}, 1
  for i = 1, #t do
    if type(t[i]) == 'table' then
      for j = 1, #t[i] do
        out[li] = t[i][j]
        li = li + 1
      end
    else
      out[li] = t[i]
      li = li + 1
    end
  end
  return out
end

function _.flat_map(t1, f, ...)
  _.expect(1, 'table', t1)
  _.expect(2, 'function', f)
  local args, n = table.pack(t1, ...), 0
  for i = 1, args.n do
    _.expect(1 + i, 'table', args[i])
    n = math.max(n, #args[i])
  end
  local out, li = {}, 0
  for i = 1, n do
    local these = {}
    for j = 1, args.n do
      these[j] = args[j][i]
    end
    local r = _.apply(f, these)
    if type(r) == 'table' then
      for i = 1, #r do
        out[li + i] = r[i]
      end
      li = li + #r
    else
      out[li + 1] = r
      li = li + 1
    end
  end
  return out
end

function _.filter(t, p)
  _.expect(1, 'table', t)
  _.expect(2, 'function', p)
  local out, li = {}, 1
  for i = 1, #t do
    if p(t[i]) then
      out[li] = t[i]
      li = li + 1
    end
  end
  return out
end

function _.id(v)
  _.expect(1, 'value', v)
  return v
end

function _.sort_by(t, f)
  _.expect(1, 'table', t)
  _.expect(2, 'function', f)
  local nt = _.map(t, _.id)

  table.sort(nt, function(a, b) return f(a) < f(b) end)
  return nt
end

function _.sort(t)
  _.expect(1, 'table', t)

  return _.sort_by(t, _.id)
end

function _.sample_size(t, n)
  _.expect(1, 'table', t)
  _.expect(2, 'number', n)

  if #t <= n then
    return t
  end

  local src = _.keys(t)
  local out = {}
  for i = 1, n do
    local k = _.sample(src)
    out[i] = t[k]

    src[k] = src[#src]
    src[#src] = nil
  end
  return out
end

function _.sample(t)
  _.expect(1, 'table', t)
  return t[math.random(1, #t)]
end

function _.head(t)
  _.expect(1, 'table', t)
  return t[1]
end

function _.tail(t)
  _.expect(1, 'table', t)
  local out = {}
  for i = 2, #t do
    out[i - 1] = t[i]
  end
  return out
end

function _.every(t, p)
  _.expect(1, 'table', t)
  _.expect(1, 'function', p)
  for i = 1, #t do
    if not p(t[i]) then
      return false
    end
  end
  return true
end

function _.some(t, p)
  _.expect(1, 'table', t)
  _.expect(1, 'function', p)
  for i = 1, #t do
    if p(t[i]) then
      return true
    end
  end
  return false
end

function _.initial(t)
  _.expect(1, 'table', t)
  local out = {}
  for i = 1, #t - 1 do
    out[i] = t[i]
  end
  return out
end

function _.last(t)
  _.expect(1, 'table', t)
  return t[#t]
end

function _.nth(t, i)
  _.expect(1, 'table', t)
  _.expect(2, 'value', i)
  return t[i]
end

function _.keys(t)
  _.expect(1, 'table', t)
  local out, i = {}, 1
  for k, v in pairs(t) do
    out[i] = k
    i = i + 1
  end
  return out
end

function _.values(t)
  _.expect(1, 'table', t)
  local out, i = {}, 1
  for k, v in pairs(t) do
    out[i] = v
    i = i + 1
  end
  return out
end

function _.shuffle(t)
  _.expect(1, 'table', t)
  local out = _.clone(t)
  for i = 1, #out - 1 do
    local j = math.random(i, #out)
    out[i], out[j] = out[j], out[i]
  end
  return out
end

function _mt.__call(_, x)
  local function wrap(f)
    return function(...)
      return _(f(...))
    end
  end
  if type(x) == 'table' then
    return setmetatable(x,
      { __index = function(t, k)
        return wrap(_[k])
      end })
  else
    return x
  end
end

_.ops = {
  plus      = function(a, b) return a + b end,
  minus     = function(a, b) return a - b end,
  times     = function(a, b) return a * b end,
  over      = function(a, b) return a / b end,
  power     = function(a, b) return a ^ b end,
  modulo    = function(a, b) return a % b end,
  concat    = function(a, b) return a .. b end,
  remainder = function(a, b) return a % b end,
  rem       = function(a, b) return a % b end,
  mod       = function(a, b) return a % b end,
  conj      = function(a, b) return a and b end,
  disj      = function(a, b) return a or b end,
  equals    = function(a, b) return a == b end,
  ['>']     = function(a, b) return a > b end,
  ['>=']    = function(a, b) return a >= b end,
  ['<']     = function(a, b) return a < b end,
  ['<=']    = function(a, b) return a <= b end,
  divisible_by = function(a, b)
    return b % a == 0
  end,
}

return _

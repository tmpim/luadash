local _mt, _ = {}, {}
setmetatable(_, _mt)

local function skip1(f)
  return function(x, _, ...)
    return f(x, ...)
  end
end

function _.expect(n, arg, t, v)
  if t == 'value' and v == nil then
    return error(('%s: bad argument #%d (got nil)'):format(n, arg))
  elseif type(v) ~= t then
    return error(('%s: bad argument #%d (expected %s, got %s)'):format(n, arg, t, type(v)))
  end
end

function _.partial(f, ...)
  _.expect('partial', 1, 'function', f)
  local args = { ... }
  return function(...)
    local args2, actual, n = { ... }, { }, #args
    for i = 1, n do
      actual[i] = args[i]
    end
    for i = 1, #args2 do
      actual[n + i] = args2[i]
    end
    return f(unpack(actual, 1, n + #args2))
  end
end

function _.map_with_key(tab, f)
  _.expect('map_with_key', 1, 'table', tab)
  _.expect('map_with_key', 2, 'function', f)
  local out = {}
  for k, v in pairs(tab) do
    local k, v = f(k, v)
    out[k] = v
  end
  return out
end

function _.reduce_with_index(tab, f, z)
  _.expect('reduce_with_index', 1, 'table', tab)
  _.expect('reduce_with_index', 2, 'function', f)
  _.expect('reduce_with_index', 2, 'value', z)
  local out = z
  for i = 1, #tab do
    out = f(out, i, tab[i])
  end
  return out
end

function _.reduce(tab, f, z)
  return _.reduce_with_index(tab, skip1(f), z)
end

function _.apply(f, t)
  _.expect('apply', 1, 'function', f)
  _.expect('apply', 2, 'table', t)
  return f(unpack(t, 1, #t))
end

function _.map(t1, f, ...)
  _.expect('map', 1, 'table', t1)
  _.expect('map', 2, 'function', f)
  local args, n = {t1, ...}, 0
  for i = 1, #args do
    _.expect('map', 1 + i, 'table', args[i])
    n = math.max(n, #args[i])
  end
  local out = {}
  for i = 1, n do
    local these = {}
    for j = 1, #args do
      these[j] = args[j][i]
    end
    out[i] = _.apply(f, these)
  end
  return out
end

function _.zip(...)
  local args = {...}
  for i = 1, #args do
    _.expect('zip', 1, 'table', args[i])
  end
  return _.map(function(...) return {...} end, ...)
end

function _.push(t, ...)
  _.expect('push', 1, 'table', t)
  local args = {...}
  for i = 1, #args do
    table.insert(t, args[i])
  end
  return t
end

function _.intersperse(t, x)
  _.expect('intersperse', 1, 'table', t)
  local out = {}
  for i = 1, #t, 1 do
    _.push(out, t[i], x)
  end
  return out
end

function _.flatten(t)
  _.expect('flatten', 1, 'table', t)
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
  _.expect('flat_map', 1, 'table', t1)
  _.expect('flat_map', 2, 'function', f)
  local args, n = {t1, ...}, 0
  for i = 1, #args do
    _.expect('map', 1 + i, 'table', args[i])
    n = math.max(n, #args[i])
  end
  local out, li = {}, 0
  for i = 1, n do
    local these = {}
    for j = 1, #args do
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
  _.expect('filter', 1, 'table', t)
  _.expect('filter', 2, 'function', p)
  local out, li = {}, 1
  for i = 1, #t do
    if p(t[i]) then
      out[li] = t[i]
      li = li + 1
    end
  end
  return out
end

function _.sample_size(t, n)
  _.expect('sample', 1, 'table', t)
  _.expect('sample', 2, 'number', n)
  local out = {}
  for i = 1, n do
    out[i] = _.sample(t)
  end
  return out
end

function _.sample(t)
  _.expect('sample', 1, 'table', t)
  return t[math.random(1, #t)]
end

function _.head(t)
  _.expect('head', 1, 'table', t)
  return x[1]
end

function _.tail(t)
  _.expect('tail', 1, 'table', t)
  local out = {}
  for i = 2, #t do
    out[i - 1] = t[i]
  end
  return out
end

function _.every(t, p)
  _.expect('every', 1, 'table', t)
  _.expect('every', 1, 'function', p)
  local out = true
  for i = 1, #t do
    out = out and p(t[i])
  end
  return out
end

function _.some(t, p)
  _.expect('some', 1, 'table', t)
  _.expect('some', 1, 'function', p)
  local out = false
  for i = 1, #t do
    out = out or p(t[i])
  end
  return out
end

function _.initial(t)
  _.expect('initial', 1, 'table', t)
  local out = {}
  for i = 1, #t - 1 do
    out[i] = t[i]
  end
  return out
end

function _.last(t)
  _.expect('last', 1, 'table', t)
  return t[#t]
end

function _.nth(t, i)
  _.expect('nth', 1, 'table', t)
  _.expect('nth', 2, 'value', i)
  return t[i]
end

function _.keys(t)
  _.expect('keys', 1, 'table', t)
  local out, i = {}, 1
  for k, v in pairs(t) do
    out[i] = k
    i = i + 1
  end
  return out
end

function _.values(t)
  _.expect('values', 1, 'table', t)
  local out, i = {}, 1
  for k, v in pairs(t) do
    out[i] = v
    i = i + 1
  end
  return out
end

function _mt.__call(_, x)
  local function wrap(f)
    return function(...)
      return _(f(...))
    end
  end
  return setmetatable( x, { __index = function(t, k) return wrap(_[k]) end })
end

_.ops = {
  plus = function(a, b) return a + b end,
  minus = function(a, b) return a - b end,
  times = function(a, b) return a * b end,
  over = function(a, b) return a / b end,
  power = function(a, b) return a ^ b end,
  modulo = function(a, b) return a % b end,
  remainder = function(a, b) return a % b end,
  rem = function(a, b) return a % b end,
  mod = function(a, b) return a % b end,
  conj = function(a, b) return a and b end,
  disj = function(a, b) return a or b end,
  equals = function(a, b) return a == b end,
  divisible_by = function(a, b)
    return b % a == 0
  end
}

return _

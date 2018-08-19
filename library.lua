local _mt, _ = {}, {}
setmetatable(_, _mt)

local function skip1(f)
  return function(x, _, ...)
    return f(x, ...)
  end
end

local function iteratee_type(p)
  local t = type(p)
  if t == 'function' then
    return t
  elseif t == 'string' then
    return 'property'
  elseif t == 'table' then
    local is_map = false
    for k, _ in pairs(p) do
      if type(k) ~= 'number' then
        is_map = true
        break
      end
    end

    if not is_map then
      if #p ~= 2 then
        is_map = true
      end
    end

    if not is_map then
      local path_type = type(p[1])
      if path_type ~= 'table' and path_type ~= 'string' then
        is_map = true
      end
    end

    if is_map then
      return 'matches'
    else
      return 'matches_property'
    end
  end

  return 'NaI'
end

local function index_iteratee(p)
  local t = iteratee_type(p)

  if t == 'function' then
    return p
  elseif t == 'property' then
    return _.property(p)
  elseif t == 'matches_property' then
    return _.matches_property(p[1], p[2])
  elseif t == 'matches' then
    return _.matches(p)
  end
end

function _.expect(n, arg, ts, v)
  if ts == 'value' then
    if v == nil then
      return error(('%s: bad argument #%d (got nil)'):format(n, arg))
    end
  else
    local valid = false
    for t in ts:gmatch("[^|]+") do
      if t == 'iteratee' or t == 'predicate' then
        local i = iteratee_type(v)
        if i ~= 'NaI' then
          valid = true
        end
      elseif type(v) == t then
        valid = true
      end
    end

    if not valid then
      return error(('%s: bad argument #%d (expected %s, got %s)'):format(n, arg, ts, type(v)))
    end
  end
end

function _.property(path)
  _.expect('property', 1, 'string|table', path)
  if type(path) == 'string' then
    path = {path}
  end

  return function(tab)
    return _.reduce(path, function(ds, p)
      if type(ds) == 'table' then
        return ds[p]
      else
        return nil
      end
    end, tab)
  end
end

function _.matches(src)
  _.expect('matches', 1, 'value', src)
  local stack = {src, n = 1}

  local f

  local function cmp(new_src, new_tab)
    if type(new_tab) ~= 'table' then return false end

    stack.n = stack.n + 1
    stack[stack.n] = new_src
    local v = f(new_tab)
    stack.n = stack.n - 1

    return v
  end

  function f(val)
    local val_type = type(val)
    if type(stack[stack.n]) ~= 'table' then
      return val == stack[stack.n]
    end

    for k, v in pairs(stack[stack.n]) do
      if type(v) == 'table' then
        if not cmp(v, val[k]) then
          return false
        end
      else
        if val_type ~= 'table' then
          return false
        end

        if val[k] ~= v then
          return false
        end
      end
    end

    return true
  end

  return f
end

function _.matches_property(path, src_value)
  _.expect('matches_property', 1, 'string|table', path)
  _.expect('matches_property', 2, 'value', src_value)
  local p = _.property(path)
  local m = _.matches(src_value)

  return function(tab)
    return m(p(tab))
  end
end

function _.partial(f, ...)
  _.expect('partial', 1, 'function', f)
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
  _.expect('map_with_key', 1, 'table', tab)
  _.expect('map_with_key', 2, 'iteratee', f)
  f = index_iteratee(f)
  local out = {}
  for k, v in pairs(tab) do
    k, v = f(k, v)
    out[k] = v
  end
  return out
end

function _.reduce_with_index(tab, f, z)
  _.expect('reduce_with_index', 1, 'table', tab)
  _.expect('reduce_with_index', 2, 'iteratee', f)
  f = index_iteratee(f)
  _.expect('reduce_with_index', 3, 'value', z)
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
  return f(table.unpack(t, 1, #t))
end

function _.map(t1, f, ...)
  _.expect('map', 1, 'table', t1)
  _.expect('map', 2, 'iteratee', f)
  f = index_iteratee(f)
  return _.flat_map(t1, function(...) return { (f(...)) } end, ...)
end

function _.zip(...)
  local args = table.pack(...)
  for i = 1, args.n do
    _.expect('zip', 1, 'table', args[i])
  end
  return _.map(args[1], function(...) return {...} end, table.unpack(args, 2, args.n))
end

function _.push(t, ...)
  _.expect('push', 1, 'table', t)
  local args = table.pack(...)
  for i = 1, args.n do
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
  _.expect('flat_map', 2, 'iteratee', f)
  f = index_iteratee(f)
  local args, n = table.pack(t1, ...), 0
  for i = 1, args.n do
    _.expect('flat_map', 1 + i, 'table', args[i])
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
      for j = 1, #r do
        out[li + j] = r[j]
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
  _.expect('filter', 2, 'predicate', p)
  p = index_iteratee(p)
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
  _.expect('id', 1, 'value', v)
  return v
end

function _.sort_by(t, f)
  _.expect('sort_by', 1, 'table', t)
  _.expect('sort_by', 2, 'iteratee', f)
  f = index_iteratee(f)
  local nt = _.map(t, _.id)

  table.sort(nt, function(a, b) return f(a) < f(b) end)
  return nt
end

function _.sort(t)
  _.expect('sort', 1, 'table', t)

  return _.sort_by(t, _.id)
end

function _.sample_size(t, n)
  _.expect('sample_size', 1, 'table', t)
  _.expect('sample_size', 2, 'number', n)

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
  _.expect('sample', 1, 'table', t)
  return t[math.random(1, #t)]
end

function _.head(t)
  _.expect('head', 1, 'table', t)
  return t[1]
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
  _.expect('every', 1, 'predicate', p)
  p = index_iteratee(p)
  for i = 1, #t do
    if not p(t[i]) then
      return false
    end
  end
  return true
end

function _.some(t, p)
  _.expect('some', 1, 'table', t)
  _.expect('some', 1, 'predicate', p)
  p = index_iteratee(p)
  for i = 1, #t do
    if p(t[i]) then
      return true
    end
  end
  return false
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
  for k, _v in pairs(t) do
    out[i] = k
    i = i + 1
  end
  return out
end

function _.values(t)
  _.expect('values', 1, 'table', t)
  local out, i = {}, 1
  for _k, v in pairs(t) do
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
  if type(x) == 'table' then
    return setmetatable(x,
      { __index = function(_t, k)
        return wrap(_[k])
      end })
  else
    return x
  end
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
  end,
  ['>'] = function(a, b) return a > b end,
  ['>='] = function(a, b) return a >= b end,
  ['<'] = function(a, b) return a < b end,
  ['<='] = function(a, b) return a <= b end,
}

function string.starts_with(self, s)
  _.expect('starts_with', 1, 'string', s)
  return self:find('^' .. s) ~= nil
end

return _

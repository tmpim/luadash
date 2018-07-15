local doc_path = '/doc/'
local topic = ((...) or 'index')

-- Levenshtein Distance
local function distance(str1, str2)
  local v0 = {}
  local v1 = {}

  for i = 0, #str2 do
    v0[i] = i
  end

  for i = 0, #str1 - 1 do
    v1[0] = i + 1

    for j = 0, #str2 - 1 do
      local delCost = v0[j + 1] + 1
      local insertCost = v1[j] + 1
      local subCost

      if str1:sub(i + 1, i + 1) == str2:sub(j + 1, j + 1) then
        subCost = v0[j]
      else
        subCost = v0[j] + 1
      end

      v1[j + 1] = math.min(delCost, insertCost, subCost)
    end

    local t = v0
    v0 = v1
    v1 = t
  end

  return v0[#str2]
end

if fs.exists(doc_path .. topic .. ".txt") then
  local f = fs.open(doc_path .. topic .. ".txt", 'r')
  local s = f.readAll()
  local lns = select(2, s:gsub('\n', '\n'))
  if lns > 15 then
    term.clear()
    term.setCursorPos(1,1)
    parallel.waitForAny(
      function()
        textutils.pagedPrint(s)
      end,
      function()
        local _, c = os.pullEvent('char')
        if c == 'q' then
          term.clear()
          term.setCursorPos(1, 1)
          error('Thank you for using LuaDash!', 0)
        end
      end)
  else
    print(s)
  end
  f.close()
else
  printError('No documentation for ' .. topic)
  local list = fs.list(doc_path)

  local candidates = {}
  for i = 1, #list do
    local item = list[i]:match('^(.+)%.txt$') or list[i]
    local mindist = math.huge
    for j = 1, math.max(#item - #topic, 1) do
      local dist = distance(topic, item:sub(j, j + #topic)) + j - 1
      if dist < mindist then
        mindist = dist
      end
    end

    if mindist < 4 then
      candidates[#candidates + 1] = {mindist, item}
    end
  end

  table.sort(candidates, function(a, b) return a[1] < b[1] end)

  if #candidates > 0 then
    print 'Did you mean:'
    for i = 1, #candidates do
      print(' \183 ' .. candidates[i][2])
    end
  end
end

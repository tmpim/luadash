local doc_path = '/doc/'
local topic = ((...) or 'index') .. '.txt'

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

if fs.exists(doc_path .. topic) then
  local f = fs.open(doc_path .. topic, 'r')
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
  print 'Did you mean one of:'

  local candidates = {}
  for i = 1, #list do

    local dist = distance(list[i], topic)
    if dist < (#topic - 4) then
      candidates[#candidates + 1] = {dist, list[i]}
    end
  end

  table.sort(candidates, function(a, b) return a[1] < a[1] end)

  for i = 1, #candidates do
    print(' \183 ' .. candidates[i][2])
  end
end

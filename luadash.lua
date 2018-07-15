local doc_path = '/doc/' -- change this to /rom/something/
local topic = ((...) or 'index') .. '.txt'

if fs.exists(doc_path .. topic) then
  local f = fs.open(doc_path .. topic, 'r')
  textutils.pagedPrint(f.readAll(), 16)
  f.close()
else
  printError('no help for ' .. topic)
end

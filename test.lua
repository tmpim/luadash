--- A simplified test runner for luadash

local _ = require "library"

local test_stack, tests_locked = { n = 0 }, false
local test_results, test_pass, test_count = { n = 0 }, 0, 0

local try_mt = { __tostring = function(self) return self.message end }
local function try(fn)
  if not debug or not debug.traceback then
    return pcall(fn)
  end

  local ok, err = xpcall(fn, debug.traceback)
  if ok or (type(err) == "table" and err.message) then
    return ok, err
  else
    if type(err) == "string" then
      -- Find the common substring between the two traces. Yes, this is horrible.
      local trace = debug.traceback()
      for i = 1, #trace do if trace:sub(-i) ~= err:sub(-i) then
        err = err:sub(1, -i)
        break
      end end
    else
      err = tostring(err)
    end

    return ok, setmetatable({ message = err }, try_mt)
  end
end

--- Describe something which will be tested, such as a function or situation
--
-- @tparam string name   The name of the object to test
-- @tparam function body A function which describes the tests for this object.
local function describe(name, body)
  _.expect('describe', 1, 'string', name)
  _.expect('describe', 2, 'function', body)
  if tests_locked then error("Cannot describe something while running tests", 2) end

  -- Push our name onto the stack, eval and pop it
  local n = test_stack.n + 1
  test_stack[n], test_stack.n = name, n

  local ok, err = try(body)

  test_stack.n = n - 1

  -- We rethrow the error within describe blocks
  if not ok then error(err, 0) end
end

--- Declare a single test within a context
--
-- @tparam string name   What you are testing
-- @tparam function body A function which runs the test, failing if it does
--                       the assertions are not met.
local function it(name, body)
  _.expect('it', 1, 'string', name)
  _.expect('it', 2, 'function', body)
  if tests_locked then error("Cannot create test while running tests", 2) end

  -- Push name onto the stack
  local n = test_stack.n + 1
  test_stack[n], test_stack.n, tests_locked = name, n, true

  math.randomseed(0)
  local ok, err = try(body)

  -- Push the test name onto the message
  test_count = test_count + 1
  test_results[test_count] = {
    ok = ok, message = not ok and err.message,
    name = table.concat(test_stack, " ", 1, test_stack.n),
  }

  -- Pop the
  test_stack.n, tests_locked = n - 1, false

  if ok then
    test_pass = test_pass + 1
    term.setTextColour(colours.green) write("\7")
  else
    term.setTextColour(colours.red) write("\4")
  end

  term.setTextColour(colours.white)
end

local function report()
  print()

  for i = 1, test_count do
    local test = test_results[i]
    if not test.ok then
      term.setTextColour(colours.red) print(test.name)
      term.setTextColour(colours.white)   print("  " .. test.message:gsub("\n", "\n  "))
    end
  end

  print(("Ran %s tests, of which %s passed (%.2f%%)")
    :format(test_count, test_pass, (test_pass / test_count) * 100))
end

--- Fail a test with the given message
--
-- @tparam message The message to fail with
local function fail(message)
  _.expect('fail', 1, 'string', message)
  error({ message = message }, 0)
end

describe("luadash", function()
  it("can be required", function()
    require("library")
  end)

  describe("has documentation for", function()
    local function normalise(string)
      return string:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""):gsub(", }", " }")
    end
    local function it_example(env, id, example, result)
      it("#" .. id, function()
        local fn, err = load("return " .. example, "=#" .. id, nil, env)
        if not fn then fn, err = load(example, "=#" .. id, nil, env) end

        if not fn then
          fail(("Could not load input (%s)\n%s"):format(err, example))
        end

        local expected_res = normalise(result)

        local res = fn()
        if res == nil and expected_res == "" then return end

        local actual_res = normalise(textutils.serialize(res))
        if actual_res ~= expected_res then
          fail(("Expected: %s\nActual:   %s"):format(expected_res, actual_res))
        end
      end)
    end

    local dir = fs.getDir(shell.getRunningProgram())
    for _, file in ipairs(fs.find(dir .. "/doc/*.txt")) do
      local name = file:match("/([^./]+)%.txt$")
      describe(name, function()
        describe("with an example", function()
          local env = setmetatable({ _ = require "library" }, { __index = _ENV })
          local count = 0

          local handle = fs.open(file, "r")
          local line = handle.readLine()
          while line do
            -- Build examples from lines starting with ">"
            local indent, body = line:match("^(%s*)>(.*)$")
            if body then
              count = count + 1
              local code, result = { body }, {}

              -- Consume the example code
              line = handle.readLine()
              while line do
                if line:sub(1, #indent + 1) == indent .. " " then
                  code[#code + 1] = line:sub(#indent + 1)
                  line = handle.readLine()
                else
                  break
                end
              end

              -- Consume the example output
              while line do
                if line:sub(1, #indent) == indent and line:sub(#indent + 1, #indent + 1) ~= ">" then
                  result[#result + 1] = line:sub(#indent)
                  line = handle.readLine()
                else
                  break
                end
              end

              it_example(env, count, table.concat(code, "\n"), table.concat(result, "\n"))
            else
              -- Skip to the next line otherwise
              line = handle.readLine()
            end
          end

          handle.close()
        end)
      end)
    end
  end)
end)

report()

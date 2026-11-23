-- Runs every tests/*_test.lua with plain Lua 5.1, no game needed. Usage: lua tests/run.lua (from the repo root)
local T = { passes = 0, fails = 0, root = arg[0]:match("^(.*)/tests/run.lua$") or "." }

function T.test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        T.passes = T.passes + 1
    else
        T.fails = T.fails + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

function T.eq(actual, expected, msg)
    if actual ~= expected then
        error((msg or "eq") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

package.path = T.root .. "/tests/?.lua;" .. package.path
local list = io.popen("ls " .. T.root .. "/tests/*_test.lua 2>/dev/null")
for path in list:lines() do
    local chunk, err = loadfile(path)
    if not chunk then
        T.fails = T.fails + 1
        print("FAIL load " .. path .. ": " .. tostring(err))
    else
        local ok, perr = pcall(chunk, T)
        if not ok then
            T.fails = T.fails + 1
            print("FAIL " .. path .. ": " .. tostring(perr))
        end
    end
end
list:close()

print(("%d passed, %d failed"):format(T.passes, T.fails))
os.exit(T.fails == 0 and 0 or 1)

local test = true
local test2 = false --[[ Testing
spooky
multiline
comments
]]--

local mline_string = [=[Spooky scary
multilines, giving such a scream]=]

if test == test2 then
	print("true")
-- Mixed case of regular lua comparators, and Callisto Script comparators
elseif test ~= test2 and test2 ~= test then
	print("false")
	if a ~= b then
		print("false")
	elseif c == b then
		print("true")
	else
		print("failed")
	end
end

if not test then
	print("false")
end

local function test_function(arg)
	return arg
end

print(test_function("function call"))

local while_test = 1
while while_test < 2 do
	print(while_test)
	local testtable = {}
	testtable[long_boi_test_her = long_boi_test_her + 1] = true
	while_tes = while_tes + 1
end

for i=1, 2 do
	print(i)
end

local loop_test = 3
repeat
	print(loop_test--;)
	local testtab = {loop_test--;}
	loop_test--;
	local bonus = loop_test
until loop_test == 2

print("this is a string++!")

-- Comment lines are automatically ignored

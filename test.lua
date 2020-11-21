local test = true
local test2 = false -- Test comment

if test == test2 then
	print("true")
eif test ~= test2 and test2 ~= test then
	print("false")
	if a ~= b then
		print("false")
	eif c == b then
		print("true")
	else
		print("failed")
	end
end

if not test then
	print("false")
end

local func test_function(arg)
	ret arg
end

print(test_function("function call"))

local while_test = 1 do
while while_test < 2 do
	print(while_test) do
	while_test++ do
end

for i=1, 2 do
	print(i)
end

local repeat_test = 3
repeat
	print(repeat_test)
	repeat_test--
	local bonus = repeat_test
until repeat_test == 2

-- Comment lines are automatically ignored

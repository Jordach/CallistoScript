-- Prototype transpiler that converts .jds scripts to .lua.

--[[
List of valid keywords:

and
break
else
eif (auto appends then at the end of the line, regex's to elseif)
end
false
for (appends do at the enc)
func (regex's to function)
if (auto appends then at the end of the line)
in
l (regex's to local) /
nil
not
or
repeat
ret (regex's to return)
until
while

List of valid tokens:

+
-
*
/
%
^
#
==
!= (regex's to ~=) /
<=
>=
<
>
=
(
)
[
]
{
}
;
:
,
.
..
...

List of numeric variable specific options:

var++;
var--;

## Comments look like this. Multilines aren't going to be supported.
]]--

-- Flip to true to enable party mode
local enable_short_hand_incrementals = true

-- Multiline detection:
local multiline_detected = false

local file_contents = {}
local result = {}

local function print_file(filename)
	local file = ""
	for k,v in pairs(result) do
		file = file .. v .. "\n"
	end
	os.remove(filename..".lua")
	local output = io.open(filename..".lua", "w+")
	output:write(file)
	output:close()
end

local function keyword_regex(ln)
	local found_multiline_start = false
	-- Check for presence of multiline comments or strings:
	if not multiline_detected then
		if file_contents[ln]:find("[%[][%=-][%[]") then -- should match [[ [=[ [==[ ...
			multiline_detected = true
			found_multiline_start = true
			print("[Notice-Callisto]: Multiline string/comment starting at line "..ln..".")
		elseif file_contents[ln]:find("[%[][%[]") then
			multiline_detected = true
			found_multiline_start = true
			print("[Notice-Callisto]: Multiline string/comment starting at line "..ln..".")
		end
	end

	--Check for multiline comments or strings (in case they end early and the software locks)
	-- Don't process any keywords. IF the start of the multiline is on the same as the end, process as normal
	-- otherwise, prevent processing of keywords.
	if multiline_detected then
		if file_contents[ln]:find("[%]][%=-][%]]") then
			multiline_detected = false
			print("[Notice-Callisto]: Multiline string/comment ended at line "..ln..".")
			if file_contents[ln]:find("##") then
				file_contents[ln] = string.gsub(file_contents[ln], "##", "--", 1)
			end
			if not found_multiline_start then
				result[ln] = file_contents[ln]
				return
			end
		elseif file_contents[ln]:find("[%]][%]]") then
			multiline_detected = false
			print("[Notice-Callisto]: Multiline string/comment ended at line "..ln..".")
			if file_contents[ln]:find("##") then
				file_contents[ln] = string.gsub(file_contents[ln], "##", "--", 1)
			end
			if not found_multiline_start then
				result[ln] = file_contents[ln]
				return
			end
		else
			if file_contents[ln]:find("##") then
				file_contents[ln] = string.gsub(file_contents[ln], "##", "--", 1)
			end
			if not found_multiline_start then
				result[ln] = file_contents[ln]
				return
			end
		end
	end

	-- Abort processing on commented out lines
	if file_contents[ln]:sub(1,2):find("##") then
		result[ln] = string.gsub(file_contents[ln], "##", "--", 1)
		return
	end
	
	-- Non blocking per line operations:

	-- l to local conversion
	local char_a, char_b = file_contents[ln]:find("l ") 
	if char_a == 1 then
		file_contents[ln] = string.gsub(file_contents[ln], "l ", "local ", 1)
	else
		-- Lua converts tabs to spaces (4 spaces per tab).
		-- So no need to be totally concerned about this strange local search.
		if file_contents[ln]:find(" l ") then
			file_contents[ln] = string.gsub(file_contents[ln], "l ", "local ", 1)
		elseif file_contents[ln]:find("\tl ") then
			file_contents[ln] = string.gsub(file_contents[ln], "l ", "local ", 1)
		end
	end
	-- Handle things like !=, ++ and --, function, 
	if file_contents[ln]:find("!=") then
		file_contents[ln] = string.gsub(file_contents[ln], "!=", "~=")
	end
	-- Also handle inline code with comments at the end of a line
	if file_contents[ln]:find("##") then
		file_contents[ln] = string.gsub(file_contents[ln], "##", "--", 1)
	end

	if file_contents[ln]:find("[++;]") then
		if not enable_short_hand_incrementals then error("C++ style increments disabled for safety purposes.") end
		local var_name = string.match(file_contents[ln], "[%w?_?]+%w*+++")
		if var_name ~= nil then
			-- Remove the ++ or -- from the ends (this works better than pattern matching)
			local len = var_name:len() - 3
			local shortform = var_name:sub(1, len)
			file_contents[ln] = string.gsub(file_contents[ln], var_name.."%+%;", shortform .. " = " .. shortform .. " + 1")
		end
	end
	if file_contents[ln]:find("[%-%-%;]") then
		if not enable_short_hand_incrementals then error("C++ style increments disabled for safety purposes.") end
		local var_name = string.match(file_contents[ln], "[%w?_?]+%w*%-%-%;")
		if var_name ~= nil then
			-- Remove the ++ or -- from the ends (this works better than pattern matching)
			local len = var_name:len() - 3
			local shortform = var_name:sub(1, len)
			file_contents[ln] = string.gsub(file_contents[ln], var_name.."%-%;", shortform .. " = " .. shortform .. " - 1")
		end
	end

	-- Blocking single line operators:
	-- if, elseif, for, while, return (as return can only be on it's own line)

	-- Append then to if, elseif statements
	if file_contents[ln]:find("eif ") then
		result[ln] = string.gsub(file_contents[ln], "eif ", "elseif ") .. " then"
		return
	elseif file_contents[ln]:find("if ") then
		result[ln] = file_contents[ln] .. " then"
		return
	end

	-- Special formatting friendly if/elseif statements:
	if file_contents[ln]:find("_eif ") then
		result[ln] = string.gsub(file_contents[ln], "_eif ", "elseif ")
		print("[Warning-Callisto]: Custom formatting elseif invoked at line " ..ln.. ".")
		return
	elseif file_contents[ln]:find("_if ") then
		result[ln] = string.gsub(file_contents[ln], "_eif ", "elseif ")
		print("[Warning-Callisto]: Custom formatting if invoked at line " ..ln.. ".")
		return
	end

	-- Append do to for, while
	if file_contents[ln]:find("for ") then
		result[ln] = file_contents[ln] .. " do"
		return
	end
	if file_contents[ln]:find("while ") then
		result[ln] = file_contents[ln] .. " do"
		return
	end
	if file_contents[ln]:find("func ") then
		result[ln] = string.gsub(file_contents[ln], "func ", "function ", 1)
		return
	end
	if file_contents[ln]:find("ret ") then
		result[ln] = string.gsub(file_contents[ln], "ret ", "return ", 1)
		return
	end

	result[ln] = file_contents[ln]
end

local function transpile_it(filename)
	for ln=1, #file_contents do
		keyword_regex(ln)
	end
	print_file(filename)
end

local function file_load(filename)
	for line in io.lines(filename..".cos") do
		file_contents[#file_contents+1] = line
	end
	transpile_it(filename)
end

local modname
if minetest ~= nil then
	modname = minetest.get_current_modname()
end

local function mt_file_load(filename)
	if minetest ~= nil then
		local current_path = minetest.get_modpath(modname)
		for line in io.lines(current_path..filename..".cos") do
			file_contents[#file_contents+1] = line
		end
		transpile_it(filename)
	else
		file_load(filename)
	end
end

--print("enter the filename of the .cos you want to process")
--file_load(io.read())
file_load("test")

-- Execute tests
-- dofile("test.lua")
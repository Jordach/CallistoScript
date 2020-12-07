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

Embedding Lua code example:

{={
	if true then
		return false
	elseif false then
		return true
	end
}=}

## Comments look like this. Multilines aren't going to be supported.
]]--

-- Flip to true to enable party mode
local enable_short_hand_incrementals = true

-- Multiline detection:
local multiline_detected = false

-- Embedded lua detection:
local lua_embbedded = false

-- File extension
local extension = ".cos"

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

local function keyword_regex(ln, filename)
	local found_multiline_start = false
	-- Check for presence of multiline comments or strings:
	if not multiline_detected then
		if file_contents[ln]:find("[%[][%=-][%[]") then -- should match [[ [=[ [==[ ...
			multiline_detected = true
			found_multiline_start = true
			print("[Notice-Callisto]: Multiline string/comment starting at line "..ln.." in file: "..filename..extension)
		elseif file_contents[ln]:find("[%[][%[]") then
			multiline_detected = true
			found_multiline_start = true
			print("[Notice-Callisto]: Multiline string/comment starting at line "..ln.." in file: "..filename..extension)
		end
	end

	-- Check for multiline comments or strings (in case they end early and the software locks)
	-- Don't process any keywords. IF the start of the multiline is on the same as the end, process as normal
	-- otherwise, prevent processing of keywords.
	if multiline_detected then
		if file_contents[ln]:find("[%]][%=-][%]]") then
			multiline_detected = false
			print("[Notice-Callisto]: Multiline string/comment ended at line "..ln.." in file: "..filename..extension)
			if file_contents[ln]:find("##") then
				file_contents[ln] = string.gsub(file_contents[ln], "##", "--", 1)
			end
			if not found_multiline_start then
				result[ln] = file_contents[ln]
				return
			end
		elseif file_contents[ln]:find("[%]][%]]") then
			multiline_detected = false
			print("[Notice-Callisto]: Multiline string/comment ended at line "..ln.." in file: "..filename..extension)
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

	-- Handle embedded Lua code:
	if not lua_embedded then
		if file_contents[ln]:find("[${][$=][${]") then
			if file_contents[ln]:find("[$}][$=][$}]") then
				error("[Error-Callisto]: Single line Lua embeds are not supported at line "..ln.." in file: "..filename..extension)
			end
			lua_embedded = true
			result[ln] = "-- [Callisto]: Embedded Lua block starts below."
			print("[Notice-Callisto]: Embedded Lua block starts at line "..ln.." in file: "..filename..extension)
			return
		end
	end

	if lua_embedded then
		if file_contents[ln]:find("[$}][$=][$}]") then
			lua_embedded = false
			result[ln] = "-- [Callisto]: Embedded Lua block ends."
			print("[Notice-Callisto]: Embedded Lua block ends at line "..ln.." in file: "..filename..extension)
			return
		else
			result[ln] = file_contents[ln]
			return
		end
	end
	
	-- Non blocking per line operations:

	-- let to local conversion
	local char_a, char_b = file_contents[ln]:find("let ") 
	if char_a == 1 then
		file_contents[ln] = string.gsub(file_contents[ln], "let ", "local ", 1)
	else -- Apparently tabs are a control sequence character
		if file_contents[ln]:find(" let ") then
			file_contents[ln] = string.gsub(file_contents[ln], "let ", "local ", 1)
		elseif file_contents[ln]:find("\tlet ") then
			file_contents[ln] = string.gsub(file_contents[ln], "let ", "local ", 1)
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

	if file_contents[ln]:find("++[%;]") then
		if not enable_short_hand_incrementals then error("[Error-Callisto]: C++ style increments disabled at "..ln.." in file: "..filename..extension) end
		local var_name = string.match(file_contents[ln], "[%w?_?]+%w*+++")
		if var_name ~= nil then
			-- Remove the ++ or -- from the ends (this works better than pattern matching)
			local len = var_name:len() - 2
			local shortform = var_name:sub(1, len)
			file_contents[ln] = string.gsub(file_contents[ln], var_name.."%+%;", shortform .. " = " .. shortform .. " + 1")
			print("[Warning-Callisto]: Incrementor statement used at line "..ln.." in file: "..filename..extension)
		end
	end
	if file_contents[ln]:find("[%-%-][%;]") then
		if not enable_short_hand_incrementals then error("[Error-Callisto]: C++ style decrements disabled at"..ln.." in file: "..filename..extension) end
		local var_name = string.match(file_contents[ln], "[%w?_?]+%w*[%-][%-][%;]")
		if var_name ~= nil then
			-- Remove the ++ or -- from the ends (this works better than pattern matching)
			local len = var_name:len() - 3
			local shortform = var_name:sub(1, len)
			file_contents[ln] = string.gsub(file_contents[ln], var_name, shortform .. " = " .. shortform .. " - 1")
			print("[Warning-Callisto]: Decrementor statement used at line "..ln.." in file: "..filename..extension)
		end
	end

	-- Blocking single line operators:
	-- if, elseif, for, while, return (as return can only be on it's own line)

	-- Special formatting friendly if/elseif statements:
	if file_contents[ln]:find("[%_]eif ") then
		result[ln] = string.gsub(file_contents[ln], "[%_]eif ", "elseif ", 1)
		print("[Warning-Callisto]: Custom formatted elseif statement at line " ..ln.." in file: "..filename..extension)
		return
	elseif file_contents[ln]:find("[%_]if ") then
		result[ln] = string.gsub(file_contents[ln], "[%_]if ", "if ", 1)
		print("[Warning-Callisto]: Custom formatted if statement at line " ..ln.." in file: "..filename..extension)
		return
	-- Append then to if, elseif statements
	elseif file_contents[ln]:find("eif ") then
		if file_contents[ln]:find(" then") then
			print ("[Notice-Callisto]: \"then\" Lua keyword found at line "..ln.." in file: "..filename..extension)
			result[ln] = file_contents[ln]
			return
		else
			result[ln] = string.gsub(file_contents[ln], "eif ", "elseif ", 1) .. " then"
			return
		end
	elseif file_contents[ln]:find("if ") then
		if file_contents[ln]:find(" then") then
			print ("[Notice-Callisto]: \"then\" Lua keyword found at line "..ln.." in file: "..filename..extension)
			result[ln] = file_contents[ln]
			return
		else
			result[ln] = file_contents[ln] .. " then"
			return
		end
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
		keyword_regex(ln, filename)
	end
	print_file(filename)
end

local function file_load(filename)
	for line in io.lines(filename..extension) do
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
		for line in io.lines(current_path..filename..extension) do
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
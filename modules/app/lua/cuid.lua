--
--------------------------------------------------------------------------------
--         File:  cuid.lua
--
--        Usage:  require("cuid")
--
--  Description:  CUID generator for Lua.
--
--      Options:  ---
-- Requirements:  ---
--         Bugs:  ---
--        Notes:  ---
--       Author:  Marco Aurélio da Silva (marcoonroad), <marcoonroad@gmail.com>
-- Organization:  ---
--      Version:  0.5
--      Created:  23-03-2018
--     Revision:  ---
--------------------------------------------------------------------------------
--

local exports = { }

local CUID_PREFIX     = "c"
local counter         = 0
local BASE            = 36
local BLOCK_SIZE      = 4
local DISCRETE_VALUES = 1679616 -- BASE ^ BLOCK_SIZE --
local LOADED_TIME     = os.time ( )
local EXECUTABLE      = os.getenv ("_")        or ""
local HOSTNAME        = os.getenv ("HOSTNAME") or ""
local USER            = os.getenv ("USER")     or ""
local DIRECTORY       = os.getenv ("PWD")      or ""

local CUSTOM_FINGERPRINT = os.getenv ("LUA_CUID_FINGERPRINT")

-- helper functions ---------------------------------
local alphabet = {
	"0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
	"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
	"n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"
}

local function to_base36 (number)
	number = math.abs (math.floor (number))

	if number < BASE then return alphabet[ number + 1 ] end

	local result = ""

	while number ~= 0 do
		local index = number % BASE

		result = alphabet[ index + 1 ] .. result
		number = math.floor (number / BASE)
	end

	return result
end

local function pad (number, size)
	local text   = string.format ("000000000%s", tostring (number))
	local length = string.len (text)

	return string.sub (text, (length - size) + 1)
end

local function safe_counter ( )
	counter = counter < DISCRETE_VALUES and counter or 0
	counter = counter + 1

	return counter - 1
end

local function random_uniform (limit)
	return math.random (0, limit - 1)
end

local function random_block ( )
	local random = random_uniform (DISCRETE_VALUES)

	return pad (to_base36 (random), BLOCK_SIZE)
end

local function fingerprint_sum (text)
	local sum    = 0
	local length = string.len (text) + 1 -- avoids div by zero --

	for letter in string.gmatch (text, ".") do
		sum = sum + string.byte (letter)
	end

	return sum / length
end

local function default_fingerprint ( )
	local first  = fingerprint_sum (EXECUTABLE)
	local second = fingerprint_sum (HOSTNAME)
	local third  = fingerprint_sum (USER)
	local fourth = LOADED_TIME
	local fifth  = fingerprint_sum (DIRECTORY)
	local sum    = (first + second + third + fourth + fifth) / 5

	return pad (to_base36 (sum), BLOCK_SIZE)
end

local DEFAULT_FINGERPRINT = default_fingerprint ( )

local function fingerprint ( )
	-- employs memoization --
	if CUSTOM_FINGERPRINT then
		local sum = fingerprint_sum (CUSTOM_FINGERPRINT)

		CUSTOM_FINGERPRINT  = nil
		DEFAULT_FINGERPRINT = pad (to_base36 (sum), BLOCK_SIZE)
	end

	return DEFAULT_FINGERPRINT
end

local function pad_from_base36 (value, size)
	return pad (to_base36 (value), size)
end

-- private API --------------------------------------
function exports.__set_fingerprint (value)
	DEFAULT_FINGERPRINT = nil
	CUSTOM_FINGERPRINT  = value
end

function exports.__reset_fingerprint ( )
	CUSTOM_FINGERPRINT  = nil
	DEFAULT_FINGERPRINT = default_fingerprint ( )
end

function exports.__structure (input)
	if input then exports.__set_fingerprint (tostring (input)) end

	local timestamp = pad_from_base36 (os.time ( ),      BLOCK_SIZE * 2)
	local count     = pad_from_base36 (safe_counter ( ), BLOCK_SIZE)
	local print     = fingerprint ( )
	local random    = random_block ( ) .. random_block ( )

	if input then exports.__reset_fingerprint ( ) end

	return {
		prefix      = CUID_PREFIX,
		timestamp   = timestamp,
		counter     = count,
		fingerprint = print,
		random      = random,
	}
end

-- public API ----------------------------------------------------
function exports.generate (input)
	local result = exports.__structure (input)

	return result.prefix ..
		result.timestamp ..
		result.counter ..
		result.fingerprint ..
		result.random
end

function exports.slug (input)
	local result = exports.__structure (input)

	return result.timestamp: sub (-2) ..
		result.counter: sub (-2) ..
		result.fingerprint: sub (1, 1) ..
		result.fingerprint: sub (-1) ..
		result.random: sub (-2)
end

return exports

-- END --

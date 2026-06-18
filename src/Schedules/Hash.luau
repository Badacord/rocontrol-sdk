--!strict
-- Portable 32-bit hashing. The schedule content hash MUST be reproducible by the
-- TypeScript backend, so the arithmetic is done in 32-bit lanes with no reliance
-- on Roblox-specific behavior.
--
-- Algorithm: FNV-1a (32-bit) over a canonical JSON string, rendered as 8 hex
-- chars. The backend computes the identical value from the same canonical JSON.

local Hash = {}

local MASK32 = 0xFFFFFFFF

-- 32-bit unsigned multiply that stays exact in IEEE-754 doubles by splitting the
-- left operand into 16-bit halves (a 32x25-bit product would overflow 2^53).
local function mul32(a: number, b: number): number
	local ah = math.floor(a / 65536)
	local al = a % 65536
	local high = (ah * b) % 65536
	local low = al * b
	return ((high * 65536) + low) % 4294967296
end
Hash.mul32 = mul32

local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619

function Hash.fnv1a32(text: string): number
	local hash = FNV_OFFSET
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = mul32(hash, FNV_PRIME)
	end
	return bit32.band(hash, MASK32)
end

-- 8-character lowercase hex of the 32-bit hash.
function Hash.ofString(text: string): string
	return string.format("%08x", Hash.fnv1a32(text))
end

-- mulberry32 PRNG, mirroring the canonical JS implementation (Math.imul-based).
-- Kept here, dependency-free, so the portable math is unit-tested in one place.
-- Returns a function yielding floats in [0, 1).
function Hash.mulberry32(seed: number): () -> number
	local state = seed % 4294967296
	return function(): number
		state = (state + 0x6D2B79F5) % 4294967296
		local t = state
		t = mul32(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
		t = bit32.bxor(
			(t + mul32(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % 4294967296,
			t
		)
		return bit32.band(bit32.bxor(t, bit32.rshift(t, 14)), MASK32) / 4294967296
	end
end

return Hash

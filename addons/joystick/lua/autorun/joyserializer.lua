
local serials = string.Explode("",[[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz,.<>?:[]{}\|1234567890-=!@#$%^&*()_+]])
local deserials = {}
for k,v in pairs(serials) do
	deserials[v] = k
end
//88 chars
//6 bits
//64 used up to \+|, 1+2 not used

joyBuffer = {}
joySerialize = function(a,b,c,d,e,f)
	//Input:
	//	0 thru 64 //Although this is technically 7 bits, I like having things center (g, or 33, is center)
	//		or
	//	bool,bool,bool,bool,bool,bool
	if tonumber(a) then
		if a < 0 then
			error("Integer greater than or equal to 0 expected.")
		elseif a > 64 then
			error("Integer less than or equal to 64 expected.")
		end
		return serials[a+1]
	else
		//Six bools
		local out = 0
		if a then
			out = out + 1
		end
		if b then
			out = out + 2
		end
		if c then
			out = out + 4
		end
		if d then
			out = out + 8
		end
		if e then
			out = out + 16
		end
		if f then
			out = out + 32
		end
		
		return serials[out+1]
	end
end

joyDeSerialize = function(n,bool)
	local cur = deserials[n]
	
	if not bool then
		return cur
	else
		cur = cur-1
		//Six bools
		local a,b,c,d,e,f
		
		//Little-endian format
		f = cur-32 >= 0
		cur = cur%32
		e = cur-16 >= 0
		cur = cur%16
		d = cur-8 >= 0
		cur = cur%8
		c = cur-4 >= 0
		cur = cur%4
		b = cur-2 >= 0
		cur = cur%2
		a = cur-1 >= 0
		
		return a,b,c,d,e,f
	end
end
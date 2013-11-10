
AddCSLuaFile("autorun/joyserializer.lua")
AddCSLuaFile("autorun/client/joystick.lua")
AddCSLuaFile("autorun/client/joynet.lua")
AddCSLuaFile("autorun/client/joyexample.lua")
AddCSLuaFile("autorun/client/joyenum.lua")
AddCSLuaFile("autorun/client/joyconfig.lua")

joystick = {}
include("autorun/joyserializer.lua")
local joystick = joystick
joystick.script_version = 28

jcon = {}
local jcon = jcon

//Holds bind data by UID
jcon.binds = {}

jcon.register = function(dat)
	/*

	Developer notes:

	jcon.register(<tblRegisterFormat>)
			//Returns <tblReg> or nil if your <tblRegisterFormat> is bad.

	<tblRegisterFormat> = {
		uid = <strUID>,
				//A 20-character unique identifier for this binding.
				//This must be a static value in order for bind saving to work.
				//Only one bind with this UID may exist - this action will return a bind of the same UID if it exists, even if the found one is in another category or is not of the same type
				//The UID MUST be 20 characters or less. Only the following characters are allowed:
					//ABCDEFGHIJKLMNOPQRSTUVWXYZ
					//abcdefghijklmnopqrstuvwxyz
					//,.<>?:[]{}\|
					//1234567890
					//-=!@#$%^&*()_+
				//No spaces are allowed.
				//I recommend the use of a general author id or project abbreviation followed by an underscore and then the specific name of the binding, e.g.:
				//bill_pitch, bill_yaw, bill_roll
				
				//WARNING
				//WARNING
				//UIDs with the substring "ent_" or another substring blocked by Garry from RunConsoleCommand will KILL THE SYSTEM
				//WARNING
				//WARNING
		
		type = <strType>,
				//"digital" or "analog", case-sensitive.
		
		description = <strDescription>,
				//Keep it to one or two words, user-friendly name.
		
		category = <strCategory>,
				//Groups similar registers, user-friendly name.
		
		max = <intUpperOutputBoundary>,
				//Upper output value for analog type registers (Output scales to a range, see below)
				//Omit to default to 255
		
		min = <intLowerOutputBoundary>,
				//Lower output value for analog type registers (Output scales to a range, see above)
				//Omit to default to 0
	}

	<tblReg>.IsJoystickReg
	<tblReg>:GetType()
	<tblReg>:GetDescription()
	<tblReg>:GetCategory()

	*/
	if
		(dat.type == "analog" or
		dat.type == "digital") and
		type(dat.description) == "string" and
		type(dat.category) == "string" and
		jcon.isValidUID(dat.uid)
	then
		do
			//Checks to see if this bind already exists by UID
			if jcon.binds[dat.uid] then
				return jcon.binds[dat.uid]
			end
		end
		
		jcon.binds[dat.uid] = {}
		local catreg = jcon.binds[dat.uid]
		
		catreg.type = dat.type
		catreg.uid = dat.uid
		catreg.category = dat.category
		catreg.description = dat.description
		if dat.type == "analog" then
			catreg.min = dat.min or 0
			catreg.max = dat.max or 255
		elseif dat.type == "digital" then
		end
		catreg.GetValue = function(self,pl)
			return "Use the joystick library."
		end
		
		catreg.IsJoystickReg = true
		catreg.GetType = function(self)
			return self.type
		end
		catreg.GetDescription = function(self)
			return self.description
		end
		catreg.GetCategory = function(self)
			return self.category
		end
		catreg.IsBound = function(self)
			return "Don't ask me, goddamn. Use the joystick library."
		end
		
		jcon.binds[catreg.uid] = catreg
		
		catreg.Send = function(self,pl)
			umsg.Start("ja",pl)
				umsg.String(catreg.uid)
				umsg.Bool(catreg.type == "analog" and true or false)
				umsg.String(catreg.description)
				umsg.String(catreg.category)
				umsg.Float(catreg.max or 0)
				umsg.Float(catreg.min or 0)
			umsg.End()
		end
		
		for k,v in pairs(player.GetAll()) do
			if v:IsConnected() then
				catreg:Send(v)
			end
		end
		
		return catreg
	end
	
	local out = "\t"
	
	if not (dat.type == "analog" or
		dat.type == "digital")
	then
		out = out..[[type is neither "analog" nor "digital"]].."\n\t"
	end
	if type(dat.description) ~= "string" then
		out = out.."description is not a string\n\t"
	end
	if type(dat.category) ~= "string" then
		out = out.."category is not a string\n\t"
	end
	local b,e = jcon.isValidUID(dat.uid)
	if not b then
		out = out..e.."\n\t"
	end
	out = out.."Have a nice day."
	error("PEBCAK error. RTFM or slap developer around with a large trout.\n"..out)
	
end

jcon.unregister = function(uid)
	jcon.binds[uid] = nil
	
	local filter = RecipientFilter()
	filter:AddAllPlayers()
	umsg.Start("joystickimpulse",filter)
		umsg.String("REMOVE")
		umsg.String(uid)
	umsg.End()
end

jcon.isValidUID = function(uid)
	if type(uid) ~= "string" then
		return false,"uid is not a string"
	end
	if uid:len() > 20 then
		return false,"uid is longer than 20 characters"
	end
	for k,v in pairs(string.Explode("",uid)) do
		if not string.find([[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz,.<>?:[]{}\|1234567890-=!@#$%^&*()_+]],v) then
			return false,"uid contains an illegal character"
		end
	end
	if string.find(uid,"ent_") then
		return false,"uid contains \"ent_\""
	end
	
	//Garry's rules, not mine
	local banlist = {
		"sv_cheats",
		"_restart",
		"exec",
		"condump",
		"bind",
		"alias",
		"ent_fire",
		"ent_setname",
		"sensitivity",
		"name",
		"r_aspect",
		"quit",
		"quti",
		"exit",
		"lua_run",
		"lua_run_cl",
		"lua_open",
		"lua_cookieclear",
		"lua_showerrors_cl",
		"lua_showerrors_sv",
		"lua_showerrors_sv",
		"lua_openscript",
		"lua_openscript_cl",
		"lua_redownload",
		"sent_reload",
		"sent_reload_cl",
		"swep_reload",
		"swep_reload_cl",
		"gamemode_reload",
		"gamemode_reload_cl",
		"con_logfile",
		"clear",
	}
	for k,v in pairs(banlist) do
		if uid:find(v) then
			ErrorNoHalt("WARNING: UID contains \"" .. v .. "\", and may cause the joystick module to fail.")
		end
	end
	
	return true
end

local st = {}
joystick.Get = function(pl,uid)
	local dat = joystick.data[pl]
	if not dat then
		return nil,1337
	end
	
	if not dat.header then
		return nil,1336
	end
	
	local pos = dat.header[uid]
	if not pos then
		//Is not bound
		return nil,1
	end
	
	if (not dat.datamap) or dat.datamap == "" then
		//Data not xmitting/xmitted
		return nil,2
	end
	
	local reg = jcon.binds[uid]
	if reg.type == "analog" then
		if #dat.datamap < pos then
			return nil,2
		end
		
		local val = joyDeSerialize(dat.datamap:sub(pos,pos))
		//Val is now an integer ranging from 1 to 65, inclusive
		return (val-1)/64*(reg.max-reg.min)+reg.min
	elseif reg.type == "digital" then
		if #dat.datamap - dat.headersplit < 0 then
			return nil,2
		end
		local map = dat.datamap:sub(dat.headersplit)
		if #map*6 < pos then
			return nil,2
		end
		local byte = math.floor((pos-1)/6)+1
		byte = map:sub(byte,byte)
		st[1],st[2],st[3],st[4],st[5],st[0] = joyDeSerialize(byte,true)
		return st[pos%6]
	end
end

//Holds player joystick and bind data (Players can have different available binds)
joystick.data = {}

hook.Add("PlayerInitialSpawn","joystickinitialspawn",function(pl)
	joystick.data[pl] = {}
	local dat = joystick.data[pl]
	dat.rawheader = ""
	//UID > map position
	dat.header = {}
	dat.headersplit = 1 //The first digital bit is on this byte of the datamap
	dat.datamap = ""
	
	for k,v in pairs(jcon.binds) do
		v:Send(pl)
	end
end)

joystick.ccupdate = function(pl,cmd,args)
	local dat = joystick.data[pl]
	if not dat then
		joystick.data[pl] = {}
		dat = joystick.data[pl]
	end
	
	if args[1] == "HEADER" and args[2] == "CANCEL" then
		dat.rawheader = ""
	elseif args[1] == "HEADER" and args[2] == "FINISH" then
		//Calculate header
		dat.header = {}
		dat.headersplit = 1
		
		local h = string.Explode(" ",dat.rawheader)
		local n = math.floor(#h/2)
		
		for i=1,n do
			//We have a leading space, so h[1] == ""
			local k,v = tostring(h[i*2]),tonumber(h[i*2+1]) or 0
			local reg = jcon.binds[k]
			if reg then
				//k is UID, v is datamap position
				dat.header[k] = v
				if reg.type == "analog" then
					if v+1 > dat.headersplit then
						dat.headersplit = v+1
					end
				end
			end
		end
	elseif args[1]:find(" ") then
		//Header data
		dat.rawheader = dat.rawheader .. tostring(args[1])
	else
		//Data map
		dat.datamap = tostring(args[1])
		
		hook.Call("JoystickUpdate",GAMEMODE,pl,dat.header)
	end
end

concommand.Add("j",joystick.ccupdate)
concommand.Add("ja",joystick.ccupdate)

timer.Simple(0.1,function()
	hook.Call("JoystickInitialize",GAMEMODE)
	hook.Call("PostJoystickInitialize",GAMEMODE)
end)
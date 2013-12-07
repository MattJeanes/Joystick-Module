// Joystick interface module
// Version 1.2
// Written by Night-Eagle

/*

I HIGHLY SUGGEST YOU USE THE JOYSTICK CONFIGURATOR AS OPPOSED TO USING
THESE REVERSE-COMPATIBILITY FUNCTIONS.

Functions you SHOULD use, if you decide not to use the joystick
	configurator:
joystick.GetJoystick(n)
joystick.NumJoysticks()

joystick:NumAxes()
joystick:NumButtons()
joystick:NumHats()
joystick:NumPovs()
joystick:GetAxis(n)
joystick:GetButton(n)
joystick:GetHat(n)
joystick:GetPov(n)

Do NOT use any functions not listed here. Those not listed are subject
to change at my discretion.
	If you use joystick.GetJoystick(n) with an n that is not greater
than 0 and less than or equal to joystick.NumJoysticks(), a nil value
will be returned.

*/

HAT_CENTERED	= -1;
HAT_RIGHT		= 0;
HAT_RIGHTUP		= 1;
HAT_UP			= 2;
HAT_LEFTUP		= 3;
HAT_LEFT		= 4;
HAT_LEFTDOWN	= 5;
HAT_DOWN		= 6;
HAT_RIGHTDOWN	= 7;

HAT_C	= -1;
HAT_0	= 0;
HAT_1	= 1;
HAT_2	= 2;
HAT_3	= 3;
HAT_4	= 4;
HAT_5	= 5;
HAT_6	= 6;
HAT_7	= 7;
HAT_8	= 0;

local oldjoystickname
if type(joystick) == "table" and joystick._name then
	oldjoystickname = joystick._name
end
local oldjoystickrestart
if type(joystick) == "table" and joystick._restart then
	oldjoystickrestart = joystick._restart
end

if file.Exists("lua/bin/gmcl_joystick_win32.dll", "GAME") then
	require("joystick")
end

if type(joystick) ~= "table" then
	print( "Joystick module is not properly installed!" )
	concommand.Add( "joyconfig", function()
		LocalPlayer():ChatPrint( "Joystick module is not loaded!" )
	end )
	return
end

joystick.version = "1.2"
if not joystick.binaryversion then
	joystick.binaryversion = 1.0
end
if tostring(joystick.version) ~= tostring(joystick.binaryversion) then
	Msg("WARNING: Lua module / application extension version mismatch! Update joystick module!\n")
end

if not oldjoystickname then
	oldjoystickname = joystick.name
end
joystick.names = {}
joystick._name = oldjoystickname
joystick.name = function(enum,override)
	if enum ~= -1 then
		if override then
			return joystick._name(enum)
		end
		return joystick.names[enum] or joystick._name(enum)
	else
		return "Keyboard"
	end
end

if not oldjoystickrestart then
	oldjoystickrestart = joystick.restart
end
joystick._restart = oldjoystickrestart
joystick.restart = function()
	hook.Call("JoystickRestartDown",GAMEMODE)
	
	joystick._restart()
	
	hook.Call("JoystickRestartUp",GAMEMODE)
end

if not joystick.guid then
	joystick.guid = function(joy)
		if joy ~= -1 then
			local a,b,c,d,e,f,g,h,i,j,k = joystick.guidm(joy)
			return "{"..a.."-"..b.."-"..c.."-"..d..":"..e..":"..f..":"..g..":"..h..":"..i..":"..j..":"..k.."}"
		else
			return "{0-0-0-0:0:0:0:0:0:0:-1}"
		end
	end
end

joystick.load = function()
	joystick.fresh = {}
	for i=0,joystick.count()-1 do
		joystick.fresh[i] = CurTime()
	end
	
	joystick.NumJoysticks = function()
		return joystick.count()
	end
	
	joystick.poll = function(joy)
		joystick.refresh(joy)
		joystick.fresh[joy] = CurTime()
	end
	
	joystick.GetJoystick = function(n)
		n = math.Round(n)-1
		if n >= 0 and n <= joystick.count()-1 then
			local j = {enum = n}
			for k,v in pairs(joystick.meta) do
				j[k] = v
			end
			
			return j
		end
	end
	
	joystick.meta = {
		NumAxes = function(self)
			return joystick.count(self.enum,1)
		end,
		NumButtons = function(self)
			return joystick.count(self.enum,2)
		end,
		NumHats = function(self)
			return joystick.count(self.enum,3)
		end,
		GetButton = function(self,n)
			if CurTime() > joystick.fresh[self.enum] + 0.001 then
				joystick.poll(self.enum)
			end
			
			return joystick.button(self.enum,n-1) > 0
		end,
		GetAxis = function(self,n)
			if CurTime() > joystick.fresh[self.enum] + 0.001 then
				joystick.poll(self.enum)
			end
			
			return joystick.axis(self.enum,n-1)/256-127
		end,
		GetHat = function(self,n)
			if CurTime() > joystick.fresh[self.enum] + 0.001 then
				joystick.poll(self.enum)
			end
			
			local pov = joystick.pov(self.enum,n-1)
			if pov > 100000 then
				return -1
			else
				pov = 2-math.Round(pov)/4500
				if pov < 0 then
					pov = pov + 8
				end
				
				return pov
			end
		end,
		GetName = function(self)
			return joystick.name(self.enum)
		end,
	}
	joystick.meta.NumPovs = joystick.meta.NumHats
	joystick.meta.GetPov = joystick.meta.GetHat
	
	Msg("Night-Eagle's joystick module loaded.\nScript version ",joystick.version,".\nBinary version ",joystick.binaryversion,".\n")
end

joystick.load()
include("joyenum.lua")
include("joynet.lua")
include("joyconfig.lua")

local joysticknetstart = joysticknetstart
_G.joysticknetstart = nil

timer.Simple(0.1,function()
	hook.Call("JoystickInitialize",GAMEMODE)
	
	//TODO: Load saved files here
	joystick.initialized = true
	joysticknetstart()
	joystick.postnetstart = true
	
	hook.Call("PostJoystickInitialize",GAMEMODE)
	joystick.postinitialized = true
end)

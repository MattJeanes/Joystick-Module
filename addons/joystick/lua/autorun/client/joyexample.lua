if true then
	return
end


/*
The only things you should use from a joystick register:

reg.IsJoystickReg
reg:GetValue()
reg:GetType()
reg:GetDescription()
reg:GetCategory()
reg:IsBound()
*/

// Example registering controls
exjcon = {}

hook.Add("JoystickInitialize","joynet",function()
	/*
	We send this serverside...
	
	exjcon.pitch = jcon.register{
		uid = "ex_1",
		type = "analog",
		description = "Pitch",
		category = "Fight Air",
	}
	
	exjcon.yaw = jcon.register{
		uid = "ex_2",
		type = "analog",
		description = "Yaw",
		category = "Fight Air",
	}
	
	exjcon.roll = jcon.register{
		uid = "ex_3",
		type = "analog",
		description = "Roll",
		category = "Fight Air",
	}
	
	exjcon.thrust = jcon.register{
		uid = "ex_4",
		type = "analog",
		description = "Thrust",
		category = "Fight Air",
	}
	
	exjcon.airbrake = jcon.register{
		uid = "ex_5",
		type = "analog",
		description = "Air brake",
		category = "Fight Air",
	}
	
	exjcon.fireprimary = jcon.register{
		uid = "ex_6",
		type = "digital",
		description = "Fire Primary",
		category = "Fight Air",
	}
	
	exjcon.firesecondary = jcon.register{
		uid = "ex_7",
		type = "digital",
		description = "Fire Secondary",
		category = "Fight Air",
	}
	
	exjcon.landinggear = jcon.register{
		uid = "ex_8",
		type = "digital",
		description = "Landing Gear",
		category = "Fight Air",
	}
	
	exjcon.beacon = jcon.register{
		uid = "ex_9",
		type = "digital",
		description = "Beacon",
		category = "Fight Air",
	}
	
	exjcon.eject = jcon.register{
		uid = "ex_10",
		type = "digital",
		description = "Eject",
		category = "Fight Air",
	}
	
	exjcon.flare = jcon.register{
		uid = "ex_11",
		type = "digital",
		description = "Flare",
		category = "Fight Air",
	}
	
	exjcon.chaff = jcon.register{
		uid = "ex_12",
		type = "digital",
		description = "Chaff",
		category = "Fight Air",
	}
	
	exjcon.shoot = jcon.register{
		uid = "ex_13",
		type = "digital",
		description = "Shoot",
		category = "Fight Ground",
	}
	
	exjcon.dive = jcon.register{
		uid = "ex_14",
		type = "digital",
		description = "Dive",
		category = "Fight Sea",
	}
	
	
	
	function exjcon.HUDPaint()
		surface.SetDrawColor(0,0,0,127)
		surface.DrawRect(0,0,ScrW(),48)
		draw.DrawText("addons/joystick/lua/autorun/client/joyexample.lua\nexjcon.HUDPaint","Trebuchet24",3,0,Color(255,255,255,255),0)
		draw.DrawText("\nUse the console command exjcon to stop.","Trebuchet24",ScrW()-3,0,Color(255,0,0,255),2)
		draw.DrawText(tostring(joynet and joynet.buffer or "BUFFER UNAVAILABLE"),"Trebuchet24",0,512-24,Color(255,0,0,255),0)
		
		surface.DrawRect(0,48,128,512)
		local i = 0
		for k,v in pairs(exjcon) do
			if type(v) == "table" and v.IsJoystickReg then
				i = i + 1
				if v:GetType() == "digital" then
					//The type of the binding will always be the same as you set it.
					//If the player binds an axis to a digital input, the register will remain a digital input.
					if v:GetValue() then
						surface.SetDrawColor(0,0,255,100)
						surface.DrawRect(0,48+i*18,128,18)
					end
				else
					surface.SetDrawColor(0,0,255,100)
					surface.DrawRect(0,48+i*18,128*(v:GetValue()/255),18)
				end
				draw.DrawText(v:GetDescription(),"Trebuchet18",3,48+i*18,Color(255,255,255,255),0)
			end
		end
	end
	hook.Add("HUDPaint","exjcon.HUDPaint",exjcon.HUDPaint)
	
	
	function exjcon.cc()
		hook.Remove("HUDPaint","exjcon.HUDPaint")
	end
	concommand.Add("exjcon",exjcon.cc)
	*/
	
	local buffer = {}
	usermessage.Hook("joyexample",function(bf)
		for i = 1,100 do
			local t = bf:ReadShort()
			if t == 1 then
				buffer[bf:ReadString()] = bf:ReadBool()
			elseif t == 2 then
				buffer[bf:ReadString()] = bf:ReadFloat()
			else
				break
			end
		end
	end)
	
	function exjcon.HUDPaint()
		surface.SetDrawColor(0,0,0,127)
		surface.DrawRect(0,0,ScrW(),48)
		draw.DrawText("addons/joystick/lua/autorun/client/joyexample.lua\nexjcon.HUDPaint","Trebuchet24",3,0,Color(255,255,255,255),0)
		draw.DrawText("\nUse the console command exjcon to stop.","Trebuchet24",ScrW()-3,0,Color(255,0,0,255),2)
		draw.DrawText(tostring(joynet and joynet.buffer or "BUFFER UNAVAILABLE"),"Trebuchet24",0,512-24,Color(255,0,0,255),0)
		
		surface.DrawRect(0,48,128,512)
		local i = 0
		for k,v in pairs(buffer) do
			i = i + 1
			if type(v) == "boolean" then
				if v then
					surface.SetDrawColor(0,0,255,100)
					surface.DrawRect(0,48+i*18,128,9)
				end
				if jcon.getRegisterByUID(k):GetValue() then
					surface.SetDrawColor(255,0,0,100)
					surface.DrawRect(0,48+i*18+9,128,9)
				end
			else
				surface.SetDrawColor(0,0,255,100)
				surface.DrawRect(0,48+i*18,128*(v/255),9)
				surface.SetDrawColor(255,0,0,100)
				surface.DrawRect(0,48+i*18+9,128*(jcon.getRegisterByUID(k):GetValue()/255),9)
			end
			draw.DrawText(jcon.getRegisterByUID(k):GetDescription(),"Trebuchet18",3,48+i*18,Color(255,255,255,255),0)
		end
	end
	hook.Add("HUDPaint","exjcon.HUDPaint",exjcon.HUDPaint)
	
	
	function exjcon.cc()
		hook.Remove("HUDPaint","exjcon.HUDPaint")
	end
	concommand.Add("exjcon",exjcon.cc)
end)

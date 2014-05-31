TOOL.Tab			= "Wire"
TOOL.Category		= "Input, Output"
TOOL.Name			= "Joystick"
TOOL.Command		= nil
TOOL.ConfigName		= ""

if ( CLIENT ) then
	language.Add( "tool.wire_joystick.name", "Joystick Tool (Wire)" )
	language.Add( "tool.wire_joystick.desc", "Spawns a Joystick Module interface chip for use with the wire system." )
	language.Add( "tool.wire_joystick.0", "Primary: Create/Update Joystick   Secondary: Copy Settings    Reload: Link to pod" )
	language.Add( "tool.wire_joystick.1", "Now select the pod to link to, or anything other than a pod to revert.")
	language.Add( "WirejoystickTool_joystick", "Joystick:" )
	language.Add( "sboxlimit_wire_joysticks", "You've hit the Joysticks limit!" )
	language.Add( "undone_Wire Joystick", "Undone Wire Joystick" )
end

if (SERVER) then
	CreateConVar('sbox_maxwire_joysticks', 20)
end

TOOL.Model = "models/jaanus/wiretool/wiretool_range.mdl"
TOOL.ClientConVar["uid"] = ""
TOOL.ClientConVar["analog"] = ""
TOOL.ClientConVar["description"] = ""
TOOL.ClientConVar["min"] = "0"
TOOL.ClientConVar["max"] = "1"

cleanup.Register( "wire_joysticks" )

usermessage.Hook("joywarn",function(um)
	local t = um:ReadShort()
	if t == 1 then
		GAMEMODE:AddNotify("Wire Joystick: UID in use by another player.",NOTIFY_ERROR,10)
		surface.PlaySound("buttons/button10.wav")
	elseif t == 2 then
		GAMEMODE:AddNotify("Wire Joystick: UID ",um:ReadString()," in use by another player.",NOTIFY_ERROR,10)
		surface.PlaySound("buttons/button10.wav")
	end
end)

function TOOL.sanitizeUID(uid)
	uid = tostring(uid)
	if uid:sub(1,3) ~= "jm_" then
		return "jm_"..uid
	end
	return uid
end

function TOOL:LeftClick( trace )
	if (!trace.HitPos) then return false end
	if (trace.Entity:IsPlayer()) then return false end
	if ( CLIENT ) then return true end
	
	local ply = self:GetOwner()
	
	local _uid = self.sanitizeUID(self:GetClientInfo("uid"))
	local _type = self:GetClientInfo("analog") == "1" and "analog" or "digital"
	local _description = self:GetClientInfo("description")
	local _min = tonumber(self:GetClientInfo("min")) or 0
	local _max = tonumber(self:GetClientInfo("max")) or 1
	
	//Check if the player owns the UID, or if the UID is free
	local status = 0
	if jcon and jcon.wireModInstances and jcon.wireModInstances[_uid] then
		for k,v in pairs(jcon.wireModInstances[_uid]) do
			if v == ply then
				status = 1
			elseif status ~= 1 then
				status = 2
			end
		end
	end
	
	if status == 2 then
		umsg.Start("joywarn",ply)
			umsg.Short(1)
		umsg.End()
		return false
	end
	
	if ( trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_joystick" && trace.Entity:GetTable().pl == ply ) then
		local uidvalid,uiderror = jcon.isValidUID(_uid)
		if not uidvalid then
			ErrorNoHalt("Wire Joystick: "..tostring(uiderror).."\n")
			return false
		end
		trace.Entity:Update(_uid,_type,_description,_min,_max)
		return true
	end
	
	if ( !self:GetSWEP():CheckLimit( "wire_joysticks" ) ) then return false end
	
	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90
	
	local wire_joystick = MakeWireJoystick(ply,trace.HitPos,Ang,_uid,_type,_description,_min,_max)
	if not wire_joystick then
		return false
	end
	
	local min = wire_joystick:OBBMins()
	wire_joystick:SetPos( trace.HitPos - trace.HitNormal * min.z )
	
	local const = WireLib.Weld(wire_joystick, trace.Entity, trace.PhysicsBone, true, true)
	
	undo.Create("Wire Joystick")
		undo.AddEntity( wire_joystick )
		undo.AddEntity( const )
		undo.SetPlayer( ply )
	undo.Finish()
	
	ply:AddCleanup( "wire_joysticks", wire_joystick )
	
	return true
end

function TOOL:RightClick( trace )
	local ply = self:GetOwner()
	if trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_joystick" && trace.Entity:GetTable().pl == ply then
		for k,v in pairs{"uid","analog","description","min","max"} do
			local tab = trace.Entity:GetTable()
			ply:ConCommand("wire_joystick_"..v.." "..tostring(tab[v]))
		end
		return true
	end
end

function TOOL:Reload( trace )
	if ( CLIENT ) then return true end
	
	if (self:GetStage() == 0) and trace.Entity:GetClass() == "gmod_wire_joystick" then
		self.PodCont = trace.Entity
		self:SetStage(1)
		return true
	elseif self:GetStage() == 1 then
		if self.PodCont:GetTable().pl ~= self:GetOwner() then
			return false
		end
		if trace.Entity.GetPassenger then
			self.PodCont:Link(trace.Entity)
		else
			self.PodCont:Link()
		end
		self:SetStage(0)
		self.PodCont = nil
		return true
	else
		return false
	end
end

/*
if (SERVER) then
	function MakeWireJoystick(pl,Pos,Ang,UID,type,description,min,max,Vel,aVel,frozen)
		if not pl:CheckLimit("wire_joysticks") then
			return false
		end
		
		if not jcon then
			return false
		end
		
		//UID = ENT:affixUID(UID)
		if UID:sub(1,3) ~= "jm_" then
			UID = "jm_"..UID
		end
		local uidvalid,uiderror = jcon.isValidUID(UID)
		if not uidvalid then
			ErrorNoHalt("Wire Joystick: "..tostring(uiderror).."\n")
			return false
		end
		
		local wire_joystick = ents.Create("gmod_wire_joystick")
		if not wire_joystick:IsValid() then
			return false
		end
		
		wire_joystick:SetAngles(Ang)
		wire_joystick:SetPos(Pos)
		wire_joystick:SetModel(Model(MODEL))
		wire_joystick:Spawn()
		
		if wire_joystick:GetPhysicsObject():IsValid() then
			wire_joystick:GetPhysicsObject():EnableMotion(!frozen)
		end
		
		wire_joystick:SetPlayer(pl)
		wire_joystick:Setup(pl,UID,type,description,min,max)
		wire_joystick.pl = pl
		
		pl:AddCount("wire_joysticks", wire_joystick)
		pl:AddCleanup("gmod_wire_joystick", wire_joystick)
		
		return wire_joystick
	end
	
	duplicator.RegisterEntityClass("gmod_wire_joystick", MakeWireJoystick, "Pos", "Ang", "uid", "type", "description", "min", "max", "Vel", "aVel", "frozen")
end
*/

function TOOL:UpdateGhostWirejoystick( ent, player )
	if ( !ent || !ent:IsValid() ) then return end

	local tr 	= util.GetPlayerTrace( player, player:GetAimVector() )
	local trace = util.TraceLine( tr )

	if (!trace.Hit || trace.Entity:IsPlayer() || trace.Entity:GetClass() == "gmod_wire_joystick" ) then
		ent:SetNoDraw( true )
		return
	end

	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90

	local min = ent:OBBMins()
	ent:SetPos( trace.HitPos - trace.HitNormal * min.z )
	ent:SetAngles( Ang )

	ent:SetNoDraw( false )
end

function TOOL:Think()
	if (!self.GhostEntity || !self.GhostEntity:IsValid() || self.GhostEntity:GetModel() != self.Model ) then
		self:MakeGhostEntity( self.Model, Vector(0,0,0), Angle(0,0,0) )
	end

	self:UpdateGhostWirejoystick( self.GhostEntity, self:GetOwner() )
end

function TOOL.BuildCPanel(panel)
	panel:AddControl("TextBox",{
		Label = "UID",
		Description = "17 characters maximum",
		MaxLength = "17",
		Text = "",
		Command = "wire_joystick_uid",
	})
	panel:AddControl("TextBox",{
		Label = "Description",
		Description = "20 characters maximum",
		MaxLength = "20",
		Text = "",
		Command = "wire_joystick_description",
	})
	panel:AddControl("CheckBox",{
		Label = "Analog",
		Description = "Unchecked for digital input",
		Command = "wire_joystick_analog",
	})
	panel:AddControl("Slider",{
		Label = "Minimum/Off",
		Type = "Integer",
		Min = "-10",
		Max = "10",
		Command = "wire_joystick_min",
	})
	panel:AddControl("Slider",{
		Label = "Maximum/On",
		Type = "Integer",
		Min = "-10",
		Max = "10",
		Command = "wire_joystick_max",
	})
	panel:AddControl("Button",{
		Label = "Joystick Configuration",
		Command = "joyconfig",
	})
	panel:AddControl("Label",{
		Text = "UID = Unique Identifier\nNo spaces, alphanumeric, 17 charater limit\nNote:\nJoystick configuration should be run after placing a chip.\nIn order to change an existing binding, there must be only one chip with its UID left.\nOne UID allows for one input.\n\nMultiple devices with the same UID will receive from the same input, but may have different max/min settings.",
	})
end

if CLIENT and joystick then
	--surface.CreateFont("trebuchet",36,500,true,false,"Trebuchet50" )
	surface.CreateFont("Trebuchet50", {size = 36, weight = 500, antialias = true, font = "trebuchet"})

	--surface.CreateFont("trebuchet",36,500,true,false,"Trebuchet36" )
	surface.CreateFont("Trebuchet36", {size = 36, weight = 500, antialias = true, font = "trebuchet"})

	--surface.CreateFont("trebuchet",20,500,true,false,"Trebuchet20" )
	surface.CreateFont("Trebuchet20", {size = 20, weight = 500, antialias = true, font = "trebuchet"})

	function TOOL.DrawToolScreen(w,h)
		local b,e = pcall(function()
			local w,h = tonumber(w) or 256,tonumber(h) or 256
			surface.SetDrawColor(0,0,0,255)
			surface.DrawRect(0,0,w,h)
			draw.DrawText("Joystick Tool","Trebuchet36",4,0,Color(255,255,255,255),0)
			
			local uid = tostring(LocalPlayer():GetInfo("wire_joystick_uid"))
			if uid:sub(1,3) ~= "jm_" then
				uid = "jm_"..uid
			end
			
			draw.DrawText("UID: "..uid,"Trebuchet20",4,36,Color(255,255,255,255),0)
			draw.DrawText("Type: "..tostring(LocalPlayer():GetInfo("wire_joystick_analog") == "1" and "analog" or "digital"),"Trebuchet20",w-4,36,Color(255,255,255,255),2)
			
			if not jcon then
				return
			end
			local reg = jcon.getRegisterByUID(uid)
			if reg and reg.IsJoystickReg then
				if reg:IsBound() then
					local val = reg:GetValue()
					if type(val) == "number" then
						surface.SetDrawColor(255,0,0,255)
						surface.DrawRect(0,h/2-16,w,32)
						surface.SetDrawColor(0,255,0,255)
						local disp = w*((val-reg.min)/(reg.max-reg.min))
						surface.DrawRect(0,h/2-16,disp,32)
						
						local text = tonumber(val) or 0
						local max = tonumber(LocalPlayer():GetInfo("wire_joystick_max")) or 0
						local min = tonumber(LocalPlayer():GetInfo("wire_joystick_min")) or 0
						text = text/255*(max-min)+min
						draw.DrawText(math.Round(text),"Trebuchet50",w/2,h/2-20,Color(0,0,255,255),1)
					elseif type(val) == "boolean" then
						surface.SetDrawColor(255,0,0,255)
						surface.DrawRect(0,h/2-16,w,32)
						surface.SetDrawColor(0,255,0,255)
						if val then
							surface.DrawRect(0,h/2-16,w,32)
						end
						local max = tonumber(LocalPlayer():GetInfo("wire_joystick_max")) or 0
						local min = tonumber(LocalPlayer():GetInfo("wire_joystick_min")) or 0
						draw.DrawText(val and max or min,"Trebuchet50",w/2,h/2-20,Color(0,0,255,255),1)
					end
					draw.DrawText(reg:GetDeviceName() or "","Trebuchet20",4,h-20,Color(255,255,255,255),0)
				else
					surface.SetDrawColor(255,165,0,255)
					surface.DrawRect(0,h/2-16,w,32)
					draw.DrawText(uid.." unbound","Trebuchet50",w/2,h/2-20,Color(0,0,255,255),1)
				end
			else
				surface.SetDrawColor(32,178,170,255)
				surface.DrawRect(0,h/2-16,w,32)
				draw.DrawText(uid.." inactive","Trebuchet50",w/2,h/2-20,Color(0,0,255,255),1)
			end
		end)
		if not b then
			ErrorNoHalt(e,"\n")
		end
	end
end
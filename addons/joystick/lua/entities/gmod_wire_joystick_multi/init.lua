AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')
ENT.WireDebugName = "Joystick Multi"
local MODEL = Model("models/jaanus/wiretool/wiretool_range.mdl")

local multi_varlist = {}
local outs = {}
for i = 1,8 do
	local strI = tostring(i)
	for k,v in pairs{"uid","analog","description","min","max"} do
		table.insert(multi_varlist,strI..v)
	end
	table.insert(outs,strI)
end


function ENT:affixUID(uid)
	if uid:sub(1,3) ~= "jm_" then
		uid = "jm_"..uid
	end
	return uid
end
function ENT:Initialize()
	self.Entity:SetModel(MODEL)
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self.Outputs = Wire_CreateOutputs(self.Entity,outs)
	
	self.lastpoll = CurTime()
	
	self.data = {}
	for i = 1,8 do
		self.data[i] = {}
	end
end
function ENT:Setup(pl,...)//UID,type,description,min,max)
	//WARNING: DUPLICITY UPDATE
	local arg = { ... }
	for i = 1,8 do
		local strI = tostring(i)
		local UID = arg[(i-1)*5+1]
		local type = arg[(i-1)*5+2]
		local description = arg[(i-1)*5+3]
		local min = arg[(i-1)*5+4]
		local max = arg[(i-1)*5+5]
		
		local temp = tonumber(type)
		if temp then
			type = type == 0 and "digital" or "analog"
		end
		
		if UID and type and description and min and max then
			UID = self:affixUID(UID)
			self.data[i].pl = pl
			self.data[i].uid = UID
			self.data[i].type = type
			self.data[i].description = description
			self.data[i].min = min or 0
			self.data[i].max = max or 255
			
			self[strI.."uid"] = UID
			self[strI.."analog"] = type == "digital" and 0 or 1
			self[strI.."description"] = description
			self[strI.."min"] = min
			self[strI.."max"] = max
			
			self:DepositUID(i)
		end
	end
end
function ENT:Update(...)
	//WARNING: DUPLICITY SETUP
	local arg = { ... }
	for i = 1,8 do
		self:WithdrawUID(i)
		
		local strI = tostring(i)
		local UID = arg[(i-1)*5+1]
		local type = arg[(i-1)*5+2]
		local description = arg[(i-1)*5+3]
		local min = arg[(i-1)*5+4]
		local max = arg[(i-1)*5+5]
		
		local temp = tonumber(type)
		if temp then
			type = type == 0 and "digital" or "analog"
		end
		
		if UID and type and description and min and max then
			UID = self:affixUID(UID)
			self.data[i].uid = UID
			self.data[i].type = type
			self.data[i].description = description
			self.data[i].min = min or 0
			self.data[i].max = max or 255
			
			self[strI.."uid"] = UID
			self[strI.."analog"] = type == "digital" and 0 or 1
			self[strI.."description"] = description
			self[strI.."min"] = min
			self[strI.."max"] = max
			
			self:DepositUID(i)
		end
	end
end
function ENT:OnRemove()
	Wire_Remove(self.Entity)
	self:WithdrawUID()
end
function ENT:WithdrawUID(i,uid)
	//Withdraw and Deposit should be used to maintain a relative balance of 1 while the entity is valid
	//Relative balance must be 0 after the entity's existence
	//Relative balance is 0 before the entity's existence
	
	local uid = uid
	if not uid then
		if i then
			uid = self.data[i].uid
		else
			uid = false
		end
	end
	
	if uid ~= false then
		if uid then
			jcon.wireModInstances[uid][self.Entity] = nil
			local count = 0
			for k,v in pairs(jcon.wireModInstances[uid]) do
				if IsEntity(k) and v and k:HasUID(uid) then
					count = count+1
				end
			end
			
			if count == 0 then
				//Remove joystick entries
				jcon.unregister(uid)
			end
		end
	else
		for i = 1,8 do
			self:WithdrawUID(i)
		end
	end
end
function ENT:DepositUID(i,uid)
	local uid = uid
	if not uid then
		if i then
			uid = self.data[i].uid
		else
			uid = false
		end
	end
	
	if uid ~= false then
		uid = self:affixUID(uid)
		if jcon then
			if i then
				self.data[i].uid = uid
			else
				Msg("Warning: Leaked UID 1...",i,":",uid,"\n")
				return
			end
			
			jcon.wireModInstances = jcon.wireModInstances or {} //Mod is for module, so shutup
			
			jcon.register{
				uid = uid,
				type = self.data[i].type,
				description = "[" .. uid .. "] - "..self.data[i].description,
				category = "Wire Joystick",
				min = 0, //Do not
				max = 255, //Change these
			}
			
			jcon.wireModInstances[uid] = jcon.wireModInstances[uid] or {}
			jcon.wireModInstances[uid][self.Entity] = self.pl //This reserves the UID so other players cannot override it
		end
	else
		Msg("Warning: Leaked UID 2...",i,":",uid,"\n")
	end
end
function ENT:SetUID(i,uid)
	self:WithdrawUID(i)
	self:DepositUID(i,uid)
end
function ENT:GetUID(i)
	return self.data[i].uid
end
function ENT:HasUID(uid)
	for k,v in ipairs(self.data) do
		if v.uid == uid then
			return true
		end
	end
	
	return false
end
function ENT:Link(pod,RC)
	//I'm copying the Adv Pod Controller so that they can be used in tandem without problem (except for RC)
	if !pod then
		self.Pod = nil
		return false
	end
	self.Pod = pod
	//self.RC = RC
	return true
end
function ENT:TriggerInput(iname, value)
end
function ENT:ShowOutput()
	local text = "Joystick Multi"
	if self.data then
		for i = 1,8 do
			text = text.."\n"..tostring(self.data[i].uid).." = "..tostring(self.data[i].value)
		end
	end
	self:SetOverlayText(text)
end
function ENT:OnRestore()
	Wire_Restored(self.Entity)
end

//WARNING: DUPLICITY gmod_wire_joystick
hook.Add("JoystickUpdate","gmod_wire_joystick",function(pl,header)
	//DON'T MODIFY header, IF WE DO, ALL INPUT WILL BE FUBAR
	for uid,bit in pairs(header) do
		if not jcon.wireModInstances then
			jcon.wireModInstances = {}
		end
		if jcon.wireModInstances[uid] then
			for k,v in pairs(jcon.wireModInstances[uid]) do
				k:PollJoystick(pl)
			end
		end
	end
end)

function ENT:PollJoystick(pl_upd)
	if self.lastpoll == CurTime() then
		return
	end
	self.lastpoll = CurTime()
	
	local pl
	if self.Pod then
		if self.Pod:IsValid() then
			pl = self.Pod:GetPassenger()
		end
	else
		pl = self:GetPlayer()
	end
	
	if pl == pl_upd and IsEntity(pl) then
		for i = 1,8 do
			local dat = self.data[i]
			dat.value = 0
			if joystick and joystick.Get then
				dat.value = joystick.Get(pl,dat.uid)
				if dat.type == "analog" then
					dat.value = dat.value and (dat.value)/255*(dat.max-dat.min)+dat.min or 0
				else
					dat.value = dat.value and dat.max or dat.min
				end
				Wire_TriggerOutput(self.Entity,tostring(i),dat.value)
			end
		end
	else
		//TODO: Reset outputs to 0 on player pod exit as option - this can be done by the player using adv pod controller and if statements
	end
end

function ENT:Think()
	self.BaseClass.Think(self)
	
	self:ShowOutput()
	self.Entity:NextThink(CurTime()+0.125)
end
--Duplicator support to save pod link (TAD2020)
function ENT:BuildDupeInfo()
	//I'm copying the Adv Pod Controller so that they can be used in tandem without problem (except for RC)
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	if (self.Pod) and (self.Pod:IsValid()) then //and (!self.RC) then
		info.pod = self.Pod:EntIndex()
	end
	return info
end
function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	//I'm copying the Adv Pod Controller so that they can be used in tandem without problem (except for RC)
	self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)
	if (info.pod) then
		self.Pod = GetEntByID(info.pod)
		if (!self.Pod) then
			self.Pod = ents.GetByIndex(info.pod)
		end
	end
end
function MakeWireJoystick_Multi(pl,Pos,Ang,...)//UID,type,description,min,max)
	if not pl:CheckLimit("wire_joysticks") then
		return false
	end
	
	if not jcon then
		return false
	end
	
	local arg = { ... }
	//UID = ENT:affixUID(UID)
	for i = 1,8 do
		local strI = tostring(i)
		local UID = arg[(i-1)*5+1]
		
		if UID then
			if UID:sub(1,3) ~= "jm_" then
				UID = "jm_"..UID
			end
			local uidvalid,uiderror = jcon.isValidUID(UID)
			if not uidvalid then
				ErrorNoHalt("Wire Joystick: "..tostring(uiderror).."\n")
				return false
			end
		end
	end
	
	local wire_joystick = ents.Create("gmod_wire_joystick_multi")
	if not wire_joystick:IsValid() then
		return false
	end
	
	wire_joystick:SetAngles(Ang)
	wire_joystick:SetPos(Pos)
	wire_joystick:SetModel(Model(MODEL))
	wire_joystick:Spawn()
	
	/*
	if wire_joystick:GetPhysicsObject():IsValid() then
		wire_joystick:GetPhysicsObject():EnableMotion(!frozen)
	end
	*/
	
	wire_joystick:SetPlayer(pl)
	wire_joystick.pl = pl
	wire_joystick:Setup(pl,unpack(arg))//UID,type,description,min,max)
	
	pl:AddCount("wire_joysticks", wire_joystick)
	pl:AddCleanup("gmod_wire_joystick_multi", wire_joystick)
	
	return wire_joystick
end
duplicator.RegisterEntityClass("gmod_wire_joystick_multi",MakeWireJoystick_Multi,"Pos","Ang",unpack(multi_varlist))

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')
ENT.WireDebugName = "Joystick"
local MODEL = Model("models/jaanus/wiretool/wiretool_range.mdl")
function ENT:Initialize()
	self.Entity:SetModel(MODEL)
	self.Entity:PhysicsInit(SOLID_VPHYSICS)
	self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
	self.Entity:SetSolid(SOLID_VPHYSICS)
	self.Outputs = Wire_CreateOutputs(self.Entity,{"Out"})
	
	self.lastpoll = CurTime()
end
function ENT:Setup(pl,UID,type,description,min,max)
	UID = self:affixUID(UID)
	self.pl = pl
	self.uid = UID
	self.type = type
	self.description = description
	self.min = min or 0
	self.max = max or 255
	
	self:DepositUID()
end
function ENT:Update(UID,type,description,min,max)
	self:WithdrawUID() //Must be run before we change the UID
	
	UID = self:affixUID(UID)
	self.uid = UID
	self.type = type
	self.description = description
	self.min = min or 0
	self.max = max or 255
	
	self:DepositUID() //Must be run after we change the UID
end
function ENT:OnRemove()
	Wire_Remove(self.Entity)
	self:WithdrawUID()
end
function ENT:WithdrawUID(uid)
	//Withdraw and Deposit should be used to maintain a relative balance of 1 while the entity is valid
	//Relative balance must be 0 after the entity's existence
	//Relative balance is 0 before the entity's existence
	
	local uid = uid or self.uid
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
function ENT:DepositUID(uid)
	local uid = uid or self.uid
	uid = self:affixUID(uid)
	if jcon then
		self.uid = uid
		
		jcon.wireModInstances = jcon.wireModInstances or {} //Mod is for module, so shutup
		
		jcon.register{
			uid = uid,
			type = self.type,
			description = "[" .. uid .. "] - "..self.description,
			category = "Wire Joystick",
			min = 0, //Do not
			max = 255, //Change these
		}
		
		jcon.wireModInstances[uid] = jcon.wireModInstances[uid] or {}
		jcon.wireModInstances[uid][self.Entity] = self.pl //This reserves the UID so other players cannot override it
	end
end
function ENT:SetUID(uid)
	self:WithdrawUID()
	self:DepositUID(uid)
end
function ENT:GetUID()
	return self.uid
end
function ENT:HasUID(uid)
	return uid == self.uid
end
function ENT:affixUID(uid)
	if uid:sub(1,3) ~= "jm_" then
		uid = "jm_"..uid
	end
	return uid
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
	local text = "Joystick"
	if self.Outputs.Out then
		text = text.."\n"..tostring(self.type).." "..tostring(self.description).."\n"..tostring(self.min).." - "..tostring(self.max).."\n"..tostring(self.uid).." = "..tostring(self.value)
	end
	self:SetOverlayText(text)
end
function ENT:OnRestore()
	Wire_Restored(self.Entity)
end

//WARNING: DUPLICITY gmod_wire_joystick_multi
hook.Add("JoystickUpdate","gmod_wire_joystick",function(pl,header)
	//DON'T MODIFY header, IF WE DO, ALL INPUT WILL BE FUBAR
	for uid,bit in pairs(header) do
		for k,v in pairs(jcon.wireModInstances[uid]) do
			k:PollJoystick(pl)
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
		self.value = 0
		if joystick and joystick.Get then
			self.value = joystick.Get(pl,self.uid)
			if self.type == "analog" then
				self.value = self.value and (self.value)/255*(self.max-self.min)+self.min or 0
			else
				self.value = self.value and self.max or self.min
			end
			Wire_TriggerOutput(self.Entity,"Out",self.value)
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
	wire_joystick.pl = pl
	wire_joystick:Setup(pl,UID,type,description,min,max)
	
	pl:AddCount("wire_joysticks", wire_joystick)
	pl:AddCleanup("gmod_wire_joystick", wire_joystick)
	
	return wire_joystick
end
duplicator.RegisterEntityClass("gmod_wire_joystick",MakeWireJoystick,"Pos","Ang","uid","type","description","min","max","Vel","aVel","frozen")

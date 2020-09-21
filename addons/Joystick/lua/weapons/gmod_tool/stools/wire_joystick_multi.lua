TOOL.Tab        = "Wire"
TOOL.Category   = "Input, Output"
TOOL.Name       = "Joystick Multi"
TOOL.Command    = nil
TOOL.ConfigName = ""

if CLIENT then
  language.Add( "tool.wire_joystick_multi.name", "Joystick Multi Tool (Wire)" )
  language.Add( "tool.wire_joystick_multi.desc", "Spawns a Joystick Module interface chip for use with the wire system." )
  language.Add( "tool.wire_joystick_multi.0", "Primary: Create/Update Joystick   Secondary: Copy Settings    Reload: Link to pod" )
  language.Add( "tool.wire_joystick_multi.1", "Now select the pod to link to, or anything other than a pod to revert.")
  language.Add( "WirejoystickTool_joystick", "Joystick:" )
  language.Add( "sboxlimit_wire_joysticks", "You've hit the Joysticks limit!" )
  language.Add( "undone_Wire Joystick Multi", "Undone Wire Joystick Multi" )
end

if SERVER then
  CreateConVar("sbox_maxwire_joysticks", 20)
end

TOOL.Model = "models/jaanus/wiretool/wiretool_range.mdl"

for i = 1, 8 do
  local strI = tostring(i)
  TOOL.ClientConVar[strI.."uid"]          = ""
  TOOL.ClientConVar[strI.."analog"]       = ""
  TOOL.ClientConVar[strI.."description"]  = ""
  TOOL.ClientConVar[strI.."min"]          = "0"
  TOOL.ClientConVar[strI.."max"]          = "1"
end

local multi_varlist = {}
for i = 1, 8 do
  local strI = tostring(i)
  for k,v in pairs{"uid","analog","description","min","max"} do
    table.insert(multi_varlist,strI..v)
  end
end

cleanup.Register( "wire_joysticks" )

--[[
usermessage.Hook("joywarn",function(um)
  local t = um:ReadShort()
  if t == 1 then
    local _uid = um:ReadString() or ""
    GAMEMODE:AddNotify("Wire Joystick: UID \"".._uid.."\" in use by another player.",NOTIFY_ERROR,10)
    surface.PlaySound("buttons/button10.wav")
  end
end)
]]--

function TOOL:SanitizeUID(uid)
  local prf, uid = "jm_", tostring(uid)
  if uid:sub(1,3) ~= prf then
    return prf..uid
  end
  return uid
end

function TOOL:LeftClick( trace )
  if (not trace.HitPos) then return false end
  if (trace.Entity:IsPlayer()) then return false end
  if CLIENT then return true end

  local ply = self:GetOwner()
  local wins = jcon and jcon.wireModInstances or nil

  -- Check all UIDs first so we notify the player of all conflicting UIDs, not just one
  local status = 0
  for i = 1, 8 do
    local strI = tostring(i)
    local _uid = self:SanitizeUID(self:GetClientInfo(strI.."uid"))

    -- Check if the player owns the UID, or if the UID is free
    if jcon and wins and wins[_uid] then
      for k,v in pairs(wins[_uid]) do
        if v == ply then
          status = 1
        elseif status ~= 1 then
          status = 2
          umsg.Start("joywarn",ply)
            umsg.Short(1)
            umsg.String(_uid)
          umsg.End()
        end
      end
    end
  end

  -- Conflicting UID, exit
  if status == 2 then
    return false
  end

  -- Validate and update
  local pass = {}
  local quit = false
  for i = 1, 8 do
    local strI = tostring(i)

    local _uid = self:SanitizeUID(self:GetClientInfo(strI.."uid"))
    local uidvalid,uiderror = jcon.isValidUID(_uid)
    if not uidvalid then
      ErrorNoHalt("Wire Joystick: "..tostring(uiderror).."\n")
      return false
    end
    local _type = self:GetClientInfo(strI.."analog") == "1" and "analog" or "digital"
    local _description = self:GetClientInfo(strI.."description")
    local _min = tonumber(self:GetClientInfo(strI.."min")) or 0
    local _max = tonumber(self:GetClientInfo(strI.."max")) or 1

    -- Check if the player owns the UID, or if the UID is free
    local status = 0
    if jcon and wins and wins[_uid] then
      for k,v in pairs(wins[_uid]) do
        if v == ply then
          status = 1
        elseif _uid == "jm_" then
          -- Allow override, everyone is allowed to use "jm_"
        elseif status ~= 1 then
          status = 2
          -- This usermessage requires stools/wire_joystick.lua
          umsg.Start("joywarn",ply)
            umsg.Short(2)
            umsg.String(_uid)
          umsg.End()
        end
      end
    end

    if status == 2 then
      return false
    end

    table.insert(pass, _uid)
    table.insert(pass, _type)
    table.insert(pass, _description)
    table.insert(pass, _min)
    table.insert(pass, _max)

    if ( trace.Entity:IsValid() and
         trace.Entity:GetClass() == "gmod_wire_joystick_multi" and
         trace.Entity:GetTable().pl == ply ) then
      -- trace.Entity:Update(_uid,_type,_description,_min,_max)
      -- return true

      quit = true
    end
  end

  -- If we're updating, exit now
  if quit then
    trace.Entity:Update(unpack(pass))
    return true
  end

  if ( not self:GetSWEP():CheckLimit( "wire_joysticks" ) ) then return false end

  local Ang = trace.HitNormal:Angle()
        Ang.pitch = Ang.pitch + 90

  local wire_joystick = MakeWireJoystick_Multi(ply,trace.HitPos,Ang,unpack(pass))
  if not ( wire_joystick and wire_joystick:IsValid() ) then return end

  local min = wire_joystick:OBBMins()
  wire_joystick:SetPos( trace.HitPos - trace.HitNormal * min.z )

  local const = WireLib.Weld(wire_joystick, trace.Entity, trace.PhysicsBone, true, true)

  undo.Create("Wire Joystick Multi")
    undo.AddEntity( wire_joystick )
    undo.AddEntity( const )
    undo.SetPlayer( ply )
  undo.Finish()

  ply:AddCleanup( "wire_joysticks", wire_joystick )

  return true
end

function TOOL:RightClick( trace )
  local ply = self:GetOwner()
  if trace.Entity:IsValid() then
    if trace.Entity:GetClass() == "gmod_wire_joystick_multi" and
       trace.Entity:GetTable().pl == ply then
      local tab = trace.Entity:GetTable()

      for k,v in pairs(multi_varlist) do
        ply:ConCommand("wire_joystick_multi_"..v.." "..tostring(tab[v]))
      end
      return true
    end
  elseif trace.HitWorld then
    ply:ConCommand("joyconfig")
  end
end

function TOOL:Reload( trace )
  if CLIENT then return true end

  if (self:GetStage() == 0) and
      trace.Entity:GetClass() == "gmod_wire_joystick_multi" then
    self.PodCont = trace.Entity
    self:SetStage(1)
    return true
  elseif self:GetStage() == 1 then
    local tPod = self.PodCont:GetTable()
    if not tPod or tPod.pl ~= self:GetOwner() then
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

--[[
if SERVER then

  function MakeWirejoystick_multi(pl,Pos,Ang,...) -- UID,type,description,min,max)
    if ( not pl:CheckLimit( "wire_joysticks" ) ) then return false end

    local wire_joystick = ents.Create( "gmod_wire_joystick_multi" )
    if (not wire_joystick:IsValid()) then return false end

    wire_joystick:SetAngles( Ang )
    wire_joystick:SetPos( Pos )
    wire_joystick:SetModel( Model("models/jaanus/wiretool/wiretool_range.mdl") )
    wire_joystick:Spawn()

    wire_joystick:Setup(pl,unpack(arg))//UID,type,description,min,max)

    wire_joystick:SetPlayer( pl )
    wire_joystick.pl = pl

    pl:AddCount( "wire_joysticks", wire_joystick )

    return wire_joystick
  end

  duplicator.RegisterEntityClass("gmod_wire_joystick_multi", MakeWirejoystick_multi,unpack(multi_varlist))

end
]]--

function TOOL:UpdateGhostWirejoystick( ent, ply )
  if ( not ent or not ent:IsValid() ) then return end

  local trace = ply:GetEyeTrace()

  if (not trace.Hit or
          trace.Entity:IsPlayer() or
          trace.Entity:GetClass() == "gmod_wire_joystick_multi" ) then
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
  if (not self.GhostEntity or
      not self.GhostEntity:IsValid() or
          self.GhostEntity:GetModel() != self.Model ) then
    self:MakeGhostEntity( self.Model, Vector(0,0,0), Angle(0,0,0) )
  end

  self:UpdateGhostWirejoystick( self.GhostEntity, self:GetOwner() )
end

function TOOL.BuildCPanel(panel)
  local sPrefix, pItem = "wire_joystick_multi"
  panel:SetName(language.GetPhrase("tool."..sPrefix..".name"))
  panel:Help(language.GetPhrase("tool."..sPrefix..".desc"))
  panel:Button( "Joystick Configuration", "joyconfig" )
  panel:Help( "Joystick configuration should be run after placing a chip. "..
    "In order to change an existing binding, there must be only one chip with its UID left.\nOne UID allows for one input.\n\n"..
    "Multiple devices with the same UID will receive from the same input, but may have different max/min settings." )
  local pItem
  for i = 1, 8 do
    local strI = tostring(i)
    panel:Help( "Control "..strI )
    pItem = panel:TextEntry( "UID" )
    pItem:SetTooltip( "Unique identifier. No spaces, alphanumeric, 17 charater limit" )
    pItem.OnChange = function(pnSelf)
      local sTxt = pnSelf:GetText():Trim():sub(1, 17)
            sTxt = sTxt:gsub("%s+", "0"):gsub("%W", "0")
      RunConsoleCommand("wire_joystick_multi_"..strI.."uid", sTxt)
    end
    pItem = panel:TextEntry( "Description" )
    pItem:SetTooltip( "Channel description. Maximum 20 characters" )
    pItem.OnChange = function(pnSelf)
      local sTxt = pnSelf:GetText():Trim():sub(1, 20)
      RunConsoleCommand("wire_joystick_multi_"..strI.."description", sTxt)
    end
    pItem = panel:CheckBox( "Analog", "wire_joystick_multi_"..strI.."analog" )
    pItem:SetTooltip( "Unchecked for digital input" )
    Item = panel:NumSlider( "Minimum / Off", "wire_joystick_multi_"..strI.."min", -10, 10, 0)
    Item:SetTooltip( "Minimum output value when analogue or OFF value when digital" )
    Item = panel:NumSlider( "Maximum / On" , "wire_joystick_multi_"..strI.."max", -10, 10, 0)
    Item:SetTooltip( "Maximum output value when analogue or ON value when digital" )
  end
end

if CLIENT and joystick then
  surface.CreateFont("Trebuchet36", {size = 36, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet20", {size = 20, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet12", {size = 12, weight = 500, antialias = true, additive = false, font = "trebuchet"})

  function TOOL:DrawToolScreen(w,h)
    local b,e = pcall(function()
      local w, h = (tonumber(w) or 256), (tonumber(h) or 256)
      surface.SetDrawColor(0, 0, 0, 255)
      surface.DrawRect(0, 0, w, h)
      draw.DrawText("Joystick Multi Tool","Trebuchet36",4,0,Color(255,255,255,255),0)
      local y, ply = 36, LocalPlayer()
      local siz = math.floor((h - y) / 8) -- No black line at the tool screen bottom

      for i = 1, 8 do
        local strI = tostring(i)
        local uid = self:SanitizeUID(ply:GetInfo("wire_joystick_multi_"..strI.."uid"))

        if not jcon then
          return
        end
        local reg = jcon.getRegisterByUID(uid)
        if reg and reg.IsJoystickReg then
          if reg:IsBound() then
            local val = reg:GetValue()
            if type(val) == "number" then
              surface.SetDrawColor(255,0,0,255)
              surface.DrawRect(0,y,w,siz)
              surface.SetDrawColor(0,255,0,255)
              local disp = w*((val-reg.min)/(reg.max-reg.min))
              surface.DrawRect(0,y,disp,siz)

              local text = tonumber(val) or 0
              local max = tonumber(ply:GetInfo("wire_joystick_multi_"..strI.."max")) or 0
              local min = tonumber(ply:GetInfo("wire_joystick_multi_"..strI.."min")) or 0
              text = text/255*(max-min)+min
              draw.DrawText(math.Round(text),"Trebuchet20",w/2,y,Color(0,0,255,255),1)
            elseif type(val) == "boolean" then
              surface.SetDrawColor(255,0,0,255)
              surface.DrawRect(0,y,w,siz)
              surface.SetDrawColor(0,255,0,255)
              if val then
                surface.DrawRect(0,y,w,siz)
              end
              local max = tonumber(ply:GetInfo("wire_joystick_multi_"..strI.."max")) or 0
              local min = tonumber(ply:GetInfo("wire_joystick_multi_"..strI.."min")) or 0
              draw.DrawText(val and max or min,"Trebuchet20",w/2,y,Color(0,0,255,255),1)
            end
            draw.DrawText(reg:GetDeviceName() or "","Trebuchet12",4,y+siz-12,Color(255,255,255,255),0)
          else
            surface.SetDrawColor(255,165,0,255)
            surface.DrawRect(0,y,w,siz)
            draw.DrawText(uid.." unbound","Trebuchet20",w/2,y,Color(0,0,255,255),1)
          end
        else
          surface.SetDrawColor(32,178,170,255)
          surface.DrawRect(0,y,w,siz)
          draw.DrawText(uid.." inactive","Trebuchet20",w/2,y,Color(0,0,255,255),1)
        end

        draw.DrawText(uid,"Trebuchet12",4,y,Color(255,255,255,255),0)
        draw.DrawText(tostring(ply:GetInfo("wire_joystick_multi_"..strI.."analog") == "1" and "analog" or "digital"),"Trebuchet12",w-4,y,Color(255,255,255,255),2)

        y = y + siz
      end
    end)
    if not b then
      ErrorNoHalt(e,"\n")
    end
  end
end

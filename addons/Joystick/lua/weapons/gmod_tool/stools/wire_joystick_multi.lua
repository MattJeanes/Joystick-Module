local gsToolModeOP = TOOL.Mode
local gsToolPrefix = gsToolModeOP.."_"
local gsToolLimits = gsToolModeOP:gsub("_multi", "").."s"
local gsSentClasMK = "gmod_"..gsToolModeOP
local MappingFxUID = "abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"

TOOL.Tab        = "Wire"
TOOL.Category   = "Input, Output"
TOOL.Name       = gsToolModeOP:gsub("wire",""):gsub("%W+", " "):gsub("%s+%w", string.upper):sub(2, -1)
TOOL.Command    = nil
TOOL.ConfigName = ""
TOOL.Model      = "models/jaanus/wiretool/wiretool_range.mdl"

if CLIENT then

  TOOL.Information = {
    { name = "info",  stage = 1   },
    { name = "left"      },
    { name = "right"     },
    { name = "reload"    }
  }

  language.Add( "tool."..gsToolModeOP..".name"           , "Joystick Multi Tool (Wire)" )
  language.Add( "tool."..gsToolModeOP..".desc"           , "Spawns a Joystick Module interface chip for use with the wire system" )
  language.Add( "tool."..gsToolModeOP..".left"           , "Create / Update joystick" )
  language.Add( "tool."..gsToolModeOP..".right"          , "Copy joystick settings. Hit world to open configuration" )
  language.Add( "tool."..gsToolModeOP..".reload"         , "Link joystick to pod controller" )
  language.Add( "tool."..gsToolModeOP..".1"              , "Now select the pod to link to, or anything other than a pod to revert.")
  language.Add( "tool."..gsToolModeOP..".uid"            , "Unique identifier. No spaces, alphanumeric, 17 character limit!" )
  language.Add( "tool."..gsToolModeOP..".uid_con"        , "UID")
  language.Add( "tool."..gsToolModeOP..".autofill"       , "Write a positive number here and hit ENTER to trigger random text autofill")
  language.Add( "tool."..gsToolModeOP..".description"    , "Write some input description here. Maximum 20 characters! For example `Steering`" )
  language.Add( "tool."..gsToolModeOP..".description_con", "Description")
  language.Add( "tool."..gsToolModeOP..".lcontr"         , "This labels the given set of input control configuration settings" )
  language.Add( "tool."..gsToolModeOP..".lcontr_con"     , "Control configuration:" )
  language.Add( "tool."..gsToolModeOP..".maxon"          , "Maximum output value when analogue or ON value when digital" )
  language.Add( "tool."..gsToolModeOP..".maxon_con"      , "Maximum / On")
  language.Add( "tool."..gsToolModeOP..".minoff"         , "Minimum output value when analogue or OFF value when digital" )
  language.Add( "tool."..gsToolModeOP..".minoff_con"     , "Minimum / Off" )
  language.Add( "tool."..gsToolModeOP..".analog"         , "Enable this when your source is analogue input" )
  language.Add( "tool."..gsToolModeOP..".analog_con"     , "Analog input" )
  language.Add( "tool."..gsToolModeOP..".config"         , "Click this button to open the joystick configuration. You can also right click on the world" )
  language.Add( "tool."..gsToolModeOP..".config_con"     , "Joystick Configuration" )
  language.Add( "undone_"..gsToolModeOP, "Undone Wire Joystick Multi" )
  language.Add( "sboxlimit_"..gsToolLimits, "You've hit the Joystick Multi limit!" )
  language.Add( "cleanup_" .. gsToolLimits, "Wire Joystick Multi chips " )
  language.Add( "cleaned_" .. gsToolLimits, "Cleaned up all Joystick Multi chips" )
end

if SERVER then
  CreateConVar("sbox_max"..gsToolLimits, 20)
end

for i = 1, 8 do
  local strI = tostring(i)
  TOOL.ClientConVar[strI.."uid"]         = ""
  TOOL.ClientConVar[strI.."analog"]      = ""
  TOOL.ClientConVar[strI.."description"] = ""
  TOOL.ClientConVar[strI.."min"]         = "0"
  TOOL.ClientConVar[strI.."max"]         = "1"
end

local gtConvarList = TOOL:BuildConVarList()

cleanup.Register( gsToolLimits )

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

local function SanitizeUID(uid)
  local prf, uid = "jm_", tostring(uid)
  if uid:sub(1,3) ~= prf then
    return prf..uid
  end
  return uid
end

local function DeSanitizeUID(uid)
  local prf, uid = "jm_", tostring(uid)
  if uid:sub(1,3) == prf then
    return uid:sub(4, -1)
  end
  return uid
end

local function GetRandomString(nLen)
  local nTop, sOut = MappingFxUID:len(), ""
  for iD = 1, nLen do
    local nRnd = math.random(nTop)
    sOut = sOut..MappingFxUID:sub(nRnd, nRnd)
  end
  return sOut
end

function TOOL:GetControlUID(sIdx)
  return SanitizeUID(self:GetClientInfo(sIdx.."uid"))
end

function TOOL:GetControlDescr(sIdx)
  return self:GetClientInfo(sIdx.."description")
end

function TOOL:GetControlType(sIdx)
  return ((self:GetClientNumber(sIdx.."analog", 0) ~= 0) and "analog" or "digital")
end

function TOOL:GetControlBorder(sIdx)
  return self:GetClientNumber(sIdx.."min", 0),
         self:GetClientNumber(sIdx.."max", 0)
end

function TOOL:GetNormalSpawn(stTr, eEnt)
  local vNorm = Vector(stTr.HitPos)
  local aNorm = stTr.HitNormal:Angle()
        aNorm.pitch = aNorm.pitch + 90
  if not ( eEnt and eEnt:IsValid() ) then
    return vNorm, aNorm
  end
  vNorm:Set(stTr.HitNormal)
  vNorm:Mul(-eEnt:OBBMins().z)
  vNorm:Add(stTr.HitPos)
  return vNorm, aNorm
end

function TOOL:LeftClick(tr)
  if (not tr.HitPos) then return false end
  if (tr.Entity:IsPlayer()) then return false end
  if CLIENT then return true end

  local ply, status = self:GetOwner(), 0

  if (not ply:CheckLimit( gsToolLimits )) then return false end

  local wins = jcon and jcon.wireModInstances or nil

  -- Check all UIDs first so we notify the player of all conflicting UIDs, not just one
  for i = 1, 8 do
    local strI = tostring(i)
    local _uid = self:GetControlUID(strI)

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
  for i = 1, 8 do
    local strI = tostring(i)

    local _uid = self:GetControlUID(strI)
    local ok, err = jcon.isValidUID(_uid)
    if not ok then
      ErrorNoHalt("Wire Joystick: "..tostring(err).."\n")
      return false
    end
    local _type = self:GetControlType(strI)
    local _description = self:GetControlDescr(strI)
    local _min, _max = self:GetControlBorder(strI)

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

    if status == 2 then return false end

    table.insert(pass, _uid)
    table.insert(pass, _type)
    table.insert(pass, _description)
    table.insert(pass, _min)
    table.insert(pass, _max)

    if (tr.Entity:IsValid() and
        tr.Entity:GetClass() == gsSentClasMK and
        tr.Entity:GetTable().pl == ply) then
        tr.Entity:Update( unpack(pass) )
        return true -- If we're updating, exit now
    end
  end
  -- Make sure the trace result is not updated
  local vPos, aAng = self:GetNormalSpawn(tr)
  local eJoystick = MakeWireJoystick_Multi(ply, vPos, aAng, unpack(pass))
  if not (eJoystick and eJoystick:IsValid()) then return end

  vPos, aAng = self:GetNormalSpawn(tr, eJoystick)
  eJoystick:SetPos(vPos)
  eJoystick:SetAngles(aAng)

  undo.Create("Wire Joystick Multi")
  undo.AddEntity( eJoystick )

  if( constraint.CanConstrain(tr.Entity, 0) ) then
    local cWeld = WireLib.Weld(eJoystick, tr.Entity, tr.PhysicsBone, true, true)
    if( cWeld and cWeld:IsValid() ) then
      eJoystick:DeleteOnRemove( cWeld )
      undo.AddEntity( cWeld )
    end
  end

  undo.SetPlayer( ply )
  undo.Finish()

  ply:AddCount  ( gsToolLimits, eJoystick )
  ply:AddCleanup( gsToolLimits, eJoystick )

  return true
end

function TOOL:RightClick(tr)
  local ply = self:GetOwner()
  if tr.Entity:IsValid() then
    if (tr.Entity:GetClass() == gsSentClasMK and
        tr.Entity:GetTable().pl == ply) then
      local tab = tr.Entity:GetTable()
      local ord = table.GetKeys(gtConvarList); table.sort(ord)
      for iD = 1, #ord do
        local var = ord[iD]
        local key = var:gsub(gsToolPrefix, "")
        local cpy = tostring(tab[key] or "")
        if (var:sub(-3, -1) == "uid") then
          cpy = DeSanitizeUID(cpy) -- Desanitize only the UID
        end -- Pass the value in quotes to proces the empty vars also
        ply:ConCommand(var.." \""..cpy.."\"")
      end
      return true
    end
  elseif tr.HitWorld then
    ply:ConCommand("joyconfig")
  end
end

function TOOL:Reload(tr)
  if CLIENT then return true end

  if (self:GetStage() == 0) and
      tr.Entity:GetClass() == gsSentClasMK then
    self.PodCont = tr.Entity
    self:SetStage(1)
    return true
  elseif self:GetStage() == 1 then
    local tPod = self.PodCont:GetTable()
    if not tPod or tPod.pl ~= self:GetOwner() then
      return false
    end
    if tr.Entity.GetPassenger then
      self.PodCont:Link(tr.Entity)
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

function TOOL:UpdateGhostWirejoystick( ent, ply )
  if (not ent or not ent:IsValid()) then return end

  local tr = ply:GetEyeTrace()

  if (not tr.Hit or
          tr.Entity:IsPlayer() or
          tr.Entity:GetClass() == gsSentClasMK) then
    ent:SetNoDraw( true ); return
  end

  local vPos, aAng = self:GetNormalSpawn(tr, ent)

  ent:SetPos( vPos )
  ent:SetAngles( aAng )
  ent:SetNoDraw( false )
end

function TOOL:Think()
  if (not self.GhostEntity or
      not self.GhostEntity:IsValid() or
          self.GhostEntity:GetModel() ~= self.Model) then
    self:MakeGhostEntity( self.Model, Vector(0,0,0), Angle(0,0,0) )
  end

  self:UpdateGhostWirejoystick( self.GhostEntity, self:GetOwner() )
end

if CLIENT and joystick then
  surface.CreateFont("Trebuchet36", {size = 36, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet20", {size = 20, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet12", {size = 12, weight = 500, antialias = true, additive = false, font = "trebuchet"})

  local clBlue  = Color( 0  , 0  , 255, 255 )
  local clWhite = Color( 255, 250, 255, 255 )

  function TOOL:DrawToolScreen(w, h)
    local b, e = pcall(function()
      local w, h = (tonumber(w) or 256), (tonumber(h) or 256)
      surface.SetDrawColor(0, 0, 0, 255)
      surface.DrawRect(0, 0, w, h)
      draw.DrawText("Joystick Multi Tool","Trebuchet36",4,0,clWhite,0)
      local y, ply = 36, LocalPlayer()
      local siz = math.floor((h - y) / 8) -- No black line at the tool screen bottom
      for i = 1, 8 do
        if not jcon then return end
        local strI = tostring(i)
        local _uid = self:GetControlUID(strI)
        local _type = self:GetControlType(strI)
        local reg = jcon.getRegisterByUID(_uid)
        if reg and reg.IsJoystickReg then
          if reg:IsBound() then
            local val = reg:GetValue()
            if type(val) == "number" then
              local _min, _max = self:GetControlBorder(strI)
              local disp = w * ((val - reg.min) / (reg.max - reg.min))
              local text = (tonumber(val) or 0) / 255 * (_max - _min) + _min
              surface.SetDrawColor(255, 0, 0, 255)
              surface.DrawRect(0, y, w, siz)
              surface.SetDrawColor(0, 255, 0, 255)
              surface.DrawRect(0, y, disp, siz)
              draw.DrawText(math.Round(text), "Trebuchet20", w / 2, y, clBlue, 1)
            elseif type(val) == "boolean" then
              local _min, _max = self:GetControlBorder(strI)
              surface.SetDrawColor(255, 0, 0, 255)
              surface.DrawRect(0,y,w,siz)
              surface.SetDrawColor(0, 255, 0, 255)
              if val then surface.DrawRect(0, y, w, siz) end
              draw.DrawText(val and _max or _min, "Trebuchet20", w / 2, y, clBlue, 1)
            end
            draw.DrawText(reg:GetDeviceName() or "", "Trebuchet12", 4, y + siz - 12, clWhite, 0)
          else
            surface.SetDrawColor(255, 165, 0, 255)
            surface.DrawRect(0, y, w, siz)
            draw.DrawText(_uid.." unbound","Trebuchet20", w / 2, y, clBlue, 1)
          end
        else
          surface.SetDrawColor(32,178,170,255)
          surface.DrawRect(0,y,w,siz)
          draw.DrawText(_uid.." inactive", "Trebuchet20", w / 2, y, clBlue, 1)
        end
        draw.DrawText(_uid, "Trebuchet12", 4, y, clWhite, 0)
        draw.DrawText(_type, "Trebuchet12", w - 4, y, clWhite, 2)
        y = y + siz
      end
    end)
    if not b then ErrorNoHalt(e,"\n") end
  end
end

local function setupTextEntry(pnBase, sName, sID, sPattern, nLen)
  local psPref = "tool."..gsToolModeOP.."."
  local pnConv = gsToolPrefix..sID..sName
  local pnText, pnName = pnBase:TextEntry(language.GetPhrase(psPref..sName.."_con"), pnConv)
  pnText.OnChange = function(pnSelf)
    local sTxt = pnSelf:GetText()
    local sPat, sNew = tostring(sPattern or ""), sTxt:Trim()
          sNew = (sPat == "") and sNew or sNew:gsub("["..sPat.."]", "X")
    if(sTxt:len() > nLen) then sNew = sNew:sub(1, nLen) end
    if(sNew ~= sTxt) then ChangeTooltip(pnSelf) end
    RunConsoleCommand(pnConv, sNew)
  end
  pnText.AllowInput = function(pnSelf, chData)
    return ((pnSelf:GetText():len() >= nLen) and true or false)
  end
  pnText.OnLoseFocus = function(pnSelf)
    pnSelf:SetText(DeSanitizeUID(GetConVar(pnConv):GetString()))
  end
  pnText.OnEnter = function(pnSelf)
    local sTxt = pnSelf:GetText()
    local nEnd = math.floor(tonumber(sTxt) or 0)
    if(nEnd <= 0) then return end
    local sRnd = GetRandomString(math.min(nEnd, nLen))
    pnSelf:SetText(sRnd)
    RunConsoleCommand(pnConv, sRnd)
  end
  pnText:SetUpdateOnType(true)
  pnText:SetEnterAllowed(true)
  pnText:SetEditable(true)
  pnText:SetTooltip(language.GetPhrase(psPref..sName))
  pnName:SetTooltip(language.GetPhrase(psPref.."autofill"))
end

function TOOL.BuildCPanel(panel)
  panel:ClearControls()
  local pnPresets = vgui.Create("ControlPresets", panel)
        pnPresets:SetPreset(gsToolModeOP)
        pnPresets:AddOption("Default", gtConvarList)
        for key, val in pairs(table.GetKeys(gtConvarList)) do
          pnPresets:AddConVar(val) end
  panel:AddItem(pnPresets)
  panel:SetName(language.GetPhrase("tool."..gsToolModeOP..".name"))
  panel:Help(language.GetPhrase("tool."..gsToolModeOP..".desc"))
  panel:Button(language.GetPhrase("tool."..gsToolModeOP..".config_con"), "joyconfig")
    :SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".config"))
  panel:ControlHelp("Joystick configuration should be run after placing a chip. "..
    "In order to change an existing binding, there must be only one chip with its UID left.\nOne UID allows for one input.\n\n"..
    "Multiple devices with the same UID will receive from the same input, but may have different max/min settings.")
  for i = 1, 8 do
    local ID, pItem = tostring(i)
    pItem = panel:Help(language.GetPhrase("tool."..gsToolModeOP..".lcontr_con").." "..ID)
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".lcontr"))
    setupTextEntry(panel, "uid"        , ID, "%s%W", 17)
    setupTextEntry(panel, "description", ID, ""    , 20)
    pItem = panel:CheckBox(language.GetPhrase("tool."..gsToolModeOP..".analog_con"), gsToolPrefix..ID.."analog")
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".analog"))
    pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".minoff_con"), gsToolPrefix..ID.."min", -10, 10, 0)
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".minoff"))
    pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".maxon_con") , gsToolPrefix..ID.."max", -10, 10, 0)
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".maxon"))
  end
end

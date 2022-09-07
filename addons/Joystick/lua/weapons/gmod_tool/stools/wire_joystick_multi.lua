local gsToolModeOP = TOOL.Mode
local gsToolPrefix = gsToolModeOP.."_"
local gsToolLimits = gsToolModeOP:gsub("_multi", "").."s"
local gsSentClasMK = "gmod_"..gsToolModeOP
local gsMappingUID = "abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local gvGhostZero, gaGhostZero = Vector(), Angle()

TOOL.Tab        = "Wire"
TOOL.Category   = "Input, Output"
TOOL.Name       = "Joystick Multi"
TOOL.Command    = nil
TOOL.ConfigName = ""
TOOL.Model      = "models/jaanus/wiretool/wiretool_range.mdl"

if ( CLIENT ) then

  TOOL.Information = {
    { name = "info"   , stage = 1},
    { name = "left"  },
    { name = "right" },
    { name = "reload"}
  }

  language.Add( "tool."..gsToolModeOP..".name"           , "Joystick Multi Tool (Wire)" )
  language.Add( "tool."..gsToolModeOP..".desc"           , "Spawns a Joystick Module interface chip for use with the wire system" )
  language.Add( "tool."..gsToolModeOP..".left"           , "Create / Update joystick" )
  language.Add( "tool."..gsToolModeOP..".right"          , "Copy joystick settings. Hit world to open configuration" )
  language.Add( "tool."..gsToolModeOP..".reload"         , "Link joystick to pod controller" )
  language.Add( "tool."..gsToolModeOP..".1"              , "Now select the pod to link to, or anything other than a pod to revert.")
  language.Add( "tool."..gsToolModeOP..".uid"            , "Unique identifier. No spaces, alphanumeric, 17 character limit!" )
  language.Add( "tool."..gsToolModeOP..".uid_con"        , "Unique ID")
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
  language.Add( "undone_"..gsToolModeOP                  , "Undone Wire Joystick Multi!" )
  language.Add( "sboxlimit_"..gsToolLimits               , "You've hit the Joystick Multi limit!" )
  language.Add( "cleanup_" .. gsToolLimits               , "Wire Joystick Multi chips" )
  language.Add( "cleaned_" .. gsToolLimits               , "Cleaned up all Joystick Multi chips!" )
end

if ( SERVER ) then
  CreateConVar("sbox_max"..gsToolLimits, 20)
end

for i = 1, 8 do
  local strI = tostring(i)
  TOOL.ClientConVar[strI.."uid"]         = ""
  TOOL.ClientConVar[strI.."analog"]      = "0"
  TOOL.ClientConVar[strI.."description"] = ""
  TOOL.ClientConVar[strI.."min"]         = "0"
  TOOL.ClientConVar[strI.."max"]         = "1"
end

local gtConvarList = TOOL:BuildConVarList()

cleanup.Register( gsToolLimits )

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
  local nTop, sOut = gsMappingUID:len(), ""
  for iD = 1, nLen do
    local nRnd = math.random(nTop)
    sOut = sOut..gsMappingUID:sub(nRnd, nRnd)
  end
  return sOut
end

function TOOL:GetControlUID(sIdx, bVal)
  local out = SanitizeUID(self:GetClientInfo(sIdx.."uid"))
  if ( bVal ) then -- Force validation of UID
    local ok, err = jcon.isValidUID(out, gsMappingUID)
    if ( not ok ) then out = nil
      ErrorNoHalt("Wire Joystick: "..tostring(err).."\n")
    end -- Validate the UID when requested
  end
  return out
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
  if ( not (eEnt and eEnt:IsValid()) ) then
    return vNorm, aNorm
  end
  vNorm:Set(stTr.HitNormal)
  vNorm:Mul(-eEnt:OBBMins().z)
  vNorm:Add(stTr.HitPos)
  return vNorm, aNorm
end

function TOOL:CheckOwnUID(sUID, uNtf, bJM)
  local oPly, iStat = self:GetOwner(), 0
  local wins = (jcon and jcon.wireModInstances or nil)

  -- Check if the player owns the UID, or if the UID is free
  if ( jcon and wins and wins[sUID] ) then
    for k, v in pairs( wins[sUID] ) do
      if ( v == oPly ) then
        iStat = 1
      elseif ( bJM and sUID == "jm_" ) then
        -- Maybe some custom override code in later dev..
        -- Allow override, everyone is allowed to use "jm_"
      elseif ( iStat ~= 1 ) then
        iStat = 2
        net.Start(gsToolPrefix.."joywarn", oPly)
          net.WriteUInt(uNtf, 4)
          net.WriteString(sUID)
        net.Send(oPly)
      end
    end
  end

  return iStat
end

function TOOL:LeftClick(tr)
  if ( CLIENT ) then return true end
  if ( not tr.Hit ) then return false end
  if ( not tr.HitPos ) then return false end
  if ( tr.Entity:IsPlayer() ) then return false end

  local oPly  , okUID = self:GetOwner(), true
  local trBone, trEnt = tr.PhysicsBone, tr.Entity

  if ( not oPly:CheckLimit( gsToolLimits ) ) then return false end

  -- Check all UIDs first so we notify the player of all conflicting UIDs, not just one
  for i = 1, 8 do
    local strI = tostring(i)
    local _uid = self:GetControlUID(strI)

    -- Check if the player owns the UID, or if the UID is free
    local iStat = self:CheckOwnUID(_uid, 1)
    if ( iStat == 2 and okUID ) then okUID = false end
  end

  -- Some conflicting UID is not OK then exit
  if ( not okUID ) then return false end

  -- Validate and update
  local pass = {}
  for i = 1, 8 do
    local strI = tostring(i)
    local _uid = self:GetControlUID(strI, true)
    if ( not _uid ) then return false end

    -- Current UID has been validated
    local _type = self:GetControlType(strI)
    local _description = self:GetControlDescr(strI)
    local _min, _max = self:GetControlBorder(strI)

    -- Check if the player owns the UID, or if the UID is free
    local iStat = self:CheckOwnUID(_uid, 2, true)
    if ( stat == 2 ) then return false end

    table.insert(pass, _uid)
    table.insert(pass, _type)
    table.insert(pass, _description)
    table.insert(pass, _min)
    table.insert(pass, _max)
  end

  if ( trEnt:IsValid() and
       trEnt:GetTable() and
       trEnt:GetTable().pl == oPly and
       trEnt:GetClass() == gsSentClasMK) then
       trEnt:Update( unpack(pass) )
      return true -- If we're updating, exit now
  end

  -- Make sure the trace result is not updated
  local vPos, aAng = self:GetNormalSpawn(tr)
  local eJoystick = MakeWireJoystick_Multi(oPly, vPos, aAng, unpack(pass))
  if ( not (eJoystick and eJoystick:IsValid()) ) then return end

  vPos, aAng = self:GetNormalSpawn(tr, eJoystick)
  eJoystick:SetPos(vPos)
  eJoystick:SetAngles(aAng)

  undo.Create("Wire Joystick Multi")
  undo.AddEntity( eJoystick )

  if ( constraint.CanConstrain(trEnt, 0) ) then
    local cWeld = WireLib.Weld(eJoystick, trEnt, trBone, true, true)
    if ( cWeld and cWeld:IsValid() ) then
      eJoystick:DeleteOnRemove( cWeld )
      undo.AddEntity( cWeld )
    end
  end

  undo.SetPlayer( oPly )
  undo.Finish()

  oPly:AddCount  ( gsToolLimits, eJoystick )
  oPly:AddCleanup( gsToolLimits, eJoystick )

  return true
end

function TOOL:RightClick(tr)
  if ( CLIENT ) then return true end
  local oPly, trEnt = self:GetOwner(), tr.Entity
  if ( trEnt:IsValid() ) then
    if ( trEnt:GetTable().pl == oPly and
         trEnt:GetClass() == gsSentClasMK ) then
      local tab = trEnt:GetTable()
      local ord = table.GetKeys(gtConvarList); table.sort(ord)
      for iD = 1, #ord do
        local var = ord[iD]
        local key = var:gsub(gsToolPrefix, "")
        local cpy = tostring(tab[key] or "")
        if ( var:sub(-3, -1) == "uid" ) then
          cpy = DeSanitizeUID(cpy) -- Desanitize only the UID
        end -- Pass the value in quotes to proces the empty vars also
        oPly:ConCommand(var.." \""..cpy.."\"")
      end
      return true
    end
  elseif ( tr.HitWorld ) then
    oPly:ConCommand("joyconfig")
  end
end

function TOOL:Reload(tr)
  if ( CLIENT ) then return true end
  local trEnt = tr.Entity
  if ( self:GetStage() == 0 and
       trEnt:GetClass() == gsSentClasMK ) then
    self.PodCont = trEnt
    self:SetStage(1)
    return true
  elseif ( self:GetStage() == 1 ) then
    local tPod = self.PodCont:GetTable()
    if ( not tPod or tPod.pl ~= self:GetOwner() ) then
      return false
    end
    if ( trEnt.GetPassenger ) then
      self.PodCont:Link(trEnt)
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

function TOOL:UpdateGhost(oEnt, oPly)
  if ( not (oEnt and oEnt:IsValid()) ) then return end

  local tr    = oPly:GetEyeTrace()
  local trEnt = tr.Entity

  if ( not tr.Hit or
       not trEnt  or
           trEnt:IsPlayer() or
           trEnt:GetClass() == gsSentClasMK ) then
    oEnt:SetNoDraw( true ); return
  end

  local vPos, aAng = self:GetNormalSpawn(tr, oEnt)

  oEnt:SetPos( vPos )
  oEnt:SetAngles( aAng )
  oEnt:SetNoDraw( false )
end

function TOOL:Think()
  if ( not self.GhostEntity or
       not self.GhostEntity:IsValid() or
           self.GhostEntity:GetModel() ~= self.Model ) then
    self:MakeGhostEntity( self.Model, gvGhostZero, gaGhostZero )
  end

  self:UpdateGhost( self.GhostEntity, self:GetOwner() )
end

if ( CLIENT and joystick ) then
  surface.CreateFont("Trebuchet36", {size = 36, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet20", {size = 20, weight = 500, antialias = true, additive = false, font = "trebuchet"})
  surface.CreateFont("Trebuchet12", {size = 12, weight = 500, antialias = true, additive = false, font = "trebuchet"})

  local clBlack = Color( 0  , 0  ,   0, 255 )
  local clBlue  = Color( 0  , 0  , 255, 255 )
  local clWhite = Color( 255, 250, 255, 255 )
  local clRed   = Color( 255, 0  , 0  , 255 )
  local clGreen = Color( 0  , 255, 0  , 255 )
  local clInBnd = Color( 255, 165,   0, 255 )
  local clInAct = Color(  32, 178, 170, 255 )

  local function drawToolScreen(oTool, nW, nH)
    local w, h = (tonumber(nW) or 256), (tonumber(nH) or 256)
    local x, y, oPly = (w / 2), 36, LocalPlayer()
    local s = math.floor((h - y) / 8) -- No black line at the tool screen bottom
    surface.SetDrawColor(clBlack)
    surface.DrawRect(0, 0, w, h)
    draw.DrawText("Joystick Multi Tool", "Trebuchet36", 4, 0, clWhite, 0)
    for i = 1, 8 do
      if ( not jcon ) then return end
      local strI = tostring(i)
      local _uid = oTool:GetControlUID(strI)
      local _type = oTool:GetControlType(strI)
      local reg = jcon.getRegisterByUID(_uid)
      if ( reg and reg.IsJoystickReg ) then
        if ( reg:IsBound() ) then
          local val = reg:GetValue()
          if ( type(val) == "number" ) then
            local _min, _max = oTool:GetControlBorder(strI)
            local disp = w * ((val - reg.min) / (reg.max - reg.min))
            local text = (tonumber(val) or 0) / 255 * (_max - _min) + _min
            surface.SetDrawColor(clRed)
            surface.DrawRect(0, y, w, s)
            surface.SetDrawColor(clGreen)
            surface.DrawRect(0, y, disp, s)
            draw.DrawText(math.Round(text), "Trebuchet20", x, y, clBlue, 1)
          elseif ( type(val) == "boolean" ) then
            local _min, _max = oTool:GetControlBorder(strI)
            local text = (val and _max or _min)
            surface.SetDrawColor(clRed)
            surface.DrawRect(0, y, w, s)
            surface.SetDrawColor(clGreen)
            if ( val ) then surface.DrawRect(0, y, w, s) end
            draw.DrawText(text, "Trebuchet20", x, y, clBlue, 1)
          end
          draw.DrawText(reg:GetDeviceName() or "N/A", "Trebuchet12", 4, y + s - 12, clWhite, 0)
        else
          surface.SetDrawColor(clInBnd)
          surface.DrawRect(0, y, w, s)
          draw.DrawText(_uid, "Trebuchet20", x, y, clBlue, 1)
        end
      else
        surface.SetDrawColor(clInAct)
        surface.DrawRect(0, y, w, s)
        draw.DrawText(_uid, "Trebuchet20", x, y, clBlue, 1)
      end
      draw.DrawText(_uid, "Trebuchet12", 4, y, clWhite, 0)
      draw.DrawText(_type, "Trebuchet12", w - 4, y, clWhite, 2)
      y = y + s
    end
  end

  function TOOL:DrawToolScreen(w, h)
    local b, e = pcall(drawToolScreen, self, w, h)
    if ( not b ) then ErrorNoHalt(e,"\n") end
  end
end

local function setupTextEntry(pnBase, sName, sID, sRem, nLen)
  local psPref = "tool."..gsToolModeOP.."."
  local pnConv = gsToolPrefix..sID..sName
  local pnText, pnName = pnBase:TextEntry(language.GetPhrase(psPref..sName.."_con"), pnConv)
  pnText.OnChange = function(pnSelf)
    local sTxt = pnSelf:GetText()
    local sPat, sNew = tostring(sRem or ""), sTxt:Trim()
          sNew = (sPat == "") and sNew or sNew:gsub(sPat, "X")
    if ( sTxt:len() > nLen ) then sNew = sNew:sub(1, nLen) end
    if ( sNew ~= sTxt ) then ChangeTooltip(pnSelf) end
    RunConsoleCommand(pnConv, sNew)
  end
  pnText.AllowInput = function(pnSelf, chData)
    return (pnSelf:GetText():len() > nLen)
  end
  pnText.OnLoseFocus = function(pnSelf)
    pnSelf:SetText(DeSanitizeUID(GetConVar(pnConv):GetString()))
  end
  pnText.OnEnter = function(pnSelf)
    local sTxt = pnSelf:GetText()
    local nEnd = math.floor(tonumber(sTxt) or 0)
    if ( nEnd <= 0 ) then return end
    local sRnd = GetRandomString(math.min(nEnd, nLen))
    pnSelf:SetText(sRnd)
    RunConsoleCommand(pnConv, sRnd)
  end
  pnText:SetUpdateOnType(true)
  pnText:SetEnterAllowed(true)
  pnText:SetEditable(true)
  pnName:SetTooltip(language.GetPhrase(psPref..sName))
  pnText:SetTooltip(language.GetPhrase(psPref.."autofill"))
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
    setupTextEntry(panel, "uid"        , ID, "[%s%W]", 17)
    setupTextEntry(panel, "description", ID,   nil   , 20)
    pItem = panel:CheckBox(language.GetPhrase("tool."..gsToolModeOP..".analog_con"), gsToolPrefix..ID.."analog")
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".analog"))
    pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".minoff_con"), gsToolPrefix..ID.."min", -10, 10, 0)
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".minoff"))
    pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".maxon_con") , gsToolPrefix..ID.."max", -10, 10, 0)
    pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".maxon"))
  end
end

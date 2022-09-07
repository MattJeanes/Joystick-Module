local gsToolModeOP = TOOL.Mode
local gsToolPrefix = gsToolModeOP.."_"
local gsToolLimits = gsToolModeOP:gsub("_multi", "").."s"
local gsSentClasMK = "gmod_"..gsToolModeOP
local gsMappingUID = "abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ_"
local gvGhostZero, gaGhostZero = Vector(), Angle()

TOOL.Tab        = "Wire"
TOOL.Category   = "Input, Output"
TOOL.Name       = "Joystick"
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

  language.Add( "tool."..gsToolModeOP..".name"           , "Joystick Tool (Wire)" )
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
  language.Add( "undone_"..gsToolModeOP                  , "Undone Wire Joystick!" )
  language.Add( "sboxlimit_"..gsToolLimits               , "You've hit the Joystick limit!" )
  language.Add( "cleanup_" .. gsToolLimits               , "Wire Joystick chips" )
  language.Add( "cleaned_" .. gsToolLimits               , "Cleaned up all Joystick chips!" )
end

if (SERVER) then
  CreateConVar("sbox_max"..gsToolLimits, 20)
end

if (SERVER) then
  util.AddNetworkString(gsToolPrefix.."joywarn")
else
  net.Receive(gsToolPrefix.."joywarn", function(nLen)
    local iD, sUID = net.ReadUInt(4), net.ReadString()
    if ( iD == 1 ) then
      GAMEMODE:AddNotify("Wire Joystick: UID in use by another player.", NOTIFY_ERROR, 10)
      surface.PlaySound("buttons/button10.wav")
    elseif ( iD == 2 ) then
      GAMEMODE:AddNotify("Wire Joystick: UID ["..sUID.."] in use by another player.", NOTIFY_ERROR, 10)
      surface.PlaySound("buttons/button10.wav")
    end
  end)
end

TOOL.ClientConVar["uid"]         = ""
TOOL.ClientConVar["analog"]      = "0"
TOOL.ClientConVar["description"] = ""
TOOL.ClientConVar["min"]         = "0"
TOOL.ClientConVar["max"]         = "1"

local gtConvarList = TOOL:BuildConVarList()

cleanup.Register( gsToolLimits )

local function SanitizeUID(uid)
  local prf, uid = "jm_", tostring(uid)
  if ( uid:sub(1,3) ~= prf ) then
    return prf..uid
  end
  return uid
end

local function DeSanitizeUID(uid)
  local prf, uid = "jm_", tostring(uid)
  if ( uid:sub(1,3) == prf ) then
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

function TOOL:GetControlUID(bVal)
  local out = SanitizeUID(self:GetClientInfo("uid"))
  if ( bVal ) then -- Force validation of UID
    local ok, err = jcon.isValidUID(out, gsMappingUID)
    if ( not ok ) then out = nil
      ErrorNoHalt("Wire Joystick: "..tostring(err).."\n")
    end -- Validate the UID when requested
  end
  return out
end

function TOOL:GetControlDescr()
  return self:GetClientInfo("description")
end

function TOOL:GetControlType()
  return ((self:GetClientNumber("analog", 0) ~= 0) and "analog" or "digital")
end

function TOOL:GetControlBorder()
  return self:GetClientNumber("min", 0),
         self:GetClientNumber("max", 0)
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

  local trBone = tr.PhysicsBone
  local oPly, trEnt = self:GetOwner(), tr.Entity
  local _uid = self:GetControlUID(true)

  if ( not _uid ) then return false end

  local _type = self:GetControlType()
  local _description = self:GetControlDescr()
  local _min, _max = self:GetControlBorder()

  if ( not oPly:CheckLimit( gsToolLimits ) ) then return false end

  -- Check if the player owns the UID, or if the UID is free
  local iStat = self:CheckOwnUID(_uid, 1)
  if ( iStat == 2 ) then return false end

  if ( trEnt:IsValid() and
       trEnt:GetTable() and
       trEnt:GetTable().pl == oPly and
       trEnt:GetClass() == gsSentClasMK ) then
       trEnt:Update(_uid, _type, _description, _min, _max)
      return true -- If we're updating, exit now
  end

  -- Make sure the trace result is not updated
  local vPos, aAng = self:GetNormalSpawn(tr)
  local eJoystick = MakeWireJoystick(oPly, vPos, aAng, _uid, _type, _description, _min, _max)
  if not ( eJoystick and eJoystick:IsValid() ) then return end

  vPos, aAng = self:GetNormalSpawn(tr, eJoystick)
  eJoystick:SetPos(vPos)
  eJoystick:SetAngles(aAng)

  undo.Create("Wire Joystick")
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
    if ( not tPod and tPod.pl ~= self:GetOwner() ) then
      return false
    end
    if ( trEnt.GetPassenger ) then
      self.PodCont:Link( trEnt )
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

  local tr = oPly:GetEyeTrace()
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
  surface.CreateFont("Trebuchet50", {size = 50, weight = 500, antialias = true, font = "trebuchet"})
  surface.CreateFont("Trebuchet36", {size = 36, weight = 500, antialias = true, font = "trebuchet"})
  surface.CreateFont("Trebuchet22", {size = 22, weight = 500, antialias = true, font = "trebuchet"})

  local clWhite = Color( 255, 250, 255, 255 )
  local clBlack = Color(   0,   0,   0, 255 )
  local clBlue  = Color(   0,   0, 255, 255 )
  local clCyan  = Color(   0, 255, 255, 255 )
  local clMagen = Color( 255,   0, 255, 255 )
  local clRed   = Color( 255,   0,   0, 255 )
  local clYello = Color( 255, 255,   0, 255 )
  local clGreen = Color(   0, 255,   0, 255 )
  local clInBnd = Color( 255, 165,   0, 255 )
  local clInAct = Color(  32, 178, 170, 255 )

  local function drawToolScreen(oTool, nW, nH)
    local w, h = (tonumber(nW) or 256), (tonumber(nH) or 256)
    local oPly, y, m, s = LocalPlayer(), 0, (0.618 * h - 16), 75
    local drwX, devY, txtY = (w / 2), (h - 32), (m + s / 10)
    surface.SetDrawColor(clBlack)
    surface.DrawRect(0, 0, w, h)
    draw.DrawText("Joystick Tool", "Trebuchet36", 4, 0, clWhite, TEXT_ALIGN_LEFT); y = y + 36
    local _uid = oTool:GetControlUID()
    local _type = oTool:GetControlType()
    local _desc = oTool:GetControlDescr()
    local _min, _max = oTool:GetControlBorder()
    draw.DrawText("UID: ".._uid,"Trebuchet24", 0, y, clGreen, TEXT_ALIGN_LEFT); y = y + 24
    draw.DrawText("Desc: ".._desc,"Trebuchet24", 0, y, clMagen, TEXT_ALIGN_LEFT); y = y + 24
    draw.DrawText("Type: ".._type,"Trebuchet24", 0, y, clCyan, TEXT_ALIGN_LEFT); y = y + 24
    draw.DrawText("Min: ".._min,"Trebuchet24", 5, y + 5, clYello, TEXT_ALIGN_LEFT)
    draw.DrawText("Max: ".._max,"Trebuchet24", w - 5, y + 5, clYello, TEXT_ALIGN_RIGHT)
    if ( not jcon ) then return end

    local reg = jcon.getRegisterByUID(_uid)
    if ( reg and reg.IsJoystickReg ) then
      if ( reg:IsBound() ) then
        local val = reg:GetValue()
        if ( type(val) == "number" ) then
          local disp = w*((val - reg.min)/(reg.max - reg.min))
          local text = ((tonumber(val) or 0) / 255 * (_max -_min) + _min)
                text = ("%+.2f"):format(math.Round(text, 2))
          surface.SetDrawColor(clRed)
          surface.DrawRect(0, m, w, s)
          surface.SetDrawColor(clGreen)
          surface.DrawRect(0, m, disp, s)
          draw.DrawText(text,"Trebuchet50",drwX, txtY, clBlue, TEXT_ALIGN_CENTER)
        elseif ( type(val) == "boolean" ) then
          local text = tostring(val and _max or _min)
          surface.SetDrawColor(clRed)
          surface.DrawRect(0, m, w, s)
          surface.SetDrawColor(clGreen)
          if ( val ) then surface.DrawRect(0, m, w, s) end
          draw.DrawText(text, "Trebuchet50", drwX, txtY, clBlue, TEXT_ALIGN_CENTER)
        end
        draw.DrawText(reg:GetDeviceName() or "N/A", "Trebuchet22", w, devY, clYello, TEXT_ALIGN_RIGHT)
      else
        surface.SetDrawColor(clInBnd)
        surface.DrawRect(0, m, w, s)
        draw.DrawText(_uid, "Trebuchet50", drwX, txtY, clBlue, TEXT_ALIGN_CENTER)
        draw.DrawText("N/A", "Trebuchet22", w, devY, clYello, TEXT_ALIGN_RIGHT)
      end
    else
      surface.SetDrawColor(clInAct)
      surface.DrawRect(0, m, w, s)
      draw.DrawText(_uid, "Trebuchet50", drwX, txtY, clBlue, TEXT_ALIGN_CENTER)
      draw.DrawText("N/A", "Trebuchet22", w, devY, clYello, TEXT_ALIGN_RIGHT)
    end
  end

  function TOOL:DrawToolScreen(w, h)
    local b, e = pcall(drawToolScreen, self, w, h)
    if ( not b ) then ErrorNoHalt(e, "\n") end
  end
end

local function setupTextEntry(pnBase, sName, sRem, nLen)
  local psPref = "tool."..gsToolModeOP.."."
  local pnConv = gsToolPrefix..sName
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
  pItem = panel:Help(language.GetPhrase("tool."..gsToolModeOP..".lcontr_con"))
  pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".lcontr"))
  setupTextEntry(panel, "uid"        , "[%s%W]", 17)
  setupTextEntry(panel, "description",   nil   , 20)
  pItem = panel:CheckBox(language.GetPhrase("tool."..gsToolModeOP..".analog_con"), gsToolPrefix.."analog")
  pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".analog"))
  pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".minoff_con"), gsToolPrefix.."min", -10, 10, 0)
  pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".minoff"))
  pItem = panel:NumSlider(language.GetPhrase("tool."..gsToolModeOP..".maxon_con") , gsToolPrefix.."max", -10, 10, 0)
  pItem:SetTooltip(language.GetPhrase("tool."..gsToolModeOP..".maxon"))
end

// Joyconfig
// Version 28
// Written by Night-Eagle
local jcon_version = 28

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
<tblReg>:GetValue()
<tblReg>:IsBound()
<tblReg>:GetType()
<tblReg>:GetDescription()
<tblReg>:GetCategory()
<tblReg>:GetDeviceName()
jcon.getRegisterByUID(<strUID>)

*/

// TODO:
// Reset invert on bind removal

--surface.CreateFont("Trebuchet",9,400,true,false,"Trebuchet9")
-- surface.CreateFont("Trebuchet9", {size = 9, weight = 400, antialias = true, additive = false, font = "trebuchet"})


if not joystick then
	return
end

local Tex_Corner8 	= surface.GetTextureID( "gui/corner8" )
local Tex_Inv = surface.GetTextureID("gui/sniper_corner")
local axisn = function(index,axismod)
	return ({"X","Y","Z","RX","RY","RZ","S1","S2"})[index]..({[0] = "-",[1] = "",[2] = "+"})[axismod or 1]
end

do
	if type(jcon) == "table" and
		type(jcon.reg) == "table" and
		type(jcon.reg.menuclosed) == "function"
	then
		jcon.reg.menuclosed()
		local b,e = pcall(jcon.shutDown)
		if not b then
			ErrorNoHalt("ShutDown Error: "..tostring(e).."\n")
		end
	end
end

jcon = {}
jcon.version = jcon_version

// Current settings globals

// Calibration

function jcon.initCalibration()
	jcon.cal = {}
	for i=0,joystick.count()-1 do
		jcon.cal[i] = {
			axes = {},
		}
		for axis = 0,7 do
			jcon.cal[i].axes[axis] = {
				max = 65535,
				min = 0,
				scale = 1,
				center = 32767,
				dead = 0,
			}
		end
	end
end
jcon.initCalibration()

// Session variables
jcon.cur = 1
jcon.m = {
	x=0,
	y=0,
	c=0,
	f=0,
}
jcon.drag = {
	type = nil,
	device = nil,
	index = nil,
	axismod = nil,
	hatpos = nil,
	threshmin = nil,
	threshmax = nil,
}
jcon.instances = {}

// End

//Input modification / Calibration
//These functions are not range protected to cut process overhead
jcon.getAxis = function(j,n)
	local s = jcon.cal[j].axes[n]
	local o = joystick.axis(j,n) - s.center
	
	//Msg(s.dead..".")
	if math.abs(o) < s.dead then
		return 32767
	end
	return o*s.scale+32767
end

//Macros
jcon.shat = function(n) //"Simple hat", not the past participle of the verb "shit"
	if n > 36000 then
		return -1
	end
	return n/4500
end

--'
/*
jcon.createbind = function(dat)
	/*
	jcon.createbind{
		device = 0,
		type = "axis",
		index = 0,
		axismod = 1,
		hatpos = 0,
	}
	
	axismod = 0 for left half, 1 for all, 2 for right half (Axes only)
	*//*
	//Msg("Attempting to create a bind for a/an ",dat.type,"...\n")
	if
		type(dat.device) == "number" and
		dat.device >= 0 and
		dat.device <= joystick.count()-1 and
		type(dat.type) == "string" and
		({
			axis = true,
			button = true,
			hat = true,
		})[dat.type] and
		type(dat.index) == "number"
	then
		if dat.type == "axis" and
			type(dat.axismod) == "number" and
			dat.axismod >= 0 and
			dat.axismod <= 2
		then
			//Msg("Created bind for axis!\n")
		elseif dat.type == "button" then
			//Msg("Created bind for button!\n")
		elseif dat.type == "hat" then
			//Msg("Created bind for hat!\n")
		end
	end
end
*/
--'
include("autorun/joyserializer.lua")

//GPS - GUI Positioning System

/*
Device menu
	w: 168
	h: 576

Joystick configuration
	w: 512
	h: 512

gimenu
	w: 512
	h: 146


Total dims:
	width: JCON + DEVICE MENU
	512+168=680
	
	height : JCON + GIMENU
	512+146=658
*/
local guipos = function(x,y)
	//Logically organized variables are for whimps
	local cx = (ScrW()-680)/2
	local cy = (ScrH()-658)/2
	
	return cx+x,cy+y
end

//GUI Macros
jcon.button = function( self, name, text, x, y, w, h, action )
	local button = vgui.Create( "DButton", self, name )
	button:SetPos( x + 5, y + 28 )
	button:SetSize( w, h )
	button:SetText( text )
	button.DoClick = action
end

jcon.text = function(self,name,text,dx,dy,w,h)
	local x = dx + 5
	local y = dy + 28
	
	local f = vgui.Create("DTextEntry",self,name)
	f:SetPos(x,y)
	f:SetSize(w,h)
	f:SetText(text)
	
	return f
end

jcon.label = function(self,name,text,dx,dy,w,h)
	local x = dx + 5
	local y = dy + 28
	
	local f = vgui.Create("DLabel",self,name)
	f:SetPos(x,y)
	f:SetSize(w,h)
	f:SetText(text)
	
	return f
end

//Panel
jcon.jconpanel = {
	Init = function(self)
		self:GetParent():GetTable().m = {
			x=0,
			y=0,
		}
		self:GetParent():GetTable().cur = jcon.cur
	end,
	Paint = function(self)
		local curdevice = self:GetParent():GetTable().cur
		if curdevice > joystick.count() then
			self:Remove()
			return
		end
		
		local status = ""
		//When the new version of Garry's Mod comes out, replace CurTime() in joystick.lua with unpredicted...
		joystick.refresh(curdevice-1)
		
		local m = self:GetParent():GetTable().m
		m.debug = nil
		local c = {
			[1] = Color(0,0,0,50),
			[2] = Color(50,100,255,100),
			[3] = Color(255,0,0,100),
			[4] = Color(0,255,0,100),
		}
		local col = c[1]
		local y = 0
		
		local totw = 158//502
		//Current device
		draw.RoundedBox(4,0,y,totw,18,col)
		draw.DrawText(curdevice..": "..joystick.name(curdevice-1),"Trebuchet18",5,y,Color(255,255,255,255),0)
		//draw.DrawText(joystick.guid(curdevice-1),"Trebuchet24",5,y,Color(255,255,255,255),0)
		
		//Status bar
		
		y = y + 23
		//Prev Next
		y = y + 29
		
		//Axes
		if m.y > y and m.y < y+179 and m.x > 24 and m.x < 152 then
			col = c[4]
			//surface.SetDrawColor(c[4].r,c[4].g,c[4].b,c[4].a)
			//surface.DrawRect(24,y,128,179)
			
			local axis = math.Round((m.y-y-6)/23)
			local axismod = 1
			if m.x-24 < 32 then
				axismod = 0
			elseif m.x-24 > 96 then
				axismod = 2
			end
			status = "Axis "
			if axis >= 0 and axis <= 7 then
				if axismod == 1 then
					draw.RoundedBox(8,24-4,y+axis*23-4,128+8,18+8,col)
				elseif axismod == 0 then
					draw.RoundedBox(8,24-4,y+axis*23-4,64+8,18+8,col)
				elseif axismod == 2 then
					draw.RoundedBox(8,24-4+64,y+axis*23-4,64+8,18+8,col)
				end
				
				if m.c == 1 then
					jcon.drag = {
						type = "axis",
						device = curdevice-1,
						index = axis,
						axismod = axismod,
						hatpos = nil,
					}
					m.c = 0
				end
			end
			m.debug = axis
			status = status..axisn(axis+1,axismod)
		end
		
		surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
		surface.DrawRect(87,y,2,179)
		surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a*.5)
		surface.DrawRect(55,y,2,179)
		surface.DrawRect(119,y,2,179)
		surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
		for axis = 0,7 do
			draw.DrawText(axisn(axis+1),"Trebuchet18",12,y+axis*23,Color(255,255,255,255),1)
			//draw.DrawText(joySerialize(math.Clamp(math.Round((jcon.getAxis(curdevice-1,axis)+256)/512/2),0,64)),"Trebuchet18",24+64,y+axis*23,Color(255,255,255,255),1)
			surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
			surface.DrawRect(24,y+axis*23,128,18)
			surface.SetDrawColor(c[3].r,c[3].g,c[3].b,c[3].a)
			surface.DrawRect(24,y+axis*23,(jcon.getAxis(curdevice-1,axis)+256)/512,18)
		end
		
		y = y + 184
		
		//Buttons
		
		if m.y > y and m.y < y+198 and m.x > 12 and m.x < 153 then
			col = c[4]
			local sel = {}
			sel.x = math.Round((m.x-24)/29)
			sel.y = math.Round((m.y-y-16)/29)
			local button = sel.y*5+sel.x
			if button >= 0 and button <= 31 then
				draw.RoundedBox(8,8+sel.x*29,y+sel.y*29-4,24+8,24+8,col)
				status = "Button "..button+1
				
				if m.c == 1 then
					jcon.drag = {
						type = "button",
						device = curdevice-1,
						index = button,
						axismod = nil,
						hatpos = nil,
					}
					m.c = 0
				end
			end
		end
		
		surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
		col = c[1]
		local bn = 0
		for by = 0,6 do
			for bx = 0,4 do
				if bn <= 31 then
					if joystick.button(curdevice-1,bn) > 0 then
						col = c[3]
					end
					
					draw.RoundedBox(8,12+bx*29,y+by*29,24,24,col)
					draw.DrawText(bn+1,"Trebuchet18",12+bx*29+12,y+by*29+4,Color(255,255,255,255),1)
					
					bn = bn+1
					col = c[1]
				end
			end
		end
		
		y = y + 203
		
		//Hats
		
		//Hat 0
		if m.y > y and m.y < y+72 and m.x > 2 and m.x < 74 then
			col = c[4]
			//surface.SetDrawColor(c[4].r,c[4].g,c[4].b,c[4].a)
			//surface.DrawRect(2,y,72,72)
			
			local sel = {}
			sel.x = math.Round((m.x-14)/24)
			sel.y = math.Round((m.y-y-12)/24)
			local pos = sel.y*3+sel.x
			
			local mapt = {
				[1] = 0,
				[3] = 6,
				[4] = -1,
				[5] = 2,
				[7] = 4,
			}
			local maptn = {
				[1] = "Up",
				[3] = "Left",
				[4] = "Center",
				[5] = "Right",
				[7] = "Down",
			}
			
			if mapt[pos] then
				draw.RoundedBox(8,2+sel.x*24-4,y+sel.y*24-4,24+8,24+8,col)
				m.debug = mapt[pos]
				status = "Hat 1 "..maptn[pos]
				
				if m.c == 1 then
					jcon.drag = {
						type = "hat",
						device = curdevice-1,
						index = 0,
						axismod = nil,
						hatpos = mapt[pos],
					}
					m.c = 0
				end
			end
		end
		
		do
			col = c[1]
			
			local shat = jcon.shat(joystick.pov(curdevice-1,0))
			local y = y
			local tex = Tex_Corner8
			surface.SetTexture( tex )
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			
			//Center
			if shat == -1 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(26,y+24,24,24)
			draw.DrawText(1,"Trebuchet18",38,y+27,Color(255,255,255,255),1)
			col = c[1]
			
			//Right
			if shat >= 1 and shat <= 3 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(50,y+24,16,24)
			surface.DrawRect(66,y+32,8,8)
			surface.DrawTexturedRectRotated(70,y+28,8,8,270)
			surface.DrawTexturedRectRotated(70,y+44,8,8,180)
			col = c[1]
			
			//Up
			if ({[7]=true,[0]=true,[1]=true})[shat] then //I bet you didn't expect that.
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(34,y,8,8)
			surface.DrawRect(26,y+8,24,16)
			surface.DrawTexturedRectRotated(30,y+4,8,8,0)
			surface.DrawTexturedRectRotated(46,y+4,8,8,270)
			col = c[1]
			
			//Left
			if shat >= 5 and shat <= 7 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(10,y+24,16,24)
			surface.DrawRect(2,y+32,8,8)
			surface.DrawTexturedRectRotated(6,y+28,8,8,0)
			surface.DrawTexturedRectRotated(6,y+44,8,8,90)
			col = c[1]
			
			//Down
			if shat >= 3 and shat <= 5 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(34,y+64,8,8)
			surface.DrawRect(26,y+48,24,16)
			surface.DrawTexturedRectRotated(46,y+68,8,8,180)
			surface.DrawTexturedRectRotated(30,y+68,8,8,90)
			col = c[1]
		end
		
		//Hat 1
		if m.y > y and m.y < y+72 and m.x > 79 and m.x < 151 then
			col = c[4]
			//surface.SetDrawColor(c[4].r,c[4].g,c[4].b,c[4].a)
			//surface.DrawRect(79,y,72,72)
			
			local sel = {}
			sel.x = math.Round((m.x-79-12)/24)
			sel.y = math.Round((m.y-y-12)/24)
			local pos = sel.y*3+sel.x
			
			local mapt = {
				[1] = 0,
				[3] = 6,
				[4] = -1,
				[5] = 2,
				[7] = 4,
			}
			local maptn = {
				[1] = "Up",
				[3] = "Left",
				[4] = "Center",
				[5] = "Right",
				[7] = "Down",
			}
			
			if mapt[pos] then
				draw.RoundedBox(8,79+sel.x*24-4,y+sel.y*24-4,24+8,24+8,col)
				m.debug = mapt[pos]
				status = "Hat 2 "..maptn[pos]
				
				if m.c == 1 then
					jcon.drag = {
						type = "hat",
						device = curdevice-1,
						index = 1,
						axismod = nil,
						hatpos = mapt[pos],
					}
					m.c = 0
				end
			end
		end
		
		do
			col = c[1]
			
			local shat = jcon.shat(joystick.pov(curdevice-1,1))
			local y = y
			local tex = Tex_Corner8
			surface.SetTexture( tex )
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			
			//Center
			if shat == -1 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(103,y+24,24,24)
			draw.DrawText(2,"Trebuchet18",115,y+27,Color(255,255,255,255),1)
			col = c[1]
			
			//Right
			if shat >= 1 and shat <= 3 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(127,y+24,16,24)
			surface.DrawRect(143,y+32,8,8)
			surface.DrawTexturedRectRotated(147,y+28,8,8,270)
			surface.DrawTexturedRectRotated(147,y+44,8,8,180)
			col = c[1]
			
			//Up
			if ({[7]=true,[0]=true,[1]=true})[shat] then //I bet you didn't expect that.
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(111,y,8,8)
			surface.DrawRect(103,y+8,24,16)
			surface.DrawTexturedRectRotated(107,y+4,8,8,0)
			surface.DrawTexturedRectRotated(123,y+4,8,8,270)
			col = c[1]
			
			//Left
			if shat >= 5 and shat <= 7 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(87,y+24,16,24)
			surface.DrawRect(79,y+32,8,8)
			surface.DrawTexturedRectRotated(83,y+28,8,8,0)
			surface.DrawTexturedRectRotated(83,y+44,8,8,90)
			col = c[1]
			
			//Down
			if shat >= 3 and shat <= 5 then
				col = c[3]
			end
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			surface.DrawRect(111,y+64,8,8)
			surface.DrawRect(103,y+48,24,16)
			surface.DrawTexturedRectRotated(123,y+68,8,8,180)
			surface.DrawTexturedRectRotated(107,y+68,8,8,90)
		end
		
		//DEBUG CURSOR
		if false then
			surface.SetDrawColor(0,0,0,100)
			surface.DrawRect(m.x,m.y,16,8)
			surface.SetFont("Trebuchet18")
			draw.RoundedBox(4,m.x+16,m.y,surface.GetTextSize(tostring(m.debug))+16,24,Color(0,0,0,100))
			draw.DrawText(tostring(m.debug),"Trebuchet18",m.x+16+8,m.y+4,Color(255,255,255,255),0)
		end
		
		local y = self:GetTall()-24
		//Status bar
		draw.RoundedBox(4,0,y,totw,24,col)
		draw.DrawText(status or "","Trebuchet24",5,y,Color(255,255,255,255),0)
		
		//Ensure value
		self:GetParent():GetTable().cur = curdevice
	end,
	OnCursorMoved = function(self,x,y)
		self:GetParent():GetTable().m.x = x
		self:GetParent():GetTable().m.y = y
	end,
	OnCursorExited = function(self)
		self:GetParent():GetTable().m.x = 0
		self:GetParent():GetTable().m.y = 0
		self:GetParent():GetTable().m.c = 0
		self:GetParent():GetTable().m.f = 0
	end,
	OnMousePressed = function(self,mc)
		self:GetParent():GetTable().m.c = 1
		self:GetParent():GetTable().m.f = 0
	end,
	OnMouseReleased = function(self,mc)
		self:GetParent():GetTable().m.c = -1
	end,
}

vgui.Register("jconpanel",jcon.jconpanel)

jcon.menu = function()
	if joystick.count() <= 0 then
		Msg("No joysticks detected.\n")
		return
	end
	local menu = {}
	local szw = 168
	local szh = 576
	local cx,cy
	if ScrH() < 576+146 then
		cx,cy = guipos(0,82)
	else
		cx,cy = guipos(0,146)
	end
	
	menu.main = jcon.genwhitegui("Device Menu")
		menu.main:SetName("menu.main")
		//menu.main:SetPos(math.max(0,ScrW()*.5-szw),ScrH()*.5-256)
		
		
		menu.main.cur = 1
		//Create additional menus to the left of existing ones + increase joystick ID
		for k,v in pairs(jcon.instances or {}) do
			if v.type == "devicemenu" and v:IsVisible() and v:GetPos()-(szw*2-1) <= cx and v:GetPos() > cx-szw then
				//cx = cx-szw
				cx = math.min(cx,v:GetPos()-szw)
				menu.main.cur = menu.main.cur + 1
			end
		end
		menu.main.cur = math.Clamp(1,menu.main.cur,joystick.count())
		
		menu.main:SetPos(cx,cy)
		menu.main:SetSize(szw,szh)
		menu.main:SetVisible(true)
		/*function menu.main:ActionSignal(key,value)
			jcon.buttonActionSignal(menu.main,key)
		end*/
		menu.main.type = "devicemenu"
	menu.panel = vgui.Create("jconpanel",menu.main,"jconpanel")
		menu.panel:SetPos(5,28)
		menu.panel:SetSize(szw-10,szh-33)
		menu.panel:SetVisible(true)
		menu.panel:SetMouseInputEnabled(true)
	local y = 0
	//jcon.cur
	y = y + 29
	jcon.button(menu.main,"Prev","<",0,23,24,24,function(self)
		self:GetParent():GetTable().cur = math.max(1,self:GetParent():GetTable().cur-1)
	end)
	jcon.button(menu.main,"Next",">",29,23,24,24,function(self)
		self:GetParent():GetTable().cur = math.min(joystick.count(),self:GetParent():GetTable().cur+1)
	end)
	jcon.button(menu.main,"Calibrate","Calibrate Axes...",58,23,94,24,function(self)
		jcon.calimenu(self:GetParent():GetTable().cur)
	end)
	y = y + 29
	
	table.insert(jcon.instances,menu.main)
end



//
// Axis Calibration
//

jcon.cali = {}

jcon.calimenu = function(curdevice)
	local cali = {}
	local cur
	cur = jcon.genwhitegui("Axis Calibration")
		cur:SetName("jconcalimain")
		cur:SetPos(ScrW()*.5-256,ScrH()*.5-256)
		cur:SetSize(512,512)
		cur:SetVisible(true)
		/*function cur:ActionSignal(key,value)
			jcon.buttonActionSignal(self,key)
		end*/
	cali.main = cur
	table.insert(jcon.instances,cur)
	
	//Globals
	cali.main:GetTable().joy = curdevice
	cali.main:GetTable().m = {
			x=0,
			y=0,
			c=0,
			f=0,
		}
	cali.main:GetTable().cur = curdevice
	cali.main:GetTable().autocal = {}
	cali.main:GetTable().texMax = {}
	cali.main:GetTable().texMin = {}
	cali.main:GetTable().texCen = {}
	cali.main:GetTable().texSca = {}
	cali.main:GetTable().texDead = {}
	
	//Panel
	cur = vgui.Create("jconcali",cali.main,"jconcali")
		cur:SetPos(5,28)
		cur:SetSize(512-10,512-33)
		cur:SetVisible(true)
		cur:SetMouseInputEnabled(true)
	cali.panel = cur
	
	local y = 0
	y = y + 29
	//Space
	jcon.button(cali.main,"Calibrate","Auto-Calibrate",5,y,147,24,function(self)
		local dat = self:GetParent():GetTable()
		//Start auto-calibrate for all axes
		for i = 0,7 do
			local p = joystick.axis(dat.cur-1,i)
			jcon.cal[dat.cur-1].axes[i] = {
				max = p,
				min = p,
				scale = 0,
				center = p,
				dead = 0,
			}
			dat.autocal[i] = true
			dat.texMax[i]:SetText(p)
			dat.texMin[i]:SetText(p)
			dat.texCen[i]:SetText(p)
			dat.texSca[i]:SetText(0)
		end
	end)
	
	y = y + 29
	//Axes
	local dat = cali.main:GetTable()
	for axis = 0,7 do
		jcon.button(cali.main,"auto"..axis,"Auto",24,y+axis*46+23,64,18,function(self)
			local dat = self:GetParent():GetTable()
			//Start auto-calibrate for single axis
			local p = joystick.axis(dat.cur-1,axis)
			jcon.cal[dat.cur-1].axes[axis] = {
				max = p,
				min = p,
				scale = 0,
				center = p,
				dead = 0,
			}
			dat.autocal[axis] = true
			dat.texMax[axis]:SetText(p)
			dat.texMin[axis]:SetText(p)
			dat.texCen[axis]:SetText(p)
			dat.texSca[axis]:SetText(0)
		end)
		
		jcon.button(cali.main,"reset"..axis,"Reset",88,y+axis*46+23,64,18,function(self)
			local dat = self:GetParent():GetTable()
			//Reset to default
			//local p = joystick.axis(dat.cur-1,axis)
			jcon.cal[dat.cur-1].axes[axis] = {
				max = 65535,
				min = 0,
				scale = 1,
				center = 32767,
				dead = 0,
			}
			dat.autocal[axis] = false
			dat.texMax[axis]:SetText(65535)
			dat.texMin[axis]:SetText(0)
			dat.texCen[axis]:SetText(32767)
			dat.texSca[axis]:SetText(1)
			dat.texDead[axis]:SetText(0)
		end)
		
		local curset = jcon.cal[dat.cur-1].axes[axis]
		jcon.label(cali.main,"maxL"..axis,"Max:",512-40-44-5-24-5,y+axis*46,24,18)
		cali.main:GetTable().texMax[axis] = jcon.text(cali.main,"max"..axis,curset.max,512-40-44-5,y+axis*46,44,18)
		jcon.label(cali.main,"minL"..axis,"Min:",512-40-44-5-24-5-44-5-24,y+axis*46,24,18)
		cali.main:GetTable().texMin[axis] = jcon.text(cali.main,"min"..axis,curset.min,512-40-44-5-24-5-44-5,y+axis*46,44,18)
		jcon.button(cali.main,"setBound"..axis,"Set",512-40,y+axis*46,28,18,function(self)
			local axis = tonumber(string.sub(self:GetName(),9))
			
			if not axis or axis < 0 or axis > 7 then
				return
			end
			
			local dat = self:GetParent():GetTable()
			
			local curset = jcon.cal[dat.cur-1].axes[axis]
			local max = tonumber(dat.texMax[axis]:GetValue())
			local min = tonumber(dat.texMin[axis]:GetValue())
			
			if max and min then
				curset.max = max
				curset.min = min
				if max-min == 0 then
					curset.scale = 0
				else
					curset.scale = math.Round((max-min-1)/65536*100)/100
				end
				curset.center = math.Round((max+min-1)*.5) //-1
				
				dat.texCen[axis]:SetText(curset.center)
				dat.texSca[axis]:SetText(curset.scale)
			else
				dat.texMax[axis]:SetText(curset.max)
				dat.texMin[axis]:SetText(curset.min)
			end
		end)
		
		jcon.label(cali.main,"cenL"..axis,"Cen:",512-40-44-5-24-5,y+axis*46+23,24,18)
		cali.main:GetTable().texCen[axis] = jcon.text(cali.main,"cen"..axis,curset.center,512-40-44-5,y+axis*46+23,44,18)
		jcon.label(cali.main,"scaL"..axis,"Sca:",512-40-44-5-24-5-44-5-24,y+axis*46+23,24,18)
		cali.main:GetTable().texSca[axis] = jcon.text(cali.main,"sca"..axis,curset.scale,512-40-44-5-24-5-44-5,y+axis*46+23,44,18)
		jcon.button(cali.main,"setCenter"..axis,"Set",512-40,y+axis*46+23,28,18,function(self)
			local axis = tonumber(string.sub(self:GetName(),10))
			
			if not axis or axis < 0 or axis > 7 then
				return
			end
			
			local dat = self:GetParent():GetTable()
			
			local curset = jcon.cal[dat.cur-1].axes[axis]
			local cen = tonumber(dat.texCen[axis]:GetValue())
			local sca = tonumber(dat.texSca[axis]:GetValue())
			
			
			if cen and sca then
				curset.cen = cen
				curset.sca = sca
				
				local ds
				if curset.sca == 0 then
					ds = 1
				else
					ds = curset.sca
				end
				
				curset.min = curset.cen-32768*ds+1
				curset.max = curset.cen+32768*ds
				
				dat.texMax[axis]:SetText(curset.max)
				dat.texMin[axis]:SetText(curset.min)
			else
				dat.texCen[axis]:SetText(curset.center)
				dat.texSca[axis]:SetText(curset.scale)
			end
		end)
		
		jcon.label(cali.main,"deadL"..axis,"Deadzone:",24+64+64+5,y+axis*46+23,50,18)
		cali.main:GetTable().texDead[axis] = jcon.text(cali.main,"dead"..axis,curset.dead,24+64+64+5+50+5,y+axis*46+23,36,18)
		jcon.button(cali.main,"setDeadzone"..axis,"Set",24+64+64+5+50+5+36+5,y+axis*46+23,28,18,function(self)
			local axis = tonumber(string.sub(self:GetName(),12))
			
			if not axis or axis < 0 or axis > 7 then
				return
			end
			
			local dat = self:GetParent():GetTable()
			local curset = jcon.cal[dat.cur-1].axes[axis]
			
			local newdead = tonumber(dat.texDead[axis]:GetValue()) or 0
			curset.dead = newdead
		end)
	end
end

//Panel
jcon.jconcali = {
	Init = function(self)
		local dat = self:GetParent():GetTable()
	end,
	Paint = function(self)
		local dat = self:GetParent():GetTable()
		//When the new version of Garry's Mod comes out, replace CurTime() in joystick.lua with unpredicted...
		joystick.refresh(dat.cur-1)
		
		
		//Auto-Calibrate...
		for i,v in pairs(dat.autocal) do
			local curSet = jcon.cal[dat.cur-1].axes[i]
			local curPos = joystick.axis(dat.cur-1,i)+1
			local oldMin = curSet.min+1
			local oldMax = curSet.max+1
			if curPos > oldMax then
				jcon.cal[dat.cur-1].axes[i].max = curPos-1
				local range = curPos-oldMin-1
				if range > 0 then
					jcon.cal[dat.cur-1].axes[i].scale = 65536/range
				end
				//if calibratecenter then
					jcon.cal[dat.cur-1].axes[i].center = oldMin+range*.5-1
				//end
				
				//Update texts
				dat.texMax[i]:SetText(curPos-1)
				dat.texCen[i]:SetText(jcon.cal[dat.cur-1].axes[i].center)
				dat.texSca[i]:SetText(jcon.cal[dat.cur-1].axes[i].scale)
			elseif curPos < oldMin then
				jcon.cal[dat.cur-1].axes[i].min = curPos-1
				local range = oldMax-curPos-1
				if range > 0 then
					jcon.cal[dat.cur-1].axes[i].scale = 65536/range
				end
				//if calibratecenter then
					jcon.cal[dat.cur-1].axes[i].center = curPos+range*.5-1
				//end
				
				//Update texts
				dat.texMin[i]:SetText(curPos-1)
				dat.texCen[i]:SetText(jcon.cal[dat.cur-1].axes[i].center)
				dat.texSca[i]:SetText(jcon.cal[dat.cur-1].axes[i].scale)
			end
			//draw.DrawText(oldMax-oldMin,"Trebuchet18",160,58+i*23,Color(255,255,255,255),0)
			//draw.DrawText(curSet.scale,"Trebuchet18",160,58+i*23,Color(255,255,255,255),0)
			//draw.DrawText(oldMin,"Trebuchet18",160,58+i*23,Color(255,255,255,255),0)
		end
		//Get on with it!
		
		
		local m = jcon.m
		local c = {
			[1] = Color(0,0,0,50),
			[2] = Color(50,100,255,100),
			[3] = Color(255,0,0,100),
		}
		local col = c[1]
		local y = 0
		
		draw.RoundedBox(4,0,y,502,24,col)
		draw.DrawText(dat.cur..": "..joystick.name(dat.cur-1),"Trebuchet24",5,y,Color(255,255,255,255),0)
		
		y = y + 29
		//Space
		y = y + 29
		//Axes
		
		//surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
		//surface.DrawRect(87,y,2,363)
		for axis = 0,7 do
			if axis%2 == 0 then
				surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
				surface.DrawRect(0,y+axis*46-2.5,512,46)
			end
			
			surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
			surface.DrawRect(24+128-1,y+axis*46,2,18)
			draw.DrawText(axisn(axis+1),"Trebuchet18",12,y+axis*46+12,Color(255,255,255,255),1)
			surface.SetDrawColor(c[1].r,c[1].g,c[1].b,c[1].a)
			surface.DrawRect(24,y+axis*46,256,18)
			surface.SetDrawColor(c[3].r,c[3].g,c[3].b,c[3].a)
			surface.DrawRect(24,y+axis*46,(jcon.getAxis(dat.cur-1,axis)+256)/256,18)
			
			local curSet = jcon.cal[dat.cur-1].axes[axis]
			local curPos = joystick.axis(dat.cur-1,axis)
			//local curPos = jcon.getAxis(dat.cur-1,axis)
			draw.DrawText(curSet.min,"Trebuchet18",24,y+axis*46,Color(255,255,255,255),0)
			draw.DrawText(curPos,"Trebuchet18",24+128,y+axis*46,Color(255,255,255,255),1)
			draw.DrawText(curSet.max,"Trebuchet18",24+256,y+axis*46,Color(255,255,255,255),2)
		end
		
		y = y + 368
		surface.SetDrawColor(0,0,0,100)
		surface.DrawRect(0,y,512,18)
	end,
	OnCursorMoved = function(self,x,y)
		local dat = self:GetParent():GetTable()
		dat.m.x = x
		dat.m.y = y
	end,
	OnCursorExited = function(self)
		local dat = self:GetParent():GetTable()
		dat.m.x = 0
		dat.m.y = 0
		dat.m.c = 0
		dat.m.f = 0
	end,
	OnMousePressed = function(self,mc)
		local dat = self:GetParent():GetTable()
		dat.m.c = 1
		dat.m.f = 0
	end,
	OnMouseReleased = function(self,mc)
		local dat = self:GetParent():GetTable()
		dat.m.c = -1
	end,
}

vgui.Register("jconcali",jcon.jconcali)




























//
// Keyboard enumerations
//

local kbd_face = {
	"ESC","F1","F2","F3","F4","","F5","F6","F7","F8","","F9","F10","F11","F12","PS","SL","BR",
	"~","1","2","3","4","5","6","7","8","9","0","-","=","Back",		"IN","HO","PU",	"NL","/","*","-",
	"Tab","Q","W","E","R","T","Y","U","I","O","P","[","]","\\",		"DE","EN","PD",	"7" ,"8","9","+",
	"Caps","A","S","D","F","G","H","J","K","L",";","'","Enter",		""            ,	"4" ,"5","6","",
	"Shift","Z","X","C","V","B","N","M",",",".","/","Shift",		""  ,"^" ,""  ,	"1" ,"2","3","=",
	"Ctrl","S","Alt","Space","Alt","S","C","Ctrl",				"<" ,"v" ,">" ,	"0"     ,".","",
}
local kbd_size = {
	1.3333,.95,.95,.95,.95,.5-.06665,.95,.95,.95,.95,.5-.06665,1.3,1.3,1.3,1.3,1,1,1,
	1,1,1,1,1,1,1,1,1,1,1,1,1,2,								1,1,1,			1,1,1,1,
	1.3333,1,1,1,1,1,1,1,1,1,1,1,1,1.5+.1667,					1,1,1,			1,1,1,1,
	1.6666,1,1,1,1,1,1,1,1,1,1,1,2.5-.1666,						3    ,			1,1,1,1,
	2,1,1,1,1,1,1,1,1,1,1,3,									1,1,1,			1,1,1,1,
	1.2222,1.25,1.25,6+.3056,1.25,1.25,1.25,1.2222,				1,1,1,			2  ,1,1,
	0,
}
local kbd_line = {
	18,
	14+3+4,
	14+3+4,
	13+1+4,
	12+3+4,
	 8+3+3,
	0,
}
local kbd_key = {
	1,59,60,61,62,nil,63,64,65,66,nil,67,68,87,88,183,70,197,
	41,2,3,4,5,6,7,8,9,10,11,12,13,14,210,199,201,69,181,55,74,
	15,16,17,18,19,20,21,22,23,24,25,26,27,43,211,207,209,71,72,73,78,
	58,30,31,32,33,34,35,36,37,38,39,40,28,nil,75,76,77,nil,
	42,44,45,46,47,48,49,50,51,52,53,54,nil,200,nil,79,80,81,156,
	29,219,56,57,184,220,221,157,203,208,205,82,83,nil,
}
local kbd_key_to_num = {
	[1] = 1,[59] = 2,[60] = 3,[61] = 4,[62] = 5,[63] = 7,[64] = 8,[65] = 9,[66] = 10,[67] = 12,[68] = 13,[87] = 14,[88] = 15,[183] = 16,[70] = 17,[197] = 18,[41] = 19,[2] = 20,[3] = 21,[4] = 22,[5] = 23,[6] = 24,[7] = 25,[8] = 26,[9] = 27,[10] = 28,[11] = 29,[12] = 30,[13] = 31,[14] = 32,[210] = 33,[199] = 34,[201] = 35,[69] = 36,[181] = 37,[55] = 38,[74] = 39,[15] = 40,[16] = 41,[17] = 42,[18] = 43,[19] = 44,[20] = 45,[21] = 46,[22] = 47,[23] = 48,[24] = 49,[25] = 50,[26] = 51,[27] = 52,[43] = 53,[211] = 54,[207] = 55,[209] = 56,[71] = 57,[72] = 58,[73] = 59,[78] = 60,[58] = 61,[30] = 62,[31] = 63,[32] = 64,[33] = 65,[34] = 66,[35] = 67,[36] = 68,[37] = 69,[38] = 70,[39] = 71,[40] = 72,[28] = 73,[75] = 75,[76] = 76,[77] = 77,[42] = 79,[44] = 80,[45] = 81,[46] = 82,[47] = 83,[48] = 84,[49] = 85,[50] = 86,[51] = 87,[52] = 88,[53] = 89,[54] = 90,[200] = 92,[79] = 94,[80] = 95,[81] = 96,[156] = 97,[29] = 98,[219] = 99,[56] = 100,[57] = 101,[184] = 102,[220] = 103,[221] = 104,[157] = 105,[203] = 106,[208] = 107,[205] = 108,[82] = 109,[83] = 110,
}

local kbd_key_to_valve = {
	[1] = 70,
	[59] = 92,
	[60] = 93,
	[61] = 94,
	[62] = 95,
	[63] = 96,
	[64] = 97,
	[65] = 98,
	[66] = 99,
	[67] = 100,
	[68] = 101,
	[87] = 102,
	[88] = 103,
	[183] = 71,
	[70] = 106,
	[197] = 78, --EOL
	[41] = 57,
	[2] = 2,
	[3] = 3,
	[4] = 4,
	[5] = 5,
	[6] = 6,
	[7] = 7,
	[8] = 8,
	[9] = 9,
	[10] = 10,
	[11] = 1,
	[12] = 62,
	[13] = 63,
	[14] = 66,
	[210] = 72,
	[199] = 74,
	[201] = 76,
	[69] = 69,
	[181] = 47,
	[55] = 48,
	[74] = 49, --EOL
	[15] = 67,
	[16] = 27,
	[17] = 33,
	[18] = 15,
	[19] = 28,
	[20] = 30,
	[21] = 35,
	[22] = 31,
	[23] = 19,
	[24] = 25,
	[25] = 26,
	[26] = 53,
	[27] = 54,
	[43] = 61,
	[211] = 73,
	[207] = 75,
	[209] = 77,
	[71] = 44,
	[72] = 45,
	[73] = 46,
	[78] = 50, --EOL
	[58] = 68,
	[30] = 11,
	[31] = 29,
	[32] = 14,
	[33] = 16,
	[34] = 17,
	[35] = 18,
	[36] = 20,
	[37] = 21,
	[38] = 22,
	[39] = 55,
	[40] = 56,
	[28] = 64,
	[75] = 41,
	[76] = 42,
	[77] = 43, --EOL
	[42] = 79,
	[44] = 36,
	[45] = 34,
	[46] = 13,
	[47] = 32,
	[48] = 12,
	[49] = 24,
	[50] = 23,
	[51] = 58,
	[52] = 59,
	[53] = 60,
	[54] = 79, --RSHIFT mapped to 79 instead of 80
	[200] = 88,
	[79] = 38,
	[80] = 39,
	[81] = 40,
	[156] = 64, --EOL
	[29] = 83,
	[219] = 85,
	[56] = 81,
	[57] = 65,
	[184] = 81, --RALT mapped to 81 instead of 82
	[220] = 86,
	[221] = 87,
	[157] = 83, --RCTRL mapped to 83 instead of 84
	[203] = 89,
	[208] = 90,
	[205] = 91,
	[82] = 37,
	[83] = 52,
}

//kbd_face[kbd_key_to_num[jcon.drag.index]]


//
// Global Drawspace
//

jcon.paint = function()
	local m = jcon.m
	m.x, m.y = gui.MousePos()
	
	if jcon.drag.type then
		draw.RoundedBox(4,m.x+12,m.y,64,40,Color(0,0,0,150))
		local disp = jcon.drag.type
		disp = string.upper(string.sub(disp,1,1))..string.sub(disp,2)
		if jcon.drag.type == "axis" then
			local disp = axisn(jcon.drag.index+1,jcon.drag.axismod)
			draw.DrawText(disp,"Trebuchet18",m.x+18,m.y+22,Color(255,255,255,255),0)
		elseif jcon.drag.type == "button" then
			draw.DrawText(jcon.drag.index+1,"Trebuchet18",m.x+18,m.y+22,Color(255,255,255,255),0)
		elseif jcon.drag.type == "key" then
			draw.DrawText(kbd_face[kbd_key_to_num[jcon.drag.index]],"Trebuchet18",m.x+18,m.y+22,Color(255,255,255,255),0)
		elseif jcon.drag.type == "hat" then
			local maptr = {
				[0] = "Up",
				[6] = "Left",
				[-1] = "Center",
				[2] = "Right",
				[4] = "Down",
			}
			disp = disp.." "..jcon.drag.index+1
			draw.DrawText(tostring(maptr[jcon.drag.hatpos]),"Trebuchet18",m.x+18,m.y+22,Color(255,255,255,255),0)
		end
		
		draw.DrawText(disp,"Trebuchet18",m.x+18,m.y+2,Color(255,255,255,255),0)
	end
end

hook.Add("PostRenderVGUI","jcon.paint",jcon.paint)

jcon.mpress = function(mc)
	jcon.m.c = 1
end
jcon.mrel = function(mc)
	jcon.m.c = -1
	jcon.drag = {}
end

hook.Add("GUIMousePressed","jcon.mpress",jcon.mpress)
hook.Add("GUIMouseReleased","jcon.mrel",jcon.mrel)


//
// General Input Menu
//



//Panel
//Use tabulator width 5 or die trying to read this

jcon.jconpanel = {
	Init = function(self)
		self:GetParent():GetTable().m = {
			x=0,
			y=0,
		}
		self:GetParent():GetTable().cur = jcon.cur
	end,
	Paint = function(self)
		local curdevice = self:GetParent():GetTable().cur
		local status = ""
		//When the new version of Garry's Mod comes out, replace CurTime() in joystick.lua with unpredicted...
		joystick.refresh(curdevice-1)
		
		local m = self:GetParent():GetTable().m
		m.debug = nil
		local c = {
			[1] = Color(0,0,0,50),
			[2] = Color(50,100,255,100),
			[3] = Color(255,0,0,100),
			[4] = Color(0,255,0,100),
		}
		local col = c[1]
		local y = 0
		
		//
		// Begin drawing
		//
		
		do
			surface.SetDrawColor(0,0,0,100)
			surface.DrawRect(5,18,270,18*5)
			surface.DrawRect(329,18,72,18*5)
			
			local face_size = 18
			local x = 5
			local y = y
			local i = 0
			local line = 1
			
			local mplaus //mouse plausible
			if m.y >= y and m.y < y+face_size then
				mplaus = true
			end
			
			for k,v in pairs(kbd_face) do
				
				i = i+1
				if i > kbd_line[line] then
					line = line+1
					x = 5
					y = y + face_size
					i = 1
					
					if m.y >= y and m.y < y+face_size then
						mplaus = true
					end
				end
				
				local selected = false
				if mplaus and m.x >= x and m.x < x+kbd_size[k]*face_size then
					selected = true
					mplaus = false
					
					if m.c == 1 and v ~= "" then
						jcon.drag = {
							type = "key",
							device = -1,
							index = kbd_key[k],
							axismod = nil,
							hatpos = nil,
						}
						m.c = 0
					end
				end
				
				if not selected then
					x = x + kbd_size[k]*face_size/2
					draw.DrawText(v,"Trebuchet18",x,y,Color(255,255,255,255),1)
				elseif v ~= "" then
					surface.SetDrawColor(0,255,0,100)
					surface.DrawRect(x,y,kbd_size[k]*face_size,face_size)
					x = x + kbd_size[k]*face_size/2
					draw.DrawText(v,"Trebuchet18",x,y,Color(178,34,34,255),1)
				else
					x = x + kbd_size[k]*face_size/2
				end
				x = x + kbd_size[k]*face_size/2
				
			end
			y = y + face_size
		end
		
		//DEBUG CURSOR
		if false then
			surface.SetDrawColor(0,0,0,100)
			surface.DrawRect(m.x,m.y,16,8)
			surface.SetFont("Trebuchet18")
			draw.RoundedBox(4,m.x+16,m.y,surface.GetTextSize(tostring(m.debug))+16,24,Color(0,0,0,100))
			draw.DrawText(tostring(m.debug),"Trebuchet18",m.x+16+8,m.y+4,Color(255,255,255,255),0)
		end
		
		local y = self:GetTall()-24
		//Status bar
		//draw.RoundedBox(4,0,y,502,24,col)
		//draw.DrawText(status or "","Trebuchet24",5,y,Color(255,255,255,255),0)
		
		//Ensure value
		self:GetParent():GetTable().cur = curdevice
	end,
	OnCursorMoved = function(self,x,y)
		self:GetParent():GetTable().m.x = x
		self:GetParent():GetTable().m.y = y
	end,
	OnCursorExited = function(self)
		self:GetParent():GetTable().m.x = 0
		self:GetParent():GetTable().m.y = 0
		self:GetParent():GetTable().m.c = 0
		self:GetParent():GetTable().m.f = 0
	end,
	OnMousePressed = function(self,mc)
		self:GetParent():GetTable().m.c = 1
		self:GetParent():GetTable().m.f = 0
	end,
	OnMouseReleased = function(self,mc)
		self:GetParent():GetTable().m.c = -1
	end,
}

vgui.Register("jcongipanel",jcon.jconpanel)

jcon.gimenu = function()
	if jcon.gimenuinstance then
		jcon.gimenuinstance:Remove()
	end
	
	local menu = {}
	local cur
	local cx,cy = guipos(168,0)
	cur = jcon.genwhitegui("General Input Menu")
		cur:SetName("jcongimenu")
		//cur:SetPos(ScrW()*.5-256,ScrH()*.5-384-18)
		cur:SetPos(cx,cy)
		cur:SetSize(512,128+18)
		cur:SetVisible(true)
		/*function cur:ActionSignal(key,value)
			jcon.buttonActionSignal(self,key)
		end*/
		cur.type = "gimenu"
	menu.main = cur
	
	cur = vgui.Create("jcongipanel",menu.main,"jcongipanel")
		cur:SetPos(5,28)
		cur:SetSize(512-10,128+18-33)
		cur:SetVisible(true)
		cur:SetMouseInputEnabled(true)
	menu.panel = cur
	
	jcon.gimenuinstance = menu.main
end

//
// Control Registration
//

jcon.reg = {}


//
// Console Command
//

jcon.reg.start = function()
	jcon.menu()
	jcon.reg.menu()
end
concommand.Add("joyconfig",jcon.reg.start)

//
// Menu
//

jcon.reg.menu = function()
	local menu = {}
	local cur
	local szw = 512
	local szh = 512
	local cx,cy = guipos(168,146)
	cur = jcon.genwhitegui("Joystick Configuration")
		cur:SetName("jfigmain")
		//cur:SetPos(ScrW()*.5,ScrH()*.5-256)
		cur:SetPos(cx,cy)
		cur:SetSize(szw,szh)
		cur:SetVisible(true)
		-- cur:MakePopup()
		/*function cur:ActionSignal(key,value)
			jcon.buttonActionSignal(self,key)
		end*/
	menu.main = cur
	
	cur = vgui.Create("jfigmenu",menu.main,"jfigmenu")
		cur:SetPos(5,28)
		cur:SetSize(szw-10,szh-33)
		cur:SetVisible(true)
		cur:SetMouseInputEnabled(true)
	menu.panel = cur
	
	local tx = 0
	jcon.button(menu.main,"openJoystick","Device",tx+5,5,45,18,function(self)
		jcon.menu()
	end)
	tx = tx + 50
	
	jcon.button(menu.main,"reloadJoystick","Scan",tx+5,5,36,18,function(self)
		joystick.restart()
	end)
	tx = tx+41
	
	jcon.button(menu.main,"openKey","Key",tx+5,5,32,18,function(self)
		jcon.gimenu()
	end)
	
	jcon.regmenuinstance = menu.main
end

jcon.reg.menuclosed = function()
	for k,v in pairs(jcon.instances) do
		if type(v) == "Panel" and v:IsVisible() then
			v:Remove()
		end
	end
	jcon.instances = {}
	
	if jcon.regmenuinstance and jcon.regmenuinstance:IsVisible() then
		jcon.regmenuinstance:Remove()
	end
	
	if jcon.gimenuinstance and jcon.gimenuinstance:IsVisible() then
		jcon.gimenuinstance:Remove()
	end
	
	//Send binding update now
	joynet.update()
end

hook.Add("Think","joycloseregmenu",function()
	if type(jcon.regmenuinstance) == "Panel" and not jcon.regmenuinstance:IsVisible() then
		jcon.reg.menuclosed()
		jcon.regmenuinstance = nil
	end
end)

jcon.reg.form  = {
	Init = function(self)
		local dat = self:GetParent():GetTable()
		dat.m = {
			x=0,
			y=0,
		}
		dat.scroll = 1
	end,
	Paint = function(self)
		local dat = self:GetParent():GetTable()
		local m = dat.m
		local status = ""
		
		//If the open category is deleted, unselect it
		if not jcon.reg.cat[dat.tabcat] then
			dat.tabcat = nil
		end
		
		local scrollmax = 1
		if dat.tabcat then
			scrollmax = #jcon.reg.cat[dat.tabcat]
		end
		
		//When the new version of Garry's Mod comes out, replace CurTime() in joystick.lua with unpredicted...
		//joystick.refresh(dat.cur-1)
		
		local cols = {
			Unsel = Color(0,0,0,50),
			Sel = Color(0,255,0,100),
			Press = Color(255,0,0,100),
			Act = Color(0,0,255,100),
		}
		local col = cols.Unsel
		
		//Background for registers
		draw.RoundedBox(4,10+128,2,364,453,Color(0,0,0,100))
		
		//Scrollbars
		draw.RoundedBox(4,10+128+344,2+4,16,453-8,Color(255,255,255,63))
		
		local s = {}
		
		if m.x >= 482 and m.x <= 498 and m.y >= 6 and m.y <= 451 then
			if m.y <= 22 then
				s[1] = true
			elseif m.y >= 435 then
				s[3] = true
			else
				s[2] = true
			end
		end
		if s[1] then
			if m.c == 1 then
				m.c = 0
				m.f = "scrollup"
			elseif m.c == -1 and m.f == "scrollup" then
				m.c = 0
				m.f = 0
				dat.scroll = dat.scroll-1
				if dat.scroll < 1 then
					dat.scroll = 1
				end
			end
			
			if not (m.f == "scrollup") then
				draw.RoundedBox(4,482+2,6+2,12,12,Color(0,255,0,100))
			else
				draw.RoundedBox(4,482+2,6+2,12,12,Color(255,0,0,100))
			end
		else
			draw.RoundedBox(4,482+2,6+2,12,12,Color(0,0,0,100))
		end
		if s[3] then
			if m.c == 1 then
				m.c = 0
				m.f = "scrolldown"
			elseif m.c == -1 and m.f == "scrolldown" then
				m.c = 0
				m.f = 0
				dat.scroll = dat.scroll+1
				if dat.scroll > scrollmax-8 then
					dat.scroll = math.max(1,scrollmax-8)
				end
			end
			
			if not (m.f == "scrolldown") then
				draw.RoundedBox(4,482+2,435+2,12,12,Color(0,255,0,100))
			else
				draw.RoundedBox(4,482+2,435+2,12,12,Color(255,0,0,100))
			end
		else
			draw.RoundedBox(4,482+2,435+2,12,12,Color(0,0,0,100))
		end
		
		do
			local mpos = 22+((dat.scroll-1)/(scrollmax-8))*413
			local mtall = 1/math.max(1,(scrollmax-8))*413
			
			if s[2] then
				if m.c == 1 then
					m.c = 0
					m.f = "scroll"
					
					dat.scroll = math.Clamp(math.floor((m.y-22)*(scrollmax-8)/413)+1,1,math.max(1,scrollmax-8))
					mpos = 22+((dat.scroll-1)/(scrollmax-8))*413
					mtall = 1/math.max(1,(scrollmax-8))*413
				elseif m.c == -1 and m.f == "scroll" then
					m.c = 0
					m.f = 0
				end
				
				if m.f ~= "scroll" then
					draw.RoundedBox(4,484,mpos,12,mtall,Color(0,255,0,100))
				else
					dat.scroll = math.Clamp(math.floor((m.y-22)*(scrollmax-8)/413)+1,1,math.max(1,scrollmax-8))
					mpos = 22+((dat.scroll-1)/(scrollmax-8))*413
					mtall = 1/math.max(1,(scrollmax-8))*413
					draw.RoundedBox(4,484,mpos,12,mtall,Color(255,0,0,100))
				end
			else
				draw.RoundedBox(4,484,mpos,12,mtall,Color(0,0,0,100))
			end
		end
		
		//Macros
		local transBind = function(reg)
			//After dragging, this binds an input to a device
			local bind = reg.bind
			if not bind.type then
				bind.type = jcon.drag.type
				bind.device = jcon.drag.device
				bind.index = jcon.drag.index
				bind.axismod = jcon.drag.axismod
				bind.hatpos = jcon.drag.hatpos
				
				if reg.type == "digital" and bind.type == "axis" then
					//Increased by 1 to prevent errors from truncating of values (And to get over the neutral hump)
					bind.threshmin = jcon.drag.threshmin or ({[true] = 32767, [false] = 49151})[bind.axismod ~= 1]
					bind.threshmax = jcon.drag.threshmax or 65535
				end
			elseif reg.type == "analog" and
				(
					bind.type == "button" or
					bind.type == "hat" or
					bind.type == "key"
				) and (
					jcon.drag.type == "button" or
					jcon.drag.type == "hat" or
					jcon.drag.type == "key"
				) then
				//Dualbool double registration
				
				reg.bind1 = {
					type = bind.type,
					device = bind.device,
					index = bind.index,
					axismod = bind.axismod,
					hatpos = bind.hatpos,
				}
				reg.bind2 = {
					type = jcon.drag.type,
					device = jcon.drag.device,
					index = jcon.drag.index,
					axismod = jcon.drag.axismod,
					hatpos = jcon.drag.hatpos,
				}
				
				bind.type = "dualbool"
				bind.device = bind.device or "DualBool"
				bind.index = nil
				bind.axismod = nil
				bind.hatpos = nil
			elseif not jcon.drag.type then
				//Clear the registry/Unbind
				bind.type = jcon.drag.type
				bind.device = jcon.drag.device
				bind.index = jcon.drag.index
				bind.axismod = jcon.drag.axismod
				bind.hatpos = jcon.drag.hatpos
			end
			
			jcon.drag = {}
		end
		
		//Y Pos
		local y = 5
		y = y+18+5
		
		//Category listing
		
		local cats = 0
		for k,v in pairs(jcon.reg.cat) do
			cats = cats + 1
		end
		
		local sel = math.Round((m.y-y+10)/20)
		local press = -1
		if m.x >= 5 and m.x <= 138 and sel >= 1 and sel <= cats then
			sel = sel-1
			if m.c == 1 then
				m.f = "tab"..sel
				m.c = 0
			elseif m.c == -1 and m.f == "tab"..sel then
				m.c = 0
				m.f = 0
				dat.tab = sel
				dat.scroll = 1
			elseif m.c == 0 and m.f == "tab"..sel then
				press = sel
			end
		else
			sel = -1
		end
		
		surface.SetTexture(Tex_Corner8)
		local i = 0
		for k,v in pairs(jcon.reg.cat) do
			if dat.tab ~= i then
				if i ~= sel and i ~= press then
					col = cols.Unsel
				elseif i == press then
					col = cols.Press
				else
					col = cols.Sel
				end
				
				surface.SetDrawColor(col.r,col.g,col.b,col.a)
				surface.DrawRect(13,y+20*i,128-3,20)
				surface.DrawRect(5,y+20*i+8,8,4)
				surface.DrawTexturedRectRotated(9,y+20*i+4,8,8,0)
				surface.DrawTexturedRectRotated(9,y+20*i+16,8,8,90)
			else
				dat.tabcat = k
			end
			
			draw.DrawText(k,"Trebuchet18",10,y+20*i+2,Color(255,255,255,255),0)
			i = i+1
		end
		if tonumber(dat.tab) and dat.tab >= 0 and dat.tab <= cats-1 then
			local k = dat.tabcat
			local v = jcon.reg.cat[k]
			i = dat.tab
			
			col = cols.Unsel
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			do
				surface.DrawRect(13,y+20*i,128-3,20)
				surface.DrawRect(5,y+20*i+8,8,4)
				surface.DrawTexturedRectRotated(9,y+20*i+4,8,8,0)
				surface.DrawTexturedRectRotated(9,y+20*i+16,8,8,90)
			end
			col = cols.Act
			surface.SetDrawColor(col.r,col.g,col.b,col.a)
			do
				surface.DrawRect(13,y+20*i,128-3,20)
				surface.DrawRect(5,y+20*i+8,8,4)
				surface.DrawTexturedRectRotated(9,y+20*i+4,8,8,0)
				surface.DrawTexturedRectRotated(9,y+20*i+16,8,8,90)
			end
			surface.SetTexture(Tex_Inv)
			surface.DrawTexturedRectRotated(130,y+20*i-8,16,16,180)
			surface.DrawTexturedRectRotated(130,y+20*i+20+8,16,16,270)
			surface.SetTexture(Tex_Corner8)
			
			draw.DrawText(k,"Trebuchet18",10,y+20*i+2,Color(255,255,255,255),0)
			
			--"
			--" Draw the registration forms
			--"
			
			local sel = -1
			if m.x >= 143 and m.x <= 497-21 and m.y >= 7 and m.y <= 450 then
				sel = math.floor((m.y-7+2.5)/50)
			end
			
			//for n,reg in pairs(v) do
			local n = -1
			for nn = dat.scroll,math.min(dat.scroll+8,#v) do
				reg = v[nn]
				n = n+1
				local col = Color(0,0,0,100)
				local hover = {}
				if sel == n then
					local runReg = true
					if reg.type == "analog" and
						m.x >= 138+10+128+5 and
						m.x <= 138+10+128+5+18 and
						m.y >= 50*n+2+10+18 and
						m.y <= 50*n+2+10+18+18
					then
						hover.Invert = true
						runReg = false
					elseif reg.type == "digital" then
						if reg.bind.type == "axis" and
							m.x >= 333-13 and
							m.x <= 333-13+18 and
							m.y >= 50*n+2+10+18 and
							m.y <= 50*n+2+10+18+18
						then
							hover.Invert = true
							runReg = false
						end
						if reg.bind.type == "axis" and
							m.x >= 333+10 and
							m.x <= 333+10+128 and
							m.y >= 50*n+2+10+18 and
							m.y <= 50*n+2+10+18+18
						then
							hover.Thresh = true
							runReg = false
						end
						
					end
					if runReg then
						if m.c == 1 then
							m.f = "reger"..n
							m.c = 0
						elseif m.c == -1 and m.f == "reger"..n then
							m.f = 0
							m.c = 0
							if jcon.drag then
								transBind(reg)
							end
						elseif m.c == -1 and jcon.drag.type then
							transBind(reg)
						end
						
						if m.f == "reger"..n then
							col = cols.Press
						else
							col = cols.Sel
						end
					end
				end
				draw.RoundedBox(4,138+5,2+5+50*n,333,45,col)
				draw.DrawText(reg.description,"Trebuchet18",138+12,50*n+2+5+4,Color(255,255,255,255),0)
				if tonumber(reg.bind.device) and reg.bind.device >= -1 and reg.bind.device <= joystick.count()-1 then
					draw.DrawText(joystick.name(reg.bind.device),"Trebuchet18",138+12+333-13,50*n+2+5+4,Color(255,255,255,255),2)
				end
				
				if reg.type == "analog" then
					surface.SetDrawColor(255,255,255,63)
					surface.DrawRect(138+10,50*n+2+10+18,128,18)
					surface.SetDrawColor(0,0,0,100)
					surface.DrawRect(138+10+63,50*n+2+10+18,2,18)
					surface.SetDrawColor(0,0,0,50)
					surface.DrawRect(138+10+31,50*n+2+10+18,2,18)
					surface.DrawRect(138+10+95,50*n+2+10+18,2,18)
					
					surface.SetDrawColor(0,255,0,150)
					surface.DrawRect(138+10,50*n+2+10+18,reg:getraw()/512,18)
					
					draw.RoundedBox(4,138+10+128+5,50*n+2+10+18,18,18,Color(255,255,255,63))
					if hover.Invert then
						if m.c == 1 then
							if not jcon.drag.type then
								m.c = 0
								m.f = "invert"..n
							else
								m.c = 0
								m.f = 0
								transBind(reg)
							end
						elseif m.c == -1 and m.f == "invert"..n then
							m.c = 0
							m.f = 0
							
							reg.bind.invert = not reg.bind.invert
						elseif m.c == -1 and jcon.drag.type then
							m.c = 0
							m.f = 0
							transBind(reg)
						end
						
						if m.f ~= "invert"..n then
							draw.RoundedBox(4,138+10+128+5,50*n+2+10+18,18,18,Color(0,255,0,150))
						else
							draw.RoundedBox(4,138+10+128+5,50*n+2+10+18,18,18,Color(255,0,0,150))
						end
					end
					
					if reg.bind.invert then
						draw.DrawText("X","Trebuchet18",138+10+128+14,50*n+2+10+19,Color(255,255,255,255),1)
					end
					if reg.bind.type == "axis" then
						draw.DrawText(axisn(reg.bind.index+1,reg.bind.axismod),"Trebuchet18",333+10+128,50*n+2+10+19,Color(255,255,255,255),2)
					elseif tonumber(reg.bind.index) then
						if reg.bind.type == "button" then
							draw.DrawText("Button "..reg.bind.index+1,"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						elseif reg.bind.type == "hat" then
							local maptr = {
								[0] = "Up",
								[6] = "Left",
								[-1] = "Center",
								[2] = "Right",
								[4] = "Down",
							}
							draw.DrawText("Hat "..reg.bind.index+1 .." "..maptr[reg.bind.hatpos],"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						elseif reg.bind.type == "key" then
							draw.DrawText("Key "..tostring(kbd_face[tonumber(kbd_key_to_num[tonumber(reg.bind.index) or -1]) or -1]),"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						end
					elseif reg.bind.type == "dualbool" then
						local tName = ""
						if reg.bind1.type == "button" then
							tName = "Button "..reg.bind1.index+1
						elseif reg.bind1.type == "hat" then
							local maptr = {
								[0] = "Up",
								[6] = "Left",
								[-1] = "Center",
								[2] = "Right",
								[4] = "Down",
							}
							tName = "Hat "..reg.bind1.index+1 .." "..maptr[reg.bind1.hatpos]
						elseif reg.bind1.type == "key" then
							tName = "Key "..tostring(kbd_face[tonumber(kbd_key_to_num[tonumber(reg.bind1.index) or -1]) or -1])
						end
						-- draw.DrawText(tName,"Trebuchet9",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						draw.DrawText(tName,"DermaDefault",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						
						tName = ""
						if reg.bind2.type == "button" then
							tName = "Button "..reg.bind2.index+1
						elseif reg.bind2.type == "hat" then
							local maptr = {
								[0] = "Up",
								[6] = "Left",
								[-1] = "Center",
								[2] = "Right",
								[4] = "Down",
							}
							tName = "Hat "..reg.bind2.index+1 .." "..maptr[reg.bind2.hatpos]
						elseif reg.bind2.type == "key" then
							tName = "Key "..tostring(kbd_face[tonumber(kbd_key_to_num[tonumber(reg.bind2.index) or -1]) or -1])
						end
						-- draw.DrawText(tName,"Trebuchet9",333+137,50*n+2+10+19+9,Color(255,255,255,255),2)
						draw.DrawText(tName,"DermaDefault",333+137,50*n+2+10+19+9,Color(255,255,255,255),2)
					end
				elseif reg.type == "digital" then
					local col
					draw.RoundedBox(8,138+10,50*n+2+10+18,18,18,Color(255,255,255,63))
					if reg:GetValue() then
						draw.RoundedBox(8,138+10,50*n+2+10+18,18,18,Color(0,255,0,150))
					end
					
					if reg.bind.type == "axis" then
						surface.SetDrawColor(255,255,255,63)
						surface.DrawRect(333+10,50*n+2+10+18,128,18)
						surface.SetDrawColor(0,0,0,100)
						surface.DrawRect(333+10+63,50*n+2+10+18,2,18)
						surface.SetDrawColor(0,0,0,50)
						surface.DrawRect(333+10+31,50*n+2+10+18,2,18)
						surface.DrawRect(333+10+95,50*n+2+10+18,2,18)
						
						surface.SetDrawColor(255,0,0,150)
						surface.DrawRect(333+10,50*n+2+10+18,reg:getanalog()/512,18)
						
						local t = {}
						t.i = (tonumber(reg.bind.threshmin)/512) or 128
						t.a = ((tonumber(reg.bind.threshmax)/512) or 128) - t.i
						surface.SetDrawColor(0,0,255,150)
						if hover.Thresh then
							if m.c == 1 then
								if not jcon.drag.type then
									m.c = 0
									m.f = "thresh"..n
								else
									m.c = 0
									m.f = 0
									transBind(reg)
								end
							elseif m.c == -1 and m.f == "thresh"..n then
								m.c = 0
								m.f = 0
							elseif m.c == -1 and jcon.drag.type then
								m.c = 0
								m.f = 0
								transBind(reg)
							end
							
							if m.f ~= "thresh"..n then
								surface.SetDrawColor(0,255,0,150)
							else
								surface.SetDrawColor(255,255,0,150)
								
								reg.bind.threshmin = math.Clamp(math.Round((m.x-343)/8)*8*512,0,65535)
								
								t.i = (tonumber(reg.bind.threshmin)/512) or 128
								t.a = ((tonumber(reg.bind.threshmax)/512) or 128) - t.i
							end
						end
						surface.DrawRect(343+t.i,50*n+30,t.a,9)
						
						draw.RoundedBox(4,333-13,50*n+2+10+18,18,18,Color(255,255,255,63))
						if hover.Invert then
							if m.c == 1 then
								if not jcon.drag.type then
									m.c = 0
									m.f = "invert"..n
								else
									m.c = 0
									m.f = 0
									transBind(reg)
								end
							elseif m.c == -1 and m.f == "invert"..n then
								m.c = 0
								m.f = 0
								
								reg.bind.invert = not reg.bind.invert
							elseif m.c == -1 and jcon.drag.type then
								m.c = 0
								m.f = 0
								transBind(reg)
							end
							
							if m.f ~= "invert"..n then
								draw.RoundedBox(4,333-13,50*n+2+10+18,18,18,Color(0,255,0,150))
							else
								draw.RoundedBox(4,333-13,50*n+2+10+18,18,18,Color(255,0,0,150))
							end
						end
						
						if reg.bind.invert then
							draw.DrawText("X","Trebuchet18",333-13+9,50*n+2+10+19,Color(255,255,255,255),1)
						end
						
						draw.DrawText(axisn(reg.bind.index+1,reg.bind.axismod),"Trebuchet18",333+10+64,50*n+2+10+19,Color(255,255,255,255),1)
					elseif tonumber(reg.bind.index) then
						if reg.bind.type == "button" then
							draw.DrawText("Button "..reg.bind.index+1,"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						elseif reg.bind.type == "hat" then
							local maptr = {
								[0] = "Up",
								[6] = "Left",
								[-1] = "Center",
								[2] = "Right",
								[4] = "Down",
							}
							draw.DrawText("Hat "..reg.bind.index+1 .." "..maptr[reg.bind.hatpos],"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						elseif reg.bind.type == "key" then
							draw.DrawText("Key "..tostring(kbd_face[tonumber(kbd_key_to_num[tonumber(reg.bind.index) or -1]) or -1]),"Trebuchet18",333+137,50*n+2+10+19,Color(255,255,255,255),2)
						end
					end
				end
			end
		end
		
		local col = Color(0,0,0,100)
		y = self:GetTall()-24
		draw.RoundedBox(4,0,y,502,24,col)
		draw.DrawText(status or "","Trebuchet24",5,y,Color(255,255,255,255),0)
		
		if m.c == -1 then
			m.c = 0
		end
	end,
	OnCursorMoved = function(self,x,y)
		local dat = self:GetParent():GetTable()
		dat.m.x = x
		dat.m.y = y
	end,
	OnCursorExited = function(self)
		local dat = self:GetParent():GetTable()
		dat.m.x = 0
		dat.m.y = 0
		dat.m.c = 0
		dat.m.f = 0
	end,
	OnMousePressed = function(self,mc)
		local dat = self:GetParent():GetTable()
		dat.m.c = 1
		dat.m.f = 0
	end,
	OnMouseReleased = function(self,mc)
		local dat = self:GetParent():GetTable()
		dat.m.c = -1
	end,
	OnMouseWheeled = function(self,delta)
		local dat = self:GetParent():GetTable()
		
		local scrollmax = 1
		if dat.tabcat then
			scrollmax = #jcon.reg.cat[dat.tabcat]
		end
		
		dat.scroll = math.Clamp(dat.scroll - delta,1,math.max(1,scrollmax-8))
	end,
}
vgui.Register("jfigmenu",jcon.reg.form)

//
// Functions
//

jcon.reg.cat = {}
jcon.reg.uid = {}
//jcon.reg.uid is an alternative index for jcon.reg.cat
//the two must be kept in sync by accessors, i.e., it is assumed that the two are always correct

jcon.getRegisterByUID = function(uid)
	if jcon.reg.uid[uid] then
		return jcon.reg.uid[uid]
	end
end

jcon.removeRegisterByUID = function(uid)
	if jcon.reg.uid[uid] then
		local reg = jcon.reg.uid[uid]
		local tab = jcon.reg.cat[reg.category]
		local num
		for k,v in pairs(tab) do
			if v.uid == reg.uid then
				num = k
			end
		end
		
		if not num then
			return
		end
		
		table.remove(tab,k)
		jcon.reg.uid[uid] = nil
		
		return reg
	end
end


local stackReg = {}
local stackUnReg = {}
local lastChangeNotify = CurTime()
hook.Add("Think","joystickProcessStack",function()
	if not joystick.postnetstart then
		return
	end
	//Execute pending registration/unregistration commands
	//This way, registering always follows unregistering
	
	local delta = 0
	
	for i = 1,#stackUnReg do
		local v = table.remove(stackUnReg,1)
		jcon.unregister(v)
		//Msg("Joystick: Binding ",v," unregistered.\n")
		delta = delta + 1
	end
	
	for i = 1,#stackReg do
		local v = table.remove(stackReg,1)
		jcon.register(v)
		//Msg("Joystick: Binding ",v.uid," registered.\n")
		delta = delta + 1
		
		jcon.checkConfigCache(v.uid)
	end
	
	if delta > 0 then
		if lastChangeNotify < CurTime() - 5 then
			GAMEMODE:AddNotify("Joystick bindings have changed!",NOTIFY_GENERIC,3)
			surface.PlaySound("ambient/water/drip"..math.random(1,4)..".wav")
			lastChangeNotify = CurTime()
		end
	end
end)

usermessage.Hook("ja",function(bf)
	local reg = {}
	reg.uid = bf:ReadString()
	reg.type = bf:ReadBool() and "analog" or "digital"
	reg.description = bf:ReadString()
	reg.category = bf:ReadString()
	if reg.type then
		reg.max = bf:ReadFloat()
		reg.min = bf:ReadFloat()
	else
		bf:ReadFloat()
		bf:ReadFloat()
	end
	
	table.insert(stackUnReg,reg.uid)
	table.insert(stackReg,reg)
	//jcon.unregister(reg.uid)
	//jcon.register(reg)
end)

usermessage.Hook("joystickimpulse",function(bf)
	local action = bf:ReadString()
	if action == "REMOVE" then
		local uid = bf:ReadString()
		table.insert(stackUnReg,uid)
		//jcon.unregister(uid)
	end
end)

jcon.shutDown = function()
	if not joystick then
		return
	end
	
	jcon.Save()
end
hook.Add("ShutDown","joystick",jcon.shutDown)

jcon.RestartDown = function()
	jcon.Save()
	
	for k,v in pairs(jcon.reg.uid) do
		v.bind = {}
	end
end
hook.Add("JoystickRestartDown","joystick",jcon.RestartDown)

jcon.RestartUp = function()
	jcon.initCalibration()
	jcon.Load()
end
hook.Add("JoystickRestartUp","joystick",jcon.RestartUp)

jcon.Save = function()
	local out = "GUID Guide"
	for i = 1,joystick.NumJoysticks() do
		out = out.."\n\t"..tostring(joystick.guid(i-1)).." = "..joystick.name(i-1)
	end
	
	out = out.."\nBinding List (Lower entries override higher entries)"
	
	/*
			entry.GUID1 = tostring(joystick.guid(reg.bind1.device))
			entry.type1 = reg.bind1.type
			entry.index1 = reg.bind1.index
			entry.hatpos1 = reg.bind1.hatpos
			
			entry.GUID2 = tostring(joystick.guid(reg.bind2.device))
			entry.type2 = reg.bind2.type
			entry.index2 = reg.bind2.index
			entry.hatpos2 = reg.bind2.hatpos
	*/
	
	//Get from names
	out = out.."\n[GUID START]"
	for k,v in pairs(jcon.names) do
		out = out.."\n\t"..tostring(k).."="..tostring(v)
	end
	out = out.."\n[GUID END]"
	
	//Get from configCache
	out = out.."\n[START]"
	for uid,v in pairs(jcon.configCache) do
		for TYPE,v in pairs(v) do
			out = out.."\n"..uid
			
			out = out.."\n\tGUID="..v.GUID
			out = out.."\n\tTYPE="..TYPE
			
			//String
			for i,o in pairs{"type","GUID1","GUID2","type1","type2"} do
				local val = v[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=str:"..tostring(val)
				end
			end
			
			//Number
			for i,o in pairs{"index","hatpos","axismod","threshmin","threshmax","index1","index2","hatpos1","hatpos2"} do
				local val = v[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=num:"..tostring(val)
				end
			end
			
			//Boolean
			for i,o in pairs{"invert"} do
				local val = v[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=boo:"..tostring(val)
				end
			end
		end
	end
	
	//Get from active binds
	for k,v in pairs(jcon.reg.uid) do
		if v:IsBound() then
			out = out.."\n"..k
			
			out = out.."\n\tGUID="..tostring(joystick.guid(v.bind.device))
			out = out.."\n\tTYPE="..tostring(v:GetType())
			
			//String
			for i,o in pairs{"type"} do
				local val = v.bind[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=str:"..tostring(val)
				end
			end
			
			//Number
			for i,o in pairs{"index","hatpos","axismod","threshmin","threshmax"} do
				local val = v.bind[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=num:"..tostring(val)
				end
			end
			
			//Boolean
			for i,o in pairs{"invert"} do
				local val = v.bind[o]
				if val ~= nil then
					out = out.."\n\t"..o.."=boo:"..tostring(val)
				end
			end
			
			//dualbool
			if v.bind.type == "dualbool" then
				for c = 1,2 do
					out = out.."\n\tGUID"..c.."=str:"..joystick.guid(v["bind"..c].device)
					
					//String
					for i,o in pairs{"type","GUID"} do
						local val = v["bind"..c][o]
						if val ~= nil then
							out = out.."\n\t"..o..c.."=str:"..tostring(val)
						end
					end
					
					//Number
					for i,o in pairs{"index","hatpos"} do
						local val = v["bind"..c][o]
						if val ~= nil then
							out = out.."\n\t"..o..c.."=num:"..tostring(val)
						end
					end
					
					//Boolean
					for i,o in pairs{"invert"} do
						local val = v["bind"..c][o]
						if val ~= nil then
							out = out.."\n\t"..o..c.."=boo:"..tostring(val)
						end
					end
				end
			end
		end
	end
	
	out = out.."\n[END]\n"
	
	file.Write("joyconfig.txt",out)
end

//Holds both loaded and unsaved binds for rebinding by UID
jcon.configCache = {}

jcon.getGUIDMAP = function()
	local guidmap = {}
	guidmap["{0-0-0-0:0:0:0:0:0:0:-1}"] = -1
	for i = 1,joystick.NumJoysticks() do
		guidmap[tostring(joystick.guid(i-1))] = i-1
	end
	return guidmap
end

jcon.names = {}
jcon.Load = function()
	if file.Exists("joyconfig.txt", "DATA") then
		//Generate a GUID table for current devices
		local guidmap = jcon.getGUIDMAP()
		
		//Generate default names for joysticks
		for i = 1,joystick.NumJoysticks() do
			jcon.names[tostring(joystick.guid(i-1))] = joystick.name(i-1)
		end
		
		//Process raw data
		local din = file.Read("joyconfig.txt")
		dincopy = din
		
		local iS = din:find("[GUID START]",nil,true)
		local iF = din:find("[GUID END]",iS,true)
		if iS and iF and iS+12 < iF then
			din = din:sub(iS+12,iF-1) or ""
			din = string.Explode("\n",din)
			
			for k,v in pairs(din) do
				if v:len() > 0 and v:sub(1,1) == "\t" then
					local v = v:sub(2)
					local sep = v:find("=",nil,true)
					if sep then
						local guid = v:sub(1,sep-1)
						local name = v:sub(sep+1)
						
						if guid:sub(1,1) == "{" and guid:sub(-1) == "}" then //Very simple validity check, GUIDs and controller names aren't transmitted to server anyway
							local enum = guidmap[guid]
							if enum then
								joystick.names[enum] = name
							end
							
							jcon.names[guid] = name
						end
					end
				end
			end
		end
		
		din = dincopy
		local iS = din:find("[START]",nil,true)
		local iF = din:find("[END]",iS,true)
		
		if iS and iF and iS+7 < iF then
			din = din:sub(iS+7,iF-1) or ""
			din = string.Explode("\n",din)
			
			local dat = {}
			local cur = nil
			for k,v in pairs(din) do
				if v:len() > 0 then
					if v:sub(1,1) == "\t" then
						if cur and v:len() > 7 then //Why 7? "%=typ:%" minimum number of characters
							local v = v:sub(2)
							local sep = v:find("=",nil,true)
							
							if sep then
								local key = v:sub(1,sep-1)
								local v = v:sub(sep+1)
								
								if key == "GUID" or key == "TYPE" then
									dat[cur][key] = v
								else
									local type = v:sub(1,3)
									v = v:sub(5)
									
									if type == "str" then
										dat[cur][key] = v
									elseif type == "num" then
										dat[cur][key] = tonumber(v) or 0
									elseif type == "boo" then
										dat[cur][key] = v == "true" and true or false
									end
								end
							end
						end
					else
						cur = tostring(v)
						dat[cur] = {}
					end
				end
			end
			
			//Sanitize data
			for uid,regdat in pairs(dat) do
				if not (
					type(regdat.GUID) == "string" and
					(
						regdat.TYPE == "analog" or
						regdat.TYPE == "digital"
					)
				) then
					Msg("Warning: ",uid," entry not sanitary.")
					//TODO: Sanitize data. Not that it is sent to the server...
				end
			end
			
			//Interpret data
			for uid,regdat in pairs(dat) do
				local reg = jcon.reg.uid[uid]
				local device = guidmap[regdat.GUID]
				if device and reg and regdat.TYPE == reg:GetType() then
					//Map it directly
					
					reg.bind = {}
					local bind = reg.bind
					
					bind.type = regdat.type
					bind.device = device
					bind.index = regdat.index
					bind.axismod = regdat.axismod
					bind.hatpos = regdat.hatpos
					bind.invert = regdat.invert
					if regdat.TYPE == "digital" and regdat.type == "axis" then
						//axis to digital bind, needs thresholds
						bind.threshmin = regdat.threshmin or 49151
						bind.threshmax = regdat.threshmax or 65535
					elseif regdat.TYPE == "analog" and regdat.type == "dualbool" then
						reg.bind1 = {}
						reg.bind1.device = guidmap[regdat.GUID1]
						reg.bind1.type = regdat.type1
						reg.bind1.index = regdat.index1
						reg.bind1.hatpos = regdat.hatpos1
						
						reg.bind2 = {}
						reg.bind2.device = guidmap[regdat.GUID2]
						reg.bind2.type = regdat.type2
						reg.bind2.index = regdat.index2
						reg.bind2.hatpos = regdat.hatpos2
						
						if not (reg.bind1.device and reg.bind2.device) then
							//Devices not available
							reg.bind = nil
							reg.bind1 = nil
							reg.bind2 = nil
						end
					end
					
					//Msg("Bind for ",uid," recovered.\n")
					/*
					bind.type = "dualbool"
					bind.device = bind.device or "DualBool"
					bind.index = nil
					bind.axismod = nil
					bind.hatpos = nil
					*/
				end
				
				//Store in jcon.configCache for joystick module reloads and old binding reinitialization, watch out for digital/analog type overlap
				jcon.configCache[uid] = jcon.configCache[uid] or {}
				jcon.configCache[uid][regdat.TYPE] = {}
				local entry = jcon.configCache[uid][regdat.TYPE]
				entry.GUID = regdat.GUID
				entry.TYPE = regdat.TYPE
				entry.type = regdat.type
				entry.index = regdat.index
				entry.axismod = regdat.axismod
				entry.hatpos = regdat.hatpos
				entry.invert = regdat.invert
				
				if regdat.TYPE == "digital" and regdat.type == "axis" then
					//axis to digital bind, needs thresholds
					entry.threshmin = regdat.threshmin or 49151
					entry.threshmax = regdat.threshmax or 65535
				elseif regdat.TYPE == "analog" and regdat.type == "dualbool" then
					entry.GUID1 = regdat.GUID1
					entry.type1 = regdat.type1
					entry.index1 = regdat.index1
					entry.hatpos1 = regdat.hatpos1
					
					entry.GUID2 = regdat.GUID2
					entry.type2 = regdat.type2
					entry.index2 = regdat.index2
					entry.hatpos2 = regdat.hatpos2
				end
			end
		end
		
	else
		
	end
end

jcon.checkConfigCache = function(uid)
	//Msg("Config cache checked!\n")
	local guidmap = jcon.getGUIDMAP()
	
	local reg = jcon.reg.uid[uid]
	
	if reg then
		//Msg("1...")
		if jcon.configCache[uid] then
			//Msg("2...")
			local regdat = jcon.configCache[uid][reg:GetType()]
			
			if regdat and reg.type == regdat.TYPE then //Check if regdat is meant for digital or analog and whether it matches the uid's digital or analog setting
				//Msg("3...")
				local device = guidmap[regdat.GUID]
				
				if device then
					//Msg("4...")
					//Map it directly
					
					reg.bind = {}
					local bind = reg.bind
					
					bind.type = regdat.type
					bind.device = device
					bind.index = regdat.index
					bind.axismod = regdat.axismod
					bind.hatpos = regdat.hatpos
					bind.invert = regdat.invert
					if regdat.TYPE == "digital" and regdat.type == "axis" then
						//axis to digital bind, needs thresholds
						//Msg("Restoring thresholds\n")
						bind.threshmin = regdat.threshmin or 49151
						bind.threshmax = regdat.threshmax or 65535
					elseif regdat.TYPE == "analog" and regdat.type == "dualbool" then
						//Msg("5...")
						//two booleans to analog bind
						reg.bind1 = {}
						reg.bind1.device = guidmap[regdat.GUID1]
						if not reg.bind1.device then
							reg.bind = nil
							reg.bind1 = nil
							reg.bind2 = nil
							return
						end
						reg.bind2 = {}
						reg.bind2.device = guidmap[regdat.GUID2]
						if not reg.bind1.device then
							reg.bind = nil
							reg.bind1 = nil
							reg.bind2 = nil
							return
						end
						
						reg.bind1.type = regdat.type1
						reg.bind2.type = regdat.type2
						reg.bind1.index = regdat.index1
						reg.bind2.index = regdat.index2
						reg.bind1.hatpos = regdat.hatpos1
						reg.bind2.hatpos = regdat.hatpos2
					end
					
					//Msg("Bind for ",uid," recovered.\n")
					/*
					bind.type = "dualbool"
					bind.device = bind.device or "DualBool"
					bind.index = nil
					bind.axismod = nil
					bind.hatpos = nil
					*/
					
					//Update the header
					joynet.update()
				end
			end
		end
	end
end

jcon.unregister = function(uid)
	local reg = jcon.reg.uid[uid]
	if not reg then
		return false
	end
	local entry
	for k,v in pairs(jcon.reg.cat[reg.category]) do
		if v.uid == uid then
			entry = k
		end
	end
	
	if not entry then
		Error("JCON category/UID index mismatch.")
		return
	end
	table.remove(jcon.reg.cat[reg.category],entry)
	if #jcon.reg.cat[reg.category] == 0 then
		jcon.reg.cat[reg.category] = nil
	end
	jcon.reg.uid[uid] = nil
	
	//Check to see if we mapped that bind - if so, recalculate data map to conserve bandwidth
	//Do so after at least 1 second of delay, just in case the server remaps that same UID
	//Do so after 30 seconds of waiting, as it is very likely that someone is doing some joystick-related work and an update will take place anyway
	//timer.Simple(30,function()
	//end)
	//Don't do this, because the stack/queue takes care of it now
	if joynet and not jcon.reg.uid[uid] then
		if joynet.mappedUIDs[uid] then
			joynet.update()
		end
	end
	
	//Add the registry to the jcon.configCache
	if reg:IsBound() and reg.bind then
		jcon.configCache[uid] = jcon.configCache[uid] or {}
		jcon.configCache[uid][reg:GetType()] = {}
		local entry = jcon.configCache[uid][reg:GetType()]
		entry.GUID = tostring(joystick.guid(reg.bind.device))
		entry.type = reg.bind.type
		entry.invert = reg.bind.invert
		entry.TYPE = reg:GetType()
		
		if entry.type ~= "dualbool" then
			entry.index = reg.bind.index
			entry.axismod = reg.bind.axismod
			entry.hatpos = reg.bind.hatpos
		else
			entry.GUID1 = tostring(joystick.guid(reg.bind1.device))
			entry.type1 = reg.bind1.type
			entry.index1 = reg.bind1.index
			entry.hatpos1 = reg.bind1.hatpos
			
			entry.GUID2 = tostring(joystick.guid(reg.bind2.device))
			entry.type2 = reg.bind2.type
			entry.index2 = reg.bind2.index
			entry.hatpos2 = reg.bind2.hatpos
		end
	end
end

jcon.register = function(dat)
	if
		(dat.type == "analog" or
		dat.type == "digital") and
		type(dat.description) == "string" and
		type(dat.category) == "string" and
		jcon.isValidUID(dat.uid)
	then
		do
			//Checks to see if this bind already exists by UID
			if jcon.reg.uid[dat.uid] then
				return jcon.reg.uid[dat.uid]
			end
		end
		
		if not jcon.reg.cat[dat.category] then
			jcon.reg.cat[dat.category] = {}
		else
			/*
			//Checks to see if this bind already exists by category and description
			for k,v in pairs(jcon.reg.cat[dat.category]) do
				if v.description == dat.description then
					return v
				end
			end
			*/
		end
		jcon.reg.cat[dat.category][#jcon.reg.cat[dat.category]+1] = {}
		local catreg = jcon.reg.cat[dat.category][#jcon.reg.cat[dat.category]]
		
		catreg.type = dat.type
		catreg.uid = dat.uid
		catreg.category = dat.category
		catreg.description = dat.description
		if dat.type == "analog" then
			catreg.min = dat.min or 0
			catreg.max = dat.max or 255
			catreg.value = 0
			catreg.bind = {}
			catreg.getdigital = function(self)
				if self.bind.type == "button" then
					return joystick.button(self.bind.device,self.bind.index) > 0
				elseif self.bind.type == "hat" then
					local n = jcon.shat(joystick.pov(self.bind.device,self.bind.index))
					if n == 0 and self.bind.hatpos == -1 then
						return false
					end
					if n == self.bind.hatpos or n == self.bind.hatpos+1 or ((n == self.bind.hatpos-1 and self.bind.hatpos > 0) or (self.bind.hatpos == 0 and n == 7)) then
						return true
					end
					return false
				elseif self.bind.type == "key" then
					return input.IsKeyDown(kbd_key_to_valve[self.bind.index])
				elseif self.bind.type == "dualbool" then
					local ret1
					if self.bind1.type == "button" then
						ret1 = joystick.button(self.bind1.device,self.bind1.index) > 0
					elseif self.bind1.type == "hat" then
						
						local n = jcon.shat(joystick.pov(self.bind1.device,self.bind1.index))
						if n == 0 and self.bind1.hatpos == -1 then
							ret1 = false
							n = true
						end
						if type(n) ~= "boolean" and (n == self.bind1.hatpos or n == self.bind1.hatpos+1 or ((n == self.bind1.hatpos-1 and self.bind1.hatpos > 0) or (self.bind1.hatpos == 0 and n == 7))) then
							ret1 = true
						end
						ret1 = nil and false or ret1
					elseif self.bind1.type == "key" then
						ret1 = input.IsKeyDown(kbd_key_to_valve[self.bind1.index])
					end
					
					local ret2
					if self.bind2.type == "button" then
						ret2 = joystick.button(self.bind2.device,self.bind2.index) > 0
					elseif self.bind2.type == "hat" then
						
						local n = jcon.shat(joystick.pov(self.bind2.device,self.bind2.index))
						if n == 0 and self.bind2.hatpos == -1 then
							ret2 = false
							n = true
						end
						if type(n) ~= "boolean" and (n == self.bind2.hatpos or n == self.bind2.hatpos+1 or ((n == self.bind2.hatpos-1 and self.bind2.hatpos > 0) or (self.bind2.hatpos == 0 and n == 7))) then
							ret2 = true
						end
						ret2 = nil and false or ret2
					elseif self.bind2.type == "key" then
						ret2 = input.IsKeyDown(kbd_key_to_valve[self.bind2.index])
					end
					
					return ret1, ret2
				end
			end
			catreg.getraw = function(self)
				if self.bind.type == "axis" then
					local dat = jcon.getAxis(self.bind.device,self.bind.index)
					local ret = self.value
					
					if self.bind.axismod == 1 then
						ret = math.Clamp(dat,0,65535)
					elseif self.bind.axismod == 0 then
						ret = math.Clamp(65535-dat*2,0,65535)
					elseif self.bind.axismod == 2 then
						ret = math.Clamp(dat*2-65535,0,65535)
					else
						return ret
					end
					
					if self.bind.invert then
						ret = 65535-ret
					end
					
					return ret
				elseif self.bind.type ~= "dualbool" then
					local ret = self:getdigital()
					if ret == nil then
						return self.value
					else
						if self.bind.invert then
							ret = not ret
						end
						return ({[true]=65535,[false]=0})[ret]
					end
				else //Dualbool
					local ret = self.value
					
					local a,b = self:getdigital()
					if a == b then
						ret = 32767
					elseif a then
						ret = 0
					else
						ret = 65535
					end
					
					if self.bind.invert then
						ret = 65535-ret
					end
					
					return ret
				end
			end
			catreg.GetValue = function(self)
				joystick.refresh(self.bind.device)
				return (self:getraw()+self.min)*(self.max-self.min)/65535
			end
		elseif dat.type == "digital" then
			catreg.value = false
			catreg.bind = {}
			catreg.getanalog = function(self)
				local dat = jcon.getAxis(self.bind.device,self.bind.index)
				local ret = self.value
				
				if self.bind.axismod == 1 then
					ret = math.Clamp(dat,0,65535)
				elseif self.bind.axismod == 0 then
					ret = math.Clamp(65535-dat*2,0,65535)
				elseif self.bind.axismod == 2 then
					ret = math.Clamp(dat*2-65535,0,65535)
				else
					return ret
				end
				
				if self.bind.invert then
					ret = 65535-ret
				end
				
				return ret
			end
			catreg.GetValue = function(self)
				joystick.refresh(self.bind.device)
				if self.bind.type == "button" then
					return joystick.button(self.bind.device,self.bind.index) > 0
				elseif self.bind.type == "hat" then
					local n = jcon.shat(joystick.pov(self.bind.device,self.bind.index))
					if n == 0 and self.bind.hatpos == -1 then
						return false
					end
					if n == self.bind.hatpos or n == self.bind.hatpos+1 or ((n == self.bind.hatpos-1 and self.bind.hatpos > 0) or (self.bind.hatpos == 0 and n == 7)) then
						return true
					else
						return false
					end
				elseif self.bind.type == "key" then
					return input.IsKeyDown(kbd_key_to_valve[self.bind.index])
				elseif self.bind.type == "axis" then
					local n = self:getanalog()
					if n >= self.bind.threshmin and n <= self.bind.threshmax then
						return true
					end
					return false
				end
			end
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
			return not not ((self.bind and self.bind.type) or (self.bind1 and self.bind1.type))
		end
		catreg.GetDeviceName = function(self)
			local a = (
					(
						self.bind and
						self.bind.device
					) or (
						self.bind1 and
						self.bind1.device
					) or (
						-65535 //Just error the hell out please
					)
				)
			if a >= 0 then
				return joystick.name(a)
			elseif a == -1 then
				return "Keyboard"
			end
		end
		
		jcon.reg.uid[catreg.uid] = catreg
		
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

//DUPLICATED CODE ON SERVERSIDE, WARNING

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

/*
The only things you should use from a joystick register:

reg.IsJoystickReg
reg:GetValue()
reg:GetType()
reg:GetDescription()
reg:GetCategory()
*/

jcon.whitegui = [[
"hud.res"
{
	"whitegui"
	{
		"ControlName"		"Frame"
		"fieldName"		"eInv"
		"xpos"		"475"
		"ypos"		"355"
		"zpos"		"290"
		"wide"		"400"
		"tall"		"66"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
		"settitlebarvisible"		"1"
		"title"		"%TITLE%"
		"sizable"		"1"
	}
	"frame_topGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_topGrip"
		"xpos"		"8"
		"ypos"		"0"
		"wide"		"384"
		"tall"		"5"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_bottomGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_bottomGrip"
		"xpos"		"8"
		"ypos"		"61"
		"wide"		"374"
		"tall"		"5"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_leftGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_leftGrip"
		"xpos"		"0"
		"ypos"		"0"
		"wide"		"5"
		"tall"		"66"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_rightGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_rightGrip"
		"xpos"		"395"
		"ypos"		"0"
		"wide"		"5"
		"tall"		"66"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_tlGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_tlGrip"
		"xpos"		"0"
		"ypos"		"0"
		"wide"		"8"
		"tall"		"8"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_trGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_trGrip"
		"xpos"		"392"
		"ypos"		"0"
		"wide"		"8"
		"tall"		"8"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_blGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_blGrip"
		"xpos"		"0"
		"ypos"		"58"
		"wide"		"8"
		"tall"		"8"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_brGrip"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_brGrip"
		"xpos"		"382"
		"ypos"		"48"
		"wide"		"18"
		"tall"		"18"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"0"
		"enabled"		"1"
		"tabPosition"		"0"
	}
	"frame_caption"
	{
		"ControlName"		"Panel"
		"fieldName"		"frame_caption"
		"xpos"		"0"
		"ypos"		"0"
		"wide"		"390"
		"tall"		"23"
		"autoResize"		"0"
		"pinCorner"		"0"
		"visible"		"1"
		"enabled"		"1"
		"tabPosition"		"0"
	}
}
]]

jcon.genwhitegui = function(caption)
	local frame = vgui.Create("DFrame")
	--frame:LoadControlsFromString(string.gsub(jcon.whitegui,"%%TITLE%%",caption))
	frame:SetTitle( caption )
	frame:MakePopup()
	return frame
end

jcon.Load()
Msg("Night-Eagle's joystick configurator loaded.\nVersion ",jcon.version,".\n")
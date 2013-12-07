
joysticknetstart = function()
	joynet = {}
	local joynet = joynet

	joynet.updateRate = 1/10 //.15
	joynet.updateNext = CurTime()+1
	joynet.updateHeader = nil
	joynet.headerBuffer = nil
	joynet.dataMapA = {}
	joynet.dataMapD = {}
	joynet.mappedUIDs = {}

	joynet.update = function()
		local tabMapperA = {}
		local tabMapperD = {}
		local dataMapA = {}
		local dataMapD = {}
		joynet.mappedUIDs = {}
		
		//Analog from left, digital from right
		
		for k,v in pairs(jcon.reg.uid) do
			if v:IsBound() then
				if v.type == "analog" then
					dataMapA[#dataMapA+1] = v
					tabMapperA[k] = #dataMapA
					joynet.mappedUIDs[v.uid] = true
				elseif v.type == "digital" then
					dataMapD[#dataMapD+1] = v
					tabMapperD[k] = #dataMapD
					joynet.mappedUIDs[v.uid] = true
				end
			end
		end
		
		//Calculate header
		local out = ""
		for k,v in pairs(tabMapperA) do
			out = out.." "..k.." "..v
		end
		for k,v in pairs(tabMapperD) do
			out = out.." "..k.." "..v
		end
		
		//We will send either 0 or 2 or more arguments
		//Msg("HEADER:",out,"\n")
		
		joynet.dataMapA = dataMapA
		joynet.dataMapD = dataMapD
		
		joynet.updateHeader = CurTime() + joynet.updateRate
		joynet.updateNext = nil
		
		if joynet.headerBuffer then
			joynet.headerCancel = true
		end
		joynet.headerBuffer = {}
		local str = out
		for i = 1,100 do
			if str:len() > 0 then
				table.insert(joynet.headerBuffer,str:sub(1,200))
				str = str:sub(201)
			end
		end
	end

	local null = {}
	null.GetValue = function()
		return false
	end

	joynet.buffer = ""
	joynet.tick = function()
		//Msg(joynet.updateNext," ",joynet.updateHeader,"\n")
		if joynet.updateNext and joynet.updateNext < CurTime() then
			local out = ""
			
			for k,v in pairs(joynet.dataMapA) do
				local a = joySerialize(math.Round((v:GetValue()-v.min)*64/(v.max-v.min)))
				out = out..a
			end
			for i=1,#joynet.dataMapD,6 do
				local b = joynet.dataMapD[i]
				local a = joySerialize(
					(joynet.dataMapD[i] or null):GetValue(),
					(joynet.dataMapD[i+1] or null):GetValue(),
					(joynet.dataMapD[i+2] or null):GetValue(),
					(joynet.dataMapD[i+3] or null):GetValue(),
					(joynet.dataMapD[i+4] or null):GetValue(),
					(joynet.dataMapD[i+5] or null):GetValue()
				)
				out = out..tostring(a)
			end
			
			if joynet.buffer ~= out then
				joynet.buffer = out
				//Msg(joynet.buffer," sent\n")
				RunConsoleCommand("ja",unpack(string.Explode(" ",joynet.buffer)))
				joynet.updateNext = CurTime() + joynet.updateRate
			else
				//Don't change update rate
			end
		elseif joynet.updateHeader and joynet.updateHeader < CurTime() then
			if joynet.headerCancel then
				RunConsoleCommand("ja","HEADER","CANCEL")
				//Msg("SENT HEADER CANCEL\n")
				joynet.headerCancel = nil
				joynet.updateHeader = CurTime() + joynet.updateRate
			elseif joynet.headerBuffer then
				if joynet.headerBuffer[1] then
					RunConsoleCommand("ja",table.remove(joynet.headerBuffer,1))
					joynet.updateHeader = CurTime() + joynet.updateRate
					//Msg("SENT HEADER FRAGMENT\n")
				else
					joynet.headerBUffer = nil
					RunConsoleCommand("ja","HEADER","FINISH")
					//Msg("SENT HEADER FINISH\n")
					joynet.updateHeader = nil
					joynet.updateNext = CurTime() + joynet.updateRate
					joynet.buffer = "" //We need to resend, so flush buffer
				end
			end
		end
	end

	hook.Add("Think","jnt",joynet.tick)

	joynet.update()
end
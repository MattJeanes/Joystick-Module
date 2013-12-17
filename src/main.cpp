#include "GarrysMod\Lua\Interface.h"
#include <stdio.h>
#include <windows.h>
#include <dinput.h>
#include <iostream>

using namespace GarrysMod::Lua;

//=============================================================================//
//	Joystick Input Module
//	Version 1.2
//	Written by Night-Eagle
//=============================================================================//

// Libraries
#pragma comment (lib, "dinput8.lib")
#pragma comment (lib, "dxguid.lib")
#pragma comment (lib, "ole32.lib")

// Globals
LPDIRECTINPUT8 din; //Root DirectInput Interface
LPDIRECTINPUTDEVICE8 dinkeyboard; //Keyboard Device
LPDIRECTINPUTDEVICE8 dinmouse; // Mouse Device
const int max_devices = 64; //Maximum number of devices

// Joystick globals
LPDIRECTINPUTDEVICE8 joy_din[max_devices]; //Joystick Device
DIDEVCAPS joy_devcaps[max_devices]; //DIDEVCAPS Struct
char joy_name[max_devices][MAX_PATH]; //Name of joystick
float joy_guid[max_devices][3]; //GUID of joystick 1
float joy_guids[max_devices][8]; //GUID of joystick 2
int joy_n = 0;
char* binaryversion = "1.2";

DIJOYSTATE2 joy_state[max_devices]; //State of joystick
bool joy_active[max_devices]; //Joystick present
// End joystick globals

//
// Lua Functions
//

int keyboardstate(lua_State* state)
{
	char buffer[256];
	HRESULT hr;
	hr = dinkeyboard->GetDeviceState(sizeof(buffer),(LPVOID)&buffer);
	if FAILED(hr)
	{
		if (hr == DIERR_INPUTLOST)
		{
			dinkeyboard->Acquire();
		}
		return 0;
	}
	#define KEYDOWN(name, key) (name[key] & 0x80)

	if (LUA->GetTypeName(1) != "table")
		LUA->CreateTable();

		int i;
		for (i=0; i<256; i++)
		{
			bool temp = KEYDOWN(buffer,i);
			LUA->PushBool(temp);
		}
		LUA->Push(-2);
	return 1;
}

int refresh(lua_State* state)
{
	int joy = (LUA->GetNumber(1));

	if ((joy >= 0) && (joy < joy_n))
	{
		HRESULT hr;
		if (joy_din[joy])
		{
			if (FAILED(hr = joy_din[joy]->Poll()))
			{
				hr = joy_din[joy]->Acquire();
			}
			else
			{
				hr = joy_din[joy]->GetDeviceState(sizeof(DIJOYSTATE2), &joy_state[joy]);
			}
		}
	}
	else
	{
		int i;
		for (i=0; i<joy_n; i++)
		{
			HRESULT hr;
			if (joy_din[i])
			{
				if (FAILED(hr = joy_din[i]->Poll()))
				{
					hr = joy_din[i]->Acquire();
				}
				else
				{
					hr = joy_din[i]->GetDeviceState(sizeof(DIJOYSTATE2), &joy_state[i]);
				}
			}
		}
	}
	return 0;
}

int axis(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	int axi = (LUA->GetNumber(2));
	long out;

	switch(axi)
	{
		case 0 :
			out = joy_state[joy].lX;
			break;
		case 1 :
			out = joy_state[joy].lY;
			break;
		case 2 :
			out = joy_state[joy].lZ;
			break;
		case 3 :
			out = joy_state[joy].lRx;
			break;
		case 4 :
			out = joy_state[joy].lRy;
			break;
		case 5 :
			out = joy_state[joy].lRz;
			break;
		case 6 :
			out = joy_state[joy].rglSlider[0];
			break;
		case 7 :
			out = joy_state[joy].rglSlider[1];
			break;
		default :
			out = 0;
	}
	
	LUA->PushNumber((float)out);
	return 1;
}

int button(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	int but = (LUA->GetNumber(2));
	LUA->PushNumber((float)(joy_state[joy].rgbButtons[but]));
	return 1;
}

int pov(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	int pov = (LUA->GetNumber(2));
	LUA->PushNumber((float)(joy_state[joy].rgdwPOV[pov]));
	return 1;
}

int count(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	int opt = (LUA->GetNumber(2));
	float out;
	switch(opt)
	{
		case 1 :
			out = (float)joy_devcaps[joy].dwAxes;
			break;
		case 2 :
			out = (float)joy_devcaps[joy].dwButtons;
			break;
		case 3 :
			out = (float)joy_devcaps[joy].dwPOVs;
			break;
		default :
			out = (float)joy_n;
	}
	LUA->PushNumber(out);
	return 1;
}

int name(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	LUA->PushString((char*) joy_name[joy]);
	return 1;
}

int guidm(lua_State* state)
{
	int joy = (LUA->GetNumber(1));
	LUA->PushNumber((float) joy_guid[joy][0]);
	LUA->PushNumber((float) joy_guid[joy][1]);
	LUA->PushNumber((float) joy_guid[joy][2]);
	int i;
	for (i=0; i<8; i++)
	{
		LUA->PushNumber((float) joy_guids[joy][i]);
	}
	return 11;
}

//
// Axis Initialization
//

BOOL CALLBACK EnumAxesCallback(const DIDEVICEOBJECTINSTANCE* pdidoi, VOID* pContext)
{
	
	HRESULT hr;
	DIPROPRANGE diprg; 
	
	diprg.diph.dwSize       = sizeof(DIPROPRANGE); 
	diprg.diph.dwHeaderSize = sizeof(DIPROPHEADER); 
	diprg.diph.dwHow        = DIPH_BYID; 
	diprg.diph.dwObj        = pdidoi->dwType;
	if ((pdidoi->dwType)&DIDFT_AXIS)
	{
		diprg.lMin              = 0; 
		diprg.lMax              = +65535;
	}
	else
	{
		diprg.lMin              = 0; 
		diprg.lMax              = +1;
	}
	
	if (FAILED(hr = joy_din[joy_n]->SetProperty(
		DIPROP_RANGE,
		&diprg.diph
	)))
	{
		return DIENUM_STOP;
	}
	else
	{
		return DIENUM_CONTINUE;
	}
}

//
// Joystick Initialization
//

BOOL CALLBACK EnumJoysticksCallback(const DIDEVICEINSTANCE* pdidInstance, VOID* pContext)
{
	HRESULT hr;

	// Get interface
	hr = din->CreateDevice(
		pdidInstance->guidInstance,
		&joy_din[joy_n],
		NULL
	);
	
	if (FAILED(hr))
	{
		return DIENUM_CONTINUE;
	}

	if (FAILED(hr = joy_din[joy_n]->SetDataFormat(&c_dfDIJoystick2)))
	{
		return DIENUM_CONTINUE;
	}

	if (FAILED(hr = joy_din[joy_n]->SetCooperativeLevel(NULL, DISCL_NONEXCLUSIVE | DISCL_BACKGROUND)))
	{
		return DIENUM_CONTINUE;
	}

	joy_devcaps[joy_n].dwSize = sizeof(DIDEVCAPS);
	if (FAILED(joy_din[joy_n]->GetCapabilities(&joy_devcaps[joy_n])))
	{
		return DIENUM_CONTINUE;
	}

	if (FAILED(joy_din[joy_n]->EnumObjects(
		EnumAxesCallback,
		NULL,
		NULL
	)))
	{
		return DIENUM_CONTINUE;
	}
	
	// User stuff
	if ((joy_devcaps[joy_n].dwFlags & DIDC_ATTACHED) > 0)
	{
		joy_active[joy_n] = true;
	}

	//Get device info
	int i;
	for (i=0;i<MAX_PATH;i++)
	{
		joy_name[joy_n][i] = pdidInstance->tszProductName[i];
	}
	
	joy_guid[joy_n][0] = (pdidInstance->guidInstance).Data1;
	joy_guid[joy_n][1] = (pdidInstance->guidInstance).Data2;
	joy_guid[joy_n][2] = (pdidInstance->guidInstance).Data3;
	for (i=0;i<8;i++)
	{
		joy_guids[joy_n][i] = (pdidInstance->guidInstance).Data4[i];
	}
	
	// Acquire the joystick
	joy_din[joy_n]->Acquire();
	
	// Increment joy_n
	joy_n++;

	// We want to enumerate all joysticks, so keep on enumerating until we are out of joysticks
	return DIENUM_CONTINUE;
}

//
// DirectInput Start/Stop
//

bool StopDI(void)
{
	dinkeyboard->Unacquire();
	din->Release();
	
	joy_n = 0;

	return true;
}

bool InitDI(void)
{
	HRESULT hr;
	
	// Start DirectInput
	DirectInput8Create(
		GetModuleHandle(NULL),
		DIRECTINPUT_VERSION,
		IID_IDirectInput8,
		(void**)&din,
		NULL
	);

	if (din == NULL)
	{
		return false;
	}
	
	hr = din->CreateDevice(
		GUID_SysKeyboard,
		&dinkeyboard,
		NULL
	);
	
	if (FAILED(hr))
	{
	} else {
		hr = dinkeyboard->SetDataFormat(&c_dfDIKeyboard);
		if (FAILED(hr))
		{
		} else {
			dinkeyboard->SetCooperativeLevel(
				NULL,
				DISCL_FOREGROUND | DISCL_EXCLUSIVE
			);
			dinkeyboard->Acquire();
		}
	}

	//
	// Joystick Meat
	//

	din->EnumDevices(
		DI8DEVCLASS_GAMECTRL,
		EnumJoysticksCallback,
		NULL,
		DIEDFL_ATTACHEDONLY
	);

	return true;
}

int restart(lua_State* state)
{
	bool result = StopDI();
	if (!result)
	{
		LUA->PushBool(false);
		return 1;
	}
	result = InitDI();
	LUA->PushBool(result);
	return 1;
}

//
// Initialization
//

GMOD_MODULE_OPEN()
{
	LUA->PushSpecial(GarrysMod::Lua::SPECIAL_GLOB);
		LUA->CreateTable();
			LUA->PushCFunction(refresh); LUA->SetField(-2, "refresh");
			LUA->PushCFunction(axis); LUA->SetField(-2, "axis");
			LUA->PushCFunction(button); LUA->SetField(-2, "button");
			LUA->PushCFunction(pov); LUA->SetField(-2, "pov");
			LUA->PushCFunction(count); LUA->SetField(-2, "count");
			LUA->PushCFunction(name); LUA->SetField(-2, "name");
			LUA->PushCFunction(guidm); LUA->SetField(-2, "guidm");
			LUA->PushCFunction(restart); LUA->SetField(-2, "restart");
			LUA->PushString(binaryversion); LUA->SetField(-2, "binaryversion");
			LUA->PushCFunction(keyboardstate); LUA->SetField(-2, "keyboardstate");
		LUA->SetField(-2, "joystick");
	LUA->Pop();

	bool result = InitDI();
	return 0;
}

GMOD_MODULE_CLOSE()
{
	bool result = StopDI();
	return 0;
}






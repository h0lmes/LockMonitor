unit frmmainu;

{$mode Delphi}{$H+}

interface

uses
  jwaWindows, Windows, Messages, Classes, SysUtils, Forms, Controls, ExtCtrls,
  Menus, StdCtrls;

type

  _SETUP = record
    bSamsung: boolean;
    bOn: boolean;
    bOff: boolean;
  end;

  PHYSICAL_MONITOR = record
    hPhysicalMonitor: THandle;
    szPhysicalMonitorDescription: array [0..127] of WideChar;
  end;

  { Tfrmmain }

  Tfrmmain = class(TForm)
    btnOk: TButton;
    chbSamsung: TCheckBox;
    Memo1: TMemo;
    msetup: TMenuItem;
    mexit: TMenuItem;
    popup: TPopupMenu;
    TrayIcon: TTrayIcon;
    procedure btnOkClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure mexitClick(Sender: TObject);
    procedure msetupClick(Sender: TObject);
  private
    hDxvaLib: THandle;
    FWndInstance: TFarProc;
    FPrevWndProc: TFarProc;
    MonHandles: TFPList;
    GetNumberOfPhysicalMonitorsFromHMONITOR: function (hMonitor: THandle; pdwNumberOfPhysicalMonitors: PDWORD): boolean; stdcall;
    GetPhysicalMonitorsFromHMONITOR: function (hMonitor: THandle; dwPhysicalMonitorArraySize: DWORD; pPhysicalMonitorArray: Pointer): boolean; stdcall;
    SetVCPFeature: function (hMonitor: THandle; bVCPCode: byte; dwNewValue: dword): boolean; stdcall;
    procedure OnSessionLock;
    procedure OnSessionUnlock;
    procedure NativeWndProc(var message: TMessage);
    procedure MonitorPower(value: boolean);
  public
    procedure Init(bSamsung, bOn, bOff: boolean);
  end;

const
  NotifyForThisSession = 0;
  SessionChangeMessage = $02B1;
  SessionLockParam     = $7;
  SessionUnlockParam   = $8;
  POWER_ON             = 1;
  POWER_STANDBY        = 2;
  POWER_SUSPEND        = 3;
  POWER_OFF            = 4;

var
  frmmain: Tfrmmain;
  Parameters: _SETUP;

implementation
{$R *.lfm}
//------------------------------------------------------------------------------
procedure Tfrmmain.Init(bSamsung, bOn, bOff: boolean);
begin
  Parameters.bSamsung := bSamsung;
  Parameters.bOn := bOn;
  Parameters.bOff := bOff;

  MonHandles := TFPList.Create;

  FWndInstance := MakeObjectInstance(NativeWndProc);
  FPrevWndProc := Pointer(GetWindowLongPtr(Handle, GWL_WNDPROC));
  SetWindowLongPtr(Handle, GWL_WNDPROC, PtrInt(FWndInstance));

  TrayIcon.Icon := self.Icon;

  hDxvaLib := LoadLibrary('Dxva2.dll');
  if hDxvaLib <> 0 then
  begin
    @GetNumberOfPhysicalMonitorsFromHMONITOR := GetProcAddress(hDxvaLib, 'GetNumberOfPhysicalMonitorsFromHMONITOR');
    @GetPhysicalMonitorsFromHMONITOR := GetProcAddress(hDxvaLib, 'GetPhysicalMonitorsFromHMONITOR');
    @SetVCPFeature := GetProcAddress(hDxvaLib, 'SetVCPFeature');
  end;

  if bOn then
  begin
    MonitorPower(true);
    Close;
    exit;
  end;

  if bOff then
  begin
    MonitorPower(false);
    Close;
    exit;
  end;

  WTSRegisterSessionNotification(Handle, NotifyForThisSession);
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MonHandles.free;
  WTSUnregisterSessionNotification(Handle);
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.FormShow(Sender: TObject);
begin
  chbSamsung.Checked := Parameters.bSamsung;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.btnOkClick(Sender: TObject);
begin
  Parameters.bSamsung := chbSamsung.Checked;
  hide;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.NativeWndProc(var message: TMessage);
begin
  message.result := 0;
  case message.msg of
    SessionChangeMessage:
      begin
        if message.wParam = SessionLockParam then OnSessionLock
        else if message.wParam = SessionUnlockParam then OnSessionUnlock;
      end;
    else message.result := CallWindowProc(FPrevWndProc, Handle, message.Msg, message.wParam, message.lParam);
  end;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.OnSessionLock;
begin
  MonitorPower(false);
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.OnSessionUnlock;
begin
  MonitorPower(true);
end;
//------------------------------------------------------------------------------
function EnumProc(hMonitor: THandle; hdcMonitor: HDC; lprcMonitor: PRect; dwData: LPARAM): BOOL; stdcall;
var
  Mons: array [0..5] of PHYSICAL_MONITOR;
  frm: Tfrmmain absolute dwData;
	i, mcnt: DWORD;
begin
	if not frm.GetNumberOfPhysicalMonitorsFromHMONITOR(hMonitor, @mcnt) then exit;
  if frm.GetPhysicalMonitorsFromHMONITOR(hMonitor, mcnt, @Mons) then
  begin
		for i := 0 to mcnt - 1 do
    begin
      if frm.MonHandles.IndexOf(pointer(Mons[i].hPhysicalMonitor)) < 0 then
        frm.MonHandles.Add(pointer(Mons[i].hPhysicalMonitor));
    end;
  end;
	result := true;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.MonitorPower(value: boolean);
var
  i: integer;
begin
  if not assigned(GetNumberOfPhysicalMonitorsFromHMONITOR) then
  begin
    messagebox(handle, 'GetNumberOfPhysicalMonitorsFromHMONITOR() not assigned', nil, 0);
    exit;
  end;

  MonHandles.Clear;
  EnumDisplayMonitors(0, nil, EnumProc, dword(self));
  i := 0;
  while i < MonHandles.Count do
  begin
    if Parameters.bSamsung then
    begin
      if value then SetVCPFeature(dword(MonHandles.Items[i]), $E1, 1)
      else SetVCPFeature(dword(MonHandles.Items[i]), $E1, 0);
    end else begin
      if value then SetVCPFeature(dword(MonHandles.Items[i]), $D6, POWER_ON)
      else SetVCPFeature(dword(MonHandles.Items[i]), $D6, POWER_OFF);
    end;
    inc(i);
  end;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.mexitClick(Sender: TObject);
begin
  Close;
end;
//------------------------------------------------------------------------------
procedure Tfrmmain.msetupClick(Sender: TObject);
begin
  application.ShowMainForm := true;
  Show;
end;
//------------------------------------------------------------------------------
end.


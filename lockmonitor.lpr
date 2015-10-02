program lockmonitor;

{$mode Delphi}{$H+}

uses
  Windows,
  Interfaces,
  interfacebase,
  SysUtils,
  Forms,
  frmmainu;

{$R *.res}
var
  i: integer;
  bSamsung, bOn, bOff: boolean;
begin
  bSamsung := false;
  bOn := false;
  bOff := false;
  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '-on' then bOn := true;
    if ParamStr(i) = '-off' then bOff := true;
    if ParamStr(i) = '-samsung' then bSamsung := true;
    inc(i);
  end;

  RequireDerivedFormResource := True;
  Application.Initialize;

  SetWindowLong(WidgetSet.AppHandle, GWL_EXSTYLE, GetWindowLong(WidgetSet.AppHandle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  Application.ShowMainForm := false;
  Application.CreateForm(Tfrmmain, frmmain);
  frmmain.Init(bSamsung, bOn, bOff);

  Application.Run;
end.


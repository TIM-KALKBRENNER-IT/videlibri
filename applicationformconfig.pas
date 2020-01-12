unit applicationformconfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, forms, Graphics, controls;

type TVideLibriForm = class(TForm)
  function GetRealBounds: TRect;
  procedure SetRealBounds(bounds: TRect);
  procedure MyAutoPlacement(var bounds: TRect; const oldBounds: TRect);
protected
  guiScaleFactor: Double;
  procedure videLibriScale(pcontrol: twincontrol);
  function getRealFontHeight: integer;
  procedure DoCreate; override;
  procedure DoShow; override;
end;

implementation

uses bbdebugtools, LCLType,StdCtrls, ComCtrls, Dialogs, LCLIntf;

type TControlBreaker = class(TControl);

//lcl's bounds do not include the border, so try to infer the border size
var BoundsRectOffset: TPoint;
    GlobalDefaultFontSize: integer = 0;

function TVideLibriForm.GetRealBounds: TRect;
var realRect: TRect;
begin
  result := BoundsRect;
  if not BoundsRectOffset.IsZero then begin
    result.Right += BoundsRectOffset.x;
    result.Bottom += BoundsRectOffset.y;
  end else if HandleAllocated and (GetWindowRect(Handle, realRect{%H-}) <> 0) then begin
    if (realrect.Width > 0) and (realRect.Height > 0) then begin
      result.Width := realRect.Width;
      result.Height := realRect.Height;
    end;
  end;
end;

procedure TVideLibriForm.SetRealBounds(bounds: TRect);
begin
  bounds.Right -= BoundsRectOffset.x;
  bounds.Bottom -= BoundsRectOffset.y;
  BoundsRect := bounds;
end;

function pointToString(const p: TPoint): string;
begin
  result :=  '(' + inttostr(p.X) + ', ' + inttostr(p.y) + ')';
end;

function rectToString(const r: TRect): string;
begin
  result := inttostr(r.Width) + 'x' + inttostr(r.Height) + ' at ' + pointToString(r.TopLeft) + '-' + pointToString(r.BottomRight);
end;

procedure TVideLibriForm.MyAutoPlacement(var bounds: TRect; const oldBounds: TRect);
var workarea: TRect;
  mon: TMonitor;
begin
  //see MoveToDefaultPosition
  workarea := default(TRect);
  if Application.MainForm <> nil then mon := Application.MainForm.Monitor
  else mon := Monitor;
  if mon <> nil then workarea := mon.WorkareaRect;
  if (workarea.Width <= 0) or (workarea.Height <= 0) then workarea := screen.WorkAreaRect;
  if (workarea.Width <= 0) or (workarea.Height <= 0) then workarea := screen.DesktopRect;
  if ((workarea.Width <= 0) or (workarea.Height <= 0)) and (mon <> nil) then workarea := mon.BoundsRect;
  if (workarea.Width <= 0) or (workarea.Height <= 0) then begin
    workarea.Width := screen.Width;
    workarea.Height := screen.Height;
  end;

{  if (Application.MainForm <> nil) and (Application.MainForm <> self) then
  ShowMessage(
      'bounds: ' + IntToStr(bounds.Left) + ' ' + inttostr(bounds.Top) + ' x ' + IntToStr(bounds.Width) + ' ' + inttostr(bounds.Height)  + #13#10
      + 'workarea: ' + IntToStr(workarea.Left) + ' ' + inttostr(workarea.Top) + ' x ' + IntToStr(workarea.Width) + ' ' + inttostr(workarea.Height) + #13#10
      + 'screen: ' + IntToStr(Screen.Width) + ' ' + inttostr(Screen.Height) + #13#10
      + 'Screen workarea: ' + IntToStr(screen.WorkAreaLeft) + ' ' + inttostr(screen.WorkAreaTop) + ' x ' + IntToStr(screen.WorkAreaWidth) + ' ' + inttostr(screen.WorkAreaHeight) + #13#10
      + 'Screen desktop: ' + IntToStr(screen.DesktopLeft) + ' ' + inttostr(screen.DesktopTop) + ' x ' + IntToStr(screen.DesktopWidth) + ' ' + inttostr(screen.DesktopHeight)
//      + 'monitor: ' + IntToStr(Screen.Width) + ' ' + inttostr(Screen.Height)
  );
}

  if (workarea.Width > 0) and (workarea.Height > 0) then begin
    if bounds.Width > workarea.Width then bounds.Width := workarea.Width;
    if bounds.Height > workarea.Height then bounds.Height := workarea.Height;
    bounds.SetLocation(workarea.Left + (workarea.Width - bounds.Width) div 2, workarea.Top + (workarea.Height - bounds.Height) div 2);
  end;

  if logging then begin
    log('Window placement for ' + name + ' ' + ClassName);
    if mon <> nil then begin
      log('  monitor workeara: ' + rectToString(mon.WorkareaRect));
      log('  monitor bounds: ' + rectToString(mon.BoundsRect));
    end;
    log('  screen workeara: ' + rectToString(screen.WorkAreaRect));
    log('  screen desktop: ' + rectToString(screen.DesktopRect));
    log('  screen size: ' + inttostr(screen.width) + 'x' + inttostr(screen.Height));

    log('  window old outer bounds: ' + rectToString(BoundsRect));
    log('  window old inner bounds: ' + rectToString(oldBounds));
    log('  window bounds: ' + rectToString(bounds));
  end;

  if bounds <> oldbounds then
    SetRealBounds(bounds);
end;

procedure TVideLibriForm.videLibriScale(pcontrol: twincontrol);
var
  i, j: Integer;
  c: TWinControl;
  lv: TListView;
  newWidth: Int64;
begin
  for i := 0 to pcontrol.ControlCount - 1 do begin
    if pcontrol.Controls[i] is TWinControl then begin
      c := TWinControl(pcontrol.Controls[i]);
      if c.AutoSize and not TControlBreaker(c).WidthIsAnchored
         and (
           (c is TEdit) or (c is TComboBox)
        ) then begin
          newWidth := MathRound(c.Width * guiScaleFactor);
          if akRight in  c.Anchors then
            c.SetBoundsKeepBase( c.Left + c.Width - newWidth, c.top, newWidth, c.Height ) //keep right border
           else
            c.Width := newWidth;
       //   log(c.Name+ ' => ' + inttostr(c.Width));
      {else if c is tlistview then begin //https://bugs.freepascal.org/view.php?id=34044
        lv := TListView(c);
        for j := 0 to lv.ColumnCount - 1 do
          if lv.Column[j].Width <> 0 then
          begin
            log(lv.Column[j].Caption + ' '+IntToStr(lv.Column[j].Width));
//            lv.Column[j].Width := MathRound(lv.Column[j].Width * guiScaleFactor);
  //          log(lv.Column[j].Caption + ' -> '+IntToStr(lv.Column[j].Width));
          end;
      end; }
        end;

      videLibriScale(c);
    end;
  end;

end;

function TVideLibriForm.getRealFontHeight: integer;
const temp_str = 'Hm,.|';
var
  bmp: TBitmap;
begin
  if logging then log('Getting font size for '+Name + ' ' + ClassName +' ' + BoolToStr(HandleAllocated));
  if HandleAllocated then
    result := Canvas.GetTextHeight(temp_str)
  else if (Application.MainForm <> nil) and Application.MainForm.HandleAllocated then
    result := Application.MainForm.Canvas.GetTextHeight(temp_str)
  else begin
    bmp := TBitmap.Create;
    bmp.Canvas.Font := Font;
    result := bmp.Canvas.GetTextHeight(temp_str);
    bmp.free;
  end;
  if (result > 0) then GlobalDefaultFontSize := result
  else result := GlobalDefaultFontSize;
  if logging then begin
    log('size: ' + inttostr(result));
    log('has handle: '+BoolToStr(HandleAllocated));
  end;
end;

procedure TVideLibriForm.DoCreate;
const REFERENCE_FONT = 19; //19 on Linux, 15 on Windows for the same DPI
var
  fontHeight: Integer;
  bounds, oldbounds: TRect;
begin
  guiScaleFactor := 1;
  fontHeight := getRealFontHeight;

  oldbounds := GetRealBounds;
  bounds := oldbounds;
  LockRealizeBounds;
  if fontHeight > REFERENCE_FONT then begin
    guiScaleFactor := fontHeight / REFERENCE_FONT;
    bounds.Width := MulDiv(bounds.Width, fontHeight, REFERENCE_FONT);
    bounds.Height := MulDiv(bounds.Height, fontHeight, REFERENCE_FONT);
    if logging then begin
      log('  scale factor: ' + FloatToStr(guiScaleFactor));
      log('  window scaled bounds: ' + rectToString(bounds));
    end;
  end;

  MyAutoPlacement(bounds, oldBounds);

  if fontHeight > REFERENCE_FONT then
    videLibriScale(self);

  inherited DoCreate;

  UnlockRealizeBounds;
  if logging then log('has handle (2): '+BoolToStr(HandleAllocated));
{  if (Application.MainForm <> nil) and (Application.MainForm <> self) then
  ShowMessage(
    'bounds: ' + IntToStr(bounds.Left) + ' ' + inttostr(bounds.Top) + ' x ' + IntToStr(bounds.Width) + ' ' + inttostr(bounds.Height)  + #13#10  +
    'boundsRect: ' + IntToStr(boundsRect.Left) + ' ' + inttostr(boundsRect.Top) + ' x ' + IntToStr(boundsRect.Width) + ' ' + inttostr(boundsRect.Height)
    );}
end;

procedure TVideLibriForm.DoShow;
var
  bounds, oldbounds: TRect;
begin
  oldbounds := GetRealBounds;
  if BoundsRectOffset.IsZero then begin //this is here, because I am not sure the window has a valid rect in docreate
    BoundsRectOffset.x := oldbounds.Width - Width;
    BoundsRectOffset.y := oldbounds.Height - Height;
  end;
  bounds := oldbounds;

  MyAutoPlacement(bounds, oldBounds);
  inherited DoShow;
end;

end.


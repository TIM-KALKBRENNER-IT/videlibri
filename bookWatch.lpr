program bookWatch;

{$mode objfpc}{$H+}

uses
  //heaptrc,
  {$IFNDEF WIN32}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,menus,Graphics
  { add your units here }, sysutils, bookWatchMain, libraryParser, options, newAccountWizard_u, errorDialog, applicationConfig, statistik_u,
  diagram, libraryAccess, sendBackError, progressDialog, bbdebugtools, bibtexexport, booklistreader, librarySearcher,
  bookListView, bookSearchForm, librarySearcherAccess, treelistviewpackage, bbutils, LCLIntf, messagesystem, accountlist,
  libraryListView, androidutils, libraryaccesstester, exportxml, applicationdesktopconfig, LCLType, debuglogviewer, inifilessafe,
  xqueryform, bookproperties, applicationformconfig, vlmaps, coverLoaderAccess;

{$IFDEF WINDOWS}{$R manifest.rc}{$R icons.res}{$ENDIF}

{$ASMMODE intel}

//{$IFDEF WINDOWS}{$R bookWatch.rc}{$ENDIF}

{$R bookWatch.res}

begin
  //printleakedblock:=true;

  Application.Initialize;
  Application.Title:='VideLibri';
  application.Name:='VideLibri';
  try
    initApplicationConfig;
  except
    on e: Exception do begin
      Application.MessageBox(pchar(e.Message), pchar('Videlibri ' +rsError), MB_ICONERROR);
      if logging then log('init exception: '+e.Message);
      cancelStarting:=true;
    end;
  end;
  mainForm:=nil;
  if not cancelStarting then begin
      Application.CreateForm(TmainForm, mainForm);
      Application.ShowMainForm:=false;
      if not startToTNA then
         mainForm.Visible:=true
        else
         mainForm.Visible:=alertAboutBooksThatMustBeReturned;
      Application.Run;
  end;
  finalizeApplicationConfig;
end.


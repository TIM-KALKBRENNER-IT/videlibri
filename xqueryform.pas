unit xqueryform;

{$mode objfpc}{$H+}
{$ModeSwitch autoderef}
interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls, Menus, TreeListView, booklistview,applicationformconfig;

type
  Txqueryfrm = class(TVideLibriForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Memo1: TMemo;
    querySave: TMenuItem;
    queryLoad: TMenuItem;
    Panel1: TPanel;
    PopupMenu1: TPopupMenu;
    Splitter1: TSplitter;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure querySaveClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
    listview: TBookListView;
  end;

var
  xqueryfrm: Txqueryfrm;

implementation

uses booklistreader,libraryAccess,xquery,applicationdesktopconfig;

procedure Txqueryfrm.Button1Click(Sender: TObject);
begin
  close
end;

procedure Txqueryfrm.Button2Click(Sender: TObject);
var r: TBookListReader;
  b:ixqvalue;
  book: TBook;
  p: TXQProperty;
  item: TTreeListItem;
begin
  listview.clear;
  listview.SortColumn := 100; //disable auto sorting, but allow user to reenable it
  listview.BeginUpdate;
  r:=TBookListReader.create(nil);
  book := TBook.create;
  EnterCriticalsection(updateThreadConfig.libraryAccessSection);
  try
    for b in queryHistory(r,memo1.Lines.text) do begin
      case b.kind of
        pvkObject: begin
          book.clear;
          book.owningAccount:=nil;
          for p in b.getPropertyEnumerator do
            case p.key  of
              '_accountPtr': book.owningAccount := TCustomBookOwner(PtrInt(p.Value.toInt64));
              'statusId': if p.Value.toString = 'history' then book.lend := false
              else begin
                book.lend := true;
                book.setProperty(p.key, p.Value.toString);
              end
              else book.setProperty(p.key, p.Value.toString);
            end;
          item := listview.Items.add;
          listview.fillBookItem(item, book);
          item.data.obj := nil;
        end;
        else listview.Items.add.RecordItemsText[listview.getPropertyColumnIndex('title')] := b.toString;
      end;
    end;
  finally
    book.free;
    LeaveCriticalsection(updateThreadConfig.libraryAccessSection);
    listview.EndUpdate;
    r.free;
  end;
end;

procedure Txqueryfrm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction := caFree;
end;

procedure Txqueryfrm.FormCreate(Sender: TObject);
begin
  listview := TBookListView.create(self,true);
  listview.addDefaultColumns;
  listview.Align := alClient;
  listview.Parent := self;
  listview.Options := listview.Options + [tlvoSorted];
end;

procedure Txqueryfrm.FormShow(Sender: TObject);
begin
  if button2.Top < 5 then panel1.Height := panel1.Height - button2.top + 10;
end;

procedure Txqueryfrm.querySaveClick(Sender: TObject);
begin
  //todo: save and load queries

  //not possible with ini files. stupid TIniFile class cannot handle linebreaks
end;


initialization
  {$I xqueryform.lrs}

end.


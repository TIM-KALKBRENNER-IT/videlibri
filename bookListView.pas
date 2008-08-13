unit bookListView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, booklistreader, TreeListView, forms, Controls,FPCanvas;

 type

 { TBookListView }

 TBookListView = class(TTreeListView) //ANSI like TreeListView

 private
    fshowlendbooks: boolean;
    lastAddBook: tbook;

    procedure BookListCompareItems(sender: TObject; i1, i2: TTreeListItem;
      var compare: longint);
    procedure BookListCustomItemDraw(sender: TObject;
      eventTyp_cdet: TCustomDrawEventTyp; item: TTreeListItem; xpos, ypos,
      xColumn: integer; lastItem: boolean; var defaultDraw: Boolean);
    procedure BookListViewItemsSortedEvent(Sender: TObject);

   procedure addBook(book: tbook);
 public
   constructor create(aowner: TComponent;showLendBooks: boolean);
   procedure clear;
   procedure addBookList(list: TBookList);
 end;

const BL_BOOK_COLUMNS_AUTHOR=2;
      BL_BOOK_COLUMNS_TITLE=3;
      BL_BOOK_COLUMNS_LIMIT_ID=6;
      BL_BOOK_EXTCOLUMNS_COLOR=9;
      BL_BOOK_EXTCOLUMNS_WEEK_SEPARATOR=10;

implementation

uses applicationconfig, bbutils, libraryParser, Graphics,
windows {for the search only};
{ TBookListView }

procedure TBookListView.BookListViewItemsSortedEvent(Sender: TObject);
var i: longint;
    lastWeek: longint;
begin
  if SortColumn<>BL_BOOK_COLUMNS_LIMIT_ID then exit;
  if items.count=0 then exit;
  BeginMultipleUpdate;
  lastWeek:=currentDate div 7;
  for i:=0 to Items.Count-1 do
    if (Items[i].tag<>0) and (tbook(Items[i].tag).lend) and
       (TBook(Items[i].tag).limitDate div 7 <> lastWeek) then begin
      Items[i].RecordItemsText[BL_BOOK_EXTCOLUMNS_WEEK_SEPARATOR]:=IntToStr(abs(TBook(Items[i].tag).limitDate div 7 - lastWeek));
      lastWeek:=TBook(Items[i].tag).limitDate div 7;
     end else
      Items[i].RecordItemsText[BL_BOOK_EXTCOLUMNS_WEEK_SEPARATOR]:='';
  EndMultipleUpdate;
end;

procedure TBookListView.BookListCompareItems(sender: TObject; i1,
  i2: TTreeListItem; var compare: longint);
var book1,book2: TBook;
begin
  book1:=TBook(i1.Tag);
  book2:=TBook(i2.Tag);
  if (book1=nil) then begin
    Compare:=1;
    exit;
  end;
  if (book2=nil) then begin
    Compare:=-1;
    exit;
  end;
  compare:=0;
  case SortColumn of
    4: if book1.issueDate<book2.issueDate then
         compare:=-1
       else if book1.issueDate>book2.issueDate then
         compare:=1;
    BL_BOOK_COLUMNS_LIMIT_ID:; //see later

    else compare:=CompareText(i1.RecordItemsText[SortColumn],i2.RecordItemsText[SortColumn]);
  end;
  if compare=0 then  //Sort LimitDate
    if book1.limitDate<book2.limitDate then
       compare:=-1
    else if book1.limitDate>book2.limitDate then
       compare:=1;
  if compare=0 then       //Sort Status
    if (book1.status in BOOK_NOT_EXTENDABLE) and (book2.status in BOOK_EXTENDABLE) then
      compare:=-1
     else if (book1.status in BOOK_EXTENDABLE) and (book2.status in BOOK_NOT_EXTENDABLE) then
      compare:=1;
//     else compare:=compareText(PBook(item1.data)^.statusStr,PBook(item2.data)^.statusStr);
  if compare=0 then       //Sort ID
    compare:=compareText(i1.Text,i2.Text);
end;

function getBookColor(book:TBook):TColor;
begin
  if book = nil then exit(colorTimeNear);
  if book.lend=false then
    result:=colorOld
  else if book.limitDate<=redTime then
    result:=colorTimeNear
  else if book.status in BOOK_NOT_EXTENDABLE then
    result:=colorLimited
  else result:=colorOK;
end;


procedure TBookListView.BookListCustomItemDraw(sender: TObject;
  eventTyp_cdet: TCustomDrawEventTyp; item: TTreeListItem; xpos, ypos,
  xColumn: integer; lastItem: boolean; var defaultDraw: Boolean);
var pa: array[0..2] of tpoint;
    i,x,y:longint;
begin
  case eventTyp_cdet of
    cdetPrePaint:
      if not item.SeemsSelected then begin
        canvas.Brush.Style:=bsSolid;
        Canvas.brush.color:=StringToColor(item.RecordItemsText[BL_BOOK_EXTCOLUMNS_COLOR]);
        if Canvas.brush.color=clnone then
          Canvas.brush.color:=self.Color;;
      end;
    cdetPostPaint: if SortColumn= BL_BOOK_COLUMNS_LIMIT_ID then
      if item.RecordItemsText[BL_BOOK_EXTCOLUMNS_WEEK_SEPARATOR] <> '' then begin
        canvas.pen.Style:=psSolid;
        canvas.pen.Color:=$bB00BB;
        Canvas.pen.Width:=2;
        Canvas.Line(0,ypos,width,ypos);
        Canvas.brush.Color:=canvas.pen.Color;
        Canvas.pen.Color:=clblack;
        Canvas.pen.width:=1;
        pa[0].x:=0;pa[0].y:=ypos-4;
        pa[1].x:=4;pa[1].y:=ypos;
        pa[2].x:=0;pa[2].y:=ypos+4;
        Canvas.Polygon(pa);
        pa[0].x:=width-F_VScroll.width-1;pa[0].y:=ypos-4;
        pa[1].x:=width-F_VScroll.width-5;pa[1].y:=ypos;
        pa[2].x:=width-F_VScroll.width-1;pa[2].y:=ypos+4;
        Canvas.Polygon(pa);
        for i:=1 to StrToInt(item.RecordItemsText[BL_BOOK_EXTCOLUMNS_WEEK_SEPARATOR]) do begin
          x:=width-F_VScroll.width-8*i-2;
          y:=ypos;
          Canvas.Ellipse(x-3,y-3,x+3,y+3);
        end;
      end;
  end;

  defaultDraw:=true;
end;


procedure TBookListView.addBook(book: tbook);
begin
  with items.Add do begin
    text:=book.id;
    RecordItems.Add(book.category);
    RecordItemsText[BL_BOOK_COLUMNS_AUTHOR] := book.author;
    RecordItemsText[BL_BOOK_COLUMNS_TITLE] := book.title;
    RecordItems.Add(book.year);
    RecordItems.Add(DateToPrettyStr(book.issueDate));
    if book.lend = false then
     RecordItems.Add('erledigt')
    else
     RecordItems.Add(DateToPrettyStr(book.limitDate));
    if book.owner<>nil then RecordItems.Add((book.owner as TCustomAccountAccess).prettyName)
    else RecordItems.Add('unbekannt');
    RecordItems.Add(BookStatusToStr(book));//Abgegeben nach '+DateToStr(book.lastExistsDate))
    
    
//    RecordItems.Add(book.year); ;
   // SubItems.add(book.otherInfo);
    RecordItemsText[BL_BOOK_EXTCOLUMNS_COLOR]:=ColorToString(getBookColor(book));

    //else
    tag:=longint(book);
  end;
end;

constructor TBookListView.create(aowner: TComponent;showLendBooks: boolean);
begin
  inherited create(aowner);
  OnCompareItems:=@BookListCompareItems;
  if showLendBooks then  begin
    OnCustomItemDraw:=@BookListCustomItemDraw;
    OnItemsSortedEvent:=@BookListViewItemsSortedEvent;
    RootLineMode:=lmNone;
  end;
  fshowlendbooks:=showLendBooks;
  Align:=alClient;

  ColumnsDragable:=true;
  Columns.Clear;
  with Columns.Add do begin
    Text:='ID';
    Width:=80;
  end;
  with Columns.Add do begin
    Text:='Kategorie';
    Width:=50;
  end;
  with Columns.Add do begin
    Text:='Verfasser';
    Width:=120;
  end;
  with Columns.Add do begin
    Text:='Titel';
    Width:=150;
  end;
  with Columns.Add do begin
    Text:='Jahr';
    Width:=30;
  end;
  with Columns.Add do begin
    Text:='Ausleihe';
    Width:=70;
    Alignment:=taCenter;
  end;
  with Columns.Add do begin
    Text:='Frist';
    Width:=70;
    Alignment:=taCenter;
  end;
  with Columns.Add do begin
    Text:='Konto';
    Width:=80;
  end;
  with Columns.Add do begin
    Text:='Bemerkung';
    Width:=250;
  end;

end;


procedure TBookListView.clear;
begin
  Items.Clear;
  lastAddBook:=nil;
end;

procedure TBookListView.addBookList(list: TBookList);
var i:longint;
begin
  for i:=0 to list.Count-1 do
    addBook(list[i]);
end;

end.


unit librarySearcherAccess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils , librarySearcher,libraryParser, booklistreader,bbutils,messagesystem,simplexmlparser,multipagetemplate;

type

TBookNotifyEvent=procedure (sender: TObject; book: TBook) of object;
TLibrarySearcherAccess = class;

{ TLibrarySearcherAccess }

TSearcherMessageTyp=(smtFree, smtConnect, smtSearch, smtDetails, smtImage, smtDisconnect);

{ TSearcherMessage }

TSearcherMessage = class
  typ: TSearcherMessageTyp;
  book: tbook;
  constructor create(t:TSearcherMessageTyp; b:TBook=nil);
end;

{ TSearcherThread }

TSearcherThread = class(TThread)
private
  fbookAccessSection: TRTLCriticalSection;

  access: TLibrarySearcherAccess;
  messages: TMessageSystem;
  Searcher: TLibrarySearcher;
  
  notifyEvent: TNotifyEvent;
  bookNotifyEvent: TBookNotifyEvent;
  changedBook: tbook;
  
  performingAction: boolean;
  
  procedure callNotifyEventSynchronized;
  procedure callBookEventSynchronized;
  procedure callNotifyEvent(event: TNotifyEvent);
  procedure callBookEvent(event: TBookNotifyEvent; book: tbook);

  procedure execute;override;
public
  constructor create(template: TMultiPageTemplate; aaccess: TLibrarySearcherAccess);
  destructor destroy;override;
end;


TLibrarySearcherAccess = class
private
  FOnException: TNotifyEvent;
  fthread: TSearcherThread;
  ftemplate: TMultiPageTemplate;
  FOnConnected: TNotifyEvent;
  FOnDetailsComplete: TBookNotifyEvent;
  FOnImageComplete: TBookNotifyEvent;
  FOnSearchComplete: TNotifyEvent;

  function operationActive: boolean;
  procedure removeOldMessageOf(typ: TSearcherMessageTyp);
  function GetSearcher: TLibrarySearcher;
  procedure threadException();
public
  constructor create();
  destructor destroy; override;

  procedure beginBookReading;
  procedure endBookReading;
  procedure beginResultReading;
  procedure endResultReading;


  procedure newSearch(template: TMultiPageTemplate); //ensures that all operations are finished

  procedure connectAsync;
  procedure searchAsync;
  procedure detailsAsyncSave(book: TBook); //save means they make sure the
  procedure imageAsyncSave(book: TBook);   //book is not updated only once
  procedure disconnectAsync;

  property OnException: TNotifyEvent read FOnException write FOnException;
  property OnConnected: TNotifyEvent read FOnConnected write FOnConnected;
  property OnSearchComplete: TNotifyEvent read FOnSearchComplete write FOnSearchComplete;
  property OnDetailsComplete: TBookNotifyEvent read FOnDetailsComplete write FOnDetailsComplete;
  property OnImageComplete: TBookNotifyEvent read FOnImageComplete write FOnImageComplete;
  property searcher: TLibrarySearcher read GetSearcher;
end;

type

  { TSearchTarget }

  TSearchTarget = class
    name: string;
    lib: TLibrary; //might be nil
    template: TMultiPageTemplate;
    constructor create(aname: string; alib: TLibrary; atemplate: TMultiPageTemplate);
  end;

  { TSearchableLocations }

  TSearchableLocations = record
    locations:  TStringList; //string->stringlist of TSearchTarget
    searchTemplates: TStringList;
  end;

function getSearchableLocations: TSearchableLocations;
implementation

uses applicationconfig, bbdebugtools;

function getSearchableLocations: TSearchableLocations;
var digibib: TMultiPageTemplate;
  temp: TStringList;
  i: Integer;
  loc: String;
begin
  with result do begin
    locations := TStringList.Create;

    searchTemplates := TStringList.Create;
    searchTemplates.LoadFromFile(dataPath+StringReplace('libraries\search\search.list','\',DirectorySeparator,[rfReplaceAll]));
    for i := searchTemplates.count-1 downto 0 do begin
      searchTemplates[i] := trim(searchTemplates[i]);
      if searchTemplates[i] = '' then searchTemplates.Delete(i);
    end;
    for i :=0 to searchTemplates.count-1 do begin
      searchTemplates.Objects[i] := TMultiPageTemplate.create();
      TMultiPageTemplate(searchTemplates.Objects[i]).loadTemplateFromDirectory(dataPath+StringReplace('libraries\search\templates\'+trim(searchTemplates[i])+'\','\',DirectorySeparator,[rfReplaceAll]),trim(searchTemplates[i]));
      if searchTemplates[i] <> 'digibib' then begin
        temp := TStringList.Create;
        temp.AddObject(searchTemplates[i], TSearchTarget.create(searchTemplates[i], nil, TMultiPageTemplate(searchTemplates.Objects[i])));
        locations.AddObject(searchTemplates[i], temp);
      end else digibib := TMultiPageTemplate(searchTemplates.Objects[i]);
    end;

    if digibib = nil then raise ELibraryException.create('Digibib template not found');

    for i := 0 to libraryManager.getLibraryCountInEnumeration-1 do begin
      loc := libraryManager[i].prettyLocation;
      if libraryManager[i].template.findAction('search') <> nil then begin
        if locations.IndexOf(loc) < 0 then
          locations.AddObject(loc, TStringList.Create);
        temp := TStringList(locations.Objects[locations.IndexOf(loc)]);
        temp.AddObject(libraryManager[i].prettyNameLong, TSearchTarget.create(libraryManager[i].prettyNameLong, libraryManager[i], libraryManager[i].template));
      end;
      if libraryManager[i].variables.IndexOfName('searchid-digibib') >= 0 then begin
        if locations.IndexOf(loc+' (digibib)') < 0 then
          locations.AddObject(loc+' (digibib)', TStringList.Create);
        temp := TStringList(locations.Objects[locations.IndexOf(loc+' (digibib)')]);
        temp.AddObject(libraryManager[i].prettyNameLong, TSearchTarget.create(libraryManager[i].prettyNameLong, libraryManager[i], digibib));
      end;
    end;

    locations.Sort;
  end;
end;

{ TSearchTarget }

constructor TSearchTarget.create(aname: string; alib: TLibrary; atemplate: TMultiPageTemplate);
begin
  name := aname;
  lib := alib;
  template := atemplate;
end;

{ TLibrarySearcherAccess }

function TLibrarySearcherAccess.GetSearcher: TLibrarySearcher;
begin
  if not assigned(fthread) then exit(nil);
  Result:=fthread.Searcher;
end;

procedure TLibrarySearcherAccess.threadException();
begin
  if logging then log('TLibrarySearcherAccess.threadException called');
  if assigned(OnException) then
    OnException(self);
end;

constructor TLibrarySearcherAccess.create();
begin
end;

destructor TLibrarySearcherAccess.destroy;
begin
  if assigned(fthread) then fthread.messages.storeMessage(TSearcherMessage.Create(smtFree));
  inherited destroy;
end;

procedure TLibrarySearcherAccess.beginBookReading;
begin
  if not assigned(fthread) then exit;
  EnterCriticalsection(fthread. fbookAccessSection);
end;

procedure TLibrarySearcherAccess.endBookReading;
begin
  if not assigned(fthread) then exit;
  LeaveCriticalsection(fthread.fbookAccessSection);
end;

procedure TLibrarySearcherAccess.beginResultReading;
begin
  beginBookReading;
end;

procedure TLibrarySearcherAccess.endResultReading;
begin
  endBookReading;
end;

function TLibrarySearcherAccess.operationActive: boolean;
begin
  result:=assigned(fthread) and (fthread.messages.existsMessage or fthread.performingAction);
end;

procedure TLibrarySearcherAccess.removeOldMessageOf(typ: TSearcherMessageTyp);
var list: TFPList;
    i:longint;
begin
  if not assigned(fthread) then exit;
  list:=fthread.messages.openDirectMessageAccess;
  for i:=list.Count-1 downto 0 do
    if TSearcherMessage(list[i]).typ=typ then
      list.Delete(i);
  fthread.messages.closeDirectMessageAccess(list);
end;

procedure TLibrarySearcherAccess.newSearch(template: TMultiPageTemplate);
begin
  if (operationActive) or not Assigned(fthread) or (ftemplate <> template) then begin
    if assigned(fthread) then fthread.messages.storeMessage(TSearcherMessage.Create(smtFree));
    ftemplate := template;
    fthread:=TSearcherThread.Create(ftemplate,self);
  end;
end;

procedure TLibrarySearcherAccess.connectAsync;
begin
  if not assigned(fthread) then exit;
  removeOldMessageOf(smtConnect);
  fthread.messages.storeMessage(TSearcherMessage.Create(smtConnect));
end;

procedure TLibrarySearcherAccess.searchAsync;
begin
  if not assigned(fthread) then exit;
  removeOldMessageOf(smtSearch);
  fthread.messages.storeMessage(TSearcherMessage.Create(smtSearch));
end;

procedure TLibrarySearcherAccess.detailsAsyncSave(book: TBook);
begin
  if not assigned(fthread) then exit;
  removeOldMessageOf(smtDetails);
  fthread.messages.storeMessage(TSearcherMessage.Create(smtDetails,book));
end;

procedure TLibrarySearcherAccess.imageAsyncSave(book: TBook);
begin
  if not assigned(fthread) then exit;
  removeOldMessageOf(smtImage);
  fthread.messages.storeMessage(TSearcherMessage.Create(smtImage,book));
end;

procedure TLibrarySearcherAccess.disconnectAsync;
begin
  if not assigned(fthread) then exit;
  removeOldMessageOf(smtDisconnect);
  fthread.messages.storeMessage(TSearcherMessage.Create(smtDisconnect));
end;

{ TSearcherThread }

procedure TSearcherThread.callNotifyEventSynchronized;
begin
  if self<>access.fthread then exit;
  notifyEvent(self);
end;

procedure TSearcherThread.callBookEventSynchronized;
begin
  if self<>access.fthread then exit;
  try
    bookNotifyEvent(self,changedBook);
  finally
    changedBook := nil;
  end;
end;

procedure TSearcherThread.callNotifyEvent(event: TNotifyEvent);
begin
  if event=nil then exit;
  notifyEvent:=event;
  Synchronize(@callNotifyEventSynchronized);
end;

procedure TSearcherThread.callBookEvent(event: TBookNotifyEvent; book: tbook);
begin
  if event=nil then exit;
  if logging then log('Changed book: '+strFromPtr(changedBook));
  while changedBook<>nil do sleep(5);
  if logging then log('wait complete');
  bookNotifyEvent:=event;
  changedBook:=book;
  Synchronize(@callBookEventSynchronized);
end;

procedure TSearcherThread.execute;
var mes: TSearcherMessage;
    image:string;
    book: tbook;
    i: Integer;
begin
  while true do begin
    try
      performingAction:=false;
      if logging then log('Searcher thread: wait for message');
      while not messages.existsMessage do sleep(5);
      if logging then log('Searcher thread: possible message');
      mes:=TSearcherMessage(messages.retrieveMessageOrNil);
      if logging then log('Searcher thread: got message'+strFromPtr(mes));
      if mes=nil then continue;
      if mes.typ=smtFree then begin
        if logging then log('Searcher thread: message typ smtFree');
        mes.free;
        exit;
      end;
      performingAction:=true;
      book:=mes.book;
      if logging then
        if mes.book = nil then log('Message book: nil')
        else begin
          log('Message book: '+strFromPtr(book) +'  ' +book.title+' from '+book.author);
          //for i:=0 to high(book.additional) do log('Book properties: '+book.additional[i].name+' = '+book.additional[i].value);
        end;
      case mes.typ of
        smtConnect: begin
          if logging then log('Searcher thread: message typ smtConnect');
          searcher.connect;
          callNotifyEvent(access.FOnConnected);
        end;
        smtSearch: begin
          if logging then log('Searcher thread: message typ smtSearch');
          searcher.search;
          callNotifyEvent(access.FOnSearchComplete);
        end;
        smtDetails: begin
          if logging then log('Searcher thread: message typ smtDetails');
          if getproperty('details-searched',book.additional)<>'true' then begin
            if logging then log('Searcher thread: search details for '+book.title+' from '+book.author);
            Searcher.details(book);
            access.beginBookReading;
            addProperty('details-searched','true',book.additional);
            access.endBookReading;
            callBookEvent(access.FOnDetailsComplete,book);
          end;
        end;
        smtImage: begin
          if logging then log('Searcher thread: message typ smtImage: image-searched: '+getproperty('image-searched',book.additional)+'  image-url: '+getProperty('image-url',book.additional));
          if (getproperty('image-searched',book.additional)<>'true') then begin
            if (getProperty('image-url',book.additional)<>'') then begin
              if logging then log('image url: '+getProperty('image-url',book.additional));
              image:=searcher.bookListReader.internet.get(getProperty('image-url',book.additional));
            end else image:='';
            if logging then log('got image: size: '+IntToStr(length(image)));
            access.beginBookReading;
            if logging then log('a');
            addProperty('image',image,book.additional);
            if logging then log('b');
            addProperty('image-searched','true',book.additional);
            if logging then log('c');
            access.endBookReading;
            if logging then log('d');
            callBookEvent(access.FOnImageComplete,book);
            if logging then log('e');
          end;
        end;
        else if logging then log('Searcher thread: unknown type');
      end;
      FreeAndNil(mes);
    except
      on e: Exception do begin
        storeException(e,nil);
        FreeAndNil(mes);
        messages.removeAndFreeAll;
        Synchronize(@access.threadException);
      end;
    end;
  end;
end;

constructor TSearcherThread.create(template: TMultiPageTemplate; aaccess: TLibrarySearcherAccess);
begin
  InitCriticalSection(fbookAccessSection);
  Searcher:=TLibrarySearcher.create(template);
  Searcher.bookListReader.bookAccessSection:=@fbookAccessSection;
  self.access:=aaccess;
  messages:=TMessageSystem.create;
  changedBook:=nil;
  FreeOnTerminate:=true;
  inherited create(false);
end;

destructor TSearcherThread.destroy;
begin
  FreeAndNil(Searcher);
  while messages.existsMessage do messages.retrieveLatestMessageOrNil.free;
  messages.free;
  DoneCriticalsection(fbookAccessSection);
  inherited destroy;
end;

{ TSearcherMessage }

constructor TSearcherMessage.create(t: TSearcherMessageTyp; b: TBook);
begin
  typ:=t;
  book:=b;
end;

end.

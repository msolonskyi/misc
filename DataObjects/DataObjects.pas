unit DataObjects;

{##############################################################################}
interface
{##############################################################################}

uses
	Classes, DBTables;

type
{
	TFieldMapEntry = record
        Name : string[30];
        ExtName : string[30];
        DisplayLabel : string[30];
        DisplayAlign : ( faLeft, faCenter, faRight );
        DisplaySize : integer;
        KeyField : boolean;
        Required : boolean;
        CopyEnable : boolean;
    end;
	TFieldMap = array[0..255] of TFieldMapEntry;
    PFieldMap = ^PFieldMap;
}
	TFieldDisplayInfo = record
    	Title : string[30];
        Size : integer;
        Alignment : ( faLeft, faCenter, faRight );
    end;
	PFieldDisplayInfo = ^TFieldDisplayInfo;

	TDataStates = (dsNew, dsLoaded, dsUpdated, dsDeleted);
	TDataState = set of TDataStates;

	TDataObject = class;
	TDataObjectsSet = class;

    TDataObjectClass = class of TDataObject;

	TDataObject = class(TObject)
	private
	// Fields
		FState,
		FSavedState : TDataState; // to keep state during transaction
		FOwner : TDataObject;
	// Events;
    	FOnChangeSubObjectsCount : TNotifyEvent;
		FOnChangeState : TNotifyEvent;
		FOnChangeUpdate :  TNotifyEvent;
		FOnInternalUpdate : TNotifyEvent;
	protected
    // must be protected for using in descendants
		FSubObjects : TList;
	// SubObjecs maintenance
		procedure ClearSubObjects;
        procedure AddSubObject(ASubObject : TDataObject);
        procedure RemoveSubObject(ASubObject : TDataObject); overload;
        procedure RemoveSubObject(AIndex : integer); overload;
		function GetSubObjectsCount : integer;
        procedure SetSubObjectsCount(ACount : integer); virtual;
    // property Support
		function IsUpdated : boolean;
		procedure SetState(AState : TDataState); virtual;
        procedure SetOwner(AOwner : TDataObject);
    // Input/Output overridables
        procedure LoadExists; overload; virtual;
        procedure LoadExists(const AQuery : TQuery); overload; virtual;
		procedure InsertNew; virtual;
		procedure UpdateExists; virtual;
		procedure DeleteExists; virtual;
	// notifycations
		procedure OnSubObjectChangeUpdate(AObject : TDataObject);
		procedure NotifyInternalUpdate;
    // Clipboard Copy/Paste support
    	// Allways overridable
    	procedure DataToCopy(var S : ANSIString); virtual;
        procedure DataFromPaste(const S : ANSIString); virtual;
	    // Seldom overridable
    	function Tag : string; virtual;
        procedure CopyToText(var AText : ANSIString); virtual;
        procedure PasteFromText(const AText : ANSIString); virtual;
    // Report support
        function GetSubstitutions : TStringList; virtual;
	public
	// Contruction/destruction
		constructor Create(AOwner : TDataObject); virtual;  // common
		destructor Destroy; override;
	// Operations
		function Edit : boolean; virtual;
		procedure Blank; virtual;
    	procedure Pack; virtual;
        procedure Load; virtual;
		procedure Delete; virtual;
		procedure Store; virtual;
	// Transaction support
		procedure StartTransaction; virtual;
		procedure Commit; virtual;
		procedure Rollback; virtual;
	// Propertys
		property State : TDataState read FState write SetState;
		property Owner : TDataObject read FOwner write SetOwner;
		property Updated : boolean read IsUpdated;
		property Count : integer read GetSubObjectsCount write SetSubObjectsCount;
        property Substitutions : TStringList read GetSubstitutions;
    // Values
        class function GetFieldsCount : integer; virtual; abstract;
        class procedure GetFieldDisplayInfo(AIndex : integer; var AInfo : TFieldDisplayInfo); virtual; abstract;
    	function GetFieldValue(AIndex : integer) : string; virtual;
    	property FieldsCount : integer read GetFieldsCount;
    	property Field[AIndex : integer] : string read GetFieldValue; default;
	// Events support;
    	property OnChangeSubObjectsCount : TNotifyEvent read FOnChangeSubObjectsCount write FOnChangeSubObjectsCount;
		property OnChangeState : TNotifyEvent read FOnChangeState write FOnChangeState;
		property OnChangeUpdate : TNotifyEvent read FOnChangeUpdate write FOnChangeUpdate;
		property OnInternalUpdate : TNotifyEvent read FOnInternalUpdate write FOnInternalUpdate;
{$IFOPT C+}
	// Debug support
	    procedure Dump(ALevel : integer; var AText : Text); virtual;
{$ENDIF}
	end;

    TDataObjectsSet = class(TDataObject)
    protected
        FClass : TDataObjectClass; // must be defined in contructor
    	function LoadingQuery : TQuery; virtual; abstract;
        procedure SetSubObjectsCount(ACount : integer); override;
        function GetSubObject(AIndex : integer) : TDataObject;
    public
        procedure Load; override;
        function Add : boolean; virtual; abstract;
        procedure Delete(ASubObject : TDataObject); reintroduce; overload; virtual;
        procedure Delete(AIndex : integer); reintroduce; overload; virtual;
        property SubObject[AIndex : integer] : TDataObject read GetSubObject; default;
        property SubObjectsCount : integer read GetSubObjectsCount;
        property ContainedClass : TDataObjectClass read FClass;
    end;

procedure StoreObject(ADatabase : TDatabase; AObject : TDataObject);
{$IFOPT C+}
function IsDataObject(const P : Pointer) : boolean;
procedure DumpDataObjects(AObject : TDataObject; AComment : ShortString = ''; AShow : boolean = TRUE);
procedure CleanDump;
{$ENDIF}

procedure SetTagValue(const ATag, AValue : string; var S : string);
function GetTagValue(const ATag, S : string) : string;

function CanPasteDataObject : boolean;
procedure CopyDataObject(const AObject : TDataObject);
procedure PasteDataObject(AObject : TDataObject);

var
	CF_DATA_OBJECT : LongWord;
	TheDataObjects : TList;

{##############################################################################}
implementation
{##############################################################################}

uses
	Windows, SysUtils, ClipBrd;

{$IFOPT C+}
const
	DumpFileName = '\Dump.TXT';
{$ENDIF}

////////////////////////////////////////////////////////////////////////////////
function TDataObject.IsUpdated : boolean;
var
	i : integer;
begin
	Result := FALSE;
	if not ( FState <= [dsNew, dsLoaded] ) then
		Result := TRUE
	else
		with FSubObjects do
			for i := 0 to Count - 1 do begin
            	ASSERT(assigned(Items[i]));
				if TDataObject(FSubObjects.Items[i]).IsUpdated then begin
					Result := TRUE;
					break;
				end;
            end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.SetState;
var
	UpdateFlagChanged : boolean;
begin
	if FState = AState then
		exit;
	UpdateFlagChanged := ((dsUpdated in AState) <> (dsUpdated in FState)) or
	((dsDeleted in AState) <> (dsDeleted in FState));
	FState := AState;
	if assigned(FOnChangeState) then
		FOnChangeState(Self);
	if UpdateFlagChanged then begin
		if assigned(FOnChangeUpdate) then
			FOnChangeUpdate(Self);
		if assigned(FOwner) then
			FOwner.OnSubObjectChangeUpdate(Self);
	end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.SetOwner;
begin
	if assigned(FOwner) then
		FOwner.RemoveSubObject(Self);
	FOwner := AOwner;
	if assigned(FOwner) then
		FOwner.AddSubObject(Self);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.ClearSubObjects;
begin
	with FSubObjects do begin
		while Count > 0 do begin
			ASSERT( assigned(TDataObject(Last)) );
			TDataObject(Last).Destroy;
		end;
        Clear;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.AddSubObject;
var
	i : integer;
begin
	ASSERT(assigned(ASubObject));
    with FSubObjects do begin
    	i := IndexOf(ASubObject);
        ASSERT(i < 0); // only one occurence expected
        Add(ASubObject);
        OnSubObjectChangeUpdate(Self);
	end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.RemoveSubObject(ASubObject : TDataObject);
var
	i : integer;
begin
	ASSERT(assigned(ASubObject));
    with FSubObjects do begin
    	i := IndexOf(ASubObject);
        if i = -1 then begin
        	CleanDump;
        	DumpDataObjects(ASubObject,'bad ASubObject',FALSE);
        	DumpDataObjects(Self,'bad Owner',TRUE);
        end;
        ASSERT(i >= 0);
	    FSubObjects.Delete(i);
        OnSubObjectChangeUpdate(Self);
	end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.RemoveSubObject(AIndex : integer);
begin
	ASSERT(assigned(FSubObjects.Items[AIndex]));
    FSubObjects.Delete(AIndex);
    OnSubObjectChangeUpdate(Self);
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObject.GetSubObjectsCount;
begin
	Result := FSubObjects.Count;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.SetSubObjectsCount(ACount : integer);
begin
	// nobody can change SubObjectsCount in DataObject,
    // ONLY in DataObject collection - DataObject_S_
	ASSERT(FSubObjects.Count = ACount);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.LoadExists;
begin
	State := [dsLoaded];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.LoadExists(const AQuery : TQuery);
begin
	State := [dsLoaded];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.InsertNew;
begin
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.UpdateExists;
begin
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.DeleteExists;
begin
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.OnSubObjectChangeUpdate;
begin
	if assigned(FOnChangeUpdate) then
		FOnChangeUpdate(AObject);
	if assigned(FOwner) then
		FOwner.OnSubObjectChangeUpdate(AObject);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.NotifyInternalUpdate;
begin
	if assigned(FOnInternalUpdate) then
		FOnInternalUpdate(Self);
	if assigned(FOwner) then
		FOwner.NotifyInternalUpdate;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.DataToCopy(var S : ANSIString);
begin
	// must be called first
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.DataFromPaste(const S : ANSIString);
begin
	// Default does nothing
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObject.Tag : string;
var
    i, nInstance : integer;
begin
    if not assigned(Owner) then
    	Result := ClassName
    else begin
    	nInstance := 0;
        with Owner.FSubObjects do
            for i := 0 to Count - 1 do begin
            	if not assigned(Items[i]) then
                	continue;
                if TDataObject(Items[i]).ClassType = Self.ClassType then
                	inc(nInstance);
                if Pointer(Items[i]) = Self then begin
                	Result := Owner.Tag + '.' + Self.ClassName + '_' + IntToStr(nInstance);
                	exit;
                end;
            end;
	    ASSERT(FALSE);
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.CopyToText(var AText : ANSIString);
var
	i : integer;
    sTag : ANSIString;
begin
	sTag := Tag;
	AText := AText + #19 + sTag + '.Self.Data='#16;
	DataToCopy(AText);
	AText := AText + #17#19 + sTag + '.SubObjects.Count='#16 + IntToStr(FSubObjects.Count) + #17;
	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).CopyToText(AText);
        end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.PasteFromText(const AText : ANSIString);
var
	i : integer;
    sTag : ANSIString;
begin
    sTag := Tag;
    DataFromPaste(GetTagValue(sTag + '.Self.Data',AText));
    Count := StrToIntDef(GetTagValue(sTag + '.SubObjects.Count',AText),-1);
	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).PasteFromText(AText);
        end;
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObject.GetFieldValue(AIndex : integer) : string;
begin
    Result := '*';
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObject.GetSubstitutions : TStringList;
begin
	Result := nil;
	if assigned(Owner) then
    	Result := Owner.GetSubstitutions;
    if not assigned(Result) then
	    Result := TStringList.Create;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TDataObject.Create;
begin
	inherited Create;
{$IFOPT C+}
	ASSERT(assigned(TheDataObjects));
    TheDataObjects.Add(Self);
{$ENDIF}
	FOwner := AOwner;
	FSubObjects := TList.Create;
	if assigned(FOwner) then
		FOwner.AddSubObject(Self);
    Blank;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TDataObject.Destroy;
begin
	SetOwner(nil);
	ClearSubObjects;
	FSubObjects.Destroy;
	FSubObjects := nil;
{$IFOPT C+}
	ASSERT(assigned(TheDataObjects));
    with TheDataObjects do begin
	    ASSERT(IndexOf(Self) >= 0);
    	Delete(IndexOf(Self));
    end;
{$ENDIF}
	inherited;
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObject.Edit;
begin
	Result := FALSE;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Blank;
var
	i : integer;
begin
	with FSubObjects do
		for i := 0 to Count - 1 do
			if assigned(Items[i]) then
				TDataObject(Items[i]).Blank;
	State := [dsNew];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Pack;
var
    i : integer;
    bWasRemoved : boolean;
begin
	bWasRemoved := FALSE;
    with FSubObjects do begin
		i := 0;
	    while i <= Count - 1 do begin
        	ASSERT(assigned(Items[i]));
           	if TDataObject(Items[i]).State = [] then begin
	            TDataObject(Items[i]).Destroy;
			    OnSubObjectChangeUpdate(Self);
                bWasRemoved := TRUE;
                end
            else
            	inc(i);
        end;
		if bWasRemoved then
    		NotifyInternalUpdate;
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).Pack;
        end;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Load;
var
	i : integer;
begin
	LoadExists;
	with FSubObjects do
		for i := 0 to Count - 1 do
			if assigned(Items[i]) then
				TDataObject(Items[i]).Load;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Delete;
begin
	if dsDeleted in FState then
		State := State - [dsDeleted]
	else
		State := State + [dsDeleted];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Store;
var
	i : integer;
begin
	if not Updated then
		exit
	else if FState = [dsNew,dsUpdated] then
		InsertNew
	else if FState = [dsLoaded,dsUpdated] then
		UpdateExists
	else if FState >= [dsLoaded,dsDeleted] then
		DeleteExists;

	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).Store;
        end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.StartTransaction;
var
	i : integer;
begin
	FSavedState := FState;
	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).StartTransaction;
        end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Commit;
var
	i : integer;
begin
	FSavedState := [];
	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).Commit;
        end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Rollback;
var
	i : integer;
begin
	FState := FSavedState;
	with FSubObjects do
		for i := 0 to Count - 1 do begin
			ASSERT(assigned(Items[i]));
			TDataObject(Items[i]).Rollback;
        end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
procedure TDataObjectsSet.SetSubObjectsCount(ACount : integer);
var
    i : integer;
begin
	ASSERT(assigned(FClass));
    with FSubObjects do
		for i := 0 to ACount - Count - 1 do
			FClass.Create(Self);
end;

////////////////////////////////////////////////////////////////////////////////
function TDataObjectsSet.GetSubObject(AIndex : integer) : TDataObject;
begin
	Result := TDataObject(FSubObjects.Items[AIndex]);
    ASSERT(assigned(Result));
	ASSERT(assigned(FClass));
	ASSERT(Result is FClass);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObjectsSet.Load;
var
	i : integer;
	Q : TQuery;
    NewObject : TDataObject;
begin
	Q := LoadingQuery;
    ASSERT(assigned(FClass));
    ASSERT(assigned(Q));
    ASSERT(Q.Active);
    ASSERT(Q.UniDirectional = FALSE);
    ASSERT(Q.CanModify = FALSE);
    ClearSubObjects;
    with Q do
    	try
        	while not EOF do begin
		    	NewObject := FClass.Create(Self);
                with NewObject do begin
        	    	LoadExists(Q);
					with FSubObjects do
						for i := 0 to Count - 1 do
							if assigned(Items[i]) then
								TDataObject(Items[i]).Load;
                end;
				Next;
			end;
        finally
        	Close;
            Destroy;
	    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObjectsSet.Delete(ASubObject : TDataObject);
begin
	ASSERT(assigned(FClass));
	ASSERT(ASubObject is FClass);
    if ASubObject.State <> [] then
    	ASubObject.Delete
    else
		RemoveSubObject(ASubObject);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObjectsSet.Delete(AIndex : integer);
begin
	ASSERT(assigned(FSubObjects.Items[AIndex]));
    with TDataObject(FSubObjects.Items[AIndex]) do
    	if State <> [] then
        	Delete
        else
			Self.RemoveSubObject(AIndex);
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
procedure StoreObject;
begin
	try
		ADatabase.StartTransaction;
		AObject.StartTransaction;
		AObject.Store;
{$IFOPT C+}
        if AObject.Updated then begin
        	DumpDataObjects(AObject,'StoreObject FAILED : Update is still TRUE');
			ASSERT(FALSE);
        end;
{$ENDIF}
		ADatabase.Commit;
		AObject.Commit;
		AObject.Pack;
	except
		on e : Exception do begin
			AObject.Rollback;
			ADatabase.Rollback;
            raise;
		end;
	end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// Debug dump support
// Available only if option Assertions enabled

{$IFOPT C+}

////////////////////////////////////////////////////////////////////////////////
function IsDataObject;
begin
	ASSERT(assigned(TheDataObjects));
	Result := TheDataObjects.IndexOf(P) >= 0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TDataObject.Dump;
var
    s : ShortString;
begin
	WriteLn(AText,StringOfChar(#9,ALevel),'Self = ',IntToHex(integer(Self),8),'h');
    s := '';
    if dsNew in FState then s := s + 'dsNew,';
    if dsLoaded in FState then s := s + 'dsLoaded,';
    if dsUpdated in FState then s := s + 'dsUpdated,';
    if dsDeleted in FState then s := s + 'dsDeleted,';
    if s[Length(s)] = ',' then SetLength(s,Length(s)-1);
    WriteLn(AText,StringOfChar(#9,ALevel),'State = [',s,']');
end;

////////////////////////////////////////////////////////////////////////////////
procedure DumpDataObjects;
var
	T : Text;
    nLevel : integer;

	////////////////////////////////////////////////////////////////////////////
    procedure DumpObject(AObject : TDataObject);
    var
    	i : integer;
    begin
        WriteLn(T,StringOfChar('-',70));
        WriteLn(T,StringOfChar(#9,nLevel),AObject.ClassName);
        AObject.Dump(nLevel,T);
        if AObject.FSubObjects.Count > 0 then begin
            inc(nLevel);
            with AObject.FSubObjects do
                for i := 0 to Count - 1 do begin
                    ASSERT(assigned(Items[i]));
                    DumpObject(TDataObject(Items[i]));
                end;
            dec(nLevel);
        end;
    end;
	////////////////////////////////////////////////////////////////////////////

begin
	nLevel := 0;
    Assign(T,DumpFileName);
   	if FileExists(DumpFileName) then begin
   	  	Reset(T);
		Append(T);
		end
    else
       	Rewrite(T);

    if AComment <> '' then begin
        WriteLn(T,'');
        WriteLn(T,StringOfChar('*',70));
        WriteLn(T,#9,AComment);
        WriteLn(T,StringOfChar('*',70));
        WriteLn(T,'');
    end;

	DumpObject(AObject);

    CloseFile(T);
    if AShow then begin
    	WinExec('notepad.exe ' + DumpFileName,SW_SHOW);
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure CleanDump;
begin
   	if FileExists(DumpFileName) then
    	DeleteFile(DumpFileName);
end;

////////////////////////////////////////////////////////////////////////////////
procedure CheckUnReleasedObjects;
var
    i : integer;
begin
	ASSERT(assigned(TheDataObjects));
    with TheDataObjects do
    	if Count <> 0 then begin
        	for i := 0 to Count - 1 do
				DumpDataObjects(TDataObject(Items[i]),'Not released object !',FALSE);
		   	WinExec('notepad.exe ' + DumpFileName,SW_SHOW);
        end;
end;
{$ENDIF}
////////////////////////////////////////////////////////////////////////////////
procedure SetTagValue(const ATag, AValue : string; var S : string);
begin
	S := S + #19 + ATag + '='#16 + AValue + #17 + #13#10
end;

////////////////////////////////////////////////////////////////////////////////
function GetTagValue(const ATag, S : string) : string;
var
	B, nCount, i, nLevel : integer;
begin
	Result := '';
    B := Pos(#19 + ATag + '='#16,S);
    if B = 0 then
    	exit
    else
    	B := B + 1 + Length(ATag) + 2;
    ASSERT(S[B-1] = #16);
    nLevel := 1; nCount := 0;
    for i := B to Length(S) do begin
    	if S[i] = #16 then
        	inc(nLevel)
        else if S[i] = #17 then begin
            dec(nLevel);
            if nLevel = 0 then begin
            	nCount := i - B;
                break;
            end;
        end;
    end;
    ASSERT(nLevel = 0);
    Result := Copy(S,B,nCount);
end;

////////////////////////////////////////////////////////////////////////////////

function CanPasteDataObject : boolean;
begin
	Result := Clipboard.HasFormat(CF_DATA_OBJECT);
end;

////////////////////////////////////////////////////////////////////////////////
procedure CopyDataObject(const AObject : TDataObject);
var
	S : ANSIString;
    hData : THandle;
begin
	S := '';
	ASSERT(assigned(AObject));
    AObject.CopyToText(S);
    Clipboard.Open;
    try
    	hData := Windows.GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE,Length(S)+1);
        StrCopy(Windows.GlobalLock(hData),PChar(S));
        Windows.GlobalUnlock(hData);
        Clipboard.SetAsHandle(CF_DATA_OBJECT,hData);
{$IFOPT C+}
		// to be viewable trough standart Clipboard Viewer
    	hData := Windows.GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE,Length(S)+1);
        StrCopy(Windows.GlobalLock(hData),PChar(S));
        Windows.GlobalUnlock(hData);
        Clipboard.SetAsHandle(CF_TEXT,hData);
{$ENDIF}
    finally
    	Clipboard.Close;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure PasteDataObject(AObject : TDataObject);
var
	S : ANSIString;
    hData : THandle;
begin
	S := '';
    ASSERT(assigned(AObject));
	if not Clipboard.HasFormat(CF_DATA_OBJECT) then
    	exit;
    Clipboard.Open;
    try
    	hData := Clipboard.GetAsHandle(CF_DATA_OBJECT);
        if hData = NULL then
        	exit;
		S := StrPas(Windows.GlobalLock(hData));
        Windows.GlobalUnlock(hData);
    finally
    	Clipboard.Close;
    end;

    if Length(S) = 0 then
    	exit;

    try
		AObject.PasteFromText(S);
    except
    	on e : Exception do begin
{$IFOPT C+}
	       	DumpDataObjects(AObject,'PasteObject FAILED: ' + e.Message);
{$ENDIF}
    		AObject.Blank;
        end;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
initialization
	TheDataObjects := TList.Create;
	CF_DATA_OBJECT := RegisterClipboardFormat('CF_DATA_OBJECT');
    ASSERT(CF_DATA_OBJECT <> 0);

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
finalization
{$IFOPT C+}
	CheckUnReleasedObjects;
{$ENDIF}
    TheDataObjects.Destroy;
{$IFOPT C+}
    CleanDump;
{$ENDIF}

end.


unit HashBase;

interface

uses
  SysUtils, Classes,
  AuxTypes;

{===============================================================================
--------------------------------------------------------------------------------
                                   THashBase
--------------------------------------------------------------------------------
===============================================================================}

type
  EHASHException = class(Exception);

  EHASHNoStream = class(EHASHException);

{===============================================================================
    THashBase - class declaration
===============================================================================}
type
  THashBase = class(TObject)
  private
    fReadBufferSize:  TMemSize;   // used as size of read buffer when processing a stream
  protected
  {
    ProcessBuffer must be implemented in hash-specialized class.

    It must be able to accept buffer of any size and must be able to be called
    multiple times on consecutive data while producing an intermediate result.
  }
    procedure ProcessBuffer(const Buffer; Size: TMemSize); virtual; abstract;
  public
    // methods implemented here
    constructor Create;
    procedure Update(const Buffer; Size: TMemSize); virtual;           // only calls ProcessBuffer
    procedure Final(const Buffer; Size: TMemSize); overload; virtual;  // calls Update with passed data and unparametrized Final
    procedure HashBuffer(const Buffer; Size: TMemSize); virtual;
    procedure HashMemory(Memory: Pointer; Size: TMemSize); virtual;
    procedure HashStream(Stream: TStream; Count: Int64 = -1); virtual;
    procedure HashFile(const FileName: String); virtual;
    procedure HashFileInMemory(const FileName: String); virtual;
    procedure HashString(const Str: String); overload; virtual;
    procedure HashAnsiString(const Str: AnsiString); overload; virtual;
    procedure HashWideString(const Str: WideString); overload; virtual;
    Function Same(Hash: THashBase): Boolean; virtual;
  {
    Following methods must be implemented in final specialized classes,
    that is, in classes that implements a specific hash.

    Methods Init and Final can be partially implemented in common classes, so
    always call inherited.
  }
    procedure Init; virtual; abstract;
    procedure Final; overload; virtual; abstract;        
    Function AsString: String; virtual; abstract;
    procedure FromString(const Str: String); virtual; abstract;
    Function TryFromString(const Str: String): Boolean; virtual; abstract;
    procedure FromStringDef(const Str: String; const Default); virtual; abstract;
    Function Compare(Hash: THashBase): Integer; virtual; abstract;
    // properties
    property ReadBufferSize: TMemSize read fReadBufferSize write fReadBufferSize;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TStreamHash                                                                    
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TStreamHash - class declaration
===============================================================================}
type
  TStreamHash = class(THashBase);
{
  Stream hash does not contain any implementation because everything needed is
  already implemented in base class (THashBase).
}

{===============================================================================
--------------------------------------------------------------------------------
                                   TBlockHash                                   
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBlockHash - class declaration
===============================================================================}
type
  TBlockHash = class(THashBase)
  private
    fBlockSize:   TMemSize;
    fFirstBlock:  Boolean;    
    fTempBlock:   Pointer;
    fTempCount:   TMemSize; // how many bytes in temp block are passed from previous round
  protected
    procedure ProcessFirst(const Block); virtual; abstract;
    procedure ProcessBlock(const Block); virtual; abstract;
    procedure ProcessLast; virtual; abstract;
    procedure ProcessBuffer(const Buffer; Size: TMemSize); overload;
  public
    procedure Init; override;
    procedure Final; overload; override;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TBufferHash
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBufferHash - class declaration
===============================================================================}
type
  TBufferHash = class(THashBase);

implementation

uses
  Math,
  StrRect;

{===============================================================================
--------------------------------------------------------------------------------
                                   THashBase
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    THashBase - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    THashBase - public methods
-------------------------------------------------------------------------------}

constructor THashBase.Create;
begin
inherited Create;
fReadBufferSize := 1024 * 1024; // 1MiB
end;

//------------------------------------------------------------------------------

procedure THashBase.Update(const Buffer; Size: TMemSize);
begin
ProcessBuffer(Buffer,Size);
end;

//------------------------------------------------------------------------------

procedure THashBase.Final(const Buffer; Size: TMemSize);
begin
Update(Buffer,Size);
Final;
end;

//------------------------------------------------------------------------------

procedure THashBase.HashBuffer(const Buffer; Size: TMemSize);
begin
Init;
Final(Buffer,Size);
end;

//------------------------------------------------------------------------------

procedure THashBase.HashMemory(Memory: Pointer; Size: TMemSize);
begin
HashBuffer(Memory^,Size);
end;

//------------------------------------------------------------------------------

procedure THashBase.HashStream(Stream: TStream; Count: Int64 = -1);
var
  Buffer:     Pointer;
  BytesRead:  Integer;
begin
If Assigned(Stream) then
  begin
    Init;  
    If Count = 0 then
      Count := Stream.Size - Stream.Position;
    If Count < 0 then
      begin
        Stream.Seek(0,soBeginning);
        Count := Stream.Size;
      end;
    GetMem(Buffer,fReadBufferSize);
    try
      repeat
        BytesRead := Stream.Read(Buffer^,Min(fReadBufferSize,Count));
        Update(Buffer^,TMemSize(BytesRead));
        Dec(Count,BytesRead);
      until BytesRead < fReadBufferSize;
    finally
      FreeMem(Buffer,fReadBufferSize);
    end;
    Final;
  end
else raise EHASHNoStream.Create('THashBase.HashStream: Stream not assigned.');
end;

//------------------------------------------------------------------------------

procedure THashBase.HashFile(const FileName: String);
var
  FileStream: TFileStream;
begin
FileStream := TFileStream.Create(StrToRTL(FileName),fmOpenRead or fmShareDenyWrite);
try
  HashStream(FileStream);
finally
  FileStream.Free;
end;
end;

//------------------------------------------------------------------------------

procedure THashBase.HashFileInMemory(const FileName: String);
var
  FileStream: TMemoryStream;
begin
FileStream := TmemoryStream.Create;
try
  FileStream.LoadFromFile(StrToRTL(FileName));
  FileStream.Seek(0,soBeginning);
  HashStream(FileStream);
finally
  FileStream.Free;
end;
end;

//------------------------------------------------------------------------------

procedure THashBase.HashString(const Str: String);
begin 
HashMemory(PChar(Str),Length(Str) * SizeOf(Char));
end;

//------------------------------------------------------------------------------

procedure THashBase.HashAnsiString(const Str: AnsiString);
begin 
HashMemory(PAnsiChar(Str),Length(Str) * SizeOf(AnsiChar));
end;

//------------------------------------------------------------------------------

procedure THashBase.HashWideString(const Str: WideString);
begin 
HashMemory(PWideChar(Str),Length(Str) * SizeOf(WideChar));
end;

//------------------------------------------------------------------------------

Function THashBase.Same(Hash: THashBase): Boolean;
begin
Result := Compare(Hash) = 0;
end;

{===============================================================================
--------------------------------------------------------------------------------
                                   TBlockHash                                   
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TBlockHash - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TBlockHash - protected methods
-------------------------------------------------------------------------------}

end.

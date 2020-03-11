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
  protected
    fReadBufferSize:      TMemSize;   // used as a size of read buffer when processing a stream
    fProcessedBytes:      TMemSize;
  {
    ProcessBuffer is a main mean of processing the data and must be implemented
    in all hash-specialized classes.

    It must be able to accept buffer of any size (including the size of 0)
    and must be able to be called multiple times on consecutive data while
    producing an intermediate result.
  }
    procedure ProcessBuffer(const Buffer; Size: TMemSize); virtual; abstract;
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    // constructors, destructors
    constructor Create;
    constructor CreateAndInitFrom(Hash: THashBase); overload; virtual; abstract;
    constructor CreateAndInitFromString(const Str: String); virtual;
    destructor Destroy; override;
    // streaming methods
    procedure Init; virtual;
    procedure Update(const Buffer; Size: TMemSize); virtual;
    procedure Final(const Buffer; Size: TMemSize); overload; virtual;
    procedure Final; overload; virtual;
    // macro methods (note that these methods are calling Init at the start of processing)
    procedure HashBuffer(const Buffer; Size: TMemSize); virtual;
    procedure HashMemory(Memory: Pointer; Size: TMemSize); virtual;
    procedure HashStream(Stream: TStream; Count: Int64 = -1); virtual;
    procedure HashFile(const FileName: String); virtual;
    procedure HashString(const Str: String); virtual;
    procedure HashAnsiString(const Str: AnsiString); virtual;
    procedure HashWideString(const Str: WideString); virtual;
    // utility methods
    Function Compare(Hash: THashBase): Integer; virtual; abstract;
    Function Same(Hash: THashBase): Boolean; virtual;
    Function AsString: String; virtual; abstract;
    procedure FromString(const Str: String); virtual; abstract;
    Function TryFromString(const Str: String): Boolean; virtual;
    procedure FromStringDef(const Str: String; const Default); virtual; abstract;
    // streaming
    procedure SaveToStream(Stream: TStream); virtual; abstract;
    procedure LoadFromStream(Stream: TStream); virtual; abstract;
    // properties
    property ReadBufferSize: TMemSize read fReadBufferSize write fReadBufferSize;
    property ProcessedBytes: TMemSize read fProcessedBytes;
  end;

{===============================================================================
--------------------------------------------------------------------------------
                                  TStreamHash                                                                    
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TStreamHash - class declaration
===============================================================================}
{
  Stream hash does not contain any implementation because everything needed is
  already implemented in the base class (THashBase).

  Following methods must be overriden or reintroduced (marked with *):

      ProcessBuffer
      CreateAndInitFrom(THashBase)
      Final
      Compare
      AsString
      FromString
    * FromStringDef
      SaveToStream
      LoadFromStream

  Following function should also be overriden if the hash calculation
  requires it:

      Initialize
      Finalize
      Init
}
type
  TStreamHash = class(THashBase);

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
    fFinalized:   Boolean;
    fTempBlock:   Pointer;
    fTempCount:   TMemSize; // how many bytes in temp block are passed from previous round
  protected
  {
    ProcessFirst and ProcessLast can call ProcessBlock if first and/or last
    block processing does not differ from normal block.
    
    ProcessFirst sets fFirstBlock to false.

    ProcessLast takes data stored in temp block (if any), alters them if
    necessary and then processes them. It also produces final result.
  }
  {
    In this implementation only sets fFirstBlock to false.
    Must be overriden in descendats
  }
    procedure ProcessFirst(const Block); virtual;
    procedure ProcessLast; virtual; abstract;
    procedure ProcessBlock(const Block); virtual; abstract;
    procedure ProcessBuffer(const Buffer; Size: TMemSize); override;
  public
    procedure Init; override;
    procedure Final; overload; override;
    property BlockSize: TMemSize read fBlockSize;
    property FirstBlock: Boolean read fFirstBlock;
    property Finalized: Boolean read fFinalized;
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
    THashBase - protected methods
-------------------------------------------------------------------------------}

procedure THashBase.Initialize;
begin
fReadBufferSize := 1024 * 1024; // 1MiB
fProcessedBytes := 0;
end;

//------------------------------------------------------------------------------

procedure THashBase.Finalize;
begin
// nothing to do
end;

{-------------------------------------------------------------------------------
    THashBase - public methods
-------------------------------------------------------------------------------}

constructor THashBase.Create;
begin
inherited Create;
Initialize;
end;

//------------------------------------------------------------------------------

constructor THashBase.CreateAndInitFromString(const Str: String);
begin
Create;
Init;
FromString(Str);
end;

//------------------------------------------------------------------------------

destructor THashBase.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

procedure THashBase.Init;
begin
fProcessedBytes := 0;
end;

//------------------------------------------------------------------------------

procedure THashBase.Update(const Buffer; Size: TMemSize);
begin
ProcessBuffer(Buffer,Size);
Inc(fProcessedBytes,Size);
end;

//------------------------------------------------------------------------------

procedure THashBase.Final(const Buffer; Size: TMemSize);
begin
Update(Buffer,Size);
Final;
end;

//------------------------------------------------------------------------------

procedure THashBase.Final;
begin
// do nothing here
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

  Function Min(A,B: Int64): Int64;  // so there is no need to link Math unit
  begin
    If A < B then
      Result := A
    else
      Result := B;
  end;

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
      until TMemSize(BytesRead) < fReadBufferSize;
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
 
//------------------------------------------------------------------------------

Function THashBase.TryFromString(const Str: String): Boolean;
begin
try
  FromString(Str);
  Result := True;
except
  Result := False;
end;
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

procedure TBlockHash.ProcessFirst(const Block);
begin
fFirstBlock := False;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.ProcessBuffer(const Buffer; Size: TMemSize);
var
  RemainingSize:  TMemSize;
  WorkPtr:        Pointer;
  i:              Integer;  

  procedure DispatchBlock(const Block);
  begin
    If fFirstBlock then
      ProcessFirst(Block)
    else
      ProcessBlock(Block);
  end;

begin
If Size > 0 then
  begin
    If fTempCount > 0 then
      begin
        If (fTempCount + Size) >= fBlockSize then
          begin
            // data will fill, and potentially overflow, the temp block
            Move(Buffer,Pointer(PtrUInt(fTempBlock) + PtrUInt(fTempCount))^,fBlockSize - fTempCount);
            DispatchBlock(fTempBlock^);
            RemainingSize := Size - (fBlockSize - fTempCount);
            fTempCount := 0;
            If RemainingSize > 0 then
              ProcessBuffer(Pointer(PtrUInt(Addr(Buffer)) + PtrUInt(Size - RemainingSize))^,RemainingSize);
          end
        else
          begin
            // data will not fill the temp block, store end return
            Move(Buffer,Pointer(PtrUInt(fTempBlock) + PtrUInt(fTempCount))^,Size);
            Inc(fTempCount,Size);
          end;
      end
    else
      begin
        WorkPtr := Addr(Buffer);
        // process whole blocks
        For i := 1 to Integer(Size div fBlockSize) do
          begin
            DispatchBlock(WorkPtr^);
            WorkPtr := Pointer(PtrUInt(WorkPtr) + PtrUInt(fBlockSize));
          end;
        // store partial block
        fTempCount := Size mod fBlockSize;
        If fTempCount > 0 then
          Move(WorkPtr^,fTempBlock^,fTempCount);
      end;
  end;
end;

{-------------------------------------------------------------------------------
    TBlockHash - public methods
-------------------------------------------------------------------------------}

procedure TBlockHash.Init;
begin
inherited;
fFirstBlock := True;
fFinalized := False;
FillChar(fTempBlock^,fBlockSize,0);
fTempCount := 0;
end;

//------------------------------------------------------------------------------

procedure TBlockHash.Final;
begin
ProcessLast;
fFinalized := True;
end;

end.

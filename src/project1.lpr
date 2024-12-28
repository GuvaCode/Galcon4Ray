program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp, raylib, raymath, rlgl, UGame;

const
  levelData: array[0..11, 0..2] of single = (
  // nodes, teams, ai delay
    (5, 2, 3),
    (6, 2, 3.5),
    (8, 2, 3),
    (10, 2, 3),
    (9, 3, 4),
    (12, 3, 3.5),
    (15, 3, 3),
    (6, 3, 2.5),
    (16, 4, 3),
    (18, 4, 2.5),
    (12, 4, 2),
    (20, 4, 1.5)
    );


type
  { TTween }
  TTween = class
  private
    FDelay: Cardinal;
    FAnimate: Boolean;
    FAlpha: single;
    FColor: Cardinal;
    FFadeOut: Boolean;
    FStart: Cardinal;
    FVisible: Boolean;
    FOnAnimationEnd: TNotifyEvent;
  public
    procedure Show(const color: Cardinal);
    procedure Hide(Delay: Cardinal = 0);

    procedure Animate;

    property Alpha: single read FAlpha;
    property Color: Cardinal read FColor;
    property Visible: Boolean read FVisible;
    property OnAnimationEnd: TNotifyEvent read FOnAnimationEnd write FOnAnimationEnd;
  end;

  { TRayApplication }
  TRayApplication = class(TCustomApplication, IDisplay)
  protected
    procedure DoRun; override;
  private
    FLevel: integer;

    FMouseDown: Boolean;
    FGame: TGameScene;
    FTween: TTween;

    FMusic: TMusic;

    FPing1Array: array[0..9] of TSound;
    FPing1Count: Cardinal;
    FPing2Array: array[0..10] of TSound;
    FPing2Count: Cardinal;

    procedure GetMouse(out x, y: single);
    procedure GetDimension(out Width, Height: single);
    procedure DoAnimationEnd(Sender: TObject);

    procedure DrawLine(x1, y1, x2, y2: single; color: cardinal;
      thickness: single = 2; alpha: single = 1);

    procedure DrawCircle(x, y, outer_radius, inner_radius: single;
      color: cardinal; glow: Boolean = false; alpha: single = 1.0;
      segments: integer = 32);

    procedure SetLevel(const ALevel: integer);
    procedure PlaySound(const sample: string);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure StartGame;
    procedure MouseDown;
    Procedure MouseUp;
    procedure UpdateMouse;
  end;

  const AppTitle = 'raylib - basic window';

{ TTween }

procedure TTween.Show(const color: Cardinal);
begin
  FColor := color;
  FFadeOut := false;
  FStart := 0;
  FAnimate := true;
  FVisible := true;
  FDelay := 0;
end;

procedure TTween.Hide(Delay: Cardinal);
begin
  FFadeOut := true;
  FStart := 0;
  FAnimate := true;
  FDelay := Delay;
end;

procedure TTween.Animate;
begin
  if not FVisible then
    exit;
  if not FAnimate then
    exit;

  if FDelay > 0 then
  begin
    FDelay := FDelay - 1;
    exit;
  end;

  if FFadeOut then
    FAlpha := FAlpha - 0.1
  else
    FAlpha := FAlpha + 0.1;

  if FAlpha >= 1 then
  begin
    FAnimate := false;
    FAlpha := 1;
    if assigned(FOnAnimationEnd) then
      FOnAnimationEnd(self);
  end;

  if FAlpha < 0 then
  begin
    FAnimate := false;
    FVisible := false;
    if assigned(FOnAnimationEnd) then
      FOnAnimationEnd(self);
  end;
end;

{ TRayApplication }

constructor TRayApplication.Create(TheOwner: TComponent);
var i: integer; //tmpSound: array [1..6] of TSound;
begin
  inherited Create(TheOwner);

  InitWindow(GetScreenWidth, GetScreenHeight, AppTitle); // for window settings, look at example - window flags
  ToggleFullscreen;

  SetTargetFPS(60); // Set our game to run at 60 frames-per-second
  FTween := TTween.Create;
  FTween.OnAnimationEnd := @DoAnimationEnd;
  FGame := TGameScene.create(self);

  InitAudioDevice();      // Initialize audio device

  FPing1Array[0] := LoadSound(PChar('resources/sfx/ping01.mp3'));
  for i := 1 to 9 do FPing1Array[i] := LoadSoundAlias(FPing1Array[0]);

  FPing2Array[0] := LoadSound(PChar('resources/sfx/launch01.mp3'));
  for i := 1 to 9 do FPing2Array[i] := LoadSoundAlias(FPing2Array[0]);

  FMusic := LoadMusicStream('resources/sfx/chromag_-_starship.xm');

  PlayMusicStream(FMusic);

  FLevel := 0;
  StartGame;

end;

procedure TRayApplication.DoRun;

begin

  while (not WindowShouldClose) do // Detect window close button or ESC key
  begin
  // Update
  //tick := round(GetTime);//GetTickCount;
  //FGame.Update((tick - FLastTick) / 1000);
  //FLastTick := tick;
  FGame.Update(GetFrameTime);
  UpdateMusicStream(FMusic);      // Update music buffer with new stream data

  if (FGame.GameOver) and (not FTween.Visible) then
  FTween.Show(gamecolors[FGame.TeamWon]);

  MouseUp;
  MouseDown;
    // Draw
    BeginDrawing();
      ClearBackground(BLACK);

      Fgame.Render;

  if Ftween.Visible then
  begin
    FTween.Animate;
    //DrawQuad(0, 0, ClientWidth, ClientHeight, FTween.Color, FTween.Alpha);
  end;
    //  DrawText('Congrats! You created your first window!', 190, 200, 20, LIGHTGRAY);
    DrawFps(10,10);
    EndDrawing();
  end;

  // Stop program loop
  Terminate;
end;

procedure TRayApplication.GetMouse(out x, y: single);
begin
  X := GetMousePosition.X;
  Y := GetMousePosition.Y;
end;

procedure TRayApplication.GetDimension(out Width, Height: single);
begin
  Width := GetScreenWidth;
  Height := GetScreenHeight;
end;

procedure TRayApplication.DoAnimationEnd(Sender: TObject);
begin
  if FTween.Visible then
  begin
    FTween.Hide(20);
    if FGame.TeamWon = 1 then inc(FLevel);
    StartGame;
  end;
end;

procedure TRayApplication.DrawLine(x1, y1, x2, y2: single; color: cardinal;
  thickness: single; alpha: single);
var
  a, r, g, b: Byte;
begin

 a := ((Color shr 24) and $FF);// div 255;
 if (a <= 0) then  exit;

 if alpha < 1 then
   a := a * Trunc(alpha);

 if alpha > 1 then  a := Trunc(alpha);

 r := ((Color shr 16) and $FF);// div 255;
 g := ((Color shr 8) and $FF);// div 255;
 b := ((Color and $FF));// div 255;

 DrawLineEX(Vector2Create(x1,y1),Vector2Create(x2,y2), thickness, ColorCreate(r,g,b,a));
end;



procedure TRayApplication.drawCircle(x, y, outer_radius, inner_radius: single;
  color: cardinal; glow: Boolean; alpha: single; segments: integer);
var
  a, r, g, b: byte;
begin
  a := ((Color shr 24) and $FF);// * 255;

 if (a <= 0) then
  exit;

  if alpha < 1 then
    a := a * trunc(alpha);

  r := ((Color shr 16) and $FF);// div 255;
  g := ((Color shr 8) and $FF);// div 255;
  b := ((Color and $FF));// div 255;


  BeginBlendMode(0);
  if glow then
  DrawRing(Vector2Create(x,y),outer_radius , inner_radius ,0, 360, segments, ColorCreate(r,g,b,100))
  else
  DrawRing(Vector2Create(x,y),outer_radius , inner_radius ,0, 360, segments, ColorCreate(r,g,b,a));
 EndBlendMode;

end;



procedure TRayApplication.SetLevel(const ALevel: integer);
begin
  FLevel := ALevel;
  if (FLevel < high(levelData)) then
    StartGame;
end;

procedure TRayApplication.PlaySound(const sample: string);
begin
  if (sample = 'ping01') then
  begin
    if not IsSoundPlaying(FPing1Array[FPing1Count]) then
    begin
      Raylib.PlaySound(FPing1Array[FPing1Count]);
      inc(FPing1Count);
      if FPing1Count >= 10 then FPing1Count := 0;
    end;
  end;

  if (sample = 'ping02') then
  begin
    if not IsSoundPlaying(FPing2Array[FPing2Count]) then
    begin
      Raylib.PlaySound(FPing2Array[FPing2Count]);
      inc(FPing2Count);
      if FPing2Count >= 10 then FPing2Count := 0;
    end;
  end;
end;

destructor TRayApplication.Destroy;
begin
  // De-Initialization
  CloseWindow(); // Close window and OpenGL context

  // Show trace log messages (LOG_DEBUG, LOG_INFO, LOG_WARNING, LOG_ERROR...)
  TraceLog(LOG_INFO, 'your first window is close and destroy');

  inherited Destroy;
end;

procedure TRayApplication.StartGame;
begin
  FLevel :=10;
  FGame.Init(trunc(levelData[FLevel][0]), trunc(levelData[FLevel][1]),
    trunc(levelData[FLevel][2]));
end;

procedure TRayApplication.MouseDown;
var
  node: TNode; xx,yy: single;
begin
  GetMouse(xx,yy);
  if IsMouseButtonDown(MOUSE_BUTTON_LEFT) then
  begin
    FMouseDown := true;
    node := FGame.getClosestNode(GetMousePosition.X,GetMousePosition.Y);
    if assigned(node) and ((node.team = 1) or (node.captureTeam = 1)) then
    node.selected := true;
  end;
end;

procedure TRayApplication.MouseUp;
begin
  if IsMouseButtonUp(MOUSE_BUTTON_LEFT) then
  begin
    FMouseDown := false;
    FGame.sendShips();
  end;
end;

procedure TRayApplication.UpdateMouse;
begin

end;

var
  Application: TRayApplication;
begin
  Application:=TRayApplication.Create(nil);
  Application.Title:=AppTitle;
  Application.Run;
  Application.Free;
end.


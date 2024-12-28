{$mode Delphi}{$H+}
{ .$DEFINE GENERICS }
unit UGame;

interface

uses Classes, SysUtils, raylib, rayMath;

const
  gamecolors: Array [0 .. 4] of cardinal = ($FFFFFFFF, $FF0065C3, $FFB70027,
    $FF248A00,$FFFFCB00);


type

  { IDisplay }

  IDisplay = interface
    ['{A3E82C50-78B7-49CE-BAE6-AF064058C21C}']
    procedure DrawLine(x1, y1, x2, y2: single; color: cardinal;
      thickness: single = 2; alpha: single = 1);

    procedure DrawCircle(x, y, outer_radius, inner_radius: single;
      color: cardinal; glow: Boolean = false; alpha: single = 1.0;
      segments: integer = 64);

    procedure GetMouse(out x, y: single);
    procedure GetDimension(out Width, Height: single);
    procedure PlaySound(const sample: String);
  end;

  TGameScene = class;
  TGameEntity = class;
  TShip = class;
  TTrail = class;
  TAI = class;
  TNode = class;

  TNodeSort = class
    node: TNode;
    tlDist: single;
    blDist: single;
    trDist: single;
    brDist: single;
    midDist: single;

    constructor create(const node: TNode);
  end;

  TNodeList = TList;
  TShipList = TList;
  TNodeSorter = TList;
  TTrailList = TList;
  TAIList = TList;

  TGameEntity = class
  private
    FGame: TGameScene;
  public
    constructor Create(const Game: TGameScene);
    function Update(const dt: single): Boolean; virtual; abstract;
    property Game: TGameScene read FGame;
  end;

  TNode = class(TGameEntity)
  private
    FSize: single;
    FBaseSize: single;
  public
    x, y: single;
    energy: single;
    satCount: integer;
    team: integer;
    captureTeam: integer;
    selected: Boolean;
    aiVal: single;
    constructor create(const Game: TGameScene; const x, y, size: single);
    function Update(const dt: single): Boolean; override;
    procedure hit(const ship: TShip);

    procedure SetSize(const Value: single);

    property BaseSize: single read FBaseSize;
    property size: single read FSize;
  end;

  TShip = class(TGameEntity)
  public
    x: single;
    y: single;
    deltaX: single;
    deltaY: single;
    speed: single;
    rotation: single;
    energy: single;

    team: integer;
    target: TNode;

    trailTimer: single;
    lastTrail: TTrail;

    constructor create(const node: TNode; target: TNode);
    function Update(const dt: single): Boolean; override;
  end;

  TTrail = class(TGameEntity)
  public
    x: single;
    y: single;
    Width: single;
    rotation: single;
    alpha: single;
    color: cardinal;
    prev: TTrail;
    constructor create(const Game: TGameScene; const x, y: single;
      const color: cardinal);
    function Update(const dt: single): Boolean; override;
  end;

  TAI = class(TGameEntity)
  private
    procedure DoSort(const List: TNodeList);
  public
    team: integer;
    timer: single;
    targets: TNodeList;
    assets: TNodeList;
    delay: single;

    constructor create(const Game: TGameScene; team: integer;
      delay: single = 2.0);
    destructor Destroy; override;
    function Update(const dt: single): Boolean; override;
  end;

  { TStar }

  TStar = class
  private
    X: Single;//Integer;
    Y: Single;//Integer;
    StarLayer: Byte;
  public
    procedure Moved(dt: Single; Rect: TRectangle);
  end;

  { TStarField }

  TStarField = class
  private
    Stars: array of TStar;
    StarCount: Integer;
    ClientRect: TRectangle;
  public
    constructor Create(StarCnt: Integer; Rect: TRectangle);
    destructor Destroy; override;
    procedure Move(dt: Single);
    procedure Render;
  end;

  { TGameScene }

  TGameScene = class
  private
    nodes: TNodeList;
    ships: TShipList;
    trails: TTrailList;
    ais: TAIList;
    FDisplay: IDisplay;

    FStar: TStarField;

    l:array [1..3]of single;
    k,u:array [1..3]of real;

    FShipTexture: array [1..4] of TTexture2d;
    FTilesTexture: TTexture2d;
    FSatTexture: TTexture2d;


    FHoverNode: TNode;
    FGameover: Boolean;
    FTeamWon: integer;

    procedure drawNodes();
    procedure drawShips();
    procedure drawTrails();
    procedure drawMeter();
    procedure drawTiles();
    procedure drawStar();

    procedure initNodes(const num: integer);
    procedure initTeams(const num: integer; const delay: single);

    procedure checkGameOver();

    function addTrail(const x, y: single; const color: cardinal): TTrail;
    function addShip(const node, target: TNode): TShip;
    function addNode(const x, y, size: single): TNode;
    function addAI(const team: integer; const delay: single): TAI;

    function moveShips(const node, target: TNode): integer;

    function overlap(const x, y: single): Boolean;

    procedure Reset;
  public


    constructor Create(const Display: IDisplay);
    destructor Destroy; override;

    procedure Init(const nodes, teams: integer;const aidelay: single);

    procedure sendShips();
    function getClosestNode(const x, y: single): TNode;

    procedure Update(const passedTime: single);
    procedure Render;

    procedure PlayPing01;
    procedure playPing02;
    procedure PlayHit;

    property GameOver: Boolean read FGameover;
    property TeamWon: integer read FTeamWon;
  end;

implementation

uses Math;

{ TGameEntity }
constructor TGameEntity.create(const Game: TGameScene);
begin
  FGame := Game;
end;

{ TNode }
constructor TNode.create(const Game: TGameScene; const x, y, size: single);
begin
  inherited create(Game);
  self.x := x;
  self.y := y;
  SetSize(size);
  self.satCount := GetRandomValue(0,3);
  team := 0;
  captureTeam := 0;
  energy := 0;
  selected := false;
end;

function TNode.Update(const dt: single): Boolean;
begin
  result := false;
  if (team > 0) and (energy < 1.0) then
  begin
    energy := energy + dt * 0.2;
    if (energy > 1.0) then
      energy := 1.0;
  end;
  if (FSize > FBaseSize) then
  begin
    FSize := FSize - dt * 0.5;
    if (FSize < FBaseSize) then
      FSize := FBaseSize;
  end;
end;

procedure TNode.SetSize(const Value: single);
begin
  FSize := Value;
  FBaseSize := Value;
end;

procedure TNode.hit(const ship: TShip);
begin
  if (team = 0) then
  begin
    if (captureTeam = ship.team) then
    begin
      energy := energy + ship.energy;
      if (energy >= 1.0) then
      begin
        energy := 1.0;
        team := ship.team;
        FGame.PlayPing01();
      end
    end
    else
    begin
      if (energy = 0) then
      begin
        energy := energy + ship.energy;
        captureTeam := ship.team;
      end
      else
      begin
        energy := energy - ship.energy;
        if (energy <= 0) then
        begin
          energy := 0;
          captureTeam := ship.team;
        end;
      end;
    end
  end
  else
  begin
    if (team = ship.team) then
    begin
      energy := energy + ship.energy;
      if (energy >= 1.0) then
      begin
        energy := 1.0;
						// size := size + ship.energy*0.5;
        FSize := FSize + ship.energy * (BaseSize / FSize) * 0.5;
      end;
    end
    else
    begin
      energy := energy - ship.energy;
      if (energy <= 0) then
      begin
        energy := 0;
        team := ship.team;
        FGame.PlayPing01();
      end;
    end;
  end;
  FGame.PlayHit();
end;

{ TShip }
constructor TShip.create(const node: TNode; target: TNode);
begin
  inherited create(node.Game);
  self.x := node.x;
  self.y := node.y;
  self.target := target;
  self.team := node.team;
  self.energy := 0.04;
  speed := 150;

  trailTimer := 0;
  lastTrail := nil;

  rotation := random(100) / 100 * PI * 2;
  deltaX := cos(rotation) * (100 + random(100));
  deltaY := sin(rotation) * (100 + random(100));
end;

function TShip.Update(const dt: single): Boolean;
var
  dx, dy, dist: single;
  angle: single;
begin
   result := false;

  dx := target.x - x;
  dy := target.y - y;
  dist := sqrt(dx * dx + dy * dy);

  if (dist > target.size * 50 + 4) then
  begin
    x := x + deltaX * dt;
    y := y + deltaY * dt;
    deltaX := deltaX - deltaX * dt * 1.2;
    deltaY := deltaY - deltaY * dt * 1.2;

    angle := arctan2(dy, dx);
    deltaX := deltaX + cos(angle) * speed * dt;
    deltaY := deltaY + sin(angle) * speed * dt;
    rotation := Vector2AngleDeg( Vector2Create(x, y) , Vector2Create(target.x,  target.y ));
  end
  else
  begin
    target.hit(self); // targeeeet
    result := true; // Remove
  end;

  if assigned(lastTrail) then
  begin
    dx := self.x - lastTrail.x;
    dy := self.y - lastTrail.y;
    dist := sqrt(dx * dx + dy * dy);
    angle := arctan2(dy, dx);
    lastTrail.Width := dist;
    lastTrail.rotation := angle;
  end;

  trailTimer := trailTimer - dt;
  if (trailTimer <= 0) then
  begin
    lastTrail := Game.addTrail(x, y, gamecolors[team]);
    trailTimer := 0.1;
  end;
end;

{ TTrail }
constructor TTrail.create(const Game: TGameScene; const x, y: single;
  const color: cardinal);
begin
  inherited create(Game);
  self.x := x;
  self.y := y;
  self.color := color;
  Width := 0;
  rotation := 0;
  alpha := 255.0;
end;

function TTrail.Update(const dt: single): Boolean;
begin
  result := false;
  Alpha := (Alpha - 5);

  if (Round(alpha) <= 0) then
  begin
    alpha := 0;
    Width := 0;
    rotation := 0;
    result := true;
  end;
end;

{ TAI }
constructor TAI.create(const Game: TGameScene; team: integer;
  delay: single = 2.0);
begin
  inherited create(Game);
  self.team := team;
  self.delay := delay;
  timer := delay + random(100) / 100 * delay;

  targets := TNodeList.create;
  assets := TNodeList.create;
end;

destructor TAI.Destroy;
begin
  targets.free;
  assets.free;
  inherited;
end;

function LevelSortCompare(e0, e1: Pointer): integer;
begin
  if (TNode(e1).y < TNode(e1).y) then
    Result := 1
  else if (TNode(e1).y > TNode(e0).y) then
    Result := -1
  else
    Result := 0;
end;

procedure TAI.DoSort(const List: TNodeList);
begin
   List.Sort(LevelSortCompare);
end;

function TAI.Update(const dt: single): Boolean;
var
  localX, localY: single;
  nodes: TNodeList;
  asset, target: TNode;
  num, i: integer;
  node: TNode;
  dx, dy, dist: single;
  needed: integer;
  sent: integer;
begin
  timer := timer - dt;
  result := false;
  if (timer <= 0) then
  begin
				// get local center
    localX := 0;
    localY := 0;
    nodes := Game.nodes;
    num := 0;
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team = team) then
      begin
        localX := localX + node.x;
        localY := localY + node.y;
        inc(num);
      end;
    end;
    if num > 0 then
    begin
      localX := localX / num;
      localY := localY / num;
    end;

    targets.Clear;
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team <> team) then
      begin
        dx := node.x - localX;
        dy := node.y - localY;
        dist := sqrt(dx * dx + dy * dy);
        if (node.team <> 0) then
          node.aiVal := dist + random(100)
        else
          node.aiVal := dist;
        targets.Add(node);
      end;
    end;
    DoSort(targets);

    assets.Clear;
    if targets.Count > 0 then
    begin
      target := targets[0];
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        if (node.team = team) then
        begin
          dx := node.x - target.x;
          dy := node.y - target.y;
          dist := sqrt(dx * dx + dy * dy);
          node.aiVal := -node.size * node.energy + dist * 0.01;
          assets.Add(node);
        end;
      end;
      DoSort(assets);

      needed := trunc(target.size * 50);
      for i := assets.Count - 1 downto 0 do
        if needed > 0 then
        begin
          asset := assets[i];
          sent := Game.moveShips(asset, target);
          needed := needed - sent;
        end;
    end;

    timer := delay + random(100) / 100 * delay;
  end;
end;

{ TStar }

procedure TStar.Moved(dt: Single; Rect: TRectangle);
begin
  case StarLayer of
    1: X := X + dt;
    2: X := X + dt * 2;
    3: X := X + dt * 4;
   end;

   if (X > Rect.Width) then
   begin
     X:= Rect.x;
     Y:= Rect.y + Random(Round(Rect.Height));
   end;
end;

{ TStarField }

constructor TStarField.Create(StarCnt: Integer; Rect: TRectangle);
var
  Loop: Integer;
  Layer: Byte;
begin
  ClientRect := Rect;
  StarCount := StarCnt;
  SetLength(Stars, StarCount);
  Layer := 1;
  for Loop := 0 to StarCount - 1 do begin
    Stars[Loop] := TStar.Create;
    with Stars[Loop] do begin
      StarLayer := Layer;
       X := Random(Round(ClientRect.Width));
       Y := Rect.y + (2 * ClientRect.Height);
       Inc(Layer);
       if Layer > 3 then
         Layer := 1;
     end;
   end;
end;

destructor TStarField.Destroy;
var
  Loop: Integer;
begin
  for Loop := 0 to StarCount - 1 do
    Stars[Loop].Free;
  inherited Destroy;
end;

procedure TStarField.Move(dt: Single);
var Loop: Integer;
begin
  for Loop := 0 to StarCount - 1 do Stars[Loop].Moved(dt, ClientRect);
end;

procedure TStarField.Render;
var Loop: Integer;
begin
  for Loop := 0 to StarCount - 1 do
    DrawRectangle(Round(Stars[Loop].X),Round(Stars[Loop].Y),2,2,DARKBLUE);///ColorCreate($FF, $FF, $FF, Random($FF) or $70));
   // DrawPixel(Round(Stars[Loop].X),Round(Stars[Loop].Y),RAYWHITE);//ColorCreate($FF, $FF, $FF, Random($FF) or $70));
end;

{ TNodeSort }
constructor TNodeSort.create(const node: TNode);
begin
  self.node := node;
end;

{ TGameScene }
procedure TGameScene.Init(const nodes, teams: integer;const aidelay: single);
begin
  Reset;
  FGameover := false;
  initNodes(nodes);
  initTeams(teams, aidelay);
end;

procedure TGameScene.initNodes(const num: integer);
var
  i: integer;
  x, y, size: single;
  W, H: single;
  overflow: integer;
begin
  FDisplay.GetDimension(W, H);
  for i := 0 to num - 1 do
  begin
    x := random(trunc(W) - 100) + 50;
    y := random(trunc(H) - 100) + 50;
    size := random(100) / 100 * 0.5 + 0.3;
    overflow := 0;
    while (overlap(x, y)) and (overflow < 1000) do
    begin
      x := random(trunc(W) - 100) + 50;
      y := random(trunc(H) - 100) + 50;
      inc(overflow);
    end;
    if (overflow < 1000) then
      addNode(x, y, size);
  end;
end;


var TeamNodeSort : integer;

function TeamSortComparer(e0, e1: Pointer): integer;
begin
        result := 0;
        case TeamNodeSort of
          0:
            if (TNodeSort(e1).blDist < TNodeSort(e0).blDist) then
              result := 1
            else if (TNodeSort(e1).blDist > TNodeSort(e0).blDist) then
              result := -1;
          1:
            if (TNodeSort(e1).trDist < TNodeSort(e0).trDist) then
              result := 1
            else if (TNodeSort(e1).trDist > TNodeSort(e0).trDist) then
              result := -1;
          2:
            if (TNodeSort(e1).midDist < TNodeSort(e0).midDist) then
              result := 1
            else if (TNodeSort(e1).midDist > TNodeSort(e0).midDist) then
              result := -1;
          3:
            if (TNodeSort(e1).tlDist < TNodeSort(e0).tlDist) then
              result := 1
            else if (TNodeSort(e1).tlDist > TNodeSort(e0).tlDist) then
              result := -1;
          4:
            if (TNodeSort(e1).brDist < TNodeSort(e0).brDist) then
              result := 1
            else if (TNodeSort(e1).brDist > TNodeSort(e0).brDist) then
              result := -1;
        end;
end;


procedure TGameScene.initTeams(const num: integer; const delay: single);
var
  dx, dy: single;
  i: integer;
  node: TNode;
  sorter: TNodeSorter;
  sortNode: TNodeSort;

  procedure DoSort(const Value: integer);
  begin
    TeamNodeSort := Value;
    sorter.Sort(TeamSortComparer);
  end;

var
  W, H: single;
  obj: TObject;
begin
  sorter := TNodeSorter.create;
  FDisplay.GetDimension(W, H);
  try
    if (num = 2) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := 0;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
    end
    else if (num = 3) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := node.y - H;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W * 0.5;
        dy := node.y - H * 0.5;
        sortNode.midDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(2);
      TNodeSort(sorter[0]).node.team := 3;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
      addAI(3, delay);
    end
    else if (num = 4) then
    begin
      for i := 0 to nodes.Count - 1 do
      begin
        node := nodes[i];
        sortNode := TNodeSort.create(node);
        dx := node.x - 0;
        dy := node.y - 0;
        sortNode.tlDist := sqrt(dx * dx + dy * dy);
        dx := node.x - 0;
        dy := node.y - H;
        sortNode.blDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - 0;
        sortNode.trDist := sqrt(dx * dx + dy * dy);
        dx := node.x - W;
        dy := node.y - H;
        sortNode.brDist := sqrt(dx * dx + dy * dy);
        sorter.Add(sortNode);
      end;

      DoSort(0);
      TNodeSort(sorter[0]).node.team := 1;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(3);
      TNodeSort(sorter[0]).node.team := 2;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(1);
      TNodeSort(sorter[0]).node.team := 3;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      DoSort(4);
      TNodeSort(sorter[0]).node.team := 4;
      TNodeSort(sorter[0]).node.SetSize(0.5);

      addAI(2, delay);
      addAI(3, delay);
      addAI(4, delay);
    end;
  finally
    for i := 0 to sorter.Count - 1 do
    begin
      obj := sorter[i];
      FreeAndNil(obj);
    end;
    sorter.free;
  end;
end;

function TGameScene.overlap(const x, y: single): Boolean;
var
  i: integer;
  node: TNode;
  dx, dy, dist: single;
begin
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    dx := node.x - x;
    dy := node.y - y;
    dist := sqrt(dx * dx + dy * dy);
    if (dist < 100) then
    begin
      result := true;
      exit;
    end;
  end;
  result := false;
end;

procedure TGameScene.checkGameOver();
var
  i: integer;
  node: TNode;
  activeTeams: Array of integer;
  ship: TShip;

  function Search(const team: integer): integer;
  var
    i: integer;
  begin
    for i := 0 to high(activeTeams) do
      if activeTeams[i] = team then
      begin
        result := i;
        exit;
      end;
    result := -1;
  end;

begin
  Setlength(activeTeams, 0);
  try
    for i := 0 to nodes.Count - 1 do
    begin
      node := nodes[i];
      if (node.team > 0) and (Search(node.team) = -1) then
      begin
        Setlength(activeTeams, length(activeTeams) + 1);
        activeTeams[high(activeTeams)] := node.team;
      end;
    end;

    for i := 0 to ships.Count - 1 do
    begin
      ship := ships[i];
      if (ship.team > 0) and (Search(ship.team) = -1) then
      begin
        Setlength(activeTeams, length(activeTeams) + 1);
        activeTeams[high(activeTeams)] := ship.team;
      end;
    end;

    if high(activeTeams) = 0 then
    begin
      FGameover := true;
      FTeamWon := activeTeams[0];
    end;
  finally
    Setlength(activeTeams, 0);
  end;
end;

function TGameScene.moveShips(const node, target: TNode): integer;
var
  num, j: integer;
begin
  result := 0;
  if (node = target) then
    exit;
  num := trunc(node.size * node.energy * 50);
  for j := 0 to num - 1 do
    addShip(node, target);
  node.energy := 0;
  playPing02();

  result := num;
end;

function TGameScene.addNode(const x, y, size: single): TNode;
begin
  result := TNode.create(self, x, y, size);

  nodes.Add(result);
end;

function TGameScene.addShip(const node, target: TNode): TShip;
begin
  result := TShip.create(node, target);
  ships.Add(result);
end;

function TGameScene.addTrail(const x, y: single; const color: cardinal): TTrail;
begin
  result := TTrail.create(self, x, y, color);
  trails.Add(result);
end;

function TGameScene.addAI(const team: integer; const delay: single): TAI;
begin
  result := TAI.create(self, team, delay);
  ais.Add(result);
end;

procedure TGameScene.Update(const passedTime: single);
var
  dt: single;
  i: integer;
  x, y: single;
  node: TNode;
  ship: TShip;
  trail: TTrail;
  ai: TAI;
begin
  FDisplay.GetMouse(x, y);
  FHoverNode := getClosestNode(x, y);

  dt := passedTime;
// juggler.advanceTime(dt);
  dt := dt * 0.5;

  for i := nodes.Count - 1 downto 0 do
  begin
    node := nodes[i];
    if node.Update(dt) then
    begin
      FreeAndNil(node);
      nodes.Delete(i);
    end;
  end;

  for i := ships.Count - 1 downto 0 do
  begin
    ship := ships[i];
    if ship.Update(dt) then
    begin
      FreeAndNil(ship);
      ships.Delete(i);
    end;
  end;

  for i := trails.Count - 1 downto 0 do
  begin
    trail := trails[i];
    if trail.Update(dt) then
    begin
      FreeAndNil(trail);
      trails.Delete(i);
    end;
  end;

  for i := ais.Count - 1 downto 0 do
  begin
    ai := ais[i];
    if ai.Update(dt) then
    begin
      FreeAndNil(ai);
      ais.Delete(i);
    end;
  end;

  if (not FGameover) then
    checkGameOver();

  FStar.Move(0.2);



end;

procedure TGameScene.Render;
begin
  drawTiles();
  drawStar();
  drawNodes();
  drawTrails();
  drawShips();
  drawMeter();
end;

procedure TGameScene.drawNodes();
var
  i,j: integer;
  node: TNode;
  size, satAngle: single;
  dx, dy, dist: single;
  mx, my: single;
  nodex, nodey, angle: single;
  targetX, targetY: single;
  minSize: single;
  a, r, g, b: Byte;
begin
  if not assigned(FDisplay) then
    exit;
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    size := node.size * node.energy * 50;
    if (size < 0) then
      size := 0;
    if (node.team = 0) then
    begin
      // не занятая планета
       //    FDisplay.drawCircle(node.x, node.y, node.size * 50 + 4, node.size * 50,
      //  gamecolors[node.team], true);
      //FDisplay.drawCircle(node.x, node.y, node.size * 50 + 4, node.size * 50,
      // gamecolors[0]);

   //   FDisplay.drawCircle(node.x, node.y, 0, size, gamecolors[node.team]);

      FDisplay.drawCircle(node.x, node.y,node.size * 50, node.size * 45,   gamecolors[node.team], true);

     /// DrawRing(Vector2Create(x,y),outer_radius , inner_radius ,0, 360, segments, ColorCreate(r,g,b,a));



      if (node.captureTeam <> 0) then
      begin
        minSize := node.size * 50 - size;

        FDisplay.drawCircle(node.x, node.y, node.size * 50, minSize,
          gamecolors[node.captureTeam], true);

        FDisplay.drawCircle(node.x, node.y, size, 0,
          gamecolors[node.captureTeam], true);
      end;
    end
    else
    begin
      FDisplay.drawCircle(node.x, node.y, node.size * 50 + 4, node.size * 50,
        gamecolors[node.team], true);

      FDisplay.drawCircle(node.x, node.y, size, 0, gamecolors[node.team]);

      FDisplay.drawCircle(node.x, node.y, size + 25, 0,
        gamecolors[node.team], true);

      {
      DrawTexturePro(FSatTexture,
                       RectangleCreate(0, 0, FSatTexture.width, FSatTexture.height),
                       RectangleCreate(node.x,node.y, FSatTexture.width / 3, FSatTexture.height / 3),
                       Vector2Create(FSatTexture.width/6, FSatTexture.height/6),
                       0,RED);
     }
     for j:=1 to node.satCount do

    begin
      l[1]:=node.size * 100;                   //длины каждого отрезка
      l[2]:=node.size * 120;
      l[3]:=node.size * 130;

      a := ((gamecolors[node.team] shr 24) and $FF);// / 255;
      r := ((gamecolors[node.team] shr 16) and $FF);// / 255;
      g := ((gamecolors[node.team] shr 8) and $FF);// / 255;
      b := ((gamecolors[node.team] and $FF));// / 255;



      DrawTextureEx(FSatTexture, Vector2Create(node.x +l[j]*cos(k[j]) ,
                                               node.y +l[j]*sin(k[j])), satAngle, 0.2, ColorCreate(r,g,b,a));
      k[j]:=k[j]+u[j];
      SatAngle += 0.1;
     end;

    end;

    if (node.selected) or (node = FHoverNode) then
      FDisplay.drawCircle(node.x, node.y, node.size * 50 + 8,
        node.size * 50 + 5, $FFFFFFFF);




    if (node.selected) then
    begin
      FDisplay.GetMouse(mx, my);
      dx := mx - node.x;
      dy := my - node.y;
      dist := sqrt(dx * dx + dy * dy);
      if (dist >= node.size * 50 + 5) then
      begin
        angle := arctan2(dy, dx);
        nodex := node.x + cos(angle) * (node.size * 50 + 7);
        nodey := node.y + sin(angle) * (node.size * 50 + 7);
        if assigned(FHoverNode) then
        begin
          if (node <> FHoverNode) then
          begin
            dx := node.x - FHoverNode.x;
            dy := node.y - FHoverNode.y;
            angle := arctan2(dy, dx);
            nodex := node.x + cos(angle + PI) * (node.size * 50 + 7);
            nodey := node.y + sin(angle + PI) * (node.size * 50 + 7);
            targetX := FHoverNode.x + cos(angle) * (FHoverNode.size * 50 + 7);
            targetY := FHoverNode.y + sin(angle) * (FHoverNode.size * 50 + 7);
            FDisplay.DrawLine(nodex, nodey, targetX, targetY, $FFFFFFFF, 2);
          end;
        end
        else
          FDisplay.DrawLine(nodex, nodey, mx, my, $FFFFFFFF, 2);
      end;
    end;
  end;
end;





procedure TGameScene.drawShips();
var
  i: integer;
  ship: TShip;
  shipColor: TColorB;
  a, r, g, b: Byte;
begin

  for i := 0 to ships.Count - 1 do
  begin
    ship := ships[i];

    //FDisplay.DrawQuad(ship.x-1, ship.y-1, ship.x + 1, ship.y + 1,
    //  gamecolors[ship.team]);
   a := ((gamecolors[ship.team] shr 24) and $FF);// / 255;
   r := ((gamecolors[ship.team] shr 16) and $FF);// / 255;
   g := ((gamecolors[ship.team] shr 8) and $FF);// / 255;
   b := ((gamecolors[ship.team] and $FF));// / 255;
   shipColor := ColorCreate(r,g,b,a);

 DrawTexturePro(FShipTexture[ship.team], RectangleCreate(0, 0, FShipTexture[ship.team].width,  FShipTexture[ship.team].height),
                              RectangleCreate(Ship.x,Ship.y, FShipTexture[ship.team].width / 3,  FShipTexture[ship.team].height / 3),
                              Vector2Create(FShipTexture[ship.team].width / 6,  FShipTexture[ship.team].height / 6), ship.rotation + 90 ,
                              shipColor);


  end;
end;

procedure TGameScene.drawTrails();
var
  i: integer;
  trail: TTrail;
begin
  if trails.Count = 0 then
    exit;

  for i := 0 to trails.Count - 1 do
  begin
    trail := trails[i];
    if trail.Width > 0 then
      FDisplay.DrawLine(trail.x, trail.y, trail.x + trail.Width *
        cos(trail.rotation), trail.y + trail.Width * sin(trail.rotation),
        trail.color, 2, trail.alpha );
  end;
end;

procedure TGameScene.drawMeter();
var
  teamStats: Array [0 .. 4] of single;
  node: TNode;
  i: integer;
  total: single;
  team1Width, team2Width, team3Width, team4Width: single;
  y, thickness: single;
  W, H: single;
begin
  FDisplay.GetDimension(W, H);
  teamStats[0] := 0;
  teamStats[1] := 0;
  teamStats[2] := 0;
  teamStats[3] := 0;
  teamStats[4] := 0;

  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    if (node.team > 0) then
      teamStats[node.team] := teamStats[node.team] + node.size;
  end;

  total := teamStats[1] + teamStats[2] + teamStats[3] + teamStats[4];
  team1Width := (teamStats[1] / total) * W;
  team2Width := (teamStats[2] / total) * W;
  team3Width := (teamStats[3] / total) * W;
  team4Width := (teamStats[4] / total) * W;
  thickness := 10;

  y := H - thickness * 0.5;
  with FDisplay do
  begin
    DrawLine(0, y, team1Width, y, gameColors[1], thickness);
    DrawLine(team1Width, y, team1Width + team2Width, y, gameColors[2], thickness);
    DrawLine(team1Width + team2Width, y, team1Width + team2Width + team3Width,
      y, gameColors[3], thickness);
    DrawLine(team1Width + team2Width + team3Width, y, team1Width + team2Width +
      team3Width + team4Width, y, gameColors[4], thickness);
  end;
end;

procedure TGameScene.drawTiles();
var i,j : integer;
begin
 //BeginBlendMode(BLEND_ADDITIVE);
   for i := 0 to GetScreenWidth div 512 do
     for j := 0 to GetScreenHeight div 512 do
       DrawTexture(FTilesTexture, i * 512 ,j*512, SKYBLUE);
 /// EndBlendMode;



end;

procedure TGameScene.drawStar();
begin
  FStar.Render;
end;

procedure TGameScene.Reset;
var
  i: integer;
  obj: TObject;
begin
  FGameover := true;
  for i := 0 to nodes.Count - 1 do
  begin
    obj := nodes[i];
    FreeAndNil(obj);
  end;
  for i := 0 to ships.Count - 1 do
  begin
    obj := ships[i];
    FreeAndNil(obj);
  end;

  for i := 0 to trails.Count - 1 do
  begin
    obj := trails[i];
    FreeAndNil(obj);
  end;

  for i := 0 to ais.Count - 1 do
  begin
    obj := ais[i];
    FreeAndNil(obj);
  end;

  nodes.Clear;
  ships.Clear;
  trails.Clear;
  ais.Clear;
end;

procedure TGameScene.PlayPing01;
begin
  FDisplay.PlaySound('ping01');
end;

procedure TGameScene.playPing02;
begin
  FDisplay.PlaySound('ping02');
end;

procedure TGameScene.PlayHit;
begin
  FDisplay.PlaySound('hit');
end;

constructor TGameScene.Create(const Display: IDisplay);
var i: integer;
begin
  FStar:=TStarField.Create(200, RectangleCreate(0,0, GetScreenWidth, GetScreenHeight - (2 * 0)));

  FDisplay := Display;
  nodes := TNodeList.create;
  ships := TShipList.create;
  trails := TTrailList.create;
  ais := TAIList.create;

   for i := 1 to 4 do
   FShipTexture[i] := LoadTexture(Pchar(format('resources/ships/ship0%d.png', [i])));

   FTilesTexture :=  LoadTexture('resources/gfx/starfield.png');

   FSatTexture := LoadTexture('resources/ships/satellite.png');

   l[1]:=100;                   //длины каждого отрезка
   l[2]:=80;
   l[3]:=60;
   u[1]:=0.003;                  //угловые скорости каждого шарика
   u[2]:=0.002;
   u[3]:=0.001;

end;

destructor TGameScene.Destroy;
begin
  Reset;
  nodes.free;
  ships.free;
  trails.free;
  ais.free;

  inherited;
end;

function TGameScene.getClosestNode(const x, y: single): TNode;
var
  closest: TNode;
  min: single;
  i: integer;
  dx, dy, dist: single;
  node: TNode;
begin
  closest := nil;
  min := 70;

  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    dx := node.x - x;
    dy := node.y - y;
    dist := sqrt(dx * dx + dy * dy);
    if (dist < node.size * 50 + 20) and (dist < min) then
    begin
      min := dist;
      closest := node;
    end;
  end;
  result := closest;
end;

procedure TGameScene.sendShips;
var
  i: integer;
  node: TNode;
begin
  for i := 0 to nodes.Count - 1 do
  begin
    node := nodes[i];
    if (node.team = 1) and (node.selected) and assigned(FHoverNode) then
      moveShips(node, FHoverNode);
    node.selected := false;
  end;
end;

end.


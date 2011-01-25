{
  Copyright 2010-2010 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Base 3D object (T3D). }
unit Base3D;

interface

uses Classes, Math, VectorMath, Frustum, Boxes3D, KambiClassUtils, KeysMouse;

type
  TRenderFromViewFunction = procedure of object;

  T3D = class;

  { Describe what visible thing changed
    for T3D.VisibleChange. }
  TVisibleChange = (
    { Something visible in the geometry changed.
      "Geometry" means that this is applicable only to actual 3D shape
      changes. (Think about "does depth buffer from some point in space
      changes" --- this is actually why we have separate vcVisibleGeometry
      and vcVisibleNonGeometry for now, as GeneratedShadowMap
      does need to be updated only on geometry changes.) So it's not applicable
      when only light conditions, materials, textures and such change. }
    vcVisibleGeometry,

    { Something visible changed, but not geometry.
      For example, material or texture on visible surface changed. }
    vcVisibleNonGeometry,

    { Camera view (the settings passed to TVRMLScene.CameraChanged) changed. }
    vcCamera);
  TVisibleChanges = set of TVisibleChange;

  TVisibleChangeEvent = procedure (Sender: T3D; Changes: TVisibleChanges) of object;

  { Triangle expressed in particular coordinate system, for T3DTriangle. }
  T3DTriangleGeometry = record
    Triangle: TTriangle3Single;

    { Area of the triangle. In other words, just a precalculated for you
      TriangleArea(Triangle). }
    Area: Single;

    case Integer of
      0: ({ This is a calculated TriangleNormPlane(Triangle),
            that is a 3D plane containing our Triangle, with normalized
            direction vector. }
          Plane: TVector4Single;);
      1: (Normal: TVector3Single;);
  end;

  { 3D triangle.

    This object should always be initialized by @link(Init),
    and updated only by it's methods (never modify fields of
    this object directly).

    I use old-style Pascal "object" to define this,
    since this makes it a little more efficient. This doesn't need
    any virtual methods or such, so (at least for now) it's easier
    and more memory-efficient to keep this as an old-style object.
    And memory efficiency is somewhat important here, since large
    scenes may easily have milions of triangles, and each triangle
    results in one TVRMLTriangle (descendant of T3DTriangle) instance. }
  T3DTriangle = object
  public
    { Initialize new triangle. Given ATriangle must satisfy IsValidTriangle. }
    constructor Init(const ATriangle: TTriangle3Single);

  public
    { Geometry of this item.
      We need two geometry descriptions:

      @unorderedList(

        @item(Local is based on initial Triangle, given when constructing
          this T3DTriangle. It's constant for this T3DTriangle. It's used
          by octree collision routines, that is things like
          TVRMLBaseTrianglesOctree.SphereCollision, TVRMLBaseTrianglesOctree.RayCollision
          and such expect parameters in the same coord space.

          This may be local coord space of this shape (this is used
          by TVRMLShape.OctreeTriangles) or world coord space
          (this is used by TVRMLScene.OctreeTriangles).)

        @item(World is the geometry of Local transformed to be in world
          coordinates. Initially, World is just a copy of Local.

          If Local already contains world-space geometry, then World
          can just remain constant, and so is always Local copy.

          If Local contains local shape-space geometry, then World
          will have to be updated by TVRMLTriangle.UpdateWorld whenever some octree item's
          geometry will be needed in world coords. This will have to be
          done e.g. by TVRMLBaseTrianglesOctree.XxxCollision for each returned item.)
      ) }
    Loc, World: T3DTriangleGeometry;
  end;
  P3DTriangle = ^T3DTriangle;

  { Return for given Triangle do we want to ignore collisions with it.
    For now, Sender is always TVRMLTriangleOctree. }
  T3DTriangleIgnoreFunc = function (
    const Sender: TObject;
    const Triangle: P3DTriangle): boolean of object;

  { Various things that T3D.PrepareResources may prepare. }
  TPrepareResourcesOption = (prRender, prBackground, prBoundingBox,
    prTrianglesListNotOverTriangulate,
    prTrianglesListOverTriangulate,
    prTrianglesListShadowCasters,
    prManifoldAndBorderEdges,
    { Prepare octrees (determined by things like TVRMLScene.Spatial). }
    prSpatial,
    prScreenEffects);
  TPrepareResourcesOptions = set of TPrepareResourcesOption;

  TTransparentGroup = (tgTransparent, tgOpaque, tgAll);
  TTransparentGroups = set of TTransparentGroup;

  { Shadow volumes helper, not depending on OpenGL. }
  TBaseShadowVolumeRenderer = class
  end;

  T3DListCore = class;

  { Represents a collision with a 3D objects (T3D descendants) tree. }
  T3DCollision = class
  public
    constructor Create;
    destructor Destroy; override;
  public
    { The path in the 3D objects tree leading from the root to the
      final colliding 3D object.

      For example, if your 3D tree is a list, and within
      this list is another list, and within this another list is your final
      colliding object (for example, some TVRMLGLScene instance),
      then Hierarchy will contain three items (in order: 1st list, 2nd list,
      TVRMLGLScene instance).

      This is never an empty list. }
    Hierarchy: T3DListCore;

    { The 3D point of collision. }
    Point: TVector3Single;

    { The triangle that collides. This triangle is always a part of the last
      item on @link(Hierarchy) list. }
    Triangle: P3DTriangle;
  end;

  { Base 3D object, that can be managed by TKamSceneManager.
    All 3D objects should descend from this, this way we can easily
    insert them into the TKamSceneManager. }
  T3D = class(TComponent)
  private
    FCastsShadow: boolean;
    FExists: boolean;
    FCollides: boolean;
    FOnVisibleChangeHere: TVisibleChangeEvent;
    FCursor: TMouseCursor;
    FOnCursorChange: TNotifyEvent;
    procedure SetCursor(const Value: TMouseCursor);
  protected
    { In T3D class, just calls OnCursorChange event. }
    procedure CursorChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Is this object visible and colliding.

      Setting this to @false pretty much turns everything of this 3D object
      to "off". This is useful for objects that disappear completely from
      the level when something happens. You could just as well remove
      this object from TKamSceneManager.Items tree, but sometimes it's more
      comfortable to simply turn this property to @false.

      @noAutoLinkHere }
    property Exists: boolean read FExists write FExists default true;

    { Should this 3D object participate in collision detection.
      You can turn this off, useful to make e.g. "fake" walls
      (to some secret places on level).

      Note that if not @link(Exists) then this doesn't matter
      (not existing objects never participate in collision detection).

      @noAutoLinkHere }
    property Collides: boolean read FCollides write FCollides default true;

    { Bounding box of the 3D object.

      Should take into account both collidable and visible objects.
      For examples, invisible walls (not visible) and fake walls (not collidable)
      should all be accounted here.

      As it's a @italic(bounding) volume, it may naturally be slightly too large
      (although, for the same of various optimizations, you should try
      to make it as tight as reasonably possible.) For now, it's also OK
      to make it a little too small (nothing bad will happen).
      Although all currently implemented descendants (TVRMLScene, TVRMLAnimation,
      more) guarantee it's never too small. }
    function BoundingBox: TBox3D; virtual; abstract;

    { Render given object. This is done only if @link(Exists).

      @param(Frustum May be used to optimize rendering, to not
        render the parts outside the Frustum.)

      @param(TransparentGroup
        Used to indicate that only opaque or only transparent
        parts should be rendered, just like for TVRMLGLScene.Render.)

      @param(InShadow If @true, means that we're using multi-pass
        shadowing technique (like shadow volumes),
        and currently doing the "shadowed" pass.

        Which means that most lights (ones with kambiShadows = TRUE)
        should be turned off, see [http://vrmlengine.sourceforge.net/kambi_vrml_extensions.php#section_ext_shadows].)
    }
    procedure Render(const Frustum: TFrustum;
      TransparentGroup: TTransparentGroup; InShadow: boolean); virtual;

    property CastsShadow: boolean read FCastsShadow write FCastsShadow
      default true;

    { Render shadow quads for all the things rendered by @link(Render).
      This is done only if @link(Exists) and @link(CastsShadow).

      It does shadow volumes culling inside (so ShadowVolumeRenderer should
      have FrustumCullingInit already initialized).

      ParentTransform and ParentTransformIsIdentity describe the transformation
      of this object in the 3D world.
      T3D objects may be organized in a hierarchy when
      parent transforms it's children. When ParentTransformIsIdentity,
      ParentTransform must be IdentityMatrix4Single (it's not guaranteed
      that when ParentTransformIsIdentity = @true, Transform value will be
      ignored !).

      @italic(Implementation note:) In @link(Render), it is usually possible
      to implement ParentTransform* by glPush/PopMatrix and Frustum.Move tricks.
      But RenderShadowVolume needs actual transformation explicitly:
      ShadowMaybeVisible needs actual box position in world coordinates,
      so bounding box has to be transformed by ParentTransform.
      And TVRMLGLScene.RenderShadowVolumeCore needs explicit ParentTransform
      to correctly detect front/back sides (for silhouette edges and
      volume capping). }
    procedure RenderShadowVolume(
      ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
      const ParentTransformIsIdentity: boolean;
      const ParentTransform: TMatrix4Single); virtual;

    { Prepare resources, making various methods (like rendering and such)
      to execute fast.

      This makes sure that appropriate methods execute as fast as possible.
      It's never required to call this method
      --- all things will be prepared "as needed" anyway.
      But this means that some calls may sometimes take a long time,
      e.g. the first @link(Render) call may take a long time because it may
      have to prepare display lists that will be reused in next @link(Render)
      calls. This may cause a strange behavior of the program: rendering of the
      first frame takes unusually long time (which confuses user, and
      also makes things like TGLWindow.DrawSpeed strange for a short
      time). So calling this procedure may be desirable.
      You may want to show to user that "now we're preparing
      the VRML scene --- please wait".

      For OpenGL rendered objects, this method ties this object
      to the current OpenGL context.
      But it doesn't change any OpenGL state or buffers contents
      (at most, it allocates some texture and display list names).

      @param(TransparentGroups For what TransparentGroup value
        we should prepare rendering resources.
        Important only if prRender is included in Options.

        The idea is that
        you're often interested in rendering only with tgAll, or
        only with [tgTransparent, tgOpaque] --- so it would be a waste of
        resources and time to prepare for every possible TransparentGroup value.

        Note for TVRMLGLScene only:
        preparing for every possible TransparentGroup value
        is actually not harmful. There's no additional use of resources,
        as the sum of [tgTransparent, tgOpaque] uses
        the same resources as [tgAll]. In other words,
        there's no difference in resource (and time) used between
        preparing for [tgTransparent, tgOpaque], [tgAll] or
        [tgTransparent, tgOpaque, tgAll] --- they'll all prepare the same
        things.)

      @param(Options What features should be prepared to execute fast.
        See TPrepareResourcesOption,
        the names should be self-explanatory (they refer to appropriate
        methods of T3D, TVRMLScene or TVRMLGLScene).)

      @param(ProgressStep Says that we should make Progress.Step calls
        (exactly PrepareResourcesSteps times) during preparation.
        Useful to show progress bar to the user during long preparation.

        TODO: for now, do not include prSpatial if you use ProgressStep.
        Reason: octree preparations have a separate mechanism
        that may want to show progress.) }
    procedure PrepareResources(
      TransparentGroups: TTransparentGroups;
      Options: TPrepareResourcesOptions;
      ProgressStep: boolean); virtual;

    { How many times PrepareResources will call Progress.Step.
      Useful only if you want to pass ProgressStep = @true to PrepareResources.
      In the base class T3D this just returns 0.  }
    function PrepareResourcesSteps: Cardinal; virtual;

    { Key and mouse events. Return @true if you handled them.
      See also TUIControl analogous events.
      Note that our MouseMove gets 3D ray corresponding to mouse
      position on the screen (this is the ray for "picking" 3D objects
      pointed by the mouse).

      @groupBegin }
    function KeyDown(Key: TKey; C: char): boolean; virtual;
    function KeyUp(Key: TKey; C: char): boolean; virtual;
    function MouseDown(const Button: TMouseButton): boolean; virtual;
    function MouseUp(const Button: TMouseButton): boolean; virtual;
    function MouseMove(const RayOrigin, RayDirection: TVector3Single;
      RayHit: T3DCollision): boolean; virtual;
    { @groupEnd }

    { Idle event, for continously repeated tasks. }
    procedure Idle(const CompSpeed: Single); virtual;

    { Something visible changed inside @italic(this) 3D object.
      This is usually called by implementation of this 3D object,
      to notify others that it changed.

      Changes is a set describing what changes occurred.
      It can be [], meaning "something else", we'll
      still make OnVisibleChangeHere then. See TVisibleChange
      docs for possible values. It must specify all things that possibly
      changed.

      The information about visibility changed is usually passed upward,
      to the TKamSceneManager, that broadcasts this to all 3D objects
      by VisibleChangeNotification. If you want to @italic(react) to visibility
      changes, you usually should override VisibleChangeNotification,
      not this method.

      In this class this simply calls OnVisibleChangeHere (if assigned). }
    procedure VisibleChangeHere(const Changes: TVisibleChanges); virtual;

    { Called when some visible part of this control changes.
      This is usually used by the scene manager
      (to know when we need to redraw the control),
      so don't use it in your own programs directly.

      Be careful when handling this event, various changes may cause this,
      so be prepared to handle OnVisibleChangeHere at every time.

      @seealso VisibleChangeHere }
    property OnVisibleChangeHere: TVisibleChangeEvent
      read FOnVisibleChangeHere write FOnVisibleChangeHere;

    { Something visible changed in the 3D world.
      This is usually called by our container (like TKamSceneManager),
      to allow this 3D object to react (e.g. by regenerating mirror textures)
      to changes in the 3D world (not necessarily in this 3D object,
      maybe in some other T3D instance).

      If you want to @italic(react) to visibility
      changes, you should override this. }
    procedure VisibleChangeNotification(const Changes: TVisibleChanges); virtual;

    { Mouse cursor over this object. }
    property Cursor: TMouseCursor read FCursor write SetCursor default mcDefault;

    { Called when the @link(Cursor) of this control changes.
      This is usually used by the scene manager
      (to know when we need to redraw the control),
      so don't use it in your own programs directly. }
    property OnCursorChange: TNotifyEvent
      read FOnCursorChange write FOnCursorChange;

    { Called when OpenGL context of the window is destroyed.
      This will be also automatically called from destructor.

      Control should clear here any resources that are tied to the GL context. }
    procedure GLContextClose; virtual;

    { Check height of a point (like a player camera) above the ground.
      This checks ray collision, from Position along the negated GravityUp vector.
      Measures distance to the nearest scene item (called "ground" here).

      @param(IsAbove Says if the 3D scene is hit.
        @false means that player floats above an empty space.
        That is, if you turn gravity on, the player will fall down forever,
        as far as this 3D scene is concerned.)

      @param(AboveHeight Height above the ground. Must be MaxSingle
        if IsAbove was set to @false (this guarantee simplifies some code).)

      @param(AboveGround Pointer to P3DTriangle representing the ground.
        Must be @nil if IsAbove was set to @false.
        @bold(May) be @nil even if IsAbove was set to @true (not all 3D
        objects may be able to generate P3DTriangle information about collision).

        This may be useful for example to make a footsteps sound dependent
        on texture of the ground.
        Or to decrease player life points for walking on hot lava.
        See "castle" for examples.)
    }
    procedure GetHeightAbove(const Position, GravityUp: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc;
      out IsAbove: boolean; out AboveHeight: Single;
      out AboveGround: P3DTriangle); virtual;

    function MoveAllowed(
      const OldPos, ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const CameraRadius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;
    function MoveAllowedSimple(
      const OldPos, ProposedNewPos: TVector3Single;
      const CameraRadius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;
    function MoveBoxAllowedSimple(
      const OldPos, ProposedNewPos: TVector3Single;
      const ProposedNewBox: TBox3D;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;

    function SegmentCollision(const Pos1, Pos2: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;
    function SphereCollision(const Pos: TVector3Single; const Radius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;
    function BoxCollision(const Box: TBox3D;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; virtual;

    { Check collision with a ray, building a T3DCollision result.
      Returns a collision as T3DCollision instance, or @nil if no collision.
      Caller is responsible for freeing the returned T3DCollision instance.

      This always returns the first collision with the 3D world, that is
      the one with smallest IntersectionDistance. For example, when
      implemented in T3DList, this checks collisions for all list items,
      and chooses the closest one. }
    function RayCollision(
      out IntersectionDistance: Single;
      const Ray0, RayVector: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): T3DCollision; virtual;

    procedure UpdateGeneratedTextures(
      const RenderFunc: TRenderFromViewFunction;
      const ProjectionNear, ProjectionFar: Single;
      const OriginalViewportX, OriginalViewportY: LongInt;
      const OriginalViewportWidth, OriginalViewportHeight: Cardinal); virtual;

    { Are we in the middle of dragging something by moving the mouse.

      This should be set to @true to disable camera navigation
      methods that also use mouse move. In practice, to disable TExamineCamera
      view rotation/movement by moving the mouse, as it makes (comfortable)
      dragging practically impossible (at each mouse move, view changes...).

      In particular, when you operate on active X3D pointing-device sensors
      (like drag sensors, e.g. PlaneSensor, but also TouchSensor may
      use it). }
    function Dragging: boolean; virtual;
  end;

  T3DList = class;

  { List of base 3D objects (T3D instances).
    This allows you to group many 3D objects, and treat them as one T3D
    descendant (for example, to translate many 3D objects by a single
    T3DCustomTranslated.Child).

    This inherits from TObjectsList, getting many
    features like TList notification mechanism (useful in some situations).
    Usually you want to use T3DList instead, which is a wrapper around
    this class. }
  T3DListCore = class(TKamObjectList)
  private
    FOwner: T3DList;

    function GetItem(const I: Integer): T3D;
    procedure SetItem(const I: Integer; const Item: T3D);
  public
    constructor Create(const FreeObjects: boolean; const AOwner: T3DList);
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
    property Items[I: Integer]: T3D read GetItem write SetItem; default;

    function First: T3D;
    function Last: T3D;

    { T3DList instance that owns this list.
      May be @nil, for example when this list is used by T3DCollision. }
    property Owner: T3DList read FOwner;
  end;

  { List of base 3D objects (T3D instances).

    This inherits from T3D class, so this list is itself a 3D object:
    it's a sum of all it's children 3D objects. }
  T3DList = class(T3D)
  private
    FList: T3DListCore;
    procedure ListVisibleChange(Sender: T3D; Changes: TVisibleChanges);
    procedure ListCursorChange(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    { Add and remove items to the @link(List).
      @groupBegin }
    procedure Add(const Item: T3D);
    procedure Insert(const Index: Integer; const Item: T3D);
    procedure Remove(const Item: T3D);
    procedure Clear;
    { @groupEnd }

    function BoundingBox: TBox3D; override;
    procedure Render(const Frustum: TFrustum;
      TransparentGroup: TTransparentGroup; InShadow: boolean); override;
    procedure RenderShadowVolume(
      ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
      const ParentTransformIsIdentity: boolean;
      const ParentTransform: TMatrix4Single); override;
    procedure PrepareResources(
      TransparentGroups: TTransparentGroups;
      Options: TPrepareResourcesOptions;
      ProgressStep: boolean); override;
    function PrepareResourcesSteps: Cardinal; override;
    function KeyDown(Key: TKey; C: char): boolean; override;
    function KeyUp(Key: TKey; C: char): boolean; override;
    function MouseDown(const Button: TMouseButton): boolean; override;
    function MouseUp(const Button: TMouseButton): boolean; override;
    function MouseMove(const RayOrigin, RayDirection: TVector3Single;
      RayHit: T3DCollision): boolean; override;
    procedure Idle(const CompSpeed: Single); override;
    procedure GLContextClose; override;
    procedure GetHeightAbove(const Position, GravityUp: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc;
      out IsAbove: boolean; out AboveHeight: Single;
      out AboveGround: P3DTriangle); override;
    function MoveAllowed(
      const OldPos, ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
      const CameraRadius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function MoveAllowedSimple(
      const OldPos, ProposedNewPos: TVector3Single;
      const CameraRadius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function MoveBoxAllowedSimple(
      const OldPos, ProposedNewPos: TVector3Single;
      const ProposedNewBox: TBox3D;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function SegmentCollision(const Pos1, Pos2: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function SphereCollision(const Pos: TVector3Single; const Radius: Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function BoxCollision(const Box: TBox3D;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean; override;
    function RayCollision(
      out IntersectionDistance: Single;
      const Ray0, RayVector: TVector3Single;
      const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): T3DCollision; override;
    procedure UpdateGeneratedTextures(
      const RenderFunc: TRenderFromViewFunction;
      const ProjectionNear, ProjectionFar: Single;
      const OriginalViewportX, OriginalViewportY: LongInt;
      const OriginalViewportWidth, OriginalViewportHeight: Cardinal); override;
    procedure VisibleChangeNotification(const Changes: TVisibleChanges); override;
    function Dragging: boolean; override;
  published
    { 3D objects inside.
      Freeing these items automatically removes them from this list. }
    property List: T3DListCore read FList;
  end;

const
  MaxSingle = Math.MaxSingle;

implementation

uses SysUtils, KambiUtils;

{ T3DTriangle  --------------------------------------------------------------- }

constructor T3DTriangle.Init(const ATriangle: TTriangle3Single);
begin
  Loc.Triangle := ATriangle;
  Loc.Plane := TriangleNormPlane(ATriangle);
  Loc.Area := TriangleArea(ATriangle);

  World := Loc;
end;

{ T3DCollision ------------------------------------------------------------- }

constructor T3DCollision.Create;
begin
  inherited;
  Hierarchy := T3DListCore.Create(false, nil);
end;

destructor T3DCollision.Destroy;
begin
  FreeAndNil(Hierarchy);
end;

{ T3D -------------------------------------------------------------------- }

constructor T3D.Create(AOwner: TComponent);
begin
  inherited;
  FCastsShadow := true;
  FExists := true;
  FCollides := true;
  FCursor := mcDefault;
end;

destructor T3D.Destroy;
begin
  GLContextClose;
  inherited;
end;

procedure T3D.Render(const Frustum: TFrustum;
  TransparentGroup: TTransparentGroup;
  InShadow: boolean);
begin
end;

procedure T3D.RenderShadowVolume(
  ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
  const ParentTransformIsIdentity: boolean;
  const ParentTransform: TMatrix4Single);
begin
end;

procedure T3D.PrepareResources(TransparentGroups: TTransparentGroups;
  Options: TPrepareResourcesOptions; ProgressStep: boolean);
begin
end;

function T3D.PrepareResourcesSteps: Cardinal;
begin
  Result := 0;
end;

function T3D.KeyDown(Key: TKey; C: char): boolean;
begin
  Result := false;
end;

function T3D.KeyUp(Key: TKey; C: char): boolean;
begin
  Result := false;
end;

function T3D.MouseDown(const Button: TMouseButton): boolean;
begin
  Result := false;
end;

function T3D.MouseUp(const Button: TMouseButton): boolean;
begin
  Result := false;
end;

function T3D.MouseMove(const RayOrigin, RayDirection: TVector3Single;
  RayHit: T3DCollision): boolean;
begin
  Result := false;
end;

procedure T3D.Idle(const CompSpeed: Single);
begin
end;

procedure T3D.VisibleChangeHere(const Changes: TVisibleChanges);
begin
  if Assigned(OnVisibleChangeHere) then
    OnVisibleChangeHere(Self, Changes);
end;

procedure T3D.VisibleChangeNotification(const Changes: TVisibleChanges);
begin
end;

procedure T3D.SetCursor(const Value: TMouseCursor);
begin
  if FCursor <> Value then
  begin
    FCursor := Value;
    CursorChange;
  end;
end;

procedure T3D.CursorChange;
begin
  if Assigned(OnCursorChange) then OnCursorChange(Self);
end;

procedure T3D.GLContextClose;
begin
end;

procedure T3D.GetHeightAbove(const Position, GravityUp: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc;
  out IsAbove: boolean; out AboveHeight: Single;
  out AboveGround: P3DTriangle);
begin
  IsAbove := false;
  AboveHeight := MaxSingle;
  AboveGround := nil;
end;

function T3D.MoveAllowed(
  const OldPos, ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
  const CameraRadius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := true;
  NewPos := ProposedNewPos;
end;

function T3D.MoveAllowedSimple(
  const OldPos, ProposedNewPos: TVector3Single;
  const CameraRadius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := true;
end;

function T3D.MoveBoxAllowedSimple(
  const OldPos, ProposedNewPos: TVector3Single;
  const ProposedNewBox: TBox3D;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := true;
end;

function T3D.SegmentCollision(const Pos1, Pos2: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := false;
end;

function T3D.SphereCollision(const Pos: TVector3Single; const Radius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := false;
end;

function T3D.BoxCollision(const Box: TBox3D;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
begin
  Result := false;
end;

function T3D.RayCollision(
  out IntersectionDistance: Single;
  const Ray0, RayVector: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): T3DCollision;
begin
  Result := nil;
end;

procedure T3D.UpdateGeneratedTextures(
  const RenderFunc: TRenderFromViewFunction;
  const ProjectionNear, ProjectionFar: Single;
  const OriginalViewportX, OriginalViewportY: LongInt;
  const OriginalViewportWidth, OriginalViewportHeight: Cardinal);
begin
end;

function T3D.Dragging: boolean;
begin
  Result := false;
end;

{ T3DListCore ------------------------------------------------------------ }

constructor T3DListCore.Create(const FreeObjects: boolean; const AOwner: T3DList);
begin
  inherited Create(FreeObjects);
  FOwner := AOwner;
end;

procedure T3DListCore.Notify(Ptr: Pointer; Action: TListNotification);
var
  B: T3D;
begin
  inherited;

  if Owner <> nil then
  begin
    B := T3D(Ptr);

    case Action of
      lnAdded:
        begin
          { Make sure Owner.ListVisibleChange will be called
            when an item calls OnVisibleChangeHere. }
          if B.OnVisibleChangeHere = nil then
            B.OnVisibleChangeHere := @Owner.ListVisibleChange;
          if B.OnCursorChange = nil then
            B.OnCursorChange := @Owner.ListCursorChange;

          { Register Owner to be notified of item destruction. }
          B.FreeNotification(Owner);
        end;
      lnExtracted, lnDeleted:
        begin
          if B.OnVisibleChangeHere = @Owner.ListVisibleChange then
            B.OnVisibleChangeHere := nil;
          if B.OnCursorChange = @Owner.ListCursorChange then
            B.OnCursorChange := nil;

          B.RemoveFreeNotification(Owner);
        end;
      else raise EInternalError.Create('T3DListCore.Notify action?');
    end;

    { This notification may get called during FreeAndNil(FList)
      in T3DList.Destroy. Then FList is already nil (as FreeAndNil
      first sets object to nil), and Owner.ListCursorChange
      may not be ready for this. }
    if Owner.FList <> nil then
      Owner.ListCursorChange(nil);
  end;
end;

function T3DListCore.GetItem(const I: Integer): T3D;
begin
  Result := T3D(inherited Items[I]);
end;

procedure T3DListCore.SetItem(const I: Integer; const Item: T3D);
begin
  (inherited Items[I]) := Item;
end;

function T3DListCore.First: T3D;
begin
  Result := (inherited First) as T3D;
end;

function T3DListCore.Last: T3D;
begin
  Result := (inherited Last) as T3D;
end;

{ T3DList ---------------------------------------------------------------- }

constructor T3DList.Create(AOwner: TComponent);
begin
  inherited;
  FList := T3DListCore.Create(false, Self);
end;

destructor T3DList.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

procedure T3DList.Add(const Item: T3D);
begin
  List.Add(Item);
end;

procedure T3DList.Insert(const Index: Integer; const Item: T3D);
begin
  List.Insert(Index, Item);
end;

procedure T3DList.Remove(const Item: T3D);
begin
  List.Remove(Item);
end;

procedure T3DList.Clear;
begin
  List.Clear;
end;

function T3DList.BoundingBox: TBox3D;
var
  I: Integer;
begin
  Result := EmptyBox3D;
  if Exists then
    for I := 0 to List.Count - 1 do
      Box3DSumTo1st(Result, List[I].BoundingBox);
end;

procedure T3DList.Render(const Frustum: TFrustum;
  TransparentGroup: TTransparentGroup; InShadow: boolean);
var
  I: Integer;
begin
  inherited;
  if Exists then
    for I := 0 to List.Count - 1 do
      List[I].Render(Frustum, TransparentGroup, InShadow);
end;

procedure T3DList.RenderShadowVolume(
  ShadowVolumeRenderer: TBaseShadowVolumeRenderer;
  const ParentTransformIsIdentity: boolean;
  const ParentTransform: TMatrix4Single);
var
  I: Integer;
begin
  inherited;
  if Exists and CastsShadow then
    for I := 0 to List.Count - 1 do
      List[I].RenderShadowVolume(ShadowVolumeRenderer,
        ParentTransformIsIdentity, ParentTransform);
end;

procedure T3DList.PrepareResources(TransparentGroups: TTransparentGroups;
  Options: TPrepareResourcesOptions; ProgressStep: boolean);
var
  I: Integer;
begin
  inherited;
  for I := 0 to List.Count - 1 do
    List[I].PrepareResources(TransparentGroups, Options, ProgressStep);
end;

function T3DList.PrepareResourcesSteps: Cardinal;
var
  I: Integer;
begin
  Result := inherited;
  for I := 0 to List.Count - 1 do
    Result += List[I].PrepareResourcesSteps;
end;

function T3DList.KeyDown(Key: TKey; C: char): boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].KeyDown(Key, C) then Exit(true);
end;

function T3DList.KeyUp(Key: TKey; C: char): boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].KeyUp(Key, C) then Exit(true);
end;

function T3DList.MouseDown(const Button: TMouseButton): boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].MouseDown(Button) then Exit(true);
end;

function T3DList.MouseUp(const Button: TMouseButton): boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].MouseUp(Button) then Exit(true);
end;

function T3DList.MouseMove(const RayOrigin, RayDirection: TVector3Single;
  RayHit: T3DCollision): boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
    if List[I].MouseMove(RayOrigin, RayDirection, RayHit) then Exit(true);
end;

procedure T3DList.Idle(const CompSpeed: Single);
var
  I: Integer;
begin
  inherited;

  for I := 0 to List.Count - 1 do
    List[I].Idle(CompSpeed);
end;

procedure T3DList.ListVisibleChange(Sender: T3D; Changes: TVisibleChanges);
begin
  { when an Item calls OnVisibleChangeHere, we'll call our own OnVisibleChangeHere,
    to pass it up the tree (eventually, to the scenemanager, that will
    pass it by TUIControl similar OnVisibleChangeHere mechanism to the container). }
  VisibleChangeHere(Changes);
end;

procedure T3DList.ListCursorChange(Sender: TObject);
begin
  { when an Item calls OnCursorChange, we'll call our own OnCursorChange,
    to pass it up the tree (eventually, to the scenemanager, that will
    pass it by TUIControl similar OnCursorChange mechanism to the container). }

  { Open question: alternatively, instead of directly sending CursorChange,
    we could update our own cursor (thus indirectly (possibly) generating
    OnCursorChange), and let scene manager to take cursor from
    MouseRayHit.Hierarchy.First.Cursor.

    Right now, scene manager takes cursor from MouseRayHit.Hierarchy.Last.Cursor,
    and pretty much ignores Cursor value of 3d stuff along
    the MouseRayHit.Hierarchy path.

    This is undecided yet, I currently don't see any compelling reason
    for one or the other behavior. }

  CursorChange;
end;

procedure T3DList.GLContextClose;
var
  I: Integer;
begin
  { this is called from inherited destrudtor, so check <> nil carefully }
  if FList <> nil then
  begin
    for I := 0 to List.Count - 1 do
      List[I].GLContextClose;
  end;

  inherited;
end;

procedure T3DList.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;

  { We have to remove a reference to the object from the List.
    This is crucial: T3DListCore.Notify,
    and e.g. GLContextClose call, assume that all objects on
    the List are always valid objects (no invalid references,
    even for a short time). }

  if (Operation = opRemove) and (AComponent is T3D) then
    List.DeleteAll(AComponent);
end;

procedure T3DList.GetHeightAbove(const Position, GravityUp: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc;
  out IsAbove: boolean; out AboveHeight: Single;
  out AboveGround: P3DTriangle);
var
  I: Integer;
  NewIsAbove: boolean;
  NewAboveHeight: Single;
  NewAboveGround: P3DTriangle;
begin
  inherited;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      List[I].GetHeightAbove(Position, GravityUp, TrianglesToIgnoreFunc,
        NewIsAbove, NewAboveHeight, NewAboveGround);

      if NewAboveHeight < AboveHeight then
      begin
        IsAbove := NewIsAbove;
        AboveHeight := NewAboveHeight;
        AboveGround := NewAboveGround;
      end;
    end;
end;

function T3DList.MoveAllowed(
  const OldPos, ProposedNewPos: TVector3Single; out NewPos: TVector3Single;
  const CameraRadius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  if Exists and Collides and (List.Count <> 0) then
  begin
    { We call MoveAllowed only one time, on the first scene.
      This means that only first scene collisions provide wall sliding.
      Collisions with other 3D objects will simply block the player.

      Otherwise, various MoveAllowed could modify NewPos
      making it colliding with other items, already checked. This would
      be wrong. So MoveAllowed is used only once, and for the others
      we use simple MoveAllowedSimple.

      TODO: this could be improved, to call MoveAllowed on the first scene
      where the simple move is not allowed. This would make it more general,
      although also slower. Is there any way to make it as fast and
      more general? }
    Result := List[0].MoveAllowed(OldPos, ProposedNewPos, NewPos,
      CameraRadius, TrianglesToIgnoreFunc);
    if not Result then Exit;

    for I := 1 to List.Count - 1 do
    begin
      Result := List[I].MoveAllowedSimple(OldPos, NewPos,
        CameraRadius, TrianglesToIgnoreFunc);
      if not Result then Exit;
    end;
  end else
  begin
    Result := true;
    NewPos := ProposedNewPos;
  end;
end;

function T3DList.MoveAllowedSimple(
  const OldPos, ProposedNewPos: TVector3Single;
  const CameraRadius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  Result := true;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      Result := List[I].MoveAllowedSimple(OldPos, ProposedNewPos,
        CameraRadius, TrianglesToIgnoreFunc);
      if not Result then Exit;
    end;
end;

function T3DList.MoveBoxAllowedSimple(
  const OldPos, ProposedNewPos: TVector3Single;
  const ProposedNewBox: TBox3D;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  Result := true;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      Result := List[I].MoveBoxAllowedSimple(OldPos, ProposedNewPos,
        ProposedNewBox, TrianglesToIgnoreFunc);
      if not Result then Exit;
    end;
end;

function T3DList.SegmentCollision(const Pos1, Pos2: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  Result := false;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      Result := List[I].SegmentCollision(Pos1, Pos2, TrianglesToIgnoreFunc);
      if Result then Exit;
    end;
end;

function T3DList.SphereCollision(const Pos: TVector3Single; const Radius: Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  Result := false;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      Result := List[I].SphereCollision(Pos, Radius, TrianglesToIgnoreFunc);
      if Result then Exit;
    end;
end;

function T3DList.BoxCollision(const Box: TBox3D;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): boolean;
var
  I: Integer;
begin
  Result := false;

  if Exists and Collides then
    for I := 0 to List.Count - 1 do
    begin
      Result := List[I].BoxCollision(Box, TrianglesToIgnoreFunc);
      if Result then Exit;
    end;
end;

function T3DList.RayCollision(
  out IntersectionDistance: Single;
  const Ray0, RayVector: TVector3Single;
  const TrianglesToIgnoreFunc: T3DTriangleIgnoreFunc): T3DCollision;
var
  I: Integer;
  NewIntersectionDistance: Single;
  NewResult: T3DCollision;
begin
  Result := nil;
  IntersectionDistance := 0; { Only to silence compiler warning }

  if Exists and Collides then
  begin
    for I := 0 to List.Count - 1 do
    begin
      NewResult := List[I].RayCollision(
        NewIntersectionDistance, Ray0, RayVector, TrianglesToIgnoreFunc);
      if NewResult <> nil then
      begin
        if (Result = nil) or (NewIntersectionDistance < IntersectionDistance) then
        begin
          IntersectionDistance := NewIntersectionDistance;
          SysUtils.FreeAndNil(Result);
          Result := NewResult;
        end else
          FreeAndNil(NewResult);
      end;
    end;

    if Result <> nil then
      Result.Hierarchy.Insert(0, Self);
  end;
end;

procedure T3DList.UpdateGeneratedTextures(
  const RenderFunc: TRenderFromViewFunction;
  const ProjectionNear, ProjectionFar: Single;
  const OriginalViewportX, OriginalViewportY: LongInt;
  const OriginalViewportWidth, OriginalViewportHeight: Cardinal);
var
  I: Integer;
begin
  inherited;
  for I := 0 to List.Count - 1 do
    List[I].UpdateGeneratedTextures(
      RenderFunc, ProjectionNear, ProjectionFar,
      OriginalViewportX, OriginalViewportY,
      OriginalViewportWidth, OriginalViewportHeight);
end;

procedure T3DList.VisibleChangeNotification(const Changes: TVisibleChanges);
var
  I: Integer;
begin
  inherited;
  for I := 0 to List.Count - 1 do
    List[I].VisibleChangeNotification(Changes);
end;

function T3DList.Dragging: boolean;
var
  I: Integer;
begin
  Result := inherited;
  if Result then Exit;

  for I := 0 to List.Count - 1 do
  begin
    Result := List[I].Dragging;
    if Result then Exit;
  end;
end;

end.

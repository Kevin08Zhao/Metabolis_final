target_task: D-29
reported_by: ACCOUNT_C
status: OPEN
discovered_at_main_commit: 959ef0ddd3d3672d7836efc3c4721ce42701655c
subject: |
  docs/D-29_TITLE_SCENE_INTEGRATION.md, landed by pull request 68, gives the
  title scene an exact layout. ACCOUNT_C has applied that layout to
  src/ui/title.tscn, which it owns under docs/coord/OWNERSHIP.md. Five points in
  the document do not match the repository. None of them blocks the scene, which
  is committed and runs, but each needs D-29 to confirm or correct before the
  screenshots in that document can be taken and called accurate.
findings:
  - id: 1
    severity: blocking_for_screenshots
    claim: |
      The document states the accepted background is
      art/backgrounds/background_title.png and must not be regenerated.
    actual: |
      That path does not exist anywhere in the repository. The landing manifest
      docs/assets/D-29_MANIFEST.md records the accepted asset as
      art/source/background_title_source.png, with output SHA-256
      6d649b3e07ee8502c6c4271aa2e6a9597e22231d0b6e0b9abf7c2816b9e1cb66, and
      docs/assets/D-29_LAND_REPORT.json agrees.

      This is not a path typo, and it is the most consequential of the five
      findings. art/source is one of three directories T-36's asset layer
      excludes by design, listed in SKIPPED_ART_DIRECTORIES in
      src/core/asset_loader.gd alongside candidates and reference. Those are
      working directories, not shippable ones. No runtime code can load an image
      from any of them, so the accepted background is currently unreachable from
      the game whatever any scene does.

      The path the integration document itself names, art/backgrounds/, is not
      skipped and would work.
    resolution: |
      D-29 lands the accepted file, unchanged, at a directory the asset layer
      does not skip. art/backgrounds/background_title.png, the path the
      integration document already names, is the obvious one.

      ACCOUNT_C has not moved or copied the file. Relocating another account's
      landed asset would break the manifest and the landing report that record
      where it went, and the instruction not to regenerate it reads as an
      instruction to leave it alone.

      Nothing else has to change when it lands. src/ui/title.tscn reserves the
      slot, SceneRouter asks AssetLoader for it by logical name on every entry to
      the title, and AssetLoader searches art recursively. The slot fills by
      itself. Until then AssetLoader returns its placeholder and warns, which is
      the degradation T-36 was built to provide, and the acceptance run asserts
      that this is what is happening rather than letting an empty title pass
      silently.
  - id: 2
    severity: needs_a_decision
    claim: |
      The layout table allocates the background Rect2(0, 0, 640, 360).
    actual: |
      The landed asset is 320 by 180. Its own landing report records that as both
      the expected and the output size, with dimension status PASS, so the asset
      is not truncated: it is half the reference canvas in each direction.
    resolution: |
      Filling the canvas is therefore an integer 2x scale. The scene does that,
      with the project's nearest-neighbour filter, which keeps every pixel square
      and introduces no interpolation. The same 2x step already appears in the
      D-22 pipeline, so it is established practice rather than a new one.
      D-29 should either state the 2x upscale in the integration document or
      supply a 640 by 360 master. Regenerating was not attempted, per the
      instruction in the document not to.
  - id: 3
    severity: specification_conflict
    claim: |
      The layout table offers two entry buttons, Begin at Rect2(240, 200, 160, 32)
      and Continue at Rect2(240, 240, 160, 32).
    actual: |
      docs/coord/done/T-32.md records an accepted entry set of three: continue,
      new game, and chapter select. Chapter select is gated on at least one
      finished stage whose snapshot can actually be entered, which T-32's
      acceptance tested both ways. The wording also differs: T-32 offers
      New Game where this document says Begin.
    resolution: |
      The user resolved this in favour of T-32: the accepted behaviour and
      wording stand, and only the geometry is adopted. MenuAnchor is sized so
      that two entries land exactly on the two rectangles above, and a third
      appears one pitch of 40 px higher, at y 160, which is clear of both the
      subtitle and the disclaimer band.
      D-29 should add a row for the third entry, or confirm the derived position.
  - id: 4
    severity: measured_overflow
    claim: |
      The disclaimer must be one line inside Rect2(80, 300, 480, 20) at font
      size 8.
    actual: |
      Measured with the engine default font at size 8, not estimated. The wording
      the scene first carried, "This game is a simplified educational model of
      human development. It is not for medical judgement, diagnosis, or
      treatment.", is 481 px against a 480 px band. It overflows by one pixel.
    resolution: |
      Shortened to "A simplified educational model of human development. Not for
      medical judgement, diagnosis, or treatment.", which measures 418 px and
      keeps all three things the statement has to say. It is registered in
      docs/UI_COPY.md with its measured width. Wrapping was not an option: the
      band is 20 px tall and a second line would be clipped rather than shown.
  - id: 5
    severity: stale
    claim: |
      The Blockers section states that the runtime title scene must exist and
      that T-32 routing currently points to res://main.tscn.
    actual: |
      Both were true when the document was written and neither is now. Pull
      request 67 landed src/ui/title.tscn, src/game/main.tscn and
      src/ui/ending.tscn, and SceneRouter.scene_paths points at all three.
    resolution: |
      The blockers can be cleared. The resolution condition of
      docs/coord/rework/D-29__from_ACCOUNT_D.open.md, that the title scene and
      final routing targets exist, is met.
what_account_c_has_already_done:
  - src/ui/title.tscn carries the D-29 rectangles for the background, title band,
    disclaimer and entry area, and the font size 8 the document specifies.
  - The background slot is reserved and wired to AssetLoader, so it fills itself
    the moment finding 1 is resolved. The asset was not moved, copied or altered.
  - AssetLoader was registered as an autoload in src/project.godot. T-36 built it
    and its own header says to register it, but nothing had, so no image outside
    the Godot project root was reachable at all. docs/coord/OWNERSHIP.md table O2
    is updated.
  - The disclaimer fits its band and is registered in docs/UI_COPY.md.
  - Every rectangle, the disclaimer width and the placeholder degradation are
    asserted by a headless run.
what_is_still_d29s:
  - The font sizing, letter spacing and centring treatment.
  - The subtle pulse, its 3 second period, its 2 px expansion and its colour.
  - The five screenshots and their verification.
  - Confirming or correcting the five findings above.
impact:
  - The scene runs and the routing works, so nothing is blocked from proceeding.
  - The screenshots in the integration document cannot be called accurate until
    findings 1, 2 and 3 are settled, because they would show a background at a
    path the document does not name and an entry set the document does not list.
opened_at: 2026-07-28T11:20:00-04:00

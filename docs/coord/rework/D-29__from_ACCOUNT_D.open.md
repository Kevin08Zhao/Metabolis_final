target_task: D-29
reported_by: ACCOUNT_D
status: OPEN
discovered_at_main_commit: d13bb366833e0fec1e89d234495b827bcdefd502
completed_art:
  - art/backgrounds/background_title.png
  - docs/assets/D-29_LAND_REPORT.json
  - docs/assets/D-29_MANIFEST.md
  - fetch_plans/D-29_fetch_plan.json
failed_contract:
  - docs/coord/done/T-32.md states that the title, game, and ending scenes do not exist and that their paths still point to res://main.tscn placeholders.
  - D-29 also requires the runtime title, educational-model disclaimer, engine font, entry buttons, subtle pulse, and up to five real screenshots.
expected:
  - A real title scene wired through T-32 routing.
  - Runtime-rendered full title, disclaimer, permitted entry buttons, and subtle pulse using the accepted background.
  - Real acceptance screenshots from the completed scene.
actual:
  - The accepted text-free background source is landed, but the runtime scene contract is not yet available.
impact:
  - Background production is preserved and must not be regenerated.
  - D-29 remains P2 integration/polish work and cannot truthfully receive DONE.
resolution_condition:
  - The title scene and final routing targets exist, then the accepted background is integrated and the required screenshots pass.
opened_at: 2026-07-29T01:03:00+08:00

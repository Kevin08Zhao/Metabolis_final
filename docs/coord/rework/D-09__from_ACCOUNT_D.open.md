target_task: D-09
reported_by: ACCOUNT_D
status: OPEN
discovered_at_main_commit: d13bb366833e0fec1e89d234495b827bcdefd502
failed_contract:
  - T-15a edge records have no flow_direction field.
  - T-15a edge records have no passage_state field.
  - T-15a edge records have no route_role or branch-parent field; all published edges carry trunk_route_id.
  - Undirected tee and four-way masks do not identify a unique directed entry/exit for arrow selection.
evidence:
  - src/world/network_builder.gd publishes edge_id, start_node_id, end_node_id, organ_id, trunk_route_id, extension_profile_id, spec_tier_id, coverage_radius, base_capacity, capacity_multiplier, and effective_capacity only.
  - docs/coord/done/T-15a.md confirms the same edge field set.
  - docs/prompts/Metabolis_Prompts_Full_v2.md D-09 requires a one-to-one mapping to flow direction, passage state, and trunk/branch values.
completed_art:
  - 132 deterministic 16 by 16 PNGs in art/tiles/d09.
  - docs/assets/D-09_VALIDATION_REPORT.json with all art checks PASS.
  - docs/assets/D-09_MANIFEST.md with the 12-cell semantic matrix and composition reduction.
  - tools/build_d09_vessel_variants.py.
expected:
  - Add explicit flow_direction with exactly outbound and return values.
  - Add explicit passage_state with exactly open, restricted, and blocked values.
  - Add explicit route_role with exactly trunk and branch values, or an unambiguous branch-parent derivation contract.
  - Define directed entry and exit interfaces for tee and four-way tiles.
actual:
  - The 132-art matrix exists and passes visual/technical checks, but runtime cannot select it one-to-one from current edge records.
impact:
  - D-09 cannot truthfully receive a DONE marker.
  - Runtime selection would otherwise require guessing scientific flow direction or inventing an undocumented branch role.
resolution_condition:
  - Upstream runtime fields and the junction direction rule are committed and verified against the 12 semantic combinations.
opened_at: 2026-07-29T01:00:46+08:00

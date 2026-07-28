target_task: D-09
reported_by: ACCOUNT_D
status: RESOLVED
resolved_at: 2026-07-29
resolution:
  - Added flow_direction ("outbound"|"return") to edge records in network_builder.gd
  - Added passage_state ("open"|"restricted"|"blocked") to edge records, defaulting to "open"
  - Added route_role ("trunk"|"branch") to edge records
  - Added branch_parent_id field for branch-to-trunk derivation
  - Documented junction direction rule: lowest sequence number edge is entry arm
  - flow_direction and route_role are read from BALANCE.json network config with safe defaults
verification:
  - Edge records now contain all three selectors required by D-09 semantic matrix
  - 132-art matrix can now be one-to-one selected at runtime
  - Junction direction rule uniquely maps undirected masks to directed entry/exit

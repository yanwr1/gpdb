-- TEST BYPASS

-- start_ignore
DROP TABLE t_bypass;
DROP ROLE role_bypass;
DROP RESOURCE GROUP rg_bypass;
-- end_ignore

-- create a resource group with concurrency = 1.
CREATE RESOURCE GROUP rg_bypass WITH(cpu_max_percent=20, concurrency=1);
CREATE ROLE role_bypass RESOURCE GROUP rg_bypass;

SET ROLE role_bypass;
CREATE TABLE t_bypass(a int) distributed by (a);
RESET ROLE;

-- Session1: pure-catalog query will be unassigned and bypassed.
1: SET ROLE role_bypass;
1: SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'suspend', 1, current_setting('gp_session_id')::int);
1&: SELECT relname FROM pg_class WHERE relname = 't_bypass';
SELECT gp_wait_until_triggered_fault('check_and_unassign_from_resgroup_entry', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

1<:
1q:
2q:

1: SET ROLE role_bypass;
1: SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'suspend', 1, current_setting('gp_session_id')::int);
1&: SELECT 1;
SELECT gp_wait_until_triggered_fault('check_and_unassign_from_resgroup_entry', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

1<:
1q:
2q:

-- Test cases for direct dispatch plan bypass (unassign).
1: SET ROLE role_bypass;
1: SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'suspend', 1, current_setting('gp_session_id')::int);
1&: INSERT INTO t_bypass VALUES (1);
SELECT gp_wait_until_triggered_fault('check_and_unassign_from_resgroup_entry', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

1<:
1q:
2q:

1: SET ROLE role_bypass;
1: SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'suspend', 1, current_setting('gp_session_id')::int);
1&: SELECT * FROM t_bypass where a = 1;
SELECT gp_wait_until_triggered_fault('check_and_unassign_from_resgroup_entry', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

1<:
1q:
2q:

-- before this line the min_cost is 0, so bypass using
-- min_cost will not work for above.
-- alter resource group's min_cost
ALTER RESOURCE GROUP rg_bypass SET min_cost 500;
ANALYZE t_bypass;
-- Session1: for quries with cost under the min_cost limit, they will be unassigned and bypassed.
1: SET gp_resource_group_bypass_direct_dispatch = 0;
1: SET ROLE role_bypass;
1: SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'suspend', 1, current_setting('gp_session_id')::int);
1&: SELECT * FROM t_bypass where a = 1;
SELECT gp_wait_until_triggered_fault('check_and_unassign_from_resgroup_entry', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('check_and_unassign_from_resgroup_entry', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

1<:
1q:
2q:

ALTER RESOURCE GROUP rg_bypass SET min_cost 0;

-- Session1: query with plan mode(top motion node have a sort child node) will be unassigned and bypassed.
-- But different from above test which bypass query before dispatch the query, the query unassign and bypass
-- current resgroup after qd's top motion fetch tuple from qe.
1: SET gp_resgroup_enable_early_bypass TO ON;
1: SET ROLE role_bypass;
1: INSERT INTO t_bypass select generate_series(1,10);
1: SELECT gp_inject_fault('func_init_plan_end', 'suspend', 1, current_setting('gp_session_id')::int);
1&: SELECT * FROM t_bypass where a < 3 ORDER BY 1;

SELECT gp_wait_until_triggered_fault('func_init_plan_end', 1, 1);

2: SET ROLE role_bypass;
2&: BEGIN;

SELECT gp_inject_fault('unassign_and_bypass_during_motion', 'suspend', 1, sess_id)
FROM pg_stat_activity WHERE rsgname = 'rg_bypass' AND wait_event_type is null;

SELECT gp_inject_fault('func_init_plan_end', 'reset', 1);

2<:
2: COMMIT;

SELECT gp_inject_fault('unassign_and_bypass_during_motion', 'reset', 1);

1<:
1q:
2q:

-- cleanup
-- start_ignore
DROP TABLE t_bypass;
DROP ROLE role_bypass;
DROP RESOURCE GROUP rg_bypass;
-- end_ignore

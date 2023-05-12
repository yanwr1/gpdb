-- TEST BYPASS

-- start_ignore
DROP TABLE t_bypass;
DROP ROLE role_bypass;
DROP RESOURCE GROUP rg_bypass;
-- end_ignore

-- create a resource group with concurrency = 1.
CREATE RESOURCE GROUP rg_bypass WITH(cpu_hard_quota_limit=20, concurrency=1);
CREATE ROLE role_bypass RESOURCE GROUP rg_bypass;

-- Session1: pure-catalog query will be unassigned and bypassed.
1: SET ROLE role_bypass;
1: CREATE TABLE t_bypass(a int);
1: SELECT relname FROM pg_class WHERE relname = 't_bypass';

-- Session2 won't be hang up
2: SET ROLE role_bypass;
2: BEGIN;

-- Reach the concurrency,session3 will be hang up.
3: SET ROLE role_bypass;
3&: BEGIN;

2: COMMIT;
3<:
3: COMMIT;

-- alter resource group's min_cost
ALTER RESOURCE GROUP rg_bypass SET min_cost 500;

-- Session1: for quries with cost under the min_cost limit, they will be unassigned and bypassed.
1: SELECT * FROM t_bypass where a = 1;

-- Session2 won't be hang up
2: SET ROLE role_bypass;
2: BEGIN;

-- Reach the concurrency,session3 will be hang up.
3: SET ROLE role_bypass;
3&: BEGIN;

2: COMMIT;
3<:
3: COMMIT;

-- cleanup
-- start_ignore
DROP TABLE t_bypass;
DROP ROLE role_bypass;
DROP RESOURCE GROUP rg_bypass;
-- end_ignore

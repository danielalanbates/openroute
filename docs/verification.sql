-- CompletionRoute :: verification chart of record
-- Applies to docs/verification.sqlite, which tools/collect_verify.py populates directly from each
-- WoW flavor's SavedVariables after running /or verifyall and /or verifyfeatures in the live client.
--   sqlite3 docs/verification.sqlite < docs/verification.sql     -- (re)create schema + read the report
--
-- Two kinds of evidence:
--   runs / failures        -- "does every guide parse and load on this client version?"
--   feature_runs / feature_checks -- "does each shipped feature actually work on this client version?"

CREATE TABLE IF NOT EXISTS runs(
    id INTEGER PRIMARY KEY,
    flavor      TEXT,   -- addon-detected flavor: era | tbc | wrath | cata | mop | retail
    client_dir  TEXT,   -- _classic_era_ | _anniversary_ | _classic_ | _retail_
    started     TEXT,
    finished    TEXT,
    total       INTEGER,
    ok          INTEGER,
    failed      INTEGER,
    UNIQUE(flavor, started));

CREATE TABLE IF NOT EXISTS failures(
    run_id   INTEGER REFERENCES runs(id),
    guide_id TEXT,
    error    TEXT);

CREATE TABLE IF NOT EXISTS feature_runs(
    id INTEGER PRIMARY KEY,
    flavor        TEXT,
    client_dir    TEXT,
    build         TEXT,   -- client TOC/interface number
    addon_version TEXT,
    at            TEXT,
    passed        INTEGER,
    failed        INTEGER,
    UNIQUE(flavor, at));

CREATE TABLE IF NOT EXISTS feature_checks(
    run_id  INTEGER REFERENCES feature_runs(id),
    feature TEXT,   -- beacon | account | core
    name    TEXT,
    pass    INTEGER,
    detail  TEXT);

-- Latest verdict per client version per check.
CREATE VIEW IF NOT EXISTS feature_matrix AS
    SELECT r.flavor, c.feature, c.name, MAX(c.pass) AS pass, MAX(r.at) AS last_run
    FROM feature_runs r JOIN feature_checks c ON c.run_id = r.id
    GROUP BY r.flavor, c.feature, c.name;

-- ---------------------------------------------------------------------------
-- Report queries
-- ---------------------------------------------------------------------------
.mode column
.headers on

-- 1. Guide coverage per client version (the "all versions, one addon" goal).
SELECT flavor, client_dir, MAX(finished) AS last_run, ok, total,
       ROUND(100.0 * ok / total, 2) AS pct_ok, failed
FROM runs GROUP BY flavor ORDER BY flavor;

-- 2. Feature matrix: one row per check, one column-ish per flavor.
SELECT feature, name,
       MAX(CASE WHEN flavor = 'era'    THEN CASE pass WHEN 1 THEN 'PASS' ELSE 'FAIL' END END) AS era,
       MAX(CASE WHEN flavor = 'tbc'    THEN CASE pass WHEN 1 THEN 'PASS' ELSE 'FAIL' END END) AS tbc,
       MAX(CASE WHEN flavor = 'mop'    THEN CASE pass WHEN 1 THEN 'PASS' ELSE 'FAIL' END END) AS mop,
       MAX(CASE WHEN flavor = 'retail' THEN CASE pass WHEN 1 THEN 'PASS' ELSE 'FAIL' END END) AS retail
FROM feature_matrix GROUP BY feature, name ORDER BY feature, name;

-- 3. Anything still failing, newest first.
SELECT r.flavor, c.feature, c.name, c.detail, r.at
FROM feature_runs r JOIN feature_checks c ON c.run_id = r.id
WHERE c.pass = 0 ORDER BY r.at DESC;

-- 4. Guides that failed to parse/load, grouped by error shape.
SELECT r.flavor, substr(f.error, 1, 60) AS error_head, COUNT(*) AS n
FROM runs r JOIN failures f ON f.run_id = r.id
GROUP BY r.flavor, error_head ORDER BY n DESC LIMIT 25;

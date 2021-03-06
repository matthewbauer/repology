-- Copyright (C) 2016-2018 Dmitry Marakasov <amdmi3@amdmi3.ru>
--
-- This file is part of repology
--
-- repology is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- repology is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with repology.  If not, see <http://www.gnu.org/licenses/>.

--------------------------------------------------------------------------------
--
-- !!get_repositories_from_past(ago) -> single dict
--
--------------------------------------------------------------------------------
SELECT
	ts AS timestamp,
	now() - ts AS timedelta,
	snapshot
FROM repositories_history
WHERE ts IN (
	SELECT
		ts
	FROM repositories_history
	WHERE ts < now() - INTERVAL %(ago)s
	ORDER BY ts DESC
	LIMIT 1
);


--------------------------------------------------------------------------------
--
-- !!get_repository_history_since(repo, since) -> array of dicts
--
--------------------------------------------------------------------------------
SELECT
	ts AS timestamp,
	now() - ts AS timedelta,
	snapshot#>ARRAY[%(repo)s] AS snapshot
FROM repositories_history
WHERE ts >= now() - INTERVAL %(since)s
ORDER BY ts;


--------------------------------------------------------------------------------
--
-- !!get_statistics_history_since(since) -> array of dicts
--
--------------------------------------------------------------------------------
SELECT
	ts AS timestamp,
	now() - ts AS timedelta,
	snapshot
FROM statistics_history
WHERE ts >= now() - INTERVAL %(since)s
ORDER BY ts;

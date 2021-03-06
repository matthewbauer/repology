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
-- !!get_maintainer_metapackages(maintainer, limit) -> array of values
--
--------------------------------------------------------------------------------
SELECT
	effname
FROM maintainer_metapackages
WHERE maintainer = %(maintainer)s
ORDER BY effname
LIMIT %(limit)s;


--------------------------------------------------------------------------------
--
-- !!get_maintainer_similar_maintainers(maintainer, limit) -> array of dicts
--
--------------------------------------------------------------------------------

-- this obscure request needs some clarification
--
-- what we calculate as score here is actually Jaccard index
-- (see wikipedia) for two sets (of metapackages maintained by
-- two maintainers)
--
-- let M = set of metapackages for maintainer passed to this function
-- let C = set of metapackages for other maintainer we test for similarity
--
-- score = |M⋂C| / |M⋃C| = |M⋂C| / (|M| + |C| - |M⋂C|)
--
-- - num_metapackages_common is |M⋂C|
-- - num_metapackages is |C|
-- - sub-select just gets |M|
-- - the divisor thus is |M⋃C| = |M| + |C| - |M⋂C|
SELECT
	maintainer,
	num_metapackages_common AS count,
	100.0 * num_metapackages_common / (
		num_metapackages - num_metapackages_common + (
			SELECT num_metapackages
			FROM maintainers
			WHERE maintainer = %(maintainer)s
		)
	) AS match
FROM
	(
		SELECT
			maintainer,
			count(*) AS num_metapackages_common
		FROM
			maintainer_metapackages
		WHERE
			maintainer != %(maintainer)s AND
			effname IN (
				SELECT
					effname
				FROM maintainer_metapackages
				WHERE maintainer = %(maintainer)s
			)
		GROUP BY maintainer
	) AS intersecting_counts
	INNER JOIN maintainers USING(maintainer)
ORDER BY match DESC
LIMIT %(limit)s;


--------------------------------------------------------------------------------
--
-- !!get_maintainer_information(maintainer) -> single dict
--
--------------------------------------------------------------------------------
SELECT
	num_packages,
	num_packages_newest,
	num_packages_outdated,
	num_packages_ignored,
	num_packages_unique,
	num_packages_devel,
	num_packages_legacy,
	num_packages_incorrect,
	num_packages_untrusted,
	num_packages_noscheme,
	num_packages_rolling,
	num_metapackages,
	num_metapackages_outdated,
	repository_package_counts,
	repository_metapackage_counts,
	category_metapackage_counts
FROM maintainers
WHERE maintainer = %(maintainer)s;


--------------------------------------------------------------------------------
--
-- !!get_all_maintainer_names(limit=None) -> array of values
--
--------------------------------------------------------------------------------
SELECT
	maintainer
FROM maintainers
LIMIT %(limit)s;


--------------------------------------------------------------------------------
--
-- !!query_maintainers(pivot=None, reverse=False, search=None, limit=None) -> array of dicts
--
--------------------------------------------------------------------------------
SELECT
	*
FROM (
	SELECT
		maintainer,
		num_packages,
		num_metapackages,
		num_metapackages_outdated
	FROM maintainers
	WHERE
		(
			num_packages > 0
		{% if pivot %}
		) AND (
			-- pivot condition
			{% if reverse %}
			maintainer <= %(pivot)s
			{% else %}
			maintainer >= %(pivot)s
			{% endif %}
		{% endif %}
		{% if search %}
		) AND (
			-- search condition
			maintainer LIKE ('%%' || %(search)s || '%%')
		{% endif %}
		)
	ORDER BY
		maintainer{% if reverse %} DESC{% endif %}
	LIMIT %(limit)s
) AS tmp
ORDER BY maintainer;


--------------------------------------------------------------------------------
--
-- !!get_recently_added_maintainers(limit=None) -> array of dicts
--
--------------------------------------------------------------------------------
SELECT
	now() - first_seen AS ago,
	maintainer
FROM maintainers
WHERE num_packages > 0
ORDER BY first_seen DESC, maintainer
LIMIT %(limit)s;


--------------------------------------------------------------------------------
--
-- !!get_recently_removed_maintainers(limit=None) -> array of dicts
--
--------------------------------------------------------------------------------
SELECT
	now() - last_seen AS ago,
	maintainer
FROM maintainers
WHERE num_packages = 0
ORDER BY last_seen DESC, maintainer
LIMIT %(limit)s;

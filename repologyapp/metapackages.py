# Copyright (C) 2016-2017 Dmitry Marakasov <amdmi3@amdmi3.ru>
#
# This file is part of repology
#
# repology is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# repology is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with repology.  If not, see <http://www.gnu.org/licenses/>.

import flask

from repology.database import MetapackageRequest
from repology.package import VersionClass
from repology.packageproc import PackagesetSortByVersion


class MetapackagesFilterInfo:
    fields = {
        'search': {
            'type': str,
            'advanced': False,
            'action': lambda request, value: request.NameSubstring(value.strip().lower()),
        },
        'maintainer': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.Maintainer(value.strip().lower()),
        },
        'category': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.Category(value.strip()),  # case sensitive (yet)
        },
        'inrepo': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.InRepo(value.strip().lower()),
        },
        'notinrepo': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.NotInRepo(value.strip().lower()),
        },
        'repos': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.Repos(value),
        },
        'families': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.Families(value),
        },
        'repos_newest': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.ReposNewest(value),
        },
        'families_newest': {
            'type': str,
            'advanced': True,
            'action': lambda request, value: request.FamiliesNewest(value),
        },
        'newest': {
            'type': bool,
            'advanced': True,
            'action': lambda request, value: request.Newest(),
        },
        'outdated': {
            'type': bool,
            'advanced': True,
            'action': lambda request, value: request.Outdated(),
        },
        'problematic': {
            'type': bool,
            'advanced': True,
            'action': lambda request, value: request.Problematic(),
        },
    }

    def __init__(self):
        self.args = {}

    def ParseFlaskArgs(self):
        flask_args = flask.request.args.to_dict()

        for fieldname, fieldinfo in MetapackagesFilterInfo.fields.items():
            if fieldname in flask_args:
                if fieldinfo['type'] == bool:
                    self.args[fieldname] = True
                elif fieldinfo['type'] == int and flask_args[fieldname].isdecimal():
                    self.args[fieldname] = int(flask_args[fieldname])
                elif fieldinfo['type'] == str and flask_args[fieldname]:
                    self.args[fieldname] = flask_args[fieldname]

    def GetDict(self):
        return self.args

    def GetRequest(self):
        request = MetapackageRequest()
        for fieldname, fieldinfo in MetapackagesFilterInfo.fields.items():
            if fieldname in self.args:
                fieldinfo['action'](request, self.args[fieldname])

        return request

    def GetMaintainer(self):
        return self.args['maintainer'] if 'maintainer' in self.args else None

    def GetRepo(self):
        return self.args['inrepo'] if 'inrepo' in self.args else None

    def IsAdvanced(self):
        for fieldname in self.args.keys():
            if MetapackagesFilterInfo.fields[fieldname]['advanced']:
                return True
        return False


def get_packages_name_range(packages):
    firstname, lastname = None, None

    if packages:
        firstname = lastname = packages[0].effname
        for package in packages[1:]:
            lastname = max(lastname, package.effname)
            firstname = min(firstname, package.effname)

    return firstname, lastname


def metapackages_to_summary_items(metapackages, repo=None, maintainer=None):
    metapackagedata = {}

    for metapackagename, packages in metapackages.items():
        # we gather two kinds of statistics: one is for explicitly requested
        # subset of packages (e.g. ones belonging to specified repo or maintainer)
        # and a general one for all other packages
        summaries = {
            sumtype: {
                'keys': [],
                'families_by_key': {}
            } for sumtype in ['explicit', 'newest', 'outdated', 'ignored']
        }

        # gather summaries
        for package in PackagesetSortByVersion(packages):
            key = (package.version, package.versionclass)
            target = None

            if (repo is not None and repo == package.repo) or (repo is None and maintainer is not None and maintainer in package.maintainers):
                target = summaries['explicit']
            elif package.versionclass in [VersionClass.outdated, VersionClass.legacy]:
                target = summaries['outdated']
                key = (package.version, VersionClass.outdated)  # we don't to distinguish legacy here
            elif package.versionclass in [VersionClass.devel, VersionClass.newest, VersionClass.unique]:
                target = summaries['newest']
            else:
                target = summaries['ignored']

            if key not in target['families_by_key']:
                target['keys'].append(key)

            target['families_by_key'].setdefault(key, set()).add(package.family)

        # convert summaries
        for sumtype, summary in summaries.items():
            summaries[sumtype] = [
                {
                    'version': key[0],
                    'versionclass': key[1],
                    'families': summary['families_by_key'][key]
                } for key in summary['keys']
            ]

        metapackagedata[metapackagename] = {
            **summaries
        }

    return metapackagedata

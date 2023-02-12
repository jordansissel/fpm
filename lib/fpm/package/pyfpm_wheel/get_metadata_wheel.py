import os
import sys
import pkg_resources
from pkginfo import Wheel
import traceback

import json

# If you have fixes, let me know.

class get_metadata_wheel:
    wheel_path = None

    def __init__(self, wheel_path):
        self.wheel_path = wheel_path

    def process_dep(self, dep):
        deps = []
        if hasattr(dep, 'marker') and dep.marker:
            # PEP0508 marker present
            if not dep.marker.evaluate():
                return deps

        if dep.specs:
            for operator, version in dep.specs:
                deps.append("%s %s %s" % (dep.project_name,
                        operator, version))
        else:
            deps.append(dep.project_name)

        return deps

    def get_home_url(self, project_urls):
        res = dict([i.strip() for i in x.split(',')] for x in project_urls)
        return res.get('Home', None)

    def run(self, output_path):

        fpm_wheel = Wheel(self.wheel_path)
        data = {
            "name": fpm_wheel.name,
            "version": fpm_wheel.version,
            "description": fpm_wheel.summary,
            "license": fpm_wheel.license,
        }

        if fpm_wheel.author:
            data["author"] = "%s <%s>" % (fpm_wheel.author, fpm_wheel.author_email)
        else:
            data["author"] = "%s" % (fpm_wheel.author_email)

        if fpm_wheel.home_page:
            data["url"] =  fpm_wheel.home_page
        else:
            data["url"] =  self.get_home_url(fpm_wheel.project_urls)

        # @todo FIXME!!!
        if fpm_wheel.requires_external:
            data["architecture"] = "native"
        else:
            data["architecture"] = "all"

        print('REQ-TOML:', fpm_wheel.requires, file=sys.stderr)
        print('REQ-TOML DIST:', fpm_wheel.requires_dist, file=sys.stderr)


        final_deps = []

        # @todo FIXME!!!

        try:
            if fpm_wheel.requires_dist:
                for dep in pkg_resources.parse_requirements(fpm_wheel.requires_dist):
                    final_deps.extend(self.process_dep(dep))

    #        if fpm_wheel.requires_dist:
    #            for dep in pkg_resources.parse_requirements(
    #                    v for k, v in fpm_wheel.requires_dist
    #                    if k.startswith(':') and pkg_resources.evaluate_marker(k[1:])):
    #                final_deps.extend(self.process_dep(dep))
        except Exception as e:
            print('REQ-TOML-DEPS-EXCEPTION:', str(e), '\n', repr(traceback.format_exc()), file=sys.stderr)
            raise


        print('REQ-TOML-FINAL-DEPS:', final_deps, file=sys.stderr)
        data["dependencies"] = final_deps

        with open(output_path, "w") as output:
            def default_to_str(obj):
                """ Fall back to using __str__ if possible """
                # This checks if the class of obj defines __str__ itself,
                # so we don't fall back to an inherited __str__ method.
                if "__str__" in type(obj).__dict__:
                    return str(obj)
                return json.JSONEncoder.default(self, obj)

            output.write(json.dumps(data, indent=2, sort_keys=True, default=default_to_str))

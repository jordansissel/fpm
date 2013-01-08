from distutils.core import Command
import pkg_resources
try:
    import simplejson as json
except ImportError:
    import json


# Note, the last time I coded python daily was at Google, so it's entirely
# possible some of my techniques below are outdated or bad.
# If you have fixes, let me know.

class get_metadata(Command):
    description = "get package metadata"
    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):
        data = {
            "name": self.distribution.get_name(),
            "version": self.distribution.get_version(),
            "author": "%s <%s>" % (
                self.distribution.get_author(),
                self.distribution.get_author_email()
            ),
            "description": self.distribution.get_description(),
            "license": self.distribution.get_license(),
            "url": self.distribution.get_url(),
        }

        if self.distribution.has_ext_modules():
            data["architecture"] = "native"
        else:
            data["architecture"] = "all"

        final_deps = []
        if getattr(self.distribution, 'install_requires', None):
            for dep in pkg_resources.parse_requirements(
                    self.distribution.install_requires):
                # add all defined specs to the dependecy list separately.
                if dep.specs:
                    for operator, version in dep.specs:
                        final_deps.append("%s %s %s" % (
                            dep.project_name,
                            (lambda x: "=" if x == "==" else x)(operator),
                            version
                        ))
                else:
                    final_deps.append(dep.project_name)

        data["dependencies"] = final_deps

        if hasattr(json, 'dumps'):
            print(json.dumps(data, indent=2))
        else:
            # For Python 2.5 and Debian's python-json
            print(json.write(data))

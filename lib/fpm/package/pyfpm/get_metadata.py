from distutils.core import Command
import re
import time
import pkg_resources
try:
    import json
except ImportError:
    import simplejson as json

# Note, the last time I coded python daily was at Google, so it's entirely
# possible some of my techniques below are outdated or bad.
# If you have fixes, let me know.


class get_metadata(Command):
  description = "get package metadata"
  user_options = []

  def initialize_options(self):
    pass
  # def initialize_options

  def finalize_options(self):
    pass
  # def finalize_options

  def run(self):
    #print type(self.distribution)
    #for i in sorted(dir(self.distribution)):
      #if i.startswith("_"):
        #continue
      ###print "%s: %r" % (i, self.__getattr__(i))
      #print "%s" % i

    data = {
      "name": self.distribution.get_name(),
      "version": self.distribution.get_version(),
      "author": "%s <%s>" % (self.distribution.get_author(),
        self.distribution.get_author_email()),
      "description": self.distribution.get_description(),
      "license": self.distribution.get_license(),
      "url": self.distribution.get_url(),
    }

    # If there are python C/extension modules, we'll want to build a native
    # arch package.
    if self.distribution.has_ext_modules():
      data["architecture"] = "native"
    else:
      data["architecture"] = "all"
    # end if

    final_deps = []
    if getattr(self.distribution, 'install_requires', None):
        for dep in pkg_resources.parse_requirements(self.distribution.install_requires):
            # add all defined specs to the dependecy list separately.
            if dep.specs:
                for operator, version in dep.specs:
                    final_deps.append("%s %s %s" % (
                        dep.project_name,
                        "=" if operator == "==" else operator,
                        version
                    ))
            else:
                final_deps.append(dep.project_name)            

    data["dependencies"] = final_deps

    #print json.dumps(data, indent=2)
    if hasattr(json, 'dumps'):
        print(json.dumps(data, indent=2))
    else:
        # For Python 2.5 and Debian's python-json
        print(json.write(data))
  # def run
# class list_dependencies

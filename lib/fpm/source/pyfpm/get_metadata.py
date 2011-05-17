from distutils.core import Command
import json
import re
import time

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

    dependencies = None
    try:
      dependencies = self.distribution.install_requires
    except:
      pass
    
    # In some cases (Mysql-Python) 'dependencies' is none, not empty.
    if dependencies is None:
      dependencies = []

    final_deps = []
    dep_re = re.compile("([^<>= ]+)(?:\s*([<>=]{1,2})\s*(.*))?$")
    for dep in dependencies:
      # python deps are strings that look like:
      # "packagename"
      # "packagename >= version"
      # Replace 'packagename' with 'python#{suffix}-packagename'
      m = dep_re.match(dep)
      if m is None:
        print "Bad dep: %s" % dep
        time.sleep(3)
      elif m.groups()[1] is None:
        name, cond, version = m.groups()[0], ">=", 0
      else:
        name, cond, version = m.groups()
      # end if

      final_deps.append("%s %s %s" % (name, cond, version))
    # end for i in dependencies

    data["dependencies"] = final_deps

    #print json.dumps(data, indent=2)
    print json.dumps(data, indent=2)
  # def run
# class list_dependencies

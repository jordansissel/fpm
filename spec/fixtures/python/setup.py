from setuptools import setup

setup(name="Example",
      version="1.0",
      description="sample description",
      author="sample author",
      author_email="sample email",
      url="sample url",
      packages=[],
      package_dir={},
      install_requires=[
          "Dependency1", "dependency2",
          # XXX: I don't know what these python_version-dependent deps mean
          # needs investigation
          # Reference: PEP-0508
           'rtxt-dep3; python_version == "2.0"',
           'rtxt-dep4; python_version > "2.0"',
           ],
      )


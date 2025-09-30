#!/usr/bin/env python3

#import pkg_resources
import packaging.requirements
import json
import sys

# Expect requirements lines via stdin.
#requirements = pkg_resources.parse_requirements(sys.stdin)

# Process environment markers, if any, and produce a list of requirements for the current environment.
def evaluate_requirements(fd):
    all_requirements = [packaging.requirements.Requirement(line) for line in sys.stdin]
    
    for req in all_requirements:
        # XXX: Note: marker.evaluate() can be given a dict() containing environment values to overwrite
        if req.marker is None or req.marker.evaluate():
            if len(req.specifier) > 0:
                for spec in req.specifier:
                    yield "%s%s" % (req.name, spec)
            else:
                yield str(req.name)

print(json.dumps(list(evaluate_requirements(sys.stdin))))

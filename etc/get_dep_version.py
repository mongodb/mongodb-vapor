import json
import sys

# Prints out the name of a dependency as specified in Package.resolved.
# Usage: python3 get_dep_version.py [package name]
# for example: python3 get_dep_version.py swift-bson

if len(sys.argv[1:]) != 1:
    print("Error: Expected exactly one argument to program, got: {}".format(sys.argv[1:]))
    exit(1)

package_name = sys.argv[1]

with open('Package.resolved', 'r') as f:
    data = json.load(f)
    try:
        package_data = next(d for d in data['object']['pins'] if d['package'] == package_name)
    except StopIteration:
        print("Error: No package named {}".format(package_name))
        exit(1)
    print(package_data['state']['version'])

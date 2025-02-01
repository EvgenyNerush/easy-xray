#!/usr/bin/env python3

# This script is designed for updating markdown files that contain
# application-dependent rulesets. Such rulesets can be auto-generated
# based on pre-defined templates and the contents of customgeo files.
# The rulesets to update are prepended with [identifier]:: which serves
# as regex marker (not rendered in the final html). Currently it only
# supports v2rayTun*.md files. Note that it also backs up original data
# with .bak extension.

import glob
import re
from base64 import b64encode
from json import dumps, loads

ANDROID = '''
[
    {{
        "domain": {},
        "enabled": true,
        "locked": false,
        "outboundTag": "proxy",
        "remarks": "proxy"
    }},
    {{
        "domain": {},
        "enabled": true,
        "locked": false,
        "outboundTag": "direct",
        "remarks": "direct"
    }}
]
'''

IOS = '''
{{
    "rules": [
        {{
            "domainMatcher": "hybrid",
            "__id__": "DB498D40-7F75-422D-B42A-70B3D22178C9",
            "type": "field",
            "__name__": "proxy",
            "outboundTag": "freedom",
            "domain": {}
        }},
        {{
            "domainMatcher": "hybrid",
            "__id__": "BC4542AF-9067-4D4E-99C6-0A3149909405",
            "type": "field",
            "__name__": "direct",
            "outboundTag": "freedom",
            "domain": {}
        }}
    ],
    "id": "5247B809-ADDB-4D7D-B91F-234CD511740E",
    "domainMatcher": "hybrid",
    "name": "Customgeo",
    "domainStrategy": "AsIs",
    "balancers": []
}}
'''

ROOT = "../docs/"

WARNING = '\033[93m'
ENDC = '\033[0m'

SEPS = (",", ":")

RE = r"(\[{}\]:: *\n``` *\n).*(\n```)"

def main():
    with open("customgeo4nekoray.txt") as direct,\
         open("customgeo-exceptions-4nekoray.txt") as proxy:
        direct = dumps(direct.read().splitlines(), separators=SEPS)
        proxy = dumps(proxy.read().splitlines(), separators=SEPS)

    ios = dumps(loads(IOS.format(proxy, direct)), separators=SEPS)
    ios = f"v2rayTun://import_route/{b64encode(ios.encode('ascii')).decode()}"
    android = dumps(loads(ANDROID.format(proxy, direct)), separators=SEPS)

    for file in glob.glob(ROOT + "v2RayTun*.md"):
        print(f"Processing {file}...")
        with open(file, "r+") as f,\
             open(file + ".bak", "w") as bak:
            data = f.read()
            bak.write(data)
            data, n = re.subn(RE.format("ios"), r"\1{}\2".format(ios), data, re.I)
            if n == 0:
                print(f"{WARNING}  Warning: iOS ruleset was not found{ENDC}")
            data, n = re.subn(RE.format("android"), r"\1{}\2".format(android), data, re.I)
            if n == 0:
                print(f"{WARNING}  Warning: Android ruleset was not found{ENDC}")
            f.seek(0)
            f.truncate()
            f.write(data)

if __name__ == "__main__":
    main()

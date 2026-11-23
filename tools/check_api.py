#!/usr/bin/env python3
"""Rough check of Roblox API names used in src/ against an API dump.

It catches typos rather than type errors: every Enum.Type.Item must exist, every
Instance.new("Class") must be a creatable class, and every `.Name =` assignment and
`:Name(` call must be a property or method of *some* Roblox class (or a name this
project defines itself).

Usage (from the repository root):
  curl -o API-Dump.json https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json
  python3 tools/check_api.py API-Dump.json
"""

import json
import pathlib
import re
import sys


def main() -> int:
    dump_path = sys.argv[1] if len(sys.argv) > 1 else "API-Dump.json"
    dump = json.load(open(dump_path))

    classes = {c["Name"]: c for c in dump["Classes"]}
    enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in dump["Enums"]}
    properties = set()
    methods = set()
    for cls in dump["Classes"]:
        for member in cls["Members"]:
            if member["MemberType"] == "Property":
                properties.add(member["Name"])
            elif member["MemberType"] == "Callback":
                properties.add(member["Name"])
            elif member["MemberType"] in ("Function", "YieldFunction"):
                methods.add(member["Name"])

    sources = sorted(pathlib.Path("src").rglob("*.luau"))
    text = {path: path.read_text() for path in sources}

    # Names the project defines itself: table fields, functions and methods.
    own = set()
    for source in text.values():
        own.update(re.findall(r"function\s+[\w.]+[.:](\w+)\s*\(", source))
        own.update(re.findall(r"^\s*(\w+)\s*=", source, re.M))
        own.update(re.findall(r"[{,]\s*(\w+)\s*=", source))
        own.update(re.findall(r"\b(\w+)\s*:\s*[\w({]", source))  # type fields

    # Luau built-in methods on strings, datatypes and signals.
    builtin_methods = {
        "Connect", "Disconnect", "Once", "Wait", "Lerp", "Inverse", "PointToObjectSpace",
        "PointToWorldSpace", "ToObjectSpace", "ToWorldSpace", "VectorToObjectSpace", "Dot",
        "Cross", "Min", "Max", "Fire", "Play", "Cancel", "Pause", "format", "find", "match",
        "VectorToWorldSpace", "GetComponents",
        "gsub", "sub", "lower", "upper",
    }
    datatype_properties = {
        "X", "Y", "Z", "Position", "Rotation", "LookVector", "UpVector", "RightVector",
        "Magnitude", "Unit", "Origin", "Direction", "Distance", "Instance", "Normal",
        "Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight", "Value",
        "FilterType", "FilterDescendantsInstances", "CollisionGroup", "RespectCanCollide",
        "MaxParts", "IgnoreWater", "__index", "__mode",
    }

    problems = []
    for path, source in text.items():
        stripped = re.sub(r"--[^\n]*", "", source)
        for type_name, item in re.findall(r"\bEnum\.(\w+)\.(\w+)", stripped):
            if type_name not in enums:
                problems.append(f"{path}: unknown enum Enum.{type_name}")
            elif item not in enums[type_name]:
                problems.append(f"{path}: Enum.{type_name} has no item {item}")
        for class_name in re.findall(r'Instance\.new\(\s*"(\w+)"', stripped):
            cls = classes.get(class_name)
            if not cls:
                problems.append(f"{path}: unknown class {class_name}")
            elif "NotCreatable" in cls.get("Tags", []):
                problems.append(f"{path}: class {class_name} cannot be created")
        # Tables created with `local X = {...}` (modules, option tables) are ours, not Instances.
        modules = set(re.findall(r"local\s+(\w+)\s*(?::[^=\n]+)?=\s*\{", stripped))
        # Fields declared in this file's own types (`name: Type`) belong to its tables.
        fields = set(re.findall(r"\b(\w+)\s*:\s*[\w({]", stripped))
        for receiver, name in re.findall(r"(\w+)\.(\w+)\s*=(?!=)", stripped):
            if receiver in modules or receiver == "self" or name in fields:
                continue
            if name not in properties and name not in datatype_properties:
                problems.append(f"{path}: assigns unknown property {receiver}.{name}")
        for name in re.findall(r"[\w)\]]:(\w+)\s*\(", stripped):
            if name not in methods and name not in own and name not in builtin_methods:
                problems.append(f"{path}: calls unknown method :{name}()")

    for problem in sorted(set(problems)):
        print(problem)
    print(f"Checked {len(sources)} files: {len(set(problems))} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

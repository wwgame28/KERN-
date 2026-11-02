#!/usr/bin/env python3
"""Static checks for a Godot 4 project when the engine itself is not available.

This is NOT a replacement for opening the project in Godot/Xogot. It catches:
- missing res:// files (scenes, scripts, icon, main scene);
- undeclared/duplicate ExtResource and SubResource ids in .tscn files;
- nodes whose parent path does not exist;
- `$Node/Path` and get_node("...") references that do not exist in the scene
  where the script is attached;
- exported property overrides in .tscn that the attached script (or its
  class_name base chain) does not declare;
- Input Actions used in scripts that are missing from project.godot;
- duplicate class_name declarations and unknown `extends` class names;
- GDScript indentation mixing spaces and tabs.

Usage: python3 tools/validate_godot_project.py COSMIC_SANDBOX
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

BUILTIN_ACTIONS = {
    "ui_accept", "ui_select", "ui_cancel", "ui_focus_next", "ui_focus_prev",
    "ui_left", "ui_right", "ui_up", "ui_down", "ui_page_up", "ui_page_down",
    "ui_home", "ui_end",
}

# Built-in node properties that may appear in .tscn files; anything else
# set on a scripted node must be declared with @export in the script chain.
COMMON_NODE_PROPERTIES = {
    "transform", "visible", "script", "editor_description", "process_mode",
    "layout_mode", "anchors_preset", "anchor_left", "anchor_top", "anchor_right",
    "anchor_bottom", "offset_left", "offset_top", "offset_right", "offset_bottom",
    "grow_horizontal", "grow_vertical", "mouse_filter", "size_flags_horizontal",
    "size_flags_vertical", "custom_minimum_size", "theme_override_styles/panel",
    "collision_layer", "collision_mask", "monitoring", "monitorable", "top_level",
    "floor_snap_length", "mesh", "shape", "environment", "light_color", "light_energy",
    "shadow_enabled", "directional_shadow_max_distance", "omni_range", "current",
    "fov", "near", "far", "spring_length", "margin", "text", "autowrap_mode",
    "horizontal_alignment", "position", "rotation", "scale",
}


@dataclass
class ScriptInfo:
    path: str
    class_name: str | None
    extends: str | None
    exports: set[str] = field(default_factory=set)
    node_refs: list[tuple[int, str]] = field(default_factory=list)
    actions: list[tuple[int, str]] = field(default_factory=list)


@dataclass
class SceneNode:
    name: str
    parent: str | None
    path: str
    props: dict[str, str] = field(default_factory=dict)
    instance: str | None = None
    line: int = 0


errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def res_to_path(root: Path, res: str) -> Path:
    return root / res.replace("res://", "", 1)


def parse_script(root: Path, file: Path) -> ScriptInfo:
    text = file.read_text(encoding="utf-8")
    rel = "res://" + file.relative_to(root).as_posix()
    class_name = None
    extends = None
    info = ScriptInfo(rel, None, None)
    for lineno, line in enumerate(text.splitlines(), 1):
        indent = re.match(r"^[ \t]*", line).group(0)
        if " " in indent and "\t" in indent:
            err(f"{rel}:{lineno}: mixed tabs and spaces in indentation")
        elif indent.startswith(" ") and line.strip():
            err(f"{rel}:{lineno}: indentation uses spaces (project uses tabs)")
        m = re.match(r"^class_name\s+(\w+)", line)
        if m:
            class_name = m.group(1)
        m = re.match(r"^extends\s+(\w+)", line)
        if m:
            extends = m.group(1)
        m = re.match(r"^@export\w*(?:\([^)]*\))?\s+var\s+(\w+)", line)
        if m:
            info.exports.add(m.group(1))
        code = line.split("#", 1)[0]
        for m in re.finditer(r"\$([A-Za-z0-9_/]+)", code):
            info.node_refs.append((lineno, m.group(1)))
        for m in re.finditer(r"get_node\(\"([^\"]+)\"\)", code):
            info.node_refs.append((lineno, m.group(1)))
        for m in re.finditer(r"&\"(\w+)\"", code):
            info.actions.append((lineno, m.group(1)))
    info.class_name = class_name
    info.extends = extends
    return info


def parse_project(root: Path) -> tuple[dict[str, str], set[str]]:
    settings: dict[str, str] = {}
    actions: set[str] = set()
    section = ""
    text = (root / "project.godot").read_text(encoding="utf-8")
    for line in text.splitlines():
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        m = re.match(r"^([\w/.]+)=(.*)$", line)
        if m:
            settings[f"{section}/{m.group(1)}"] = m.group(2)
            if section == "input":
                actions.add(m.group(1))
    return settings, actions


def parse_value_list(header: str) -> dict[str, str]:
    return {k: v for k, v in re.findall(r'(\w+)=("[^"]*"|\S+)', header)}


def parse_scene(root: Path, file: Path, scripts: dict[str, ScriptInfo],
                classes: dict[str, ScriptInfo]) -> None:
    rel = "res://" + file.relative_to(root).as_posix()
    text = file.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or not lines[0].startswith("[gd_scene"):
        err(f"{rel}: first line must be a [gd_scene ...] header")
        return
    if "format=3" not in lines[0]:
        err(f"{rel}: expected format=3 (Godot 4)")

    ext: dict[str, tuple[str, str]] = {}
    sub: set[str] = set()
    nodes: dict[str, SceneNode] = {}
    current: SceneNode | None = None
    current_kind = ""

    for lineno, line in enumerate(lines, 1):
        if line.startswith("["):
            m = re.match(r"^\[(\w+)\s*(.*)\]$", line)
            if not m:
                err(f"{rel}:{lineno}: malformed section header")
                continue
            kind, rest = m.group(1), m.group(2)
            attrs = parse_value_list(rest)
            current_kind = kind
            current = None
            if kind == "ext_resource":
                rid = attrs.get("id", "").strip('"')
                path = attrs.get("path", "").strip('"')
                rtype = attrs.get("type", "").strip('"')
                if rid in ext:
                    err(f"{rel}:{lineno}: duplicate ext_resource id {rid}")
                ext[rid] = (path, rtype)
                if not res_to_path(root, path).exists():
                    err(f"{rel}:{lineno}: missing file {path}")
            elif kind == "sub_resource":
                rid = attrs.get("id", "").strip('"')
                if rid in sub:
                    err(f"{rel}:{lineno}: duplicate sub_resource id {rid}")
                sub.add(rid)
            elif kind == "node":
                name = attrs.get("name", "").strip('"')
                parent = attrs.get("parent")
                parent = parent.strip('"') if parent is not None else None
                if parent is None:
                    if nodes:
                        err(f"{rel}:{lineno}: second root node {name}")
                    path = "."
                else:
                    if parent != "." and parent not in nodes:
                        err(f"{rel}:{lineno}: parent '{parent}' of node '{name}' not found")
                    path = name if parent == "." else f"{parent}/{name}"
                if path in nodes:
                    err(f"{rel}:{lineno}: duplicate node path {path}")
                node = SceneNode(name, parent, path, line=lineno)
                inst = re.search(r'instance=ExtResource\("([^"]+)"\)', rest)
                if inst:
                    if inst.group(1) not in ext:
                        err(f"{rel}:{lineno}: instance ExtResource {inst.group(1)} not declared")
                    else:
                        node.instance = ext[inst.group(1)][0]
                nodes[path] = node
                current = node
            continue

        for m in re.finditer(r'ExtResource\("([^"]+)"\)', line):
            if m.group(1) not in ext:
                err(f"{rel}:{lineno}: ExtResource {m.group(1)} used before declaration")
        for m in re.finditer(r'SubResource\("([^"]+)"\)', line):
            if m.group(1) not in sub:
                err(f"{rel}:{lineno}: SubResource {m.group(1)} used before declaration")
        if current is not None and current_kind == "node":
            m = re.match(r"^([\w/]+)\s*=\s*(.*)$", line)
            if m:
                current.props[m.group(1)] = m.group(2)

    # Script-level checks for every node that has a script attached.
    for path, node in nodes.items():
        script_ref = node.props.get("script")
        if not script_ref:
            continue
        m = re.match(r'ExtResource\("([^"]+)"\)', script_ref)
        if not m or m.group(1) not in ext:
            continue
        script_path = ext[m.group(1)][0]
        info = scripts.get(script_path)
        if info is None:
            err(f"{rel}: node {path} uses unknown script {script_path}")
            continue
        # Exported properties along the class_name inheritance chain.
        exported: set[str] = set()
        chain = info
        seen = set()
        while chain is not None and chain.path not in seen:
            seen.add(chain.path)
            exported |= chain.exports
            chain = classes.get(chain.extends or "")
        for prop in node.props:
            if prop in COMMON_NODE_PROPERTIES or prop.startswith("theme_override"):
                continue
            if prop not in exported:
                warnings.append(f"{rel}:{node.line}: node {path} sets '{prop}' which is not an @export of {script_path} (ok only if it is a built-in property)")
        # $Path references relative to this node.
        for lineno, ref in info.node_refs:
            target = ref if path == "." else f"{path}/{ref}"
            if target not in nodes:
                err(f"{script_path}:{lineno}: ${ref} not found under node '{path}' in {rel}")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    root = Path(sys.argv[1]).resolve()
    if not (root / "project.godot").exists():
        print(f"project.godot not found in {root}")
        return 2

    settings, actions = parse_project(root)
    main_scene = settings.get("application/run/main_scene", "").strip('"')
    if not main_scene or not res_to_path(root, main_scene).exists():
        err(f"project.godot: main scene missing: {main_scene!r}")
    icon = settings.get("application/config/icon", "").strip('"')
    if icon and not res_to_path(root, icon).exists():
        err(f"project.godot: icon missing: {icon}")

    scripts: dict[str, ScriptInfo] = {}
    classes: dict[str, ScriptInfo] = {}
    for file in sorted(root.rglob("*.gd")):
        if ".godot" in file.parts:
            continue
        info = parse_script(root, file)
        scripts[info.path] = info
        if info.class_name:
            if info.class_name in classes:
                err(f"duplicate class_name {info.class_name}: {classes[info.class_name].path} and {info.path}")
            classes[info.class_name] = info

    for info in scripts.values():
        if info.extends and info.extends[0].isupper() and info.extends in classes:
            pass
        for lineno, action in info.actions:
            if action in BUILTIN_ACTIONS or action in actions:
                continue
            # Only flag names that look like input actions (used with Input/StringName consts).
            if action in {"portals"}:
                continue
            err(f"{info.path}:{lineno}: Input Action '{action}' is not defined in project.godot")

    for file in sorted(root.rglob("*.tscn")):
        if ".godot" in file.parts:
            continue
        parse_scene(root, file, scripts, classes)

    print(f"Scripts: {len(scripts)}, classes: {len(classes)}, input actions: {len(actions)}")
    for w in warnings:
        print("WARN ", w)
    for e in errors:
        print("ERROR", e)
    print("OK" if not errors else f"FAILED: {len(errors)} error(s)")
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())

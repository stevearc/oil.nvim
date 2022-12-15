import os
from dataclasses import dataclass, field
import os.path
import re
from functools import lru_cache
from typing import List

from nvim_doc_tools.vimdoc import format_vimdoc_params
from nvim_doc_tools import (
    Command,
    LuaParam,
    Vimdoc,
    VimdocSection,
    commands_from_json,
    format_md_commands,
    format_vimdoc_commands,
    generate_md_toc,
    indent,
    leftright,
    parse_functions,
    read_nvim_json,
    read_section,
    render_md_api,
    render_vimdoc_api,
    replace_section,
    wrap,
)

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, os.path.pardir))
README = os.path.join(ROOT, "README.md")
DOC = os.path.join(ROOT, "doc")
VIMDOC = os.path.join(DOC, "oil.txt")


def add_md_link_path(path: str, lines: List[str]) -> List[str]:
    ret = []
    for line in lines:
        ret.append(re.sub(r"(\(#)", "(" + path + "#", line))
    return ret


def update_md_api():
    funcs = parse_functions(os.path.join(ROOT, "lua", "oil", "init.lua"))
    lines = ["\n"] + render_md_api(funcs, 3) + ["\n"]
    replace_section(
        README,
        r"^<!-- API -->$",
        r"^<!-- /API -->$",
        lines,
    )


def update_readme_toc():
    toc = ["\n"] + generate_md_toc(README, max_level=1) + ["\n"]
    replace_section(
        README,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )


def update_config_options():
    config_file = os.path.join(ROOT, "lua", "oil", "config.lua")
    opt_lines = read_section(config_file, r"^\s*local default_config =", r"^}$")
    replace_section(
        README,
        r"^require\(\"oil\"\)\.setup\(\{$",
        r"^}\)$",
        opt_lines,
    )


@dataclass
class ColumnDef:
    name: str
    adapters: str
    editable: bool
    summary: str
    params: List["LuaParam"] = field(default_factory=list)


HL = [LuaParam("highlight", "string|fun", "Highlight group")]
TIME = [
    LuaParam("format", "string", "Format string (see :help strftime)"),
]
COL_DEFS = [
    ColumnDef(
        "type",
        "*",
        False,
        "The type of the entry (file, directory, link, etc)",
        HL + [LuaParam("icons", "table<string, string>", "Mapping of entry type to icon")],
    ),
    ColumnDef(
        "icon",
        "*",
        False,
        "An icon for the entry's type (requires nvim-web-devicons)",
        HL + [],
    ),
    ColumnDef("size", "files, ssh", False, "The size of the file", HL + []),
    ColumnDef("permissions", "files, ssh", True, "Access permissions of the file", HL + []),
    ColumnDef("ctime", "files", False, "Change timestamp of the file", HL + TIME + []),
    ColumnDef(
        "mtime", "files", False, "Last modified time of the file", HL + TIME + []
    ),
    ColumnDef("atime", "files", False, "Last access time of the file", HL + TIME + []),
    ColumnDef(
        "birthtime", "files", False, "The time the file was created", HL + TIME + []
    ),
]


def get_options_vimdoc() -> "VimdocSection":
    section = VimdocSection("options", "oil-options")
    config_file = os.path.join(ROOT, "lua", "oil", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    lines = ["\n", ">\n", '    require("oil").setup({\n']
    lines.extend(indent(opt_lines, 4))
    lines.extend(["    })\n", "<\n"])
    section.body = lines
    return section


def get_highlights_vimdoc() -> "VimdocSection":
    section = VimdocSection("Highlights", "oil-highlights", ["\n"])
    highlights = read_nvim_json('require("oil")._get_highlights()')
    for hl in highlights:
        name = hl["name"]
        desc = hl.get("desc")
        if desc is None:
            continue
        section.body.append(leftright(name, f"*hl-{name}*"))
        section.body.extend(wrap(desc, 4))
        section.body.append("\n")
    return section


def get_columns_vimdoc() -> "VimdocSection":
    section = VimdocSection("Columns", "oil-columns", ["\n"])
    for col in COL_DEFS:
        section.body.append(leftright(col.name, f"*column-{col.name}*"))
        section.body.extend(wrap(f"Adapters: {col.adapters}", 4))
        if col.editable:
            section.body.extend(wrap(f"Editable: this column is read/write", 4))
        section.body.extend(wrap(col.summary, 4))
        section.body.append("\n")
        section.body.append("    Parameters:\n")
        section.body.extend(format_vimdoc_params(col.params, 6))
        section.body.append("\n")
    return section


def generate_vimdoc():
    doc = Vimdoc("oil.txt", "oil")
    funcs = parse_functions(os.path.join(ROOT, "lua", "oil", "init.lua"))
    doc.sections.extend(
        [
            get_options_vimdoc(),
            VimdocSection("API", "oil-api", render_vimdoc_api("oil", funcs)),
            get_columns_vimdoc(),
            get_highlights_vimdoc(),
        ]
    )

    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def main() -> None:
    """Update the README"""
    update_config_options()
    update_md_api()
    update_readme_toc()
    generate_vimdoc()

import os
import os.path
import re
from dataclasses import dataclass, field
from typing import Any, Dict, List

from nvim_doc_tools import (
    LuaParam,
    LuaTypes,
    Vimdoc,
    VimdocSection,
    generate_md_toc,
    indent,
    leftright,
    parse_directory,
    read_nvim_json,
    read_section,
    render_md_api2,
    render_vimdoc_api2,
    replace_section,
    wrap,
)
from nvim_doc_tools.vimdoc import format_vimdoc_params

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
    api_doc = os.path.join(DOC, "api.md")
    types = parse_directory(os.path.join(ROOT, "lua"))
    funcs = types.files["oil/init.lua"].functions
    lines = ["\n"] + render_md_api2(funcs, types, 2) + ["\n"]
    replace_section(
        api_doc,
        r"^<!-- API -->$",
        r"^<!-- /API -->$",
        lines,
    )
    toc = ["\n"] + generate_md_toc(api_doc, max_level=1) + ["\n"]
    replace_section(
        api_doc,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )
    toc = add_md_link_path("doc/api.md", toc)
    replace_section(
        README,
        r"^<!-- API -->$",
        r"^<!-- /API -->$",
        toc,
    )


def update_readme():
    def get_toc(filename: str) -> List[str]:
        subtoc = generate_md_toc(os.path.join(DOC, filename))
        return add_md_link_path("doc/" + filename, subtoc)

    recipes_toc = get_toc("recipes.md")

    replace_section(
        README,
        r"^## Recipes$",
        r"^#",
        ["\n"] + recipes_toc + ["\n"],
    )


def update_md_toc(filename: str, max_level: int = 99):
    toc = ["\n"] + generate_md_toc(filename, max_level) + ["\n"]
    replace_section(
        filename,
        r"^<!-- TOC -->$",
        r"^<!-- /TOC -->$",
        toc,
    )


def update_config_options():
    config_file = os.path.join(ROOT, "lua", "oil", "config.lua")
    opt_lines = ['\n```lua\nrequire("oil").setup({\n']
    opt_lines.extend(read_section(config_file, r"^\s*local default_config =", r"^}$"))
    replace_section(
        README,
        r"^## Options$",
        r"^}\)$",
        opt_lines,
    )


@dataclass
class ColumnDef:
    name: str
    adapters: str
    editable: bool
    sortable: bool
    summary: str
    params: List["LuaParam"] = field(default_factory=list)


HL = [
    LuaParam(
        "highlight",
        "string|fun(value: string): string",
        "Highlight group, or function that returns a highlight group",
    )
]
TIME = [
    LuaParam("format", "string", "Format string (see :help strftime)"),
]
COL_DEFS = [
    ColumnDef(
        "type",
        "*",
        False,
        True,
        "The type of the entry (file, directory, link, etc)",
        HL
        + [LuaParam("icons", "table<string, string>", "Mapping of entry type to icon")],
    ),
    ColumnDef(
        "icon",
        "*",
        False,
        False,
        "An icon for the entry's type (requires nvim-web-devicons)",
        HL
        + [
            LuaParam(
                "default_file",
                "string",
                "Fallback icon for files when nvim-web-devicons returns nil",
            ),
            LuaParam("directory", "string", "Icon for directories"),
            LuaParam(
                "add_padding",
                "boolean",
                "Set to false to remove the extra whitespace after the icon",
            ),
        ],
    ),
    ColumnDef("size", "files, ssh", False, True, "The size of the file", HL + []),
    ColumnDef(
        "permissions",
        "files, ssh",
        True,
        False,
        "Access permissions of the file",
        HL + [],
    ),
    ColumnDef(
        "ctime", "files", False, True, "Change timestamp of the file", HL + TIME + []
    ),
    ColumnDef(
        "mtime", "files", False, True, "Last modified time of the file", HL + TIME + []
    ),
    ColumnDef(
        "atime", "files", False, True, "Last access time of the file", HL + TIME + []
    ),
    ColumnDef(
        "birthtime",
        "files",
        False,
        True,
        "The time the file was created",
        HL + TIME + [],
    ),
]


def get_options_vimdoc() -> "VimdocSection":
    section = VimdocSection("config", "oil-config")
    config_file = os.path.join(ROOT, "lua", "oil", "config.lua")
    opt_lines = read_section(config_file, r"^local default_config =", r"^}$")
    lines = ["\n", ">lua\n", '    require("oil").setup({\n']
    lines.extend(indent(opt_lines, 4))
    lines.extend(["    })\n", "<\n"])
    section.body = lines
    return section


def get_options_detail_vimdoc() -> "VimdocSection":
    section = VimdocSection("options", "oil-options")
    section.body.append(
        """
skip_confirm_for_simple_edits                  *oil.skip_confirm_for_simple_edits*
    type: `boolean` default: `false`
    Before performing filesystem operations, Oil displays a confirmation popup to ensure
    that all operations are intentional. When this option is `true`, the popup will be
    skipped if the operations:
        * contain no deletes
        * contain no cross-adapter moves or copies (e.g. from local to ssh)
        * contain at most one copy or move
        * contain at most five creates

prompt_save_on_select_new_entry              *oil.prompt_save_on_select_new_entry*
    type: `boolean` default: `true`
    There are two cases where this option is relevant:
    1. You copy a file to a new location, then you select it and make edits before
       saving.
    2. You copy a directory to a new location, then you enter the directory and make
       changes before saving.

    In case 1, when you edit the file you are actually editing the original file because
    oil has not yet moved/copied it to its new location. This means that the original
    file will, perhaps unexpectedly, also be changed by any edits you make.

    Case 2 is similar; when you edit the directory you are again actually editing the
    original location of the directory. If you add new files, those files will be
    created in both the original location and the copied directory.

    When this option is `true`, Oil will prompt you to save before entering a file or
    directory that is pending within oil, but does not exist on disk.
"""
    )
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


def load_params(params: Dict[str, Any]) -> List[LuaParam]:
    ret = []
    for name, data in sorted(params.items()):
        ret.append(LuaParam(name, data["type"], data["desc"]))
    return ret


def get_actions_vimdoc() -> "VimdocSection":
    section = VimdocSection("Actions", "oil-actions", ["\n"])
    section.body.append(
        """The `keymaps` option in `oil.setup` allow you to create mappings using all the same parameters as |vim.keymap.set|.
>lua
    keymaps = {
        -- Mappings can be a string
        ["~"] = "<cmd>edit $HOME<CR>",
        -- Mappings can be a function
        ["gd"] = function()
            require("oil").set_columns({ "icon", "permissions", "size", "mtime" })
        end,
        -- You can pass additional opts to vim.keymap.set by using
        -- a table with the mapping as the first element.
        ["<leader>ff"] = {
            function()
                require("telescope.builtin").find_files({
                    cwd = require("oil").get_current_dir()
                })
            end,
            mode = "n",
            nowait = true,
            desc = "Find files in the current directory"
        },
        -- Mappings that are a string starting with "actions." will be
        -- one of the built-in actions, documented below.
        ["`"] = "actions.tcd",
        -- Some actions have parameters. These are passed in via the `opts` key.
        ["<leader>:"] = {
            "actions.open_cmdline",
            opts = {
                shorten_path = true,
                modify = ":h",
            },
            desc = "Open the command line with the current directory as an argument",
        },
    }
"""
    )
    section.body.append("\n")
    section.body.extend(
        wrap(
            """Below are the actions that can be used in the `keymaps` section of config options. You can refer to them as strings (e.g. "actions.<action_name>") or you can use the functions directly with `require("oil.actions").action_name.callback()`"""
        )
    )
    section.body.append("\n")
    actions = read_nvim_json('require("oil.actions")._get_actions()')
    actions.sort(key=lambda a: a["name"])
    for action in actions:
        if action.get("deprecated"):
            continue
        name = action["name"]
        desc = action["desc"]
        section.body.append(leftright(name, f"*actions.{name}*"))
        section.body.extend(wrap(desc, 4))
        params = action.get("parameters")
        if params:
            section.body.append("\n")
            section.body.append("    Parameters:\n")
            section.body.extend(
                format_vimdoc_params(load_params(params), LuaTypes(), 6)
            )

        section.body.append("\n")
    return section


def get_columns_vimdoc() -> "VimdocSection":
    section = VimdocSection("Columns", "oil-columns", ["\n"])
    section.body.extend(
        wrap(
            'Columns can be specified as a string to use default arguments (e.g. `"icon"`), or as a table to pass parameters (e.g. `{"size", highlight = "Special"}`)'
        )
    )
    section.body.append("\n")
    for col in COL_DEFS:
        section.body.append(leftright(col.name, f"*column-{col.name}*"))
        section.body.extend(wrap(f"Adapters: {col.adapters}", 4))
        if col.sortable:
            section.body.extend(
                wrap(f"Sortable: this column can be used in view_props.sort", 4)
            )
        if col.editable:
            section.body.extend(wrap(f"Editable: this column is read/write", 4))
        section.body.extend(wrap(col.summary, 4))
        section.body.append("\n")
        section.body.append("    Parameters:\n")
        section.body.extend(format_vimdoc_params(col.params, LuaTypes(), 6))
        section.body.append("\n")
    return section


def get_trash_vimdoc() -> "VimdocSection":
    section = VimdocSection("Trash", "oil-trash", [])
    section.body.append(
        """
Oil has built-in support for using the system trash. When
`delete_to_trash = true`, any deleted files will be sent to the trash instead
of being permanently deleted. You can browse the trash for a directory using
the `toggle_trash` action (bound to `g\\` by default). You can view all files
in the trash with `:Oil --trash /`.

To restore files, simply move them from the trash to the desired destination,
the same as any other file operation. If you delete files from the trash they
will be permanently deleted (purged).

Linux:
    Oil supports the FreeDesktop trash specification.
    https://specifications.freedesktop.org/trash-spec/1.0/
    All features should work.

Mac:
    Oil has limited support for MacOS due to the proprietary nature of the
    implementation. The trash bin can only be viewed as a single dir
    (instead of being able to see files that were trashed from a directory).

Windows:
    Oil supports the Windows Recycle Bin. All features should work.
"""
    )
    return section


def generate_vimdoc():
    doc = Vimdoc("oil.txt", "oil")
    types = parse_directory(os.path.join(ROOT, "lua"))
    funcs = types.files["oil/init.lua"].functions
    doc.sections.extend(
        [
            get_options_vimdoc(),
            get_options_detail_vimdoc(),
            VimdocSection("API", "oil-api", render_vimdoc_api2("oil", funcs, types)),
            get_columns_vimdoc(),
            get_actions_vimdoc(),
            get_highlights_vimdoc(),
            get_trash_vimdoc(),
        ]
    )

    with open(VIMDOC, "w", encoding="utf-8") as ofile:
        ofile.writelines(doc.render())


def main() -> None:
    """Update the README"""
    update_config_options()
    update_md_api()
    update_md_toc(README, max_level=1)
    update_md_toc(os.path.join(DOC, "recipes.md"))
    update_readme()
    generate_vimdoc()

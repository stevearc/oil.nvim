# API

<!-- TOC -->

- [get_entry_on_line(bufnr, lnum)](#get_entry_on_linebufnr-lnum)
- [get_cursor_entry()](#get_cursor_entry)
- [discard_all_changes()](#discard_all_changes)
- [set_columns(cols)](#set_columnscols)
- [set_sort(sort)](#set_sortsort)
- [set_is_hidden_file(is_hidden_file)](#set_is_hidden_fileis_hidden_file)
- [toggle_hidden()](#toggle_hidden)
- [get_current_dir()](#get_current_dir)
- [open_float(dir)](#open_floatdir)
- [toggle_float(dir)](#toggle_floatdir)
- [open(dir)](#opendir)
- [close()](#close)
- [open_preview(opts)](#open_previewopts)
- [select(opts, callback)](#selectopts-callback)
- [save(opts, cb)](#saveopts-cb)
- [setup(opts)](#setupopts)

<!-- /TOC -->

<!-- API -->

## get_entry_on_line(bufnr, lnum)

`get_entry_on_line(bufnr, lnum): nil|oil.Entry` \
Get the entry on a specific line (1-indexed)

| Param | Type      | Desc |
| ----- | --------- | ---- |
| bufnr | `integer` |      |
| lnum  | `integer` |      |

## get_cursor_entry()

`get_cursor_entry(): nil|oil.Entry` \
Get the entry currently under the cursor


## discard_all_changes()

`discard_all_changes()` \
Discard all changes made to oil buffers


## set_columns(cols)

`set_columns(cols)` \
Change the display columns for oil

| Param | Type               | Desc |
| ----- | ------------------ | ---- |
| cols  | `oil.ColumnSpec[]` |      |

## set_sort(sort)

`set_sort(sort)` \
Change the sort order for oil

| Param | Type       | Desc |
| ----- | ---------- | ---- |
| sort  | `string[]` | []   |

## set_is_hidden_file(is_hidden_file)

`set_is_hidden_file(is_hidden_file)` \
Change how oil determines if the file is hidden

| Param          | Type                                                  | Desc                                         |
| -------------- | ----------------------------------------------------- | -------------------------------------------- |
| is_hidden_file | `fun(filename: string, bufnr: nil\|integer): boolean` | Return true if the file/dir should be hidden |

## toggle_hidden()

`toggle_hidden()` \
Toggle hidden files and directories


## get_current_dir()

`get_current_dir(): nil|string` \
Get the current directory


## open_float(dir)

`open_float(dir)` \
Open oil browser in a floating window

| Param | Type          | Desc                                                                                        |
| ----- | ------------- | ------------------------------------------------------------------------------------------- |
| dir   | `nil\|string` | When nil, open the parent of the current buffer, or the cwd if current buffer is not a file |

## toggle_float(dir)

`toggle_float(dir)` \
Open oil browser in a floating window, or close it if open

| Param | Type          | Desc                                                                                        |
| ----- | ------------- | ------------------------------------------------------------------------------------------- |
| dir   | `nil\|string` | When nil, open the parent of the current buffer, or the cwd if current buffer is not a file |

## open(dir)

`open(dir)` \
Open oil browser for a directory

| Param | Type          | Desc                                                                                        |
| ----- | ------------- | ------------------------------------------------------------------------------------------- |
| dir   | `nil\|string` | When nil, open the parent of the current buffer, or the cwd if current buffer is not a file |

## close()

`close()` \
Restore the buffer that was present when oil was opened


## open_preview(opts)

`open_preview(opts)` \
Preview the entry under the cursor in a split

| Param | Type         | Desc                                               |                                       |
| ----- | ------------ | -------------------------------------------------- | ------------------------------------- |
| opts  | `nil\|table` |                                                    |                                       |
|       | vertical     | `boolean`                                          | Open the buffer in a vertical split   |
|       | horizontal   | `boolean`                                          | Open the buffer in a horizontal split |
|       | split        | `"aboveleft"\|"belowright"\|"topleft"\|"botright"` | Split modifier                        |

## select(opts, callback)

`select(opts, callback)` \
Select the entry under the cursor

| Param    | Type                         | Desc                                               |                                                      |
| -------- | ---------------------------- | -------------------------------------------------- | ---------------------------------------------------- |
| opts     | `nil\|table`                 |                                                    |                                                      |
|          | vertical                     | `boolean`                                          | Open the buffer in a vertical split                  |
|          | horizontal                   | `boolean`                                          | Open the buffer in a horizontal split                |
|          | split                        | `"aboveleft"\|"belowright"\|"topleft"\|"botright"` | Split modifier                                       |
|          | tab                          | `boolean`                                          | Open the buffer in a new tab                         |
|          | close                        | `boolean`                                          | Close the original oil buffer once selection is made |
| callback | `nil\|fun(err: nil\|string)` | Called once all entries have been opened           |                                                      |

## save(opts, cb)

`save(opts, cb)` \
Save all changes

| Param | Type                         | Desc                            |                                                                                             |
| ----- | ---------------------------- | ------------------------------- | ------------------------------------------------------------------------------------------- |
| opts  | `nil\|table`                 |                                 |                                                                                             |
|       | confirm                      | `nil\|boolean`                  | Show confirmation when true, never when false, respect skip_confirm_for_simple_edits if nil |
| cb    | `nil\|fun(err: nil\|string)` | Called when mutations complete. |                                                                                             |

**Note:**
<pre>
If you provide your own callback function, there will be no notification for errors.
</pre>

## setup(opts)

`setup(opts)` \
Initialize oil

| Param | Type         | Desc |
| ----- | ------------ | ---- |
| opts  | `nil\|table` |      |


<!-- /API -->

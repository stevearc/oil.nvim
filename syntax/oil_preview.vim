if exists("b:current_syntax")
  finish
endif

syn match oilCreate /^CREATE /
syn match oilMove   /^  MOVE /
syn match oilDelete /^DELETE /
syn match oilCopy   /^  COPY /
syn match oilChange /^CHANGE /
" Trash operations
syn match oilRestore /^RESTORE /
syn match oilPurge /^ PURGE /
syn match oilTrash /^ TRASH /

let b:current_syntax = "oil_preview"

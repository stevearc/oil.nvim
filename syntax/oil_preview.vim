if exists("b:current_syntax")
  finish
endif

syn match oilCreate /^CREATE /
syn match oilMove   /^  MOVE /
syn match oilDelete /^DELETE /
syn match oilCopy   /^  COPY /
syn match oilChange /^CHANGE /
" Trash operations
" FIXME add new highlight groups
syn match oilCreate /^RESTORE /
syn match oilDelete /^ PURGE /
syn match oilDelete /^ TRASH /

let b:current_syntax = "oil_preview"

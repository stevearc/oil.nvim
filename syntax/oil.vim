if exists("b:current_syntax")
  finish
endif

syn match oilId /^\/\d* / conceal

let b:current_syntax = "oil"

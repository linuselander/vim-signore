" Copyright 2017 Linus Elander <linus@elander.nu>
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

"Global settings {{{

"Exposes setting to opt to completely ignore previously defined wildignore
if !exists("g:signore#append")
  let g:signore#append=1
endif

"Allow signore to run automatically on every BufEnter
if !exists("g:signore#auto")
  let g:signore#auto=0
endif

"The built-in edit command needs folder/ while CtrlP needs */folder/*
if !exists("g:signore#use_ctrlp_format")
  let g:signore#use_ctrlp_format=0
endif
" }}}

" Utility functions {{{

function! s:get_git_root(dir, previous_dir) "{{{
  if a:dir == a:previous_dir
    "If a:previous_dir hasn't changed we don't need to lookup git root again
    return a:previous_dir
  else
    "If we have a new dir we might also have a new git root
    let root = system("cd ".a:dir." 2> /dev/null && git rev-parse --show-toplevel")
    if root=~"^fatal:"
      "echom a:dir." is not within a git working tree"
      return s:cached_git_root
    endif
    "Remove trailing NUL
    return substitute(root, '\n$', '', '')
  endif
endfunction "}}}

function! s:get_ignore_rules(dir) " {{{
  "Compose a system command
  let cmd="git -C ".fnameescape(a:dir).
        \" status --ignored --porcelain 2> /dev/null |
        \ grep '^!!' |
        \ sed -e 's/!! //g'"
  "Execute command and return results as an array
  return systemlist(cmd)
endfunction "}}}

function! s:format_rules(rules) " {{{
  let formatted_rules = []
  for rule in a:rules
    let formatted_rule = rule
    if g:signore#use_ctrlp_format == 1
      let formatted_rule = substitute(formatted_rule, "^", "*\/", "")
      let formatted_rule = substitute(formatted_rule, "\/$", "\/*", "")
    else
      let formatted_rule = substitute(formatted_rule, "^", "**\/", "")
      let formatted_rule = substitute(formatted_rule, "\/$", "\/*", "")
    endif  
    call add(formatted_rules, formatted_rule)
  endfor
  return formatted_rules
endfunction " }}}

function! s:get_current_buffer_dir() " {{{
  return expand("%:p:h")
endfunction " }}}

" }}}

" Main signore#run() {{{
function! signore#run()

  let current_buffer_dir = s:get_current_buffer_dir()
  let current_git_root = s:get_git_root(current_buffer_dir, s:cached_buffer_dir)

  if current_git_root == s:cached_git_root
    return 0
  else
    let s:cached_git_root = current_git_root
    "echom "Changed local working dir to: ".s:cached_git_root
    execute ":lcd" fnameescape(s:cached_git_root)
  endif

  let rules=s:get_ignore_rules(current_buffer_dir)

  let ignores=join(s:format_rules(rules), ",")

  if g:signore#append && strlen(s:original_wildignore) > 0  && strlen(ignores) > 0
    let ignores=",".ignores
  endif

  let &wildignore=g:signore#append
        \? s:original_wildignore.ignores
        \: ignores

endfunction

" }}}

" Actions {{{

function! signore#reset()
  let &wildignore=s:original_wildignore
  "echom "&wildignore was reset to it's original value"
endfunction

function! signore#auto()
  augroup signore
    au!
    au BufEnter * call signore#run()
  augroup END
  call signore#run()
  "echom "Signore will run every time a new buffer is opened"
endfunction

function! signore#stop()
  augroup signore
    au!
  augroup END
  augroup! signore
  call signore#reset()
  "echom "Signore is now in manual mode"
endfunction

" }}}

" Initialization {{{

function! signore#init()
  "Stores the original value of wildignore so we can reset
  let s:original_wildignore=&wildignore

  "We keep track of previous git root to avoid ambiguos system calls
  let s:cached_git_root=""

  "We keep track of previous buffer dir so we know if we have changed dir
  let s:cached_buffer_dir=""

  if g:signore#auto
    call signore#auto()
  endif
endfunction

" }}}

" vim: set foldmethod=marker:


vim9script noclear

# The MIT License (MIT)
#
# Copyright (c) 2016 Junegunn Choi
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

def Warn(message: string)
  echohl WarningMsg
  echom message
  echohl None
enddef

def Shrug()
  Warn('¯\_(ツ)_/¯')
enddef

var begin: string = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

def gv#sha(...l: list<string>): string
  return get(l, 0, getline('.'))->matchstr(begin .. '\zs[a-f0-9]\+')
enddef

def Move(flag: string): string
  var l: number
  var c: number
  [l, c] = searchpos(begin, flag)
  return l ? printf('%dG%d|', l, c) : ''
enddef

def Browse(url: string)
  netrw#BrowseX(b:git_origin.url, 0)
enddef

def Tabnew()
  execute ':' .. (tabpagenr() - 1) .. 'tabnew'
enddef

def Gbrowse()
  var sha: string = gv#sha()
  if empty(sha)
    Shrug()
    return
  endif
  execute 'GBrowse ' .. sha
enddef

def Type(visual: bool): list<any>
  if visual
    var shas: list<string> = getline("'<", "'>")
      ->map((_, v: string): string => gv#sha(v))
      ->filter((_, v: string): bool => !empty(v))
    if len(shas) < 2
      return [0, 0]
    endif
    return ['diff', fugitive#repo().git_command('diff', shas[-1], shas[0])]
  endif

  if exists('b:git_origin')
    var syn: string = synID('.', col('.'), false)
      ->synIDattr('name')
    if syn == 'gvGitHub'
      return ['link', '/issues/' .. expand('<cword>')[1 :]]
    elseif syn == 'gvTag'
      var tag: string = getline('.')
        ->matchstr('(tag: \zs[^ ,)]\+')
      return ['link', '/releases/' .. tag]
    endif
  endif

  var sha: string = gv#sha()
  if !empty(sha)
    return ['commit', g:FugitiveFind(sha, b:git_dir)]
  endif
  return [0, 0]
enddef

def Split(tab: bool)
  if tab
    Tabnew()
  elseif winnr('$')->getwinvar('gv')
    :$ wincmd w
    enew
  else
    vertical botright new
  endif
  w:gv = 1
enddef

def Open(visual: bool, ...l: list<bool>)
  var type: string
  var target: string
  [type, target] = Type(visual)

  if empty(type)
    Shrug()
    return
  elseif type == 'link'
    Browse(target)
    return
  endif

  Split(len(l) != 0)
  Scratch()
  if type == 'commit'
    execute 'edit ' .. escape(target, ' ')
    nnoremap <silent> <buffer> gb <Cmd>GBrowse<cr>
  elseif type == 'diff'
    Fill(target)
    setfiletype diff
  endif
  nnoremap <silent> <buffer> q :close<cr>
  var bang: string = len(l) != 0 ? '!' : ''
  if exists('#User#GV' .. bang)
    execute 'doautocmd <nomodeline> User GV' .. bang
  endif
  wincmd p
  echo
enddef

def Dot(): string
  var sha: string = gv#sha()
  return empty(sha) ? '' : ':Git  ' .. sha .. "\<s-left>\<left>"
enddef

def Syntax()
  setfiletype GV
  syntax clear
  syntax match gvInfo    /^[^0-9]*\zs[0-9-]\+\s\+[a-f0-9]\+ / contains=gvDate,gvSha nextgroup=gvMessage,gvMeta
  syntax match gvDate    /\S\+ / contained
  syntax match gvSha     /[a-f0-9]\{6,}/ contained
  syntax match gvMessage /.* \ze(.\{-})$/ contained contains=gvTag,gvGitHub,gvJira nextgroup=gvAuthor
  syntax match gvAuthor  /.*$/ contained
  syntax match gvMeta    /([^)]\+) / contained contains=gvTag nextgroup=gvMessage
  syntax match gvTag     /(tag:[^)]\+)/ contained
  syntax match gvGitHub  /\<#[0-9]\+\>/ contained
  syntax match gvJira    /\<[A-Z]\+-[0-9]\+\>/ contained
  highlight default link gvDate   Number
  highlight default link gvSha    Identifier
  highlight default link gvTag    Constant
  highlight default link gvGitHub Label
  highlight default link gvJira   Label
  highlight default link gvMeta   Conditional
  highlight default link gvAuthor String

  syn match gvAdded     "^\W*\zsA\t.*"
  syn match gvDeleted   "^\W*\zsD\t.*"
  highlight default link gvAdded    diffAdded
  highlight default link gvDeleted  diffRemoved

  syntax match diffAdded   "^+.*"
  syntax match diffRemoved "^-.*"
  syntax match diffLine    "^@.*"
  syntax match diffFile    "^diff\>.*"
  syntax match diffFile    "^+++ .*"
  syntax match diffNewFile "^--- .*"
  highlight default link diffFile    Type
  highlight default link diffNewFile diffFile
  highlight default link diffAdded   Identifier
  highlight default link diffRemoved Special
  highlight default link diffFile    Type
  highlight default link diffLine    Statement
enddef

def Maps()
  nnoremap <buffer> q    <Cmd>$ wincmd w <bar> close<cr>
  nnoremap <buffer> <nowait> gq <Cmd>$ wincmd w <bar> close<cr>
  nnoremap <buffer> gb   <Cmd>call <sid>Gbrowse()<cr>
  nnoremap <buffer> <cr> <Cmd>call <sid>Open(v:false)<cr>
  nnoremap <buffer> o    <Cmd>call <sid>Open(v:false)<cr>
  nnoremap <buffer> O    <Cmd>call <sid>Open(v:false, v:true)<cr>
  xnoremap <buffer> <cr> <Cmd>call <sid>Open(v:true)<cr>
  xnoremap <buffer> o    <Cmd>call <sid>Open(v:true)<cr>
  xnoremap <buffer> O    <Cmd>call <sid>Open(v:true, v:true)<cr>
  nnoremap <buffer> <expr> .  <sid>Dot()
  nnoremap <buffer> <expr> ]] <sid>Move('')
  nnoremap <buffer> <expr> ][ <sid>Move('')
  nnoremap <buffer> <expr> [[ <sid>Move('b')
  nnoremap <buffer> <expr> [] <sid>Move('b')
  xnoremap <buffer> <expr> ]] <sid>Move('')
  xnoremap <buffer> <expr> ][ <sid>Move('')
  xnoremap <buffer> <expr> [[ <sid>Move('b')
  xnoremap <buffer> <expr> [] <sid>Move('b')

  nmap              <buffer> <C-n> ]]o
  nmap              <buffer> <C-p> [[o
  xmap              <buffer> <C-n> ]]ogv
  xmap              <buffer> <C-p> [[ogv
enddef

def Setup(git_dir: string, git_origin: string)
  Tabnew()
  Scratch()

  var domain: string
  if exists('g:fugitive_github_domains')
    domain = extend(['github.com'], g:fugitive_github_domains)
      ->map((_, v: string): string => v->split('://')[-1]->substitute('/*$', '', '')->escape('.'))
      ->join('\|')
  else
    domain = '.*github.\+'
  endif
  # https://  github.com  /  junegunn/gv.vim  .git
  # git@      github.com  :  junegunn/gv.vim  .git
  var pat: string = '^\(https\?://\|git@\)\(' .. domain .. '\)[:/]\([^@:/]\+/[^@:/]\{-}\)\%(.git\)\?$'
  var origin: list<string> = git_origin->matchlist(pat)
  if !empty(origin)
    var scheme: string = origin[1] =~ '^http' ? origin[1] : 'https://'
    b:git_origin = printf('%s%s/%s', scheme, origin[2], origin[3])
  endif
  b:git_dir = git_dir
enddef

def Scratch()
  setlocal buftype=nofile bufhidden=wipe noswapfile nomodeline
enddef

def Fill(cmd: string)
  setlocal modifiable
  silent execute 'read ' .. escape('!' .. cmd, '%')
  normal! gg"_dd
  setlocal nomodifiable
enddef

def Tracked(fugitive_repo: dict<func>, file: string): bool
  fugitive_repo.git_command('ls-files', '--error-unmatch', file)->system()
  return !v:shell_error
enddef

def CheckBuffer(fugitive_repo: dict<func>, current: string)
  if empty(current)
    throw 'untracked buffer'
  elseif !Tracked(fugitive_repo, current)
    throw current .. ' is untracked'
  endif
enddef

def LogOpts(
  fugitive_repo: dict<func>,
  bang: bool,
  visual: bool,
  line1: number,
  line2: number
): list<list<string>>

  if visual || bang
    var current: string = expand('%')
    CheckBuffer(fugitive_repo, current)
    return visual ? [[printf('-L%d,%d:%s', line1, line2, current)], []] : [['--follow'], ['--', current]]
  endif
  return [['--graph'], []]
enddef

def List(fugitive_repo: dict<func>, log_opts: list<string>)
  var default_opts: list<string> = ['--color=never', '--date=short', '--format=%cd %h%d %s (%an)']
  var git_args: list<string> = ['log'] + default_opts + log_opts
  var git_log_cmd: string = call(fugitive_repo.git_command, git_args, fugitive_repo)

  var repo_short_name: string = fugitive_repo.dir()
    ->substitute('[\\/]\.git[\\/]\?$', '', '')
    ->fnamemodify(':t')
  var bufname: string = repo_short_name .. ' ' .. join(log_opts)
  silent execute (bufexists(bufname) ? 'buffer ' : 'file ') .. fnameescape(bufname)

  Fill(git_log_cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#

  if !exists(':GBrowse')
    doautocmd <nomodeline> User Fugitive
  endif
  Maps()
  Syntax()
  redraw
  echo 'o: open split / O: open tab / gb: GBrowse / q: quit'
enddef

def Trim(arg: string): string
  var trimmed: string = arg->substitute('\s*$', '', '')
  return trimmed =~ "^'.*'$" ? trimmed[1 : -2]->substitute("''", '', 'g')
       : trimmed =~ '^".*"$' ? trimmed[1 : -2]->substitute('""', '', 'g')->substitute('\\"', '"', 'g')
       : trimmed->substitute('""\|''''', '', 'g')->substitute('\\ ', ' ', 'g')
enddef

def gv#shellwords(arg: string): list<string>
  var words: list<string>
  var contd: bool
  for token: string in arg->split('\%(\%(''\%([^'']\|''''\)\+''\)\|\%("\%(\\"\|[^"]\)\+"\)\|\%(\%(\\ \|\S\)\+\)\)\s*\zs')
    var trimmed: string = Trim(token)
    if contd
      words[-1] ..= trimmed
    else
      words->add(trimmed)
    endif
    contd = token !~ '\s\+$'
  endfor
  return words
enddef

def SplitPathspec(args: list<string>): list<list<string>>
  var split: number = args->index('--')
  if split < 0
    return [args, []]
  elseif split == 0
    return [[], args]
  endif
  return [args[0 : split - 1], args[split :]]
enddef

def Gl(buf: number, visual: bool)
  if !exists(':Gllog')
    return
  endif
  tab split
  silent execute visual ? ":'<,'>" : "" 'Gllog'
  getloclist(0)
    ->insert({bufnr: buf}, 0)
    ->setloclist(0)
  noautocmd b %%
  lopen
  xnoremap <buffer> o <Cmd>call <sid>Gld()<cr>
  nnoremap <buffer> o <cr><c-w><c-w>
  nnoremap <buffer> O <Cmd>call <sid>Gld()<cr>
  nnoremap <buffer> q <Cmd>tabclose<cr>
  nnoremap <buffer> gq <Cmd>tabclose<cr>
  matchadd('Conceal', '^fugitive://.\{-}\.git//')
  matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / q: quit'
enddef

def Gld()
  var firstline: number
  var lastline: number
  if mode() =~ "^[vV\<C-V>]$"
    execute "normal! \<Esc>"
    [firstline, lastline] = [line("'<"), line("'>")]
  else
    [firstline, lastline] = [line('.'), line('.')]
  endif
  var to: string
  var from: string
  [to, from] = [firstline, lastline]
    ->mapnew((_, v: string): string => v->getline()->split('|')[0])
  execute ':' .. (tabpagenr() - 1) .. 'tabedit ' .. escape(to, ' ')
  if from != to
    execute 'vsplit ' .. escape(from, ' ')
    windo diffthis
  endif
enddef

def Gv(
  bang: bool,
  visual: bool,
  line1: number,
  line2: number,
  args: string
)

  if !exists('g:loaded_fugitive')
    Warn('fugitive not found')
    return
  endif

  var git_dir: string = g:FugitiveGitDir()
  if empty(git_dir)
    Warn('not in git repo')
    return
  endif

  var fugitive_repo: dict<func> = fugitive#repo(git_dir)
  var cd: string = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  var cwd: string = getcwd()
  var root: string = fugitive_repo.tree()
  try
    if cwd != root
      execute cd .. ' ' .. escape(root, ' ')
    endif
    if args =~ '?$'
      if len(args) > 1
        Warn('invalid arguments')
        return
      endif
      CheckBuffer(fugitive_repo, expand('%'))
      Gl(bufnr(''), visual)
    else
      var opts1: list<string>
      var opts2: list<string>
      var paths1: list<string>
      var paths2: list<string>
      var log_opts: list<string>
      [opts1, paths1] = LogOpts(fugitive_repo, bang, visual, line1, line2)
      [opts2, paths2] = gv#shellwords(args)->SplitPathspec()
      log_opts = opts1 + opts2 + paths1 + paths2
      Setup(git_dir, fugitive_repo.config('remote.origin.url'))
      List(fugitive_repo, log_opts)
      g:FugitiveDetect(@#)
    endif
  catch
    Warn(v:exception)
    return
  finally
    if getcwd() != cwd
      cd -
    endif
  endtry
enddef

def Gvcomplete(a: string, _, _): list<string>
  return fugitive#repo().superglob(a)
enddef

command -bang -nargs=* -range=0 -complete=customlist,Gvcomplete GV Gv(<bang>0, <count>, <line1>, <line2>, <q-args>)

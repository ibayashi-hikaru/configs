" dein.vim settings
if &compatible
  set nocompatible
endif

let s:dein_dir = expand('~/.cache/dein')
let s:repos_dir = s:dein_dir . '/repos/github.com'

if &runtimepath !~# '/dein.vim'
  if !isdirectory(s:repos_dir . '/Shougo/dein.vim')
    call system('git clone https://github.com/Shougo/dein.vim '
          \ . s:repos_dir . '/Shougo/dein.vim')
  endif
  execute 'set runtimepath^=' . s:repos_dir . '/Shougo/dein.vim'
endif

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  " Add or remove your plugins here like this:
  call dein#add('Shougo/dein.vim')
  call dein#add('Townk/vim-autoclose')
  call dein#add('scrooloose/nerdtree')
  call dein#add('hotwatermorning/auto-git-diff')
  call dein#add('tomtom/tcomment_vim')
  call dein#add('Shougo/vimproc')
  call dein#add('octol/vim-cpp-enhanced-highlight')
  call dein#add('pseewald/vim-anyfold')

  call dein#end()
  call dein#save_state()
endif

if dein#check_install()
  call dein#install()
endif

filetype plugin indent on
syntax enable
set t_Co=256

" Your other Vim settings
set tabstop=4
set shiftwidth=4
set autoindent
set encoding=utf-8
set number
set clipboard=unnamed
set guioptions+=r
set guioptions+=R
set guioptions+=l
set guioptions+=L
set ambiwidth=double
set display+=lastline
set binary
set noeol
nnoremap <C-n> gt
nnoremap <C-p> gT
nnoremap j gj
nnoremap k gk
nnoremap <Down> gj
nnoremap <Up>   gk
imap jj <esc>
imap <c-j> <esc>
syntax on
filetype on
execute "set <f28>=\<Esc>[200~"
execute "set <f29>=\<Esc>[201~"
cmap <f28> <nop>
cmap <f29> <nop>
set expandtab
colorscheme molokai
set noswapfile
command! W  write

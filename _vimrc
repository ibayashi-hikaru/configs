" neobundle settings {{{
if has('vim_starting')
  set nocompatible
  " neobundle をインストールしていない場合は自動インストール
  if !isdirectory(expand("~/.vim/bundle/neobundle.vim/"))
    echo "install neobundle..."
    " vim からコマンド呼び出しているだけ neobundle.vim のクローン
    :call system("git clone git://github.com/Shougo/neobundle.vim ~/.vim/bundle/neobundle.vim")
  endif
  " runtimepath の追加は必須
  set runtimepath+=~/.vim/bundle/neobundle.vim/
endif
call neobundle#begin(expand('~/.vim/bundle'))
let g:neobundle_default_git_protocol='https'

" neobundle#begin - neobundle#end の間に導入するプラグインを記載します。
" インデントに色を付けて見やすくする

" vimを立ち上げたときに、自動的にvim-indent-guidesをオンにする
" let g:indent_guides_enable_on_vim_startup = 1
"
NeoBundleFetch 'Shougo/neobundle.vim'
NeoBundle 'Townk/vim-autoclose'
NeoBundle 'scrooloose/nerdtree'
NeoBundle 'hotwatermorning/auto-git-diff'
NeoBundle 'tomtom/tcomment_vim'
NeoBundle 'Shougo/vimproc'
NeoBundle 'octol/vim-cpp-enhanced-highlight'
NeoBundle 'pseewald/vim-anyfold'
" vimrc に記述されたプラグインでインストールされていないものがないかチェックする
NeoBundleCheck
call neobundle#end()
filetype plugin indent on
set t_Co=256
syntax on
set tabstop=4
set shiftwidth=4
set autoindent
" 行数表示
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

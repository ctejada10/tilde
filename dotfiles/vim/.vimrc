"Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" ================ General Config ====================

set backspace=indent,eol,start  "Allow backspace in insert mode
set history=1000                "Store lots of :cmdline history
set showcmd                     "Show incomplete cmds down the bottom
set showmode                    "Show current mode down the bottom
set gcr=a:blinkon0              "Disable cursor blink
set visualbell                  "No sounds
set cursorcolumn
set cursorline
set relativenumber
set numberwidth=2
set viminfo+=n~/.vim/viminfo    "Save viminfo in .vim

"Tturn on syntax highlighting
syntax on

" Maintain undo history between sessions
set undofile
set undodir=~/.vim/undo

" Misc
set mouse=a
set hidden       "Allow switching away from unwritten buffers
set wildmenu     "Tab-complete command mode above command line
set wildmode=list:longest
set laststatus=2

" ================ Indentation ======================

set autoindent
set shiftwidth=2
set softtabstop=2
set tabstop=2
set expandtab
set ff=unix      " Automatically deal with dos files
set nowrap       " Don't wrap lines
set linebreak    " Wrap lines at convenient points

" Hard tabs for Python
au Filetype python setlocal noexpandtab
au Filetype python setlocal textwidth=70 " Wrap properly with any number of columns for Python files

" ================ Folds ============================

set foldmethod=indent   "fold based on indent
set foldnestmax=3       "deepest fold is 3 levels
set nofoldenable        "dont fold by default

" ================ Scrolling ========================

"set scrolloff=8         "Start scrolling when we're 8 lines away from margins
set sidescrolloff=15
set sidescroll=1

" ================ Vundle ============================
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

  " Let Vundle manage Vundle, required
  Plugin 'VundleVim/Vundle.vim'

  " Git
  Plugin 'mattn/gist-vim'
  Plugin 'mattn/webapi-vim'
  Plugin 'tpope/vim-fugitive'

  " Super Searching
  "Plugin 'kien/ctrlp.vim'

  " Vim Align
  Plugin 'junegunn/vim-easy-align'

  " One plugin to rule them all
  Plugin 'sheerun/vim-polyglot'

  Plugin 'junegunn/goyo.vim'
  Plugin 'editorconfig/editorconfig-vim'


call vundle#end()

" ================ Theme ===========================

let g:afterglow_blackout=1
let g:afterglow_italic_comments=1
set t_Co=16

" ================ Hides ===========================

hi vertsplit ctermfg=238 ctermbg=235
hi LineNr ctermfg=237
hi StatusLine ctermfg=235 ctermbg=245
hi StatusLineNC ctermfg=235 ctermbg=237
hi Search ctermbg=58 ctermfg=15
hi Default ctermfg=1
hi clear SignColumn
hi SignColumn ctermbg=235
hi GitGutterAdd ctermbg=235 ctermfg=245
hi GitGutterChange ctermbg=235 ctermfg=245
hi GitGutterDelete ctermbg=235 ctermfg=245
hi GitGutterChangeDelete ctermbg=235 ctermfg=245
hi EndOfBuffer ctermfg=237 ctermbg=235

set statusline=%=%f\ %m
set fillchars=vert:\ ,stl:\ ,stlnc:\ 
set noshowmode

" ================ Maps ============================
nmap gm :LivedownToggle<CR>
nmap tf :TableFormat<CR>
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
nnoremap <C-]> :bnext<CR>
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==

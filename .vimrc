set nocompatible
filetype off
set rtp+=~/.vim
filetype plugin indent on

"Plugings
"========
call plug#begin('~/.vim/plugged')

Plug 'Lokaltog/vim-easymotion'
Plug 'airblade/vim-gitgutter'
Plug 'christoomey/vim-tmux-navigator'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'editorconfig/editorconfig-vim'
Plug 'gcmt/breeze.vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'rking/ag.vim'
Plug 'scrooloose/syntastic'
Plug 'tomtom/tcomment_vim'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

"General Config
"==============
let mapleader=" "
set noerrorbells
set autoread
set tabstop=4 shiftwidth=4 expandtab
set showmode
set backspace=indent,eol,start
set showcmd
set autoindent
set cursorline
au BufWritePre * :%s/\s\+$//e "Strip trailing space on save

"Tabs
"====
au FileType python setl ts=4 sts=4 sw=4
au FileType json setl ts=4 sts=4 sw=4
au FileType scala setl ts=2 sts=2 sw=2
au FileType gitcommit setl spell "spell git commit messages
au FileType md setl spell "spell git commit messages

au bufwritepost .vimrc source $MYVIMRC
nmap <leader>v :tabedit $MYVIMRC<CR>

set noswapfile                  " Don't use swapfile
set nobackup                    " Don't create annoying backup files
set splitright                  " Split vertical windows right to the current windows
set splitbelow                  " Split horizontal windows below to the current windows
set encoding=utf-8              " Set default encoding to UTF-8
set wildmenu
set rnu

set fillchars=vert:│,fold:-     "nicer splits
highlight VertSplit cterm=none ctermbg=none ctermfg=247

"Escaping
"========
imap jk <Esc>

"Show nice tabs
"===============
set listchars=tab:>-,trail:~,extends:>,precedes:<
set list

"Styling
"=======
if has("unix")
  let s:uname = system("uname -s")
  if s:uname == "Darwin"
    set t_Co=256
    colorscheme molokai
    let g:molokai_original = 1
    let g:rehash256 = 1
  endif
endif

"Sets the proper font for GVIM.
"==============================
if has("gui_running")
  set lines=45
  set columns=84
    set guioptions-=T "Strips the tabbar
  if has("win32")
      set guifont=Sauce_Code_Powerline:h11:cANSI
  else
    set guifont=Source\ Code\ Pro\ for\ Powerline
  endif
endif

set number
syntax on

"Better Search
"=============
set ignorecase
set smartcase
set incsearch
set hlsearch

"Buffer Helpers
"===========
map <C-left> :bp<cr>
map <C-right> :bn<cr>

"Vmap for maintain Visual Mode after shifting > and <
"====================================================
vmap < <gv
vmap > >gv

"Tab Helpers
"===========
map <C-t><up> :tabr<cr>
map <C-t><down> :tabl<cr>
map <C-t><left> :tabp<cr>
map <C-t><right> :tabn<cr>
map <C-t>t :tabnew

"Quitting in style
"=================
cab W! w!
cab Q! q!
cab Wq wq
cab Wa wa
cab wQ wq
cab WQ wq
cab W w
cab Q q
:map Q <Nop> "Disabling ex mode

"Git
"===
noremap <Leader>ga :!git add .<CR>
noremap <Leader>gc :!git commit -m '<C-R>="'"<CR>
noremap <Leader>gp :!git push<CR>
noremap <Leader>gs :Gstatus<CR>
noremap <Leader>gb :Gblame<CR>
noremap <Leader>gd :Gvdiff<CR>
noremap <Leader>gr :Gremove<CR>

"Vim-airline
"===========
let g:airline_theme='powerlineish'
set laststatus=2
let g:airline_theme='badwolf'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:Powerline_symbols = 'fancy'
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#syntastic#enabled = 1
"let g:airline_section_gutter=""
"let g:airline_detect_whitespace=0
set ttimeoutlen=50

"JSHint
"======
let g:syntastic_javascript_checkers = ['jshint']
let g:syntastic_javascript_jshint_conf = '~/.jshintrc'

"Copy/Paste/Cut
"==============
noremap YY "+y<CR>
noremap P "+gP<CR>
noremap XX "+x<CR>

nnoremap <leader>j :%!jq .<CR>

"Tmux
"====
let g:tmux_navigator_save_on_switch = 1

"Tab Autocomplete
"================

function! Tab_Or_Complete()
  if col('.')>1 && strpart( getline('.'), col('.')-2, 3 ) =~ '^\w'
    return "\<C-N>"
  else
    return "\<Tab>"
  endif
endfunction

inoremap <Tab> <C-R>=Tab_Or_Complete()<CR>

"CTRL P
"======

let g:ctrlp_custom_ignore = 'logs\|target/\|node_modules\|DS_Store\|git'

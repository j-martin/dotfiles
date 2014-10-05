# dotfiles

Inspired from [organizing dotfiles in a git repository](https://fuller.li/posts/organising-dotfiles-in-a-git-repository/).

    $ alias home="git --work-tree=$HOME --git-dir=$HOME/.files.git"
    $ home init
    $ home remote add origin git@github.com:j-martin/dotfiles.git
    $ home fetch
    $ home checkout master

# Run this with user previlage
# Touchpad indicator
cd $HOME
chsh -s /usr/bin/zsh
git clone --depth 1 https://github.com/robbyrussell/oh-my-zsh.git .oh-my-zsh
unlink $HOME/.tmux.conf
unlink $HOME/.gitconfig
unlink $HOME/.gitignore_global
unlink $HOME/.vimrc
mkdir $HOME/.vim
unlink $HOME/.zshrc
ln -s $HOME/configs/_tmux.conf $HOME/.tmux.conf
ln -s $HOME/configs/_gitconfig $HOME/.gitconfig
ln -s $HOME/configs/_gitignore_global $HOME/.gitignore_global
ln -s $HOME/configs/_vimrc $HOME/.vimrc
ln -s $HOME/configs/_zshrc $HOME/.zshrc
ln -s $HOME/configs/ssh_config $HOME/.ssh/config
touch $HOME/configs/myShellConfig.sh
cp -r $HOME/configs/colors $HOME/.vim
sudo fc-cache
# Notes

# Japanese Input
# https://hirooka.pro/?p=6224

# Iosevka font
# Edit->Profile Preference

# Startup Applications

# Remap caps lock as ctr
# gnome-tweak tool

# Ubuntu Desktop 
# edit .config/user-dirs.dirs 

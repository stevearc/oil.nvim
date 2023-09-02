#!/bin/bash
set -e
PLUGINS="$HOME/.local/share/nvim/site/pack/plugins/start"
mkdir -p "$PLUGINS"

wget "https://github.com/neovim/neovim/releases/download/${NVIM_TAG-stable}/nvim.appimage"
chmod +x nvim.appimage
./nvim.appimage --appimage-extract >/dev/null
rm -f nvim.appimage
mkdir -p ~/.local/share/nvim
mv squashfs-root ~/.local/share/nvim/appimage
sudo ln -s "$HOME/.local/share/nvim/appimage/AppRun" /usr/bin/nvim

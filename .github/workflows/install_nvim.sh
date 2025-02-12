#!/bin/bash
set -e
version="${NVIM_TAG-stable}"
dl_name="nvim-linux-x86_64.appimage"
# The appimage name changed in v0.10.4
if python -c 'from packaging.version import Version; import sys; sys.exit(not (Version(sys.argv[1]) < Version("v0.10.4")))' "$version" 2>/dev/null; then
  dl_name="nvim.appimage"
fi
curl -sL "https://github.com/neovim/neovim/releases/download/${version}/${dl_name}" -o nvim.appimage
chmod +x nvim.appimage
./nvim.appimage --appimage-extract >/dev/null
rm -f nvim.appimage
mkdir -p ~/.local/share/nvim
mv squashfs-root ~/.local/share/nvim/appimage
sudo ln -s "$HOME/.local/share/nvim/appimage/AppRun" /usr/bin/nvim
/usr/bin/nvim --version

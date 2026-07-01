# Remove old installations
sudo pacman -Rns code code-oss

# Update packages
sudo pacman -Syu

# Install official Microsoft VS Code
sudo pacman -S code

# Verify
code --version
which code

# Launch without blocking terminal
code &

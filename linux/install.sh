#!/bin/bash

echo " Installing Habity..."

# Define the hidden installation paths for the current user
INSTALL_DIR="$HOME/.local/share/Habity"
DESKTOP_DIR="$HOME/.local/share/applications"
EXEC_PATH="$INSTALL_DIR/Habity"
ICON_PATH="$INSTALL_DIR/icon.png"

# 1. Create the installation directory
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"

# 2. Copy the app files into the installation directory
# (This copies everything from the folder where the script is run)
cp -r ./* "$INSTALL_DIR/"

# 3. Make the main app executable
chmod +x "$EXEC_PATH"

# 4. Generate the .desktop shortcut file dynamically
cat <<EOF > "$DESKTOP_DIR/habity.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Habity
Comment=A clean, privacy-first habit tracker
Exec=$EXEC_PATH
Icon=$ICON_PATH
Terminal=false
Categories=Utility;Lifestyle;
EOF

# 5. Make the shortcut executable so it shows up in the menu
chmod +x "$DESKTOP_DIR/habity.desktop"

echo " Installation complete! You can now launch Habity from your application menu."
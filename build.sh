#!/bin/bash
set -e

# Install Flutter if not available
if ! command -v flutter &> /dev/null; then
  if [ ! -d "$HOME/flutter" ]; then
    echo "Installing Flutter SDK..."
    git clone https://github.com/flutter/flutter.git "$HOME/flutter" -b stable --depth 1
  fi
  export PATH="$HOME/flutter/bin:$PATH"
fi

echo "Flutter version:"
flutter --version

flutter config --enable-web
flutter pub get
flutter build web --release --base-href "/"

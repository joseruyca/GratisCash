#!/usr/bin/env bash
set -euo pipefail

FLUTTER_HOME="$HOME/flutter"
EXPECTED_FLUTTER_VERSION="3.41.6"
export PATH="$FLUTTER_HOME/bin:$PATH"

install_expected_flutter() {
  local current=""
  if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
    local current_info
    current_info="$("$FLUTTER_HOME/bin/flutter" --version 2>/dev/null || true)"
    current="${current_info%%
  if [[ "$current" == *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
    return
  fi

  rm -rf "$FLUTTER_HOME"
  git clone     --depth 1     --branch "$EXPECTED_FLUTTER_VERSION"     https://github.com/flutter/flutter.git     "$FLUTTER_HOME"
}

install_expected_flutter
flutter config --enable-web

FLUTTER_INFO="$(flutter --version)"
FLUTTER_VERSION="${FLUTTER_INFO%%
TMP_WEB="$(mktemp -d)"
if [ -f web/index.html ]; then
  cp web/index.html "$TMP_WEB/index.html"
fi
if [ -f web/robots.txt ]; then
  cp web/robots.txt "$TMP_WEB/robots.txt"
fi

flutter create   --platforms=web   --org com.gratiscash   --project-name gratiscash   .

if [ -f "$TMP_WEB/index.html" ]; then
  cp "$TMP_WEB/index.html" web/index.html
fi
if [ -f "$TMP_WEB/robots.txt" ]; then
  cp "$TMP_WEB/robots.txt" web/robots.txt
fi
rm -rf "$TMP_WEB"

case "${1:-}" in
  install)
    flutter pub get
    ;;
  build)
    flutter build web --release       --dart-define=APP_ENV="${APP_ENV:-staging}"       --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}"       --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}"       --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}"       --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}"       --dart-define=GOOGLE_AUTH_ENABLED="${GOOGLE_AUTH_ENABLED:-false}"       --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
    ;;
  *)
    echo "Usage: bash vercel_build.sh install|build" >&2
    exit 2
    ;;
esac
\n'*}"
  fi

  if [[ "$current" == *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
    return
  fi

  rm -rf "$FLUTTER_HOME"
  git clone     --depth 1     --branch "$EXPECTED_FLUTTER_VERSION"     https://github.com/flutter/flutter.git     "$FLUTTER_HOME"
}

install_expected_flutter
flutter config --enable-web

FLUTTER_VERSION="$(flutter --version | head -n 1)"
if [[ "$FLUTTER_VERSION" != *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
  echo "Flutter inesperado: $FLUTTER_VERSION" >&2
  exit 3
fi
flutter --version

TMP_WEB="$(mktemp -d)"
if [ -f web/index.html ]; then
  cp web/index.html "$TMP_WEB/index.html"
fi
if [ -f web/robots.txt ]; then
  cp web/robots.txt "$TMP_WEB/robots.txt"
fi

flutter create   --platforms=web   --org com.gratiscash   --project-name gratiscash   .

if [ -f "$TMP_WEB/index.html" ]; then
  cp "$TMP_WEB/index.html" web/index.html
fi
if [ -f "$TMP_WEB/robots.txt" ]; then
  cp "$TMP_WEB/robots.txt" web/robots.txt
fi
rm -rf "$TMP_WEB"

case "${1:-}" in
  install)
    flutter pub get
    ;;
  build)
    flutter build web --release       --dart-define=APP_ENV="${APP_ENV:-staging}"       --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}"       --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}"       --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}"       --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}"       --dart-define=GOOGLE_AUTH_ENABLED="${GOOGLE_AUTH_ENABLED:-false}"       --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
    ;;
  *)
    echo "Usage: bash vercel_build.sh install|build" >&2
    exit 2
    ;;
esac
\n'*}"
if [[ "$FLUTTER_VERSION" != *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
  echo "Flutter inesperado: $FLUTTER_VERSION" >&2
  exit 3
fi
printf '%s\n' "$FLUTTER_INFO"

TMP_WEB="$(mktemp -d)"
if [ -f web/index.html ]; then
  cp web/index.html "$TMP_WEB/index.html"
fi
if [ -f web/robots.txt ]; then
  cp web/robots.txt "$TMP_WEB/robots.txt"
fi

flutter create   --platforms=web   --org com.gratiscash   --project-name gratiscash   .

if [ -f "$TMP_WEB/index.html" ]; then
  cp "$TMP_WEB/index.html" web/index.html
fi
if [ -f "$TMP_WEB/robots.txt" ]; then
  cp "$TMP_WEB/robots.txt" web/robots.txt
fi
rm -rf "$TMP_WEB"

case "${1:-}" in
  install)
    flutter pub get
    ;;
  build)
    flutter build web --release       --dart-define=APP_ENV="${APP_ENV:-staging}"       --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}"       --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}"       --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}"       --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}"       --dart-define=GOOGLE_AUTH_ENABLED="${GOOGLE_AUTH_ENABLED:-false}"       --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
    ;;
  *)
    echo "Usage: bash vercel_build.sh install|build" >&2
    exit 2
    ;;
esac
\n'*}"
  fi

  if [[ "$current" == *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
    return
  fi

  rm -rf "$FLUTTER_HOME"
  git clone     --depth 1     --branch "$EXPECTED_FLUTTER_VERSION"     https://github.com/flutter/flutter.git     "$FLUTTER_HOME"
}

install_expected_flutter
flutter config --enable-web

FLUTTER_VERSION="$(flutter --version | head -n 1)"
if [[ "$FLUTTER_VERSION" != *"Flutter $EXPECTED_FLUTTER_VERSION"* ]]; then
  echo "Flutter inesperado: $FLUTTER_VERSION" >&2
  exit 3
fi
flutter --version

TMP_WEB="$(mktemp -d)"
if [ -f web/index.html ]; then
  cp web/index.html "$TMP_WEB/index.html"
fi
if [ -f web/robots.txt ]; then
  cp web/robots.txt "$TMP_WEB/robots.txt"
fi

flutter create   --platforms=web   --org com.gratiscash   --project-name gratiscash   .

if [ -f "$TMP_WEB/index.html" ]; then
  cp "$TMP_WEB/index.html" web/index.html
fi
if [ -f "$TMP_WEB/robots.txt" ]; then
  cp "$TMP_WEB/robots.txt" web/robots.txt
fi
rm -rf "$TMP_WEB"

case "${1:-}" in
  install)
    flutter pub get
    ;;
  build)
    flutter build web --release       --dart-define=APP_ENV="${APP_ENV:-staging}"       --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}"       --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}"       --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}"       --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}"       --dart-define=GOOGLE_AUTH_ENABLED="${GOOGLE_AUTH_ENABLED:-false}"       --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}"       --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
    ;;
  *)
    echo "Usage: bash vercel_build.sh install|build" >&2
    exit 2
    ;;
esac

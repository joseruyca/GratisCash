#!/usr/bin/env bash
set -euo pipefail

FLUTTER_HOME="$HOME/flutter"
FLUTTER_VERSION="3.41.6"
export PATH="$FLUTTER_HOME/bin:$PATH"

ensure_flutter() {
  if [ -x "$FLUTTER_HOME/bin/flutter" ]; then
    local info
    info="$("$FLUTTER_HOME/bin/flutter" --version 2>/dev/null || true)"
    if [[ "$info" == *"Flutter $FLUTTER_VERSION"* ]]; then
      return
    fi
    rm -rf "$FLUTTER_HOME"
  fi

  git clone \
    --depth 1 \
    --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_HOME"
}

prepare_web_project() {
  local tmp_web
  tmp_web="$(mktemp -d)"

  if [ -f web/index.html ]; then
    cp web/index.html "$tmp_web/index.html"
  fi
  if [ -f web/robots.txt ]; then
    cp web/robots.txt "$tmp_web/robots.txt"
  fi

  flutter create \
    --platforms=web \
    --org com.gratiscash \
    --project-name gratiscash \
    .

  if [ -f "$tmp_web/index.html" ]; then
    cp "$tmp_web/index.html" web/index.html
  fi
  if [ -f "$tmp_web/robots.txt" ]; then
    cp "$tmp_web/robots.txt" web/robots.txt
  fi

  rm -rf "$tmp_web"
}

ensure_flutter
flutter config --enable-web
flutter --version

case "${1:-}" in
  install)
    prepare_web_project
    flutter pub get
    ;;
  build)
    flutter build web --release \
      --dart-define=APP_ENV="${APP_ENV:-staging}" \
      --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}" \
      --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}" \
      --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}" \
      --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}" \
      --dart-define=GOOGLE_AUTH_ENABLED="${GOOGLE_AUTH_ENABLED:-false}" \
      --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}" \
      --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}" \
      --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
    ;;
  *)
    echo "Usage: bash vercel_build.sh install|build" >&2
    exit 2
    ;;
esac

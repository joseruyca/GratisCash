#!/usr/bin/env bash
set -euo pipefail
FLUTTER_HOME="$HOME/flutter"
export PATH="$FLUTTER_HOME/bin:$PATH"
if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
fi
flutter config --enable-web
flutter --version
flutter create --platforms=web --org com.gratiscash --project-name gratiscash .
if [ "${1:-}" = "install" ]; then
  flutter pub get
  exit 0
fi
if [ "${1:-}" = "build" ]; then
  flutter build web --release     --dart-define=APP_ENV="${APP_ENV:-staging}"     --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qmuyrobiqowcjgbpyliv.supabase.co}"     --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_PUBLISHABLE_KEY:-sb_publishable_QzSCaKTlqSbzaBNHCWqs9Q_2ugIP0AW}"     --dart-define=WEBSITE_URL="${WEBSITE_URL:-https://gratiscashv1.vercel.app}"     --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://gratiscashv1.vercel.app/auth}"     --dart-define=LEGAL_OWNER="${LEGAL_OWNER:-PENDIENTE DE COMPLETAR}"     --dart-define=LEGAL_EMAIL="${LEGAL_EMAIL:-PENDIENTE DE COMPLETAR}"     --dart-define=LEGAL_ADDRESS="${LEGAL_ADDRESS:-PENDIENTE DE COMPLETAR}"
  exit 0
fi
echo "Usage: bash vercel_build.sh install|build" >&2
exit 2

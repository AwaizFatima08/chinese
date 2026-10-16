#!/bin/bash
# backup.sh — three-layer backup of LingoDaily (Chinese learning app).
#   1. local tarball   /mnt/storage/project_backups/Chinese_Backup/
#   2. GitHub          AwaizFatima08/chinese  (refuses uncommitted changes)
#   3. Google Drive    folder 1x041WOlOutqVFM0MU0uJXa1xGP-_5IRU via rclone remote "gdrive"
# Run after a session:  bash scripts/backup.sh   (commit first)
# Raw source data (data/raw) and build output are excluded: re-create with
# scripts/fetch_sources.sh and `flutter build`. Secrets (.secrets/, key.properties)
# are never sent to GitHub; the local tarball keeps them, Drive does not.

set -u
PROJECT_DIR="/mnt/storage/projects/Chinese"
BACKUP_DIR="/mnt/storage/project_backups/Chinese_Backup"
GDRIVE_FOLDER_ID="1x041WOlOutqVFM0MU0uJXa1xGP-_5IRU"
TS=$(date +"%Y%m%d_%H%M%S")
FAIL=0

echo "━━━ LingoDaily backup $TS ━━━"

# 1. local tarball ---------------------------------------------------------
echo "[1/3] local tarball"
mkdir -p "$BACKUP_DIR"
if tar --exclude="Chinese/build" --exclude="Chinese/.dart_tool" \
       --exclude="Chinese/data/raw" --exclude="Chinese/android/.gradle" \
       --exclude="Chinese/android/build" --exclude="Chinese/android/app/build" \
       -czf "$BACKUP_DIR/chinese_$TS.tar.gz" -C /mnt/storage/projects Chinese; then
  echo "  ok  chinese_$TS.tar.gz ($(du -h "$BACKUP_DIR/chinese_$TS.tar.gz" | cut -f1))"
else
  echo "  FAILED tarball"; FAIL=1
fi
( cd "$BACKUP_DIR" && ls -t chinese_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f )

# 2. GitHub ----------------------------------------------------------------
echo "[2/3] git"
cd "$PROJECT_DIR" || exit 1
if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin https://github.com/AwaizFatima08/chinese.git
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "  SKIPPED: uncommitted changes. Commit first (git add -A && git commit), then re-run."
  FAIL=1
else
  if git push -u origin main 2>&1 | tail -3; then
    echo "  ok  pushed $(git rev-parse --short HEAD)"
  else
    echo "  FAILED push"; FAIL=1
  fi
fi

# 3. Google Drive ----------------------------------------------------------
echo "[3/3] Google Drive"
if rclone sync "$PROJECT_DIR" "gdrive:" --drive-root-folder-id "$GDRIVE_FOLDER_ID" \
     --exclude "build/**" --exclude ".dart_tool/**" --exclude ".git/**" \
     --exclude "data/raw/**" --exclude "android/.gradle/**" --exclude "android/build/**" \
     --exclude "android/app/build/**" --exclude ".secrets/**" --exclude "android/key.properties" \
     --exclude "*.keystore" --exclude "*.jks" --exclude "releases/**" \
     --exclude "lib/l10n/app_localizations*.dart" 2>&1 | tail -3; then
  echo "  ok  synced"
else
  echo "  FAILED drive sync"; FAIL=1
fi

echo "━━━ done ($([ $FAIL = 0 ] && echo all layers ok || echo WITH ERRORS)) ━━━"
echo "  local : $BACKUP_DIR"
echo "  git   : github.com/AwaizFatima08/chinese"
echo "  drive : drive.google.com/drive/folders/$GDRIVE_FOLDER_ID"
exit $FAIL

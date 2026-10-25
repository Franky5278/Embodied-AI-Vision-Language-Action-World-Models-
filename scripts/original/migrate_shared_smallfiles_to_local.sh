#!/usr/bin/env bash

set -uo pipefail

ROOT="/root/autodl-tmp/embodied"
SHARED="/autodl-fs/data/embodied"
LOG="$ROOT/results/storage_migration_001"

mkdir -p "$LOG"

migrate_dir () {

    SRC="$1"
    DST="$2"
    NAME="$3"

    echo
    echo "================================================"
    echo "MIGRATE: $NAME"
    echo "SRC: $SRC"
    echo "DST: $DST"
    echo "================================================"

    if [ -L "$SRC" ]; then
        echo "[SKIP] Already a symlink:"
        ls -l "$SRC"
        return 0
    fi

    if [ ! -d "$SRC" ]; then
        echo "[SKIP] Source does not exist."
        return 0
    fi

    mkdir -p "$DST"

    echo
    echo "Source size:"
    du -sh "$SRC" || true

    echo "Source entries:"
    find "$SRC" | wc -l

    echo
    echo "Copying..."

    rsync -aH \
      --info=progress2 \
      "$SRC/" \
      "$DST/" \
      2>&1 | tee "$LOG/${NAME}_rsync.log"

    RC=${PIPESTATUS[0]}

    if [ "$RC" -ne 0 ]; then
        echo "[FAIL] rsync failed: $RC"
        return "$RC"
    fi

    echo
    echo "Verifying..."

    VERIFY="$LOG/${NAME}_verify.txt"

    rsync -aHn \
      --itemize-changes \
      "$SRC/" \
      "$DST/" \
      > "$VERIFY"

    if [ -s "$VERIFY" ]; then
        echo "[FAIL] Source and destination differ."
        head -50 "$VERIFY"
        return 20
    fi

    echo "[OK] Verification passed."

    echo
    echo "Removing shared copy..."

    rm -rf "$SRC"

    ln -s "$DST" "$SRC"

    echo
    echo "[DONE]"
    ls -ld "$SRC"

    echo
    echo "Shared inode status:"
    df -i /autodl-fs/data | tail -1
}


##############################################################################
# ALL PYTHON ENVS
##############################################################################

mkdir -p "$ROOT/envs"

if [ -d "$SHARED/envs" ]; then

    for SRC in "$SHARED/envs"/*; do

        [ -e "$SRC" ] || continue
        [ -L "$SRC" ] && continue
        [ -d "$SRC" ] || continue

        NAME=$(basename "$SRC")

        migrate_dir \
          "$SRC" \
          "$ROOT/envs/$NAME" \
          "env_${NAME}"

    done
fi


##############################################################################
# CACHES
##############################################################################

migrate_dir \
  "$SHARED/pip_cache" \
  "$ROOT/pip_cache" \
  "pip_cache"

migrate_dir \
  "$SHARED/uv_cache" \
  "$ROOT/uv_cache" \
  "uv_cache"

migrate_dir \
  "$SHARED/conda_pkgs" \
  "$ROOT/conda_pkgs" \
  "conda_pkgs"

migrate_dir \
  "$SHARED/torch_cache" \
  "$ROOT/torch_cache" \
  "torch_cache"

migrate_dir \
  "$SHARED/hf_cache" \
  "$ROOT/hf_cache" \
  "hf_cache"


echo
echo "================================================"
echo " MIGRATION FINISHED"
echo "================================================"

df -h /root/autodl-tmp /autodl-fs/data \
  | tee "$LOG/df_after.txt"

df -i /root/autodl-tmp /autodl-fs/data \
  | tee "$LOG/inodes_after.txt"

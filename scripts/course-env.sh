#!/usr/bin/env bash
# Source this file from Bash. It loads public course pins; it creates no objects.
APP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)" || return 1
. "$APP_ROOT/versions.env" || return 1
export APP_ROOT

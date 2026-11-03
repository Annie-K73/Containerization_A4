#!/usr/bin/env bash
set -euo pipefail

# Se placer à la racine du projet, quel que soit le dossier d'où on lance le script
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Charger les variables du cours (dont NGINX_IMAGE)
. scripts/course-env.sh

docker run -d \
  --name td01-web \
  --label course.lab=TD01 \
  --label course.environment=course-lab \
  --restart no \
  -p 127.0.0.1:8080:8080 \
  "$NGINX_IMAGE"
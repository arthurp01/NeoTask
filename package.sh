#!/usr/bin/env bash
# Build the distributable NeoTask package.
set -euo pipefail

cd "$(dirname "$0")"

rm -f neotask.plasmoid
zip -rq neotask.plasmoid metadata.json contents

echo "Built $(pwd)/neotask.plasmoid"

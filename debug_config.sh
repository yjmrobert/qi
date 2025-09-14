#!/bin/bash
source lib/utils.sh
source lib/config.sh

echo "=== Initial state ==="
for key in "${!QI_CONFIG[@]}"; do
    echo "$key = ${QI_CONFIG[$key]}"
done | sort

echo "=== Creating test config ==="
temp_file=$(mktemp)
cat > "$temp_file" << 'EOC'
cache_dir=/tmp/test_cache
default_branch=develop
auto_update=true
verbose=false
max_cache_size=2G
EOC

echo "=== Loading config ==="
load_config "$temp_file"

echo "=== After loading ==="
for key in "${!QI_CONFIG[@]}"; do
    echo "$key = ${QI_CONFIG[$key]}"
done | sort

echo "=== Testing specific access ==="
echo "cache_dir = '${QI_CONFIG[cache_dir]}'"
echo "default_branch = '${QI_CONFIG[default_branch]}'"
echo "max_cache_size = '${QI_CONFIG[max_cache_size]}'"

rm "$temp_file"

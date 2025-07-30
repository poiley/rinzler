#!/bin/bash

# Storage Analysis and Cleanup Script

echo "=== Storage Analysis ==="
echo "Date: $(date)"
echo ""

echo "=== ZFS Pool Details ==="
zpool list -v storage
echo ""
zfs list -r -t all -o name,used,lused,ratio storage
echo ""

echo "=== Largest Directories in /storage ==="
du -h /storage/ --max-depth=2 | sort -hr | head -20
echo ""

echo "=== Docker Volumes Usage ==="
docker system df -v
echo ""

echo "=== Finding old files in /storage/downloads ==="
echo "Files older than 6 months:"
find /storage/downloads -type f -mtime +180 -exec ls -lah {} \; | awk '{sum+=$5; print $0} END {print "\nTotal size: " sum/1024/1024/1024 " GB"}'
echo ""

echo "=== Downloads by age ==="
echo "30+ days old:"
find /storage/downloads -type f -mtime +30 | wc -l
echo "90+ days old:"
find /storage/downloads -type f -mtime +90 | wc -l
echo "180+ days old:"
find /storage/downloads -type f -mtime +180 | wc -l
echo ""

echo "=== To clean up downloads older than 6 months, run: ==="
echo "find /storage/downloads -type f -mtime +180 -delete"
echo ""
echo "=== To see what would be deleted first: ==="
echo "find /storage/downloads -type f -mtime +180 -ls"
echo ""

echo "=== Docker Cleanup Commands ==="
echo "Remove unused Docker resources:"
echo "docker system prune -a --volumes"
echo ""
echo "Remove specific unused networks:"
docker network ls --format "table {{.Name}}\t{{.ID}}" | grep -vE "bridge|host|none" | tail -n +2 | while read name id; do
    if [ $(docker network inspect $id --format '{{len .Containers}}') -eq 0 ]; then
        echo "docker network rm $name  # (unused)"
    fi
done
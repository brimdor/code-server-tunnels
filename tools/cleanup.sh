#!/bin/bash

# Exception list: container names to ignore during cleanup
EXCEPT_CONTAINERS=("twingate_shiny-dragonfly" "twingate_organic-quokka") # Add your exceptions here

# Function to check if a container is in the exception list
is_exception() {
    local name="$1"
    for ex in "${EXCEPT_CONTAINERS[@]}"; do
        if [[ "$name" == "$ex" ]]; then
            return 0
        fi
    done
    return 1
}

echo "Cleaning up Docker environment..."

# Stop and remove containers not in the exception list
ALL_CONTAINERS=$(docker ps -aq)
for cid in $ALL_CONTAINERS; do
    cname=$(docker inspect --format='{{.Name}}' "$cid" | sed 's/^\///')
    if ! is_exception "$cname"; then
        echo "Stopping and removing container: $cname ($cid)"
        docker stop "$cid" 2>/dev/null
        docker rm -f "$cid" 2>/dev/null
    else
        echo "Skipping exception container: $cname ($cid)"
    fi
done

# Remove unused images only
echo "Removing unused images..."
docker image prune -a -f 2>/dev/null

# Remove unused volumes only
echo "Removing unused volumes..."
docker volume prune -f 2>/dev/null

# Remove unused networks only (not default or in use)
echo "Removing unused networks..."
docker network prune -f 2>/dev/null

# Prune ALL unused data (force prune with volumes)
echo "Pruning unused data..."
docker system prune -a -f --volumes 2>/dev/null

echo "Environment cleaned successfully."
echo "*********************************"
echo ""
echo "Current Containers Running"
docker ps -a
echo ""
echo "Current Images"
docker images
echo ""
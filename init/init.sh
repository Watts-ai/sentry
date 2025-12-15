#!/usr/bin/env bash
set -euo pipefail

echo "============================================="
echo "Sentry Self-Hosted Initialization"
echo "============================================="

# Volume mount paths
CONFIG_DIR="/volumes/config"
RELAY_CONFIG_DIR="/volumes/relay-config"
NGINX_WWW_DIR="/volumes/nginx-www"

# Compose file and project name
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.production.yml}"
PROJECT_NAME="${COMPOSE_PROJECT_NAME:-sentry}"

# Step 1: Copy Sentry configuration files if they don't exist
echo ""
echo "[1/5] Setting up Sentry configuration files..."

mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/config.yml" ]; then
    echo "  Creating Sentry config.yml..."
    cp /templates/sentry/config.yml "$CONFIG_DIR/config.yml"
fi

if [ ! -f "$CONFIG_DIR/sentry.conf.py" ]; then
    echo "  Creating Sentry sentry.conf.py..."
    cp /templates/sentry/sentry.conf.py "$CONFIG_DIR/sentry.conf.py"
fi

if [ ! -f "$CONFIG_DIR/entrypoint.sh" ]; then
    echo "  Creating Sentry entrypoint.sh..."
    cp /templates/sentry/entrypoint.sh "$CONFIG_DIR/entrypoint.sh"
    chmod +x "$CONFIG_DIR/entrypoint.sh"
fi

# Step 2: Generate secret key if needed
echo ""
echo "[2/5] Generating secret key..."

if grep -q "system.secret-key: '!!changeme!!'" "$CONFIG_DIR/config.yml" 2>/dev/null; then
    echo "  Generating new secret key..."
    SECRET_KEY=$(head /dev/urandom | tr -dc "a-z0-9@#%^&*(-_=+)" | head -c 50 | sed -e 's/[\/&]/\\&/g')
    sed -i "s/^system.secret-key:.*$/system.secret-key: '$SECRET_KEY'/" "$CONFIG_DIR/config.yml"
    echo "  Secret key generated and written to config.yml"
else
    echo "  Secret key already exists"
fi

# Step 3: Setup Relay credentials
echo ""
echo "[3/5] Setting up Relay credentials..."

mkdir -p "$RELAY_CONFIG_DIR"

if [ ! -f "$RELAY_CONFIG_DIR/config.yml" ]; then
    echo "  Creating Relay config.yml..."
    cp /templates/relay/config.yml "$RELAY_CONFIG_DIR/config.yml"
fi

if [ ! -f "$RELAY_CONFIG_DIR/credentials.json" ]; then
    echo "  Generating Relay credentials..."
    docker run --rm "$RELAY_IMAGE" credentials generate --stdout > "$RELAY_CONFIG_DIR/credentials.json.tmp" 2>/dev/null || true
    if [ -f "$RELAY_CONFIG_DIR/credentials.json.tmp" ]; then
        mv "$RELAY_CONFIG_DIR/credentials.json.tmp" "$RELAY_CONFIG_DIR/credentials.json"
        echo "  Relay credentials generated"
    else
        echo "  WARNING: Failed to generate relay credentials, will retry on next run"
    fi
else
    echo "  Relay credentials already exist"
fi

# Step 4: Bootstrap Snuba
echo ""
echo "[4/5] Bootstrapping Snuba..."

if [ "${SKIP_SNUBA_MIGRATIONS:-}" == "" ]; then
    echo "  Running Snuba bootstrap..."
    docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" run --rm snuba-api bootstrap --force || true
    echo "  Snuba bootstrap complete"
else
    echo "  Skipped Snuba migrations (SKIP_SNUBA_MIGRATIONS is set)"
fi

# Step 5: Run database migrations
echo ""
echo "[5/5] Running database migrations..."

if [ "${SKIP_SENTRY_MIGRATIONS:-}" == "" ]; then
    echo "  Running Sentry database migrations..."
    
    if [ "${SKIP_USER_CREATION:-0}" == "1" ]; then
        docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" run --rm web upgrade --noinput --create-kafka-topics || true
        echo ""
        echo "  Did not prompt for user creation. Run the following command to create one:"
        echo "    docker compose -p $PROJECT_NAME -f $COMPOSE_FILE run --rm web createuser"
        echo ""
    else
        docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" run --rm web upgrade --create-kafka-topics || true
    fi
    
    echo "  Database migrations complete"
else
    echo "  Skipped database migrations (SKIP_SENTRY_MIGRATIONS is set)"
fi

# Setup nginx www directory
mkdir -p "$NGINX_WWW_DIR"

# Done!
echo ""
echo "============================================="
echo "Initialization complete!"
echo "============================================="
echo ""
echo "Sentry is now ready to start."
echo ""

exit 0

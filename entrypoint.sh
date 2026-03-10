#!/bin/bash
set -e

MOODLE_DIR=/var/www/html/moodle
CONFIG_FILE="${MOODLE_DIR}/config.php"

# -----------------------------------------------------------------------------
# Wait for database to be ready
# -----------------------------------------------------------------------------
echo "[entrypoint] Waiting for database at ${MOODLE_DB_HOST}:${MOODLE_DB_PORT}..."
until php -r "
    \$conn = @mysqli_connect('${MOODLE_DB_HOST}', '${MOODLE_DB_USER}', '${MOODLE_DB_PASS}', '${MOODLE_DB_NAME}', ${MOODLE_DB_PORT});
    if (\$conn) { mysqli_close(\$conn); exit(0); } exit(1);
" 2>/dev/null; do
    echo "[entrypoint] Database not ready, retrying in 3s..."
    sleep 3
done
echo "[entrypoint] Database is ready."

# -----------------------------------------------------------------------------
# Install Moodle if config.php doesn't exist
# -----------------------------------------------------------------------------
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[entrypoint] config.php not found. Running Moodle installer..."

    php "${MOODLE_DIR}/admin/cli/install.php" \
        --lang=en \
        --wwwroot="${MOODLE_URL}" \
        --dataroot="${MOODLE_DATA}" \
        --dbtype="${MOODLE_DB_TYPE}" \
        --dbhost="${MOODLE_DB_HOST}" \
        --dbport="${MOODLE_DB_PORT}" \
        --dbname="${MOODLE_DB_NAME}" \
        --dbuser="${MOODLE_DB_USER}" \
        --dbpass="${MOODLE_DB_PASS}" \
        --prefix="${MOODLE_DB_PREFIX}" \
        --fullname="${MOODLE_FULLNAME}" \
        --shortname="${MOODLE_SHORTNAME}" \
        --adminuser="${MOODLE_ADMIN_USER}" \
        --adminpass="${MOODLE_ADMIN_PASS}" \
        --adminemail="${MOODLE_ADMIN_EMAIL}" \
        --non-interactive \
        --agree-license

    echo "[entrypoint] Moodle installation complete."
else
    echo "[entrypoint] config.php found. Skipping installation."

    # Run upgrade in case code was updated
    echo "[entrypoint] Running upgrade check..."
    php "${MOODLE_DIR}/admin/cli/upgrade.php" --non-interactive || true
fi

# -----------------------------------------------------------------------------
# Fix permissions
# -----------------------------------------------------------------------------
chown -R www-data:www-data "${MOODLE_DATA}"
chmod -R 775 "${MOODLE_DATA}"

# -----------------------------------------------------------------------------
# Start cron daemon
# -----------------------------------------------------------------------------
echo "[entrypoint] Starting cron..."
service cron start

# -----------------------------------------------------------------------------
# Hand off to Apache (or whatever CMD was passed)
# -----------------------------------------------------------------------------
echo "[entrypoint] Starting Apache..."
exec "$@"

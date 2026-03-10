# =============================================================================
# Moodle 4.5 Stable - Docker Image
# Based on PHP 8.3 with Apache
# =============================================================================
FROM php:8.3-apache

LABEL maintainer="TD <developer@example.com>"
LABEL description="Moodle 4.5 Stable (MOODLE_405_STABLE branch)"
LABEL version="4.5"

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------
ENV MOODLE_BRANCH=MOODLE_405_STABLE \
    MOODLE_DB_TYPE=mariadb \
    MOODLE_DB_HOST=db \
    MOODLE_DB_PORT=3306 \
    MOODLE_DB_NAME=moodle \
    MOODLE_DB_USER=moodle \
    MOODLE_DB_PASS=moodle \
    MOODLE_DB_PREFIX=mdl_ \
    MOODLE_URL=http://localhost:8080 \
    MOODLE_ADMIN_USER=admin \
    MOODLE_ADMIN_PASS=Admin@1234 \
    MOODLE_ADMIN_EMAIL=admin@example.com \
    MOODLE_FULLNAME="Moodle LMS" \
    MOODLE_SHORTNAME="Moodle" \
    MOODLE_DATA=/var/www/moodledata \
    DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Install system dependencies
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # General utilities
    git \
    unzip \
    curl \
    wget \
    cron \
    vim \
    # Libraries for PHP extensions
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libxml2-dev \
    libzip-dev \
    libicu-dev \
    libldap2-dev \
    libsodium-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libmemcached-dev \
    zlib1g-dev \
    # For Ghostscript (PDF annotations)
    ghostscript \
    # For maxima (STACK question type)
    maxima \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Install & configure PHP extensions required by Moodle
# -----------------------------------------------------------------------------
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install -j$(nproc) \
    gd \
    intl \
    ldap \
    mbstring \
    mysqli \
    opcache \
    pdo \
    pdo_mysql \
    soap \
    xml \
    xsl \
    zip \
    exif \
    sodium \
    && pecl install redis apcu memcached \
    && docker-php-ext-enable redis apcu memcached

# -----------------------------------------------------------------------------
# PHP configuration for Moodle
# -----------------------------------------------------------------------------
RUN { \
    echo 'upload_max_filesize = 256M'; \
    echo 'post_max_size = 256M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'max_input_vars = 5000'; \
    echo 'memory_limit = 512M'; \
    echo 'date.timezone = Asia/Kolkata'; \
    echo 'opcache.enable = 1'; \
    echo 'opcache.memory_consumption = 128'; \
    echo 'opcache.max_accelerated_files = 10000'; \
    echo 'opcache.revalidate_freq = 60'; \
    echo 'opcache.use_cwd = 1'; \
    echo 'opcache.validate_timestamps = 1'; \
    echo 'opcache.save_comments = 1'; \
    } > /usr/local/etc/php/conf.d/moodle.ini

# -----------------------------------------------------------------------------
# Configure Apache
# -----------------------------------------------------------------------------
RUN a2enmod rewrite headers expires \
    && sed -i 's|/var/www/html|/var/www/html/moodle|g' /etc/apache2/sites-available/000-default.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Allow .htaccess overrides
RUN sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# -----------------------------------------------------------------------------
# Create mount-point directories (source is bind-mounted at runtime)
# -----------------------------------------------------------------------------
RUN mkdir -p /var/www/html/moodle ${MOODLE_DATA} \
    && chown -R www-data:www-data /var/www/html/moodle ${MOODLE_DATA} \
    && chmod -R 775 ${MOODLE_DATA}

# -----------------------------------------------------------------------------
# Setup Moodle cron job (every minute as recommended)
# -----------------------------------------------------------------------------
RUN echo "* * * * * www-data /usr/local/bin/php /var/www/html/moodle/admin/cli/cron.php > /dev/null 2>&1" \
    > /etc/cron.d/moodle-cron \
    && chmod 0644 /etc/cron.d/moodle-cron \
    && crontab /etc/cron.d/moodle-cron

# -----------------------------------------------------------------------------
# Entrypoint script
# -----------------------------------------------------------------------------
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80

VOLUME ["${MOODLE_DATA}"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]

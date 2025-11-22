# IBSng Dockerfile
# Based on CentOS 7 for compatibility with original installation

FROM centos:7

# Metadata
LABEL maintainer="mohseni676"
LABEL description="IBSng - ISP Billing System (Dockerized). Complete ISP billing and RADIUS server solution with web interface, XML-RPC API, and RADIUS authentication/accounting support."
LABEL version="A1.23"
LABEL org.opencontainers.image.title="IBSng Dockerized"
LABEL org.opencontainers.image.description="IBSng ISP Billing System containerized for easy deployment. Includes PostgreSQL database support, Apache web server, and full RADIUS server capabilities."
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="mohseni676"
LABEL org.opencontainers.image.url="https://github.com/mohseni676/ibsng-dockerized"
LABEL org.opencontainers.image.documentation="https://github.com/mohseni676/ibsng-dockerized/blob/main/README.md"

# Fix CentOS 7 repositories (EOL - use vault)
# Use archive.org mirror as vault.centos.org has access issues
# Handle both x86_64 and aarch64 architectures
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        REPO_ARCH="x86_64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        REPO_ARCH="aarch64"; \
        # For ARM64, try to use x86_64 emulation or skip if not available
        echo "Warning: CentOS 7 ARM64 support is limited, using x86_64 repositories"; \
        REPO_ARCH="x86_64"; \
    else \
        REPO_ARCH="x86_64"; \
    fi && \
    for repo in /etc/yum.repos.d/CentOS-*.repo; do \
        sed -i 's/mirrorlist/#mirrorlist/g' "$repo"; \
        sed -i "s|#baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/|baseurl=http://archive.kernel.org/centos-vault/7.9.2009/os/${REPO_ARCH}/|g" "$repo"; \
        sed -i "s|#baseurl=http://mirror.centos.org/centos/\$releasever/updates/\$basearch/|baseurl=http://archive.kernel.org/centos-vault/7.9.2009/updates/${REPO_ARCH}/|g" "$repo"; \
        sed -i "s|#baseurl=http://mirror.centos.org/centos/\$releasever/extras/\$basearch/|baseurl=http://archive.kernel.org/centos-vault/7.9.2009/extras/${REPO_ARCH}/|g" "$repo"; \
    done

# Install required packages
RUN yum update -y && \
    yum install -y \
    httpd \
    php \
    postgresql \
    postgresql-python \
    git \
    perl \
    python \
    iproute \
    iptables \
    net-tools \
    procps \
    which \
    curl \
    && yum clean all

# Set working directory
WORKDIR /usr/local

# Copy application files
COPY . /usr/local/IBSng/

# Set IBSng root
ENV IBS_ROOT=/usr/local/IBSng
ENV PATH=$PATH:/usr/local/IBSng

# Create necessary directories
RUN mkdir -p /var/log/IBSng && \
    mkdir -p /var/run && \
    mkdir -p /usr/local/IBSng/interface/smarty/templates_c && \
    chmod -R 755 /usr/local/IBSng && \
    chmod 777 /var/log/IBSng && \
    chmod 777 /usr/local/IBSng/interface/smarty/templates_c

# Copy and set permissions for scripts
RUN cp /usr/local/IBSng/backup_ibs /usr/bin/backup_ibs && \
    cp /usr/local/IBSng/restore_ibs /usr/bin/restore_ibs && \
    chmod +x /usr/bin/backup_ibs && \
    chmod +x /usr/bin/restore_ibs && \
    chmod +x /usr/local/IBSng/ibs.py && \
    chmod +x /usr/local/IBSng/scripts/init.py && \
    chmod +x /usr/local/IBSng/core/defs_lib/defs2sql.py

# Configure Apache
RUN cp /usr/local/IBSng/addons/apache/ibs.conf /etc/httpd/conf.d/ && \
    echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf && \
    echo "" >> /etc/httpd/conf/httpd.conf && \
    echo "<Directory \"/usr/local/IBSng/interface/IBSng\">" >> /etc/httpd/conf/httpd.conf && \
    echo "    Options None" >> /etc/httpd/conf/httpd.conf && \
    echo "    AllowOverride None" >> /etc/httpd/conf/httpd.conf && \
    echo "    Require all granted" >> /etc/httpd/conf/httpd.conf && \
    echo "</Directory>" >> /etc/httpd/conf/httpd.conf

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose ports
EXPOSE 80 1235 1812/udp 1813/udp

# Set environment variables
ENV IBSNG_DB_HOST=db
ENV IBSNG_DB_PORT=5432
ENV IBSNG_DB_USER=ibs
ENV IBSNG_DB_PASSWORD=ibsdbpass
ENV IBSNG_DB_NAME=IBSng

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD pgrep -f "ibs.py" > /dev/null && curl -f http://localhost/IBSng/admin/ || exit 1

# Use entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]


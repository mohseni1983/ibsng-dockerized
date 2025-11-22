# IBSng Dockerfile
# Based on CentOS 7 for compatibility with original installation

FROM centos:7

# Metadata
LABEL maintainer="IBSng Team"
LABEL description="IBSng - ISP Billing System"
LABEL version="A1.23"

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
    echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf

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


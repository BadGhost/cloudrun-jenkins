# Dockerfile for Jenkins with required plugins
FROM jenkins/jenkins:lts

# Switch to root to install plugins and dependencies
USER root

# Install required system packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-cli

# Switch back to jenkins user
USER jenkins

# Install Jenkins plugins
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Copy Jenkins configuration
COPY config/jenkins.yaml /var/jenkins_config/jenkins.yaml

# Set environment variables
ENV CASC_JENKINS_CONFIG=/var/jenkins_config/jenkins.yaml
ENV JAVA_OPTS="-Djava.awt.headless=true -Xmx1g -XX:+UseG1GC -XX:+UseContainerSupport"
ENV JENKINS_OPTS="--httpPort=8080"

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8080/login || exit 1

FROM bitnami/java:1.8-debian-11

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends git maven unzip && \
    rm -rf /var/lib/apt/lists/*

# Define the version of Spark to install
ARG SPARK_VERSION=3.5.0

# Set environment variables for Spark
ENV SPARK_HOME=/opt/spark
ENV LIVY_HOME=/opt/livy

# Download and install Spark
RUN wget --no-verbose "https://downloads.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz" && \
    tar -xzf "spark-${SPARK_VERSION}-bin-hadoop3.tgz" -C /opt/ && \
    rm "spark-${SPARK_VERSION}-bin-hadoop3.tgz" && \
    mv  /opt/spark-3.5.0-bin-hadoop3 ${SPARK_HOME}

# Set the location of the Livy zip file
ARG LIVY_ZIP_URL=https://github.com/vakarisbk/incubator-livy/releases/download/0.9.1/livy-0.9-snapshot.zip

# Download and extract the Livy zip file into /opt/livy
RUN wget --no-verbose "${LIVY_ZIP_URL}" -O /opt/livy.zip && \
    unzip /opt/livy.zip -d /opt && \
    mv /opt/apache-livy-0.9.0-incubating-SNAPSHOT_2.12-bin ${LIVY_HOME}

RUN mkdir /var/log/livy

ENV LIVY_VERSION            0.9.0-snapshot
ENV LIVY_CONF_DIR           $LIVY_HOME/conf
ENV PATH                    $PATH:$LIVY_HOME/bin
ENV LIVY_LOG_DIR            /var/log/livy/

COPY entrypoint.sh /opt/livy/

ENTRYPOINT /opt/livy/entrypoint.sh

FROM fedora:28 as build

RUN yum -y update && yum clean all

RUN yum -y install java-1.8.0-openjdk maven \
    && yum clean all \
    && rm -rf /var/cache/yum

RUN mkdir /build
COPY . /build

WORKDIR /build

RUN mvn -B -e -T 1C -DskipTests=true -DfailIfNoTests=false -Dtest=false clean package -Pdist

FROM quay.io/coreos/hadoop:metering-3.1.1

ENV HIVE_VERSION=2.3.3
ENV HIVE_HOME=/opt/hive-$HIVE_VERSION
ENV PATH=$HIVE_HOME/bin:$PATH

RUN mkdir -p /opt
WORKDIR /opt

USER root

COPY --from=build /build/packaging/target/apache-hive-$HIVE_VERSION-bin/apache-hive-$HIVE_VERSION-bin $HIVE_HOME

ENV HADOOP_CLASSPATH $HIVE_HOME/hcatalog/share/hcatalog/*:${HADOOP_CLASSPATH}
ENV HIVE_AUX_JARS_PATH /usr/hdp/current/hive-server2/auxlib

# ENV POSTGRESQL_JDBC_JAR postgresql-42.2.2.jar
# # Using mysql-connector-java-8.0.11 resulted in hive schema creation failing due to incorrect syntax.
# ENV MYSQL_JDBC_VERSION mysql-connector-java-5.1.46
# ENV MYSQL_JDBC_JAR $MYSQL_JDBC_VERSION.jar

# # Install PostgreSQL JDBC
# RUN set -x \
#     && curl -fSLs -o "$HIVE_HOME/lib/$POSTGRESQL_JDBC_JAR" "https://jdbc.postgresql.org/download/$POSTGRESQL_JDBC_JAR"

# # Install MySQL JDBC
# RUN set -x \
#     && curl -fSLs "https://dev.mysql.com/get/Downloads/Connector-J/$MYSQL_JDBC_VERSION.tar.gz" | tar -zx --strip-components=1 -C "$HIVE_HOME/lib" "$MYSQL_JDBC_VERSION/$MYSQL_JDBC_JAR"

# Configure Hadoop AWS Jars to be available to hive
RUN mkdir -p /usr/hdp/current/hive-server2/auxlib && ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* $HIVE_HOME/lib
RUN ln -s $HIVE_HOME /opt/hive

RUN \
    mkdir -p /var/lib/hive /user/hive/warehouse && \
    chown -R 1002:0 /opt /var/lib/hive /user/hive/warehouse && \
    chmod -R 770 /opt /var/lib/hive /user/hive/warehouse /etc/passwd

VOLUME /user/hive/warehouse /var/lib/hive

USER 1002


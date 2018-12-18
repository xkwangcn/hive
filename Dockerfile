FROM fedora:28 as build

RUN yum -y update && yum clean all

RUN yum -y install --setopt=skip_missing_names_on_install=False \
        java-1.8.0-openjdk maven \
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

RUN yum install --setopt=skip_missing_names_on_install=False -y \
        postgresql-jdbc \
        mysql-connector-java \
    && yum clean all \
    && rm -rf /var/cache/yum

COPY --from=build /build/packaging/target/apache-hive-$HIVE_VERSION-bin/apache-hive-$HIVE_VERSION-bin $HIVE_HOME

ENV HADOOP_CLASSPATH $HIVE_HOME/hcatalog/share/hcatalog/*:${HADOOP_CLASSPATH}

# Configure Hadoop AWS Jars to be available to hive
RUN ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* $HIVE_HOME/lib
# Configure MySQL connector jar to be available to hive
RUN ln -s /usr/share/java/mysql-connector-java.jar "$HIVE_HOME/lib/mysql-connector-java.jar"
# Configure Postgesql connector jar to be available to hive
RUN ln -s /usr/share/java/postgresql-jdbc.jar "$HIVE_HOME/lib/postgresql-jdbc.jar"

RUN ln -s $HIVE_HOME /opt/hive

RUN \
    mkdir -p /var/lib/hive /user/hive/warehouse && \
    chown -R 1002:0 /opt /var/lib/hive /user/hive/warehouse && \
    chmod -R 774 /opt /var/lib/hive /user/hive/warehouse /etc/passwd

VOLUME /user/hive/warehouse /var/lib/hive

USER 1002

LABEL io.k8s.display-name="OpenShift Hive" \
      io.k8s.description="This is an image used by operator-metering to to install and run Apache Hive." \
      io.openshift.tags="openshift" \
      maintainer="Chance Zibolski <czibolsk@redhat.com>"



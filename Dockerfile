# This dockerfile builds the zap stable release
FROM ubuntu:20.04
ARG VCS_REF
ARG BUILD_DATE
ARG VERSION
ARG USER_EMAIL="jack.crosnier@w6d.io"
ARG USER_NAME="Jack CROSNIER"
LABEL maintainer="${USER_NAME} <${USER_EMAIL}>" \
        org.label-schema.vcs-ref=$VCS_REF \
        org.label-schema.vcs-url="https://github.com/w6d-io/docker-owasp" \
        org.label-schema.build-date=$BUILD_DATE \
        org.label-schema.version=$VERSION

ARG DEBIAN_FRONTEND=noninteractive
ARG WEBSWING_URL=""

RUN apt-get update && apt-get install -q -y --fix-missing \
	make \
	automake \
	autoconf \
	gcc g++ \
	openjdk-11-jdk \
	wget \
	curl \
	xmlstarlet \
	unzip \
	git \
	openbox \
	xterm \
	net-tools \
	python3-pip \
	python-is-python3 \
	firefox \
	xvfb \
	x11vnc && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip zapcli python-owasp-zap-v2.4

RUN useradd -d /home/zap -m -s /bin/bash zap
RUN echo zap:zap | chpasswd
RUN mkdir /zap && chown zap:zap /zap

WORKDIR /zap

#Change to the zap user so things get done as the right person (apart from copy)
USER zap

RUN mkdir /home/zap/.vnc

ENV WEBSWING_VERSION 21.1

# Download and expand the latest stable release
RUN curl -s https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml | xmlstarlet sel -t -v //url |grep -i Linux | wget -nv --content-disposition -i - -O - | tar zxv && \
	cp -R ZAP*/* . &&  \
	rm -R ZAP* && \
	# Setup Webswing
	if [ -z "$WEBSWING_URL" ] ; \
	then curl -s -L  "https://storage.googleapis.com/builds.webswing.org/releases/webswing-examples-eval-${WEBSWING_VERSION}-distribution.zip" > webswing.zip; \
	else curl -s -L  "$WEBSWING_URL-${WEBSWING_VERSION}-distribution.zip" > webswing.zip; fi && \
	unzip webswing.zip && \
	rm webswing.zip && \
	mv webswing-* webswing && \
	# Remove Webswing bundled examples
	rm -Rf webswing/apps/

ENV JAVA_HOME /usr/lib/jvm/java-11-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:/zap/:$PATH
ENV ZAP_PATH /zap/zap.sh

# Default port for use with zapcli
ENV ZAP_PORT 8080
ENV IS_CONTAINERIZED true
ENV HOME /home/zap/
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

COPY zap* CHANGELOG.md /zap/
COPY webswing.config /zap/webswing/
COPY webswing.properties /zap/webswing/
COPY policies /home/zap/.ZAP/policies/
COPY policies /root/.ZAP/policies/
# The scan script loads the scripts from dev home dir.
COPY scripts /home/zap/.ZAP_D/scripts/
COPY .xinitrc /home/zap/

#Copy doesn't respect USER directives so we need to chown and to do that we need to be root
USER root

RUN chown zap:zap /zap/* && \
	chown zap:zap /zap/webswing/webswing.config && \
	chown zap:zap /zap/webswing/webswing.properties && \
	chown zap:zap -R /home/zap/.ZAP/ && \
	chown zap:zap /home/zap/.xinitrc && \
	chmod a+x /home/zap/.xinitrc

HEALTHCHECK --retries=5 --interval=5s CMD zap-cli status

RUN mkdir -p /zap/wrk
RUN chmod 775 /zap/wrk

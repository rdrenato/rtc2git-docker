FROM java:8u66

MAINTAINER rtc.to
LABEL description="Docker image for RTC to GIT migration"

ARG VERSION=6.0.2

# Add jenkins script
ADD jenkins/ /jenkins/
RUN chmod +x /jenkins/*.sh

# Add GitHub credentials on build
ARG SSH_PRIVATE_KEY
RUN mkdir /root/.ssh/
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa

# Make sure your domain is accepted
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.ibm.com >> /root/.ssh/known_hosts
RUN chmod 644 /root/.ssh/known_hosts

# Add Git LFS
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash
RUN apt-get install git-lfs
RUN git lfs install

# Extract RTC SCM tools
ADD RTC-scmTools-Linux64-6.0.2.zip /tmp/rtc-scm-tools.zip
RUN unzip -q -d /opt /tmp/rtc-scm-tools.zip
RUN rm -f /tmp/rtc-scm-tools.zip
RUN mkdir /var/data
ADD scm.ini /opt/jazz/scmtools/eclipse/scm.ini
ADD plugins/ /opt/jazz/scmtools/eclipse/plugins/
ADD jazz-scm/ /root/.jazz-scm/

ENV PATH=$PATH:/opt/jazz/scmtools/eclipse

VOLUME /var/data

WORKDIR /var/data

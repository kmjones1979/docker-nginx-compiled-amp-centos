FROM centos:centos7

MAINTAINER "Kevin Jones - kevin@nginx.com"

#environment variables
ENV nginxVersion "1.11.0"
ENV tmp "/tmp/nginx/src"
ENV container docker

# systemd prep
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
    systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]

# environment
ARG API_KEY

# create nginx group and user
RUN groupadd -r nginx && useradd -r -g nginx nginx

# install dependencies
RUN yum install -y wget gcc gcc-c++ make zlib-devel pcre-devel openssl-devel

# download nginx source code
RUN mkdir -p $tmp
RUN wget http://nginx.org/download/nginx-$nginxVersion.tar.gz -P $tmp
RUN tar -zxvf $tmp/nginx-$nginxVersion.tar.gz -C $tmp

# build nginx from source
RUN cd $tmp/nginx-$nginxVersion && ./configure \
    --prefix=/etc/nginx/ \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --user=nginx \
    --group=nginx \
    --with-http_v2_module \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_random_index_module \
    --with-http_secure_link_module \
    --with-http_stub_status_module \
    --with-http_auth_request_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-file-aio \
    --with-ipv6
RUN cd $tmp/nginx-$nginxVersion && make && make install

# install NGINX amplify agent
RUN mkdir -p /tmp/amplify/
RUN curl -L -o /tmp/amplify/amplify-install.sh \
               https://github.com/nginxinc/nginx-amplify-agent/raw/master/packages/install.sh
RUN sh ./tmp/amplify/amplify-install.sh -y

# install supervisord
RUN yum -y install python-setuptools
RUN easy_install supervisor
RUN mkdir -p /var/log/supervisor

# copy supervisor configuration
COPY etc/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# copy static Nginx Plus files
COPY etc/nginx /etc/nginx

# clean up
RUN yum clean all

# clean up
RUN rm -rf /tmp/*

EXPOSE 80 443 8080 8089

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

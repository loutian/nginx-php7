FROM centos
MAINTAINER loutian <loutian@gmail.com>
##
# Nginx: 1.11.8
# PHP  : 7.1.0
##
#Install system library
#RUN yum update -y

ENV PHP_VERSION 7.1.0
ENV NGINX_VERSION 1.11.8

RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && yum install -y gcc \
    gcc-c++ \
    autoconf \
    automake \
    libtool \
    zip \
    unzip \
    make \
    cmake && \
    yum clean all

#Install PHP library
## libmcrypt-devel DIY
RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-9.noarch.rpm && \
    yum install -y wget \
    zlib \
    zlib-devel \
    openssl \
    openssl-devel \
    pcre-devel \
    libxml2 \
    libxml2-devel \
    libcurl \
    libcurl-devel \
    libpng-devel \
    libjpeg-devel \
    freetype-devel \
    libmcrypt-devel \
    openssh-server \
    mysql \
    python-setuptools && \
    yum clean all

#Add user
RUN groupadd -r www && \
    useradd -M -s /sbin/nologin -r -g www www

#Download nginx & php
RUN mkdir -p /home/nginx-php && cd $_ && \
    wget -c -O nginx.tar.gz http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    wget -O php.tar.gz http://php.net/distributions/php-$PHP_VERSION.tar.gz

#Make install nginx
RUN cd /home/nginx-php && \
    tar -zxvf nginx.tar.gz && \
    cd nginx-$NGINX_VERSION && \
    ./configure --prefix=/usr/local/nginx \
    --user=www --group=www \
    --error-log-path=/var/log/nginx_error.log \
    --http-log-path=/var/log/nginx_access.log \
    --pid-path=/var/run/nginx.pid \
    --with-pcre \
    --with-http_ssl_module \
    --with-http_realip_module \
    --with-http_v2_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --with-http_gzip_static_module && \
    make -j8 && make install

#Make install php
RUN cd /home/nginx-php && \
    tar zvxf php.tar.gz && \
    cd php-$PHP_VERSION && \
    ./configure --prefix=/usr/local/php \
    --with-config-file-path=/usr/local/php/etc \
    --with-config-file-scan-dir=/usr/local/php/etc/php.d \
    --with-fpm-user=www \
    --with-fpm-group=www \
    --with-mcrypt=/usr/include \
    --with-mysqli \
    --with-pdo-mysql \
    --with-openssl \
    --with-gd \
    --with-iconv \
    --with-zlib \
    --with-gettext \
    --with-curl \
    --with-png-dir \
    --with-jpeg-dir \
    --with-freetype-dir \
    --with-xmlrpc \
    --with-mhash \
    --enable-fpm \
    --enable-xml \
    --enable-shmop \
    --enable-sysvsem \
    --enable-inline-optimization \
    --enable-mbregex \
    --enable-mbstring \
    --enable-ftp \
    --enable-gd-native-ttf \
    --enable-mysqlnd \
    --enable-pcntl \
    --enable-sockets \
    --enable-zip \
    --enable-soap \
    --enable-session \
    --enable-opcache \
    --enable-bcmath \
    --enable-exif \
    --enable-fileinfo \
    --disable-rpath \
    --enable-ipv6 \
    --disable-debug \
    --without-pear && \
    make -j8 && make install


RUN cd /home/nginx-php/php-$PHP_VERSION && \
    cp php.ini-production /usr/local/php/etc/php.ini && \
    cp /usr/local/php/etc/php-fpm.conf.default /usr/local/php/etc/php-fpm.conf && \
    cp /usr/local/php/etc/php-fpm.d/www.conf.default /usr/local/php/etc/php-fpm.d/www.conf

RUN ln -s /usr/local/php/bin/php /usr/local/bin/php

#Install supervisor
RUN easy_install supervisor && \
    mkdir -p /var/log/supervisor && \
    mkdir -p /var/run/supervisord


#ADD config/php.ini /usr/local/php/etc/php.ini

WORKDIR /root/

#Add supervisord conf
ADD config/supervisord.conf /etc/supervisord.conf

#Remove zips
RUN cd / && rm -rf /home/nginx-php



# install compose
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === '669656bab3166a7aff8a7506b8cb2d1c292f042046c5a994c43155c0be6190fa0355160742ab2e1c88d40d5be660b410') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer



#Add php-redis
COPY package/redis-php7.zip /tmp/
WORKDIR /tmp/
RUN unzip redis-php7.zip
WORKDIR /tmp/phpredis-php7
RUN /usr/local/php/bin/phpize && ./configure --with-php-config=/usr/local/php/bin/php-config &&  make -j8 && make install && echo "extension=redis.so" >> /usr/local/php/etc/php.ini
#RUN echo "extension=redis.so" >> /usr/local/php/etc/php.ini
#ADD config/php.ini /usr/local/php/etc/php.ini




WORKDIR /data/www/

#Create web folder
VOLUME ["/data/www", "/usr/local/nginx/conf/ssl", "/usr/local/nginx/conf/vhost", "/usr/local/php/etc/php.d"]

#Update nginx config
ADD config/nginx.conf /usr/local/nginx/conf/nginx.conf

#change chown
RUN chown -R www. /data/www/



RUN ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key && \
    ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key && \
    echo 'root:123456' |chpasswd && \
    sed -ri 's/^PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/UsePAM yes/#UsePAM yes/g' /etc/ssh/sshd_config && \
    sed -ri 's/#ClientAliveInterval 0/ClientAliveInterval 3600/g' /etc/ssh/sshd_config && \
    sed -ri 's/#ClientAliveCountMax 3/ClientAliveCountMax 10/g' /etc/ssh/sshd_config


#Start
ADD start.sh /start.sh
RUN chmod +x /start.sh

#Set port
EXPOSE 80 443 9000 22

#Start it
ENTRYPOINT ["/start.sh"]

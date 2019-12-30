FROM centos:centos7.7.1908
MAINTAINER loutian <loutian@gmail.com>
##
# Nginx: 1.16.1
# PHP  : 7.2.26
##
#Install system library
#RUN yum update -y

ENV NGINX_VERSION 1.16.1
ENV PHP_VERSION 7.2.26

RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && yum install -y gcc \
    gcc-c++ \
    autoconf \
    automake \
    libtool \
    zip \
    unzip \
    make \
    cmake && \
    yum clean all && \
    yum remove -y libzip

#Install PHP library
## libmcrypt-devel DIY
RUN rpm -ivh http://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-7-12.noarch.rpm && \
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

#install libzip
#COPY package/libzip-1.2.0.tar.gz /tmp/
#WORKDIR /tmp/
#RUN tar xvzf libzip-1.2.0.tar.gz
#WORKDIR /tmp/libzip-1.2.0/
#RUN ./configure && make && make install && rm -rf /tmp/libzip-1.2.0


#RUN echo '/usr/local/lib64 /usr/local/lib /usr/lib /usr/lib64' >> /etc/ld.so.conf && ldconfig -v

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


ADD config/php.ini /usr/local/php/etc/php.ini

WORKDIR /root/

#Add supervisord conf
ADD config/supervisord.conf /etc/supervisord.conf

#Remove zips
RUN cd / && rm -rf /home/nginx-php



# install compose
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php -r "if (hash_file('SHA384', 'composer-setup.php') === 'baf1608c33254d00611ac1705c1d9958c817a1a33bce370c0595974b342601bd80b92a3f46067da89e3b06bff421f182') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
    php composer-setup.php && \
    php -r "unlink('composer-setup.php');" && \
    mv composer.phar /usr/local/bin/composer && chmod +x /usr/local/bin/composer

#Add php-redis
COPY package/phpredis-5.1.1.zip /tmp/
WORKDIR /tmp/
RUN unzip phpredis-5.1.1.zip
WORKDIR /tmp/phpredis-5.1.1
RUN /usr/local/php/bin/phpize && ./configure --with-php-config=/usr/local/php/bin/php-config &&  make && make install && echo "extension=redis.so" >> /usr/local/php/etc/php.ini



#Add mongodb extension
COPY package/mongodb-1.6.1.tgz /tmp/
WORKDIR /tmp/
RUN tar xvzf mongodb-1.6.1.tgz
WORKDIR /tmp/mongodb-1.6.1/
RUN /usr/local/php/bin/phpize && ./configure --with-php-config=/usr/local/php/bin/php-config &&  make && make install && echo "extension=mongodb.so" >> /usr/local/php/etc/php.ini

WORKDIR /data/www/
#install laravel5
#RUN composer create-project laravel/laravel --prefer-dist laravel


#Create web folder
VOLUME ["/data/www", "/usr/local/nginx/conf/ssl", "/usr/local/nginx/conf/vhost", "/usr/local/php/etc/php.d"]

#Update nginx config
ADD config/nginx.conf /usr/local/nginx/conf/nginx.conf

#change chown
RUN chown -R www. /data/www/

#Start
ADD start.sh /start.sh
RUN chmod +x /start.sh

#Set port
EXPOSE 80 443 9000

#Start it
ENTRYPOINT ["/start.sh"]

FROM golang:1.12 AS backend-build

WORKDIR /go/src/app
COPY ./backend .

ENV GO111MODULE on
ENV GOPROXY https://goproxy.io

RUN go install -v ./...

FROM node:8.16.0-alpine AS frontend-build

ADD ./frontend /app
WORKDIR /app

# install frontend
RUN npm config set unsafe-perm true
RUN npm install -g yarn && yarn install

RUN npm run build:prod

# images
FROM ubuntu:latest

# Upgrade installed packages
RUN apt-get update && apt-get upgrade -y && apt-get clean

# Python package management and basic dependencies
RUN apt-get install -y curl python3.7 python3.7-dev python3.7-distutils

# Register the version in alternatives
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.7 1

# Set python 3 as the default python
RUN update-alternatives --set python /usr/bin/python3.7

# Upgrade pip to latest version
RUN curl -s https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python get-pip.py --force-reinstall && \
    rm get-pip.py

# OpenCV environment dependent
RUN apt-get install -y libglib2.0-0 libsm6 libxext6 libxrender-dev

# set as non-interactive
ENV DEBIAN_FRONTEND noninteractive

# set CRAWLAB_IS_DOCKER
ENV CRAWLAB_IS_DOCKER Y

# install packages
RUN chmod 777 /tmp \
	&& apt-get update \
	&& apt-get install -y curl git net-tools iputils-ping ntp ntpdate nginx wget vim

# install dumb-init
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64
RUN chmod +x /usr/local/bin/dumb-init

# install backend
RUN pip install scrapy pymongo bs4 requests crawlab-sdk scrapy-splash -i https://mirrors.aliyun.com/pypi/simple/

# 大陆内切换pip源加速
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/

# add files
ADD . /app

# copy backend files
RUN mkdir -p /opt/bin
COPY --from=backend-build /go/bin/crawlab /opt/bin
RUN cp /opt/bin/crawlab /usr/local/bin/crawlab-server

# copy frontend files
COPY --from=frontend-build /app/dist /app/dist

# copy nginx config files
COPY ./nginx/crawlab.conf /etc/nginx/conf.d
COPY ./nginx/default /etc/nginx/sites-enabled

# working directory
WORKDIR /app/backend

# timezone environment
ENV TZ Asia/Shanghai

# language environment
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# frontend port
EXPOSE 8080

# backend port
EXPOSE 8000

# start backend
CMD ["/bin/bash", "/app/docker_init.sh"]

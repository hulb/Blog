FROM alpine AS build
ADD https://github.com/gohugoio/hugo/releases/download/v0.128.0/hugo_0.128.0_Linux-64bit.tar.gz .
RUN tar -zxf hugo_0.128.0_Linux-64bit.tar.gz -C /bin
RUN chmod +x /bin/hugo && mkdir /src
COPY . /src
RUN mkdir -p /blog
RUN /bin/hugo -s /src -d /blog

FROM joseluisq/static-web-server:latest
COPY --from=build /blog /public

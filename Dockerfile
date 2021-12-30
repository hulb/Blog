FROM alpine AS build
ADD https://github.com/gohugoio/hugo/releases/download/v0.91.2/hugo_0.91.2_Linux-64bit.tar.gz .
RUN tar -zxf hugo_0.91.2_Linux-64bit.tar.gz -C /bin
RUN chmod +x /bin/hugo && mkdir /src
COPY . /src
RUN mkdir -p /blog
RUN /bin/hugo -s /src -d /blog

FROM docker.io/nginx:alpine
COPY --from=build /blog /usr/share/nginx/html

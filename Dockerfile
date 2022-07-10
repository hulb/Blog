FROM alpine AS build
ADD https://github.com/gohugoio/hugo/releases/download/v0.101.0/hugo_0.101.0_Linux-64bit.tar.gz .
RUN tar -zxf hugo_0.101.0_Linux-64bit.tar.gz -C /bin
RUN chmod +x /bin/hugo && mkdir /src
COPY . /src
RUN mkdir -p /blog
RUN /bin/hugo -s /src -d /blog

FROM lipanski/docker-static-website:latest
COPY --from=build /blog .

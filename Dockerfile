FROM hulb/docker-hugo AS build
WORKDIR /hugo
ADD . /hugo
RUN mkdir /blog
RUN /go/hugo -d /blog

FROM nginx:alpine
COPY --from=build /blog /usr/share/nginx/html
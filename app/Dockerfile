FROM nginx:alpine
ARG BUILD_NUMBER=0
ENV BUILD_NUMBER=${BUILD_NUMBER}
RUN apk add --no-cache envsubst
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]

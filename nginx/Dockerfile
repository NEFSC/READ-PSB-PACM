FROM nginx:alpine
COPY default.conf /etc/nginx/conf.d/default.conf
COPY --from=pacm-vue-app /app/dist /usr/share/nginx/html

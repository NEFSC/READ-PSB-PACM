# BUILDER
FROM node:16 AS builder

WORKDIR /app
COPY package*.json ./
RUN npm install

COPY . .

RUN npx update-browserslist-db@latest
RUN npm run build

# SERVER
FROM nginx:stable-alpine-slim AS server

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/ssl.conf /etc/nginx/ssl.conf

COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80
EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]

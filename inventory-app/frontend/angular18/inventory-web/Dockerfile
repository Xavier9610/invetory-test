# build
FROM node:18 AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build  # el --configuration ya está en package.json

# runtime
FROM nginx:stable-alpine
# SPA fallback (creamos nginx.conf en el paso 3)
COPY nginx.conf /etc/nginx/conf.d/default.conf
# OJO: verifica que el nombre de carpeta en dist sea 'inventory-web'
COPY --from=build /app/dist/inventory-web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx","-g","daemon off;"]

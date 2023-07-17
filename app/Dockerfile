FROM node:18.14
WORKDIR /app
# Dependencies
COPY package*.json /app/
RUN npm install
# App
COPY index.js /app/
COPY views /app/views
CMD [ "node", "index.js" ]
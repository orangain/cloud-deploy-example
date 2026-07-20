FROM node:22-slim
WORKDIR /workspace
COPY package*.json ./
RUN npm install --omit=dev
COPY index.js ./
ENV PORT=8080
CMD ["npm", "start"]


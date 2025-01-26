FROM node:20-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

# Create logs directory with proper permissions
RUN mkdir -p /app/logs && \
    chown -R node:node /app/logs

# Switch to non-root user
USER node

EXPOSE 3000

CMD ["npm", "start"]

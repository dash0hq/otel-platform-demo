FROM node:24-slim

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application source
COPY . .

# Expose the port the app runs on
EXPOSE 3001

# Run the app
CMD [ "npm", "start" ]

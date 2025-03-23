# Use an official Node.js runtime as the base image
FROM node:18

# Set the working directory inside the container
WORKDIR /app

# Copy package.json and package-lock.json to install dependencies first
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the entire project into the container
COPY . .

# Expose a port (if necessary)
EXPOSE 8545

# Default command to start Hardhat Node
CMD ["npx", "hardhat", "node"]

# Use the official Nginx image as the base image
FROM nginx

# Copy your HTML file into the Nginx default document root directory
COPY . /usr/share/nginx/html/

# Expose port 80 for Nginx
EXPOSE 80

# Start Nginx and keep the container running in the foreground
CMD ["nginx", "-g", "daemon off;"]

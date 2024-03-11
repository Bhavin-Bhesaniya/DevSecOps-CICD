###############################################################################################################################################################
# Starting Nginx Configuration for reverse proxy, certbot
###############################################################################################################################################################
echo "Starting Nginx Configuration"
sudo apt upgrade -y
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
sudo apt install certbot python3-certbot-nginx -y     # Install Certbot
echo "Installing successfully Nginx and Certbot"

# Create or edit the Nginx configuration file for Jenkins
sudo touch /etc/nginx/sites-available/jen-clovin.duckdns.org

# Configuration content
cat << EOF > /etc/nginx/sites-available/jen-clovin.duckdns.org
upstream jenkins {
    server 127.0.0.1:8080;
}

server {
    listen      80;
    server_name jen-clovin.duckdns.org;

    access_log /var/log/nginx/jenkins.access.log;
    error_log   /var/log/nginx/jenkins.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://jenkins;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host              $host;
        proxy_set_header    X-Real-IP         $remote_addr;
        proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto https;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/jen-clovin.duckdns.org /etc/nginx/sites-enabled/    # Enable the site by creating a symbolic link
sudo nginx -t                                                                             # Test for syntax errors
sudo systemctl restart nginx                                                              # Restart Nginx to apply the changes

echo "Openssl configuration for jenkins................................................................"
sudo certbot --nginx -d jen-clovin.duckdns.org --agree-tos --email bkbhesaniya11@gmail.com
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
echo "Certbot configuration Completed for jenkins......................................................"


# Sonarqube
sudo touch /etc/nginx/sites-avaliable/sonar-clovin.duckdns.org
cat << EOF > /etc/nginx/sites-available/sonar-clovin.duckdns.org
upstream sonarqube {
    server 127.0.0.1:9000;
}

server {
    listen      80;
    server_name sonar-clovin.duckdns.org;

    access_log /var/log/nginx/sonarqube.access.log;
    error_log /var/log/nginx/sonarqube.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://sonarqube;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host              $host;
        proxy_set_header    X-Real-IP         $remote_addr;
        proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto https;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/sonar-clovin.duckdns.org /etc/nginx/sites-enabled/  # Enable the site by creating a symbolic link
sudo nginx -t                                                                             # Test for syntax errors
sudo systemctl restart nginx                                                              # Restart Nginx to apply the changes

echo "Openssl configuration for sonarqube ................................................................"
sudo certbot --nginx -d sonar-clovin.duckdns.org --agree-tos --email bkbhesaniya11@gmail.com
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
echo "Certbot configuration Completed for sonarqube ......................................................"
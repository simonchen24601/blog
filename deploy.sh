ssh -i ~/.ssh/com-vps-rsa4096 root@simonc24601.com -t 'rm -r /DataCenter/nginx_static/public'
scp -i ~/.ssh/com-vps-rsa4096 -r public/ root@simonc24601.com:/DataCenter/nginx_static

# Source code for [alexdarbyshire.com](https://www.alexdarbyshire.com)
- Developed in Hugo
- Self-hosted using Cloudflare tunnels and Nginx 
- Running on K3s 

## Config
Copy deploy/secrets.yaml.example to deploy/secrets.yaml
`cp deploy/secrets.yaml.example deploy/secrets.yaml`

Convert the Cloudflare tunnel token to Base64 and then insert in secrets.yaml
`echo "insert_token_here" | base64 w -0`

## Deploy
Build image
`docker build --build-arg HUGO_BASEURL="https://www.alexdarbyshire.com" --build-arg HUGO_ENV=production -t localhost:5000/alexdarbyshire-site:4 -t localhost:5000/alexdarbyshire-site:latest .`

Bring up the private repo
```
sudo k3s kubectl apply -f deploy/distribution-pvc.yaml deploy/distribution.yaml
```

Push image to private repo
`docker push localhost:5000/alexdarbyshire-site:latest` 

Bring up rest of the resources in deploy
`sudo k3s kubectl apply -f deploy/.`


Also see `config.toml`


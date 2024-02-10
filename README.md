# Source code for [alexdarbyshire.com](https://www.alexdarbyshire.com)
- Developed in Hugo
- Self-hosted using Cloudflare tunnel and Nginx 
- Running on K3s with Vault 

## Config

See `config.toml` for Hugo configuration

## Deploy
Build image

`docker build --build-arg HUGO_BASEURL="https://www.alexdarbyshire.com" --build-arg HUGO_ENV=production -t localhost:5000/alexdarbyshire-site:4 -t localhost:5000/alexdarbyshire-site:latest .`

Bring up the private repo
```
sudo k3s kubectl apply -f deploy/distribution-pvc.yaml deploy/distribution.yaml
```

Push image to private repo
`docker push localhost:5000/alexdarbyshire-site:latest` 

Install Vault and Consul
- see post 4

Configure Vault
- see post 4

Bring up rest of the resources in deploy
`sudo k3s kubectl apply -f deploy/.`

TODO: Update readme, several steps in contained posts are not documented here yet





---
title: "Self-Hosted Website with Hugo, Docker, and Cloudflare Tunnels"
date: 2024-01-27T13:09:09+10:00
author: "Alex Darbyshire"
banner: "img/banners/person-working-on-connecting-hugo.jpeg"
toc: true
tags: 
  - Hugo
  - Docker
  - Cloudflare
  - Linux
---


This post will step through the process of building a Hugo-based website image using Docker in Ubuntu Linux, setting up a Cloudflare tunnel, and using a Docker Compose stack to bring up the website and Cloudflared containers. This will make a website available on the internet using an existing top-level domain. Some basic knowledge of Linux is required.

At the time of writing, this is how this site is being hosted. However, there are a few more manual steps in the process for creating subsequent builds than we would like. In the spirit of [kaizen](https://en.wikipedia.org/wiki/Kaizen), we will make it better in a future post.


Note that there are cheaper and simpler ways to host a top-level domain website, particularly if there isn't an available computer running around the clock already. This method suits a person who is keen to get experience using these technologies.


## Example
[Checkout how this setup looks like in GitHub](https://github.com/alexdarbyshire/alexdarbyshire.com/tree/b468af84c2b2473776549cbba7d3238541556ce2) 

Note, the example has additions to `config.toml`, `content/`, and `static/` not included in this post. Additional content being the first three posts on this site and more theme setup.

## Tech Stack
Here’s a brief overview of the tools we’ll be using:

- **Ubuntu Linux** - variant of the famous open-source operating system, *thanks Linus Torvalds et al.*
- **Hugo** - framework for building fast static websites using markdown.
- **Docker** - software for building, deploying and running containers.
- **Docker Compose** - software for defining and running multi-container applications.
- **Cloudflare Tunnel** - provides a means to make resources on a network available without opening any ports or having a publicly routable IP. This is handy for those behind [CGNAT](https://en.wikipedia.org/wiki/Carrier-grade_NAT) like a lot of 5G internet and a bunch of other use cases.

## Bring Your Own
Before we begin, we will need the following:

-   **Domain name** - can be purchased from the likes of Namecheap or Cloudflare
-   **Domain name set up with and configured to Cloudflare's name servers**
    - [Adding a site to Cloudflare](https://developers.cloudflare.com/fundamentals/setup/account-setup/add-site/)
- **Host running Ubuntu Linux** - for example: 
	- To play, the [Windows Subsystem for Linux WSL2](https://ubuntu.com/wsl) running Ubuntu could be used, or
	- An Ubuntu Virtual Machine (VM) running in [VirtualBox](https://www.virtualbox.org/).
	- To run perpetually for a low traffic site, a thin-client type PC running Ubuntu would do. This site is currently on an Ubuntu VM running in a Proxmox cluster which lives in my home office.
    - A Virtual Private Server (VPS)
- **Docker** - installed on host, recent versions come with Docker Compose which is also required
  - [Install Docker](https://docs.docker.com/engine/install/ubuntu/)
  - [Install Docker with convenience script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)

-   **User to be part of `docker` user group** (in Ubuntu) - alternatively run all docker commands prefixed with `sudo `

## Versions

For reference, these are the versions in use. If something doesn't work, and more recent versions are being used, the cause could possibly be determined by looking at the change notes.

- Ubuntu server 22.04

- Docker 24.0.7

- Docker Compose 2.21.0

- Hugo v0.68.3

- Nginx 1.25.3

## Steps
### Create the site with Hugo
#### Install Hugo in the VM

"Wait, what? I thought we were using docker"

Well, yes, we are. 

I find there is less friction testing and developing the website using Hugo directly in a VM, rather than having to bring up a shell in the Hugo docker container every time we want to run a Hugo command. 

It can all be done inside the container. 

The following command examples are run in Ubuntu VM's bash shell.


#### Update the package repository lists and install hugo and git
```bash
sudo apt update
sudo apt install hugo git
```
![Install Hugo and Git](1-install-hugo-git.png)


#### Change directory (cd) to where the website directory will be created
We will `cd` to the current user's home directory (the ~ tilde symbol is an alias for it) in the example. 
Select a directory name for the new site, in the example below it is `alexdarbyshire`.


#### Create the site and initiate a git repository
```bash
cd ~
hugo new site alexdarbyshire
cd alexdarbyshire
git init
```
![Create Site and Initiate Git Repository](2-create-site-and-repo.png)


#### Install a theme
Here we use the [Hugo Universal Theme](https://github.com/devcows/hugo-universal-theme), the below commands are from their docs.

```bash
cd themes
git clone https://github.com/devcows/hugo-universal-theme
cd ..
```
![Install Hugo Universal Theme](3-install-theme.png)

#### Set the theme
Now we want to set the theme in the config.toml, we'll do this by appending to the end of this file rather than firing up a text editor.

```bash
echo "theme = 'hugo-universal-theme'" >> config.toml
```
![Set Theme in Config](4-set-theme.png)


#### Test the site
Let's run the Hugo server to see how we went. 
```bash
hugo server --bind 0.0.0.0
```
The `--bind 0.0.0.0` means any IP (that can reach the host) will be able to access the content.

![Test the Site - Start the Hugo Server](5-test-the-site.png)

To check the content we'll either need another shell open on the same machine, or to know the IP of the VM and have network access to it from another computer which has a web browser.

##### Using another shell on same machine
![Test the Site - Curl](6-test-the-site-curl.png)
##### Using a browser on a machine that has network access to the VM.
Note, the IP shown starting with 192.168 is in a range reserved for private networks - the IP will be different when doing this on other machines.
![Test the Site - Browser](7-test-the-site-success.png)

Success!

We will not get further into 'how to use Hugo'. This working site is enough for proof-of-concept of the rest of the workflow. 

For more info on Hugo, [see their docs here](https://gohugo.io/documentation/), also see the [GitHub example](#Example) for this site at the time of this post.


### Turn the site into a Docker image
#### Create the Docker definition for the website image 
Create a file called `Dockerfile` in the website directory using a text editor, if you don't have a preferred, `nano` is relatively easy to pick up. 

The Dockerfile is the definition for the image we will build, it is sourced from the [Docker mods documentation](https://hugomods.com/docs/docker/#create-dockerfile) and modified.

The contents of the Dockerfile:
```yaml
###############
# Build Stage #
###############

FROM hugomods/hugo:exts as builder
# Base URL
ARG HUGO_BASEURL
ENV HUGO_BASEURL=${HUGO_BASEURL}
# Hugo Environment
ARG HUGO_ENV
ENV HUGO_ENV=${HUGO_ENV}

# Build site
COPY . /src
RUN hugo --enableGitInfo --minify

###############
# Final Stage #
###############
FROM hugomods/hugo:nginx
COPY --from=builder /src/public /site
```
This Dockerfile defines a multi-stage build process. First a container with Hugo is created and the `hugo build` command is run on the site we created. The static web content generated is then copied from the first image on top of a fresh image of Nginx (webserver in this use case) which becomes our new website image.

#### Build the Docker image
Build using the following command. Note to update the build argument for HUGO_BASEURL to be the applicable domain name. In the command, the `-t homelab/alexdarbyshire-site:latest -t homelab/alexdarbyshire-site:1` tags the image which is built with the namespace `homelab`, the name `alexdarbyshire-site` and specifies it version 1 as well as it being the latest version. In subsequent builds we will up the version number, and eventually we will use Git SHAs in place of version numbers.
```bash
docker build --build-arg HUGO_BASEURL="https://www.alexdarbyshire.com" --build-arg HUGO_ENV=production -t homelab/alexdarbyshire-site:latest .
```
![Build the Image 1](8-build-the-image.png)
![Build the Image 2](9-build-the-image2.png)
#### Test the image
```bash
docker run --detach -p 8081:80 --name test-hugo homelab/alexdarbyshire-site:latest
curl localhost:8081
```
![Test the Image](10-test-the-image.png)

#### Stop and remove the image
```bash
docker stop test-hugo
docker rm test-hugo
```
![Remove the Test Container](11-remove-the-test-container.png)

### Setup a Cloudflare tunnel

##### Login to Cloudflare dashboard
Click the domain. If it is missing see [Bring Your Own](#Bring-Your-Own).
![Cloudflare - Select Domain](12-cloudflare-select-domain.png)

##### Click into `DNS` section
![Cloudflare - Click DNS](13-cloudflare-click-dns.png)

Within the domain's DNS check there aren't any CNAME records for yourdomain.com and www, if there are, delete them by clicking into `Edit` and then `Delete`.
![Cloudflare - Check DNS Records](13-cloudflare-check-dns-records.png)

##### Click back button to get back to the dashboard
![Cloudflare - Back to Dashboard](14-cloudflare-back-to-dashboard.png)

##### Click `Zero Trust`
![Cloudflare - Click Zero Trust](15-cloudflare-click-zero-trust.png)

##### Click `Tunnels` under Access
![Cloudflare - Click Tunnels](16-cloudflare-click-tunnels.png)

##### Create a tunnel
Give it any name to identify it.
![Cloudflare - Create a Tunnel](17-cloudflare-create-a-tunnel.png)


Under `Connectors`, click `Docker` and make note of the docker run command, we will use part of it in our docker-compose file.
![Cloudflare - Note Tunnel Token](18-cloudflare-note-tunnel-token.png)


Click next and add a host for our domain, we will need to repeat this for our www subdomain (or alternatively use an A record and page direct rule)
![Cloudflare - Add a public hostname](19-cloudflare-add-a-public-hostname.png)

![Cloudflare - Add a public hostname details](20-cloudflare-add-a-public-hostname-details.png)


### Use Docker Compose to bring it all together
#### Create a `docker-compose.yml` file 
In the web directory folder. The service name of 'nginx-hugo' is important, it needs to be the same as the host we added when creating the Cloudflare tunnel connector. Within the docker compose stack a network is created and the service name functions as a hostname, in other words the Cloudflared container uses the service name we used in the URL `http://nginx-hugo:80/` to talk to the Nginx container which serves the website.

If unfamiliar with YAML files, be aware the indentation requirements are strict. Incorrect indentation will result in errors.

The contents of the docker-compose.yml file:
```yaml
version: "3"
services:
  nginx-hugo:
  image: homelab/alexdarbyshire-site:latest
  container_name: nginx-hugo
  restart: always

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-hugo
    restart: always
    environment:
        - CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN} 
    command: tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN"
```
Using Docker secrets would be preferable to passing the token as an environment variable. However, the Cloudflared image isn't setup to read token from a file. It can be done using a custom Dockerfile for those who are keen. See [this gist](https://gist.github.com/j0sh/b1971bfbbffeb92709cf096fb788f70).

#### Create a `.env` file for the Cloudflare token
Create the file using a text editor. 

Make sure to replace `insert_token_here` with the token from the Docker run command we noted when we created the tunnel, it was the long sequence of numbers are letters that follow `-token`.

Contents of `.env` file:
```dotenv
CLOUDFLARE_TUNNEL_TOKEN=insert_token_here
```

#### Create a .gitignore file 
We will add two lines to prevent the token being added to git repository, as well as the Hugo generated static website content.
```bash
echo ".env" >> .gitignore
echo "public/" >> .gitignore
```

#### Bring up the stack
```bash
docker compose up -d
```
![Bring the Stack Up](21-bring-up-the-stack.png)


In Cloudflare, we should see the tunnel come online, this might take a minute.
![Cloudflare - Confirm Tunnel is Healthy](22-cloudflare-confirm-tunnel-is-healthy.png)


Now we should be able to access the site in our browser.
![Success - Website showing in Browser](24-success.png)
The above shows our end result, a self-hosted website accessed using a top-level domain in browser.


Should debugging the containers be required, use the following command to see the logs:
e.g. for the nginx-hugo container
```bash
docker logs nginx-hugo 
```

#### Future builds
Now, any time the site is updated we can build a new version of the image and bring the docker stack up and down.
```bash
docker build --build-arg HUGO_BASEURL="https://www.alexdarbyshire.com" --build-arg HUGO_ENV=production -t homelab/alexdarbyshire-site:latest .
docker compose down
docker compose up -d
```

#### Make a commit
Commit the code to the local repo.
```bash
git add .
git commit -m "Install and setup theme, create Dockerfile and docker-compose.yml for deploying site"
```

### A note on SSL
SSL is the s in `https` and handles encrypting traffic between web browsers and our host.

Cloudflare handles SSL certificates for us, however make sure that [SSL strict is enabled in Cloudflare](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/#process) for the domain.  

This ensures that anyone trying to access the `http` address will get redirected to the `https` address.

Note, in the case of Cloudflare tunnels, the traffic is encrypted using SSL between the client and Cloudflare's edge. The traffic between Cloudflare and our server passes through a wireguard tunnel which is encrypted, however the data is visible to parties on either end of the tunnel (being us and Cloudflare). 

For additional security implement SSL between our server and Cloudflare. 

## Done
We give ourselves a pat on the back, relish the satisfaction of self-hosting, and then start thinking about all the ways we could improve and automate this process. To be continued in a series of follow-up posts...


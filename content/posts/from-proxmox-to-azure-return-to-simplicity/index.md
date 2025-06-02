
---
title: "From Proxmox to Azure Static Web Apps: Return to Simplicity"
date:  2025-06-01T09:01:01+10:00
author: "Alex Darbyshire"
TOC: false
tags: 
  - Azure 
---


After well over a year without a post...

## Personal Update

At the end of March 2024, my father died. May he rest in peace. With the process of grieving taking its natural course, this site went well on the back-burner, or even off the stove entirely for a time.

## The Migration Journey

Then we moved house, and my Proxmox cluster turned back into a single node. I stayed up late one night and transitioned the site's K3s stack on to an Azure VM as an interim measure. Sometime later the K3s state on that VM lost integrity and there was another unplanned service interruption.

Finally, yesterday I went with a much simpler approach - Azure Static Web Apps. 

## Why Azure Static Web Apps?

It is free for personal use of up to 100GB of traffic per month. I have been using Azure of late at work, hence why it was chosen over the other available options like Github pages, Cloudflare's offering, and the many others.

The process was straightforward. Created the resource in the Azure web interface, linked my Github account and the repo containing the Hugo code. Azure committed the necessary Github action workflow YAML to the repo. Then I created a custom domain for the Azure Static Web App and added a CNAME for `www` with my DNS provider.

# Theme Update and All

While I was at it I took the opportunity to update the Hugo theme to [Terminal by Panr](https://github.com/panr/hugo-theme-terminal). The Diffusion generated Hero images I was using in the previous theme were getting a bit long in the tooth. I feel the novelty of such images has been somewhat lost. In the seas of LLM generated text and Diffusion images I am finding an 'uncanny valley' effect striking all too regulary after clicking on some search result and getting part way through the first paragraph. 

## The New Plan

Initially this site started as largely demonstration of Devops and SRE related tools in practice, with the several of the pages serving as guides and the repo showing the infra config as it evolved. Since then I have had the opportunity to do quite a bit more in my day job including managing small-scale Kubernetes, using ArgoCD for GitOps, and observing with Grafana Loki. More recently I am migrating on-prem web applications onto Azure and moving Gitlab CI pipelines into Github. 

In other words, I am getting enough infra and infra as code at work to satisfy the inner tinkerer and I want a 'just works' site for when I feel the need to share something.
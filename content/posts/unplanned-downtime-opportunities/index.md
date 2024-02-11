---
title: "Navigating Unplanned Downtime: Turning Challenges into Opportunities"
date: 2024-02-10T00:08:09+10:00
author: "Alex Darbyshire"
banner: "img/banners/circuitry-holding-a-500.jpeg"
slug: "Unplanned Downtime Opportunities"
toc: true
---

A reflection on how to react to unplanned downtime once services are restored.

The opportunity for growth and improvement is often highest during and directly after the times when complex systems behave unexpectedly.

The potential for damage to stakeholder relationships is present at these times, particularly within teams or management structures. The term `throw someone under a bus` comes to mind, a metaphor for a very painful and maybe fatal experience.

The environment we foster post-event is important to both growing from it and reducing the likelihood of damage to relationships. This environment is ideally supported by an existing culture of openness and improvement.

In continuing with the theme, we will use this site as an example. It underwent some unplanned downtime recently. While this site receives little to no traffic and is maintained by a team of one, it still allows us to explore some relevant concepts.

### How Language Influences Processes 

The terms we adopt influence the perception of and behaviour around processes. To draw an example, imagine we have an `Aftermath Incident Inquisition and Fallout All Hands` meeting and acronymise it to a `AIIFAH`. The acronym and the process will carry with it the negative connotations of the language used.

There is also an effect where over time positive language becomes perceived as negative within an organisation due to the processes attached to that language. It can work both ways. On a side note, this happens with certain job roles and business functions which have a habit of changing names every five or ten years.

As an example, a term like 'Opportunity for Improvement' (OFI) may objectively consist of positive language. Its historic use in business contexts may trigger defensive behaviour in people familiar with the term.

Or, how `accidents` became `incidents`, and `incidents` are becoming `events`.

Many industries adopt terms from the medical professions for event analysis, e.g. `postmortem`, `cold debrief` and `hot debrief`.

We will go with a `hot debrief` which is performed immediately after a critical incident such as surgery, resuscitation event, etc where there is considered benefit in having one. Later a `cold brief` will often be undertaken which can occur days or weeks after the event.

### Strike While the Iron is Hot (and debrief)

- Agree on a facilitator, ideally a human's human
- Gather the immediate people involved
- Be thoughtful about including people who might make attendees defensive or less likely to contribute
- Outline the intent and desired outcome of the `hot debrief`
    - Identifying the casual and contributing factors which led to the event along a timeline
    - Undertaking objective analysis without attributing blame
    - Not assigning causes to the actions or inaction of people
        - Causal or contributing factors which may be attributable to the behaviour of people should consider the systems which enabled the behaviour to have the impact it did
    - Generating a list of improvements which could prevent recurrence without restraining ideas by 'expense' in time, cost or effort
    - Identifying improvements from the list with low 'expense' to impact
- It is not impromptu Scrum meeting where stories are re-prioritised
- Document the result, it will feed into subsequent processes including the `cold debrief`

Key to the `hot debrief` is not having time to replay what happened in our heads multiple times. We are less likely to have become defensive or started playing the blame game, and the fickleness and mutable nature of memory is at its least pronounced.

### Our Example
This site recently had unplanned downtime.

#### Tech Stack

At the time of the outage the site was self-hosted with the following stack:

- Proxmox running on bare-metal
- Ubuntu running on a Virtual Machine (VM) on Proxmox host
- K3s Kubernetes Distribution in Ubuntu (single node)
- Static web content baked into Nginx image running as a K3s deployment
- Cloudflare Tunnel to make Nginx available externally
- Hashicorp Vault for secrets management of Cloudflare token
- GitHub actions for Continuous Delivery of the site via self-hosted runners (ARC)
#### Breakdown of Events

##### Proxmox Backup

Every Monday morning the Proxmox host performs backups of the VMs. Newly created VMs are included in the backup schedule automatically.

The backups were configured to stop and start the VMs. This backup approach was implemented as the Proxmox machine uses hardware passthrough of several GPUs which don't play well with the typical suspend type VM backup for VMs utilising the GPUs. The VM running the site did not utilise GPUs.

##### Vault sealed

Following the VM stopping and starting, Hashicorp Vault became sealed. This is expected behaviour for Vault after a shutdown or reboot event.

##### Website update pushed to `main` and deployment triggered

An hour or so after, a minor update to the website was pushed to GitHub and the deployment pipeline triggered.

##### Patching a Kubernetes deployment while Vault was sealed

The new image was built and pushed to the registry, then the pipeline patched the Nginx deployment with the new image tag.

The patch was unsuccessful in bringing up the new pods as the Vault sidecar for secret injection would fail with Vault being sealed.

##### Discovery

The outage was discovered approximately 50 minutes later when trying to access the website.

#### How can we stop this happening again?

Here we brainstorm potential approaches to prevent recurrence. At this stage we will not give thought to the expense of a solution.

- Remove Vault and use solely Kubernetes secrets management
- Implement additional Kubernetes nodes
- Adjust Proxmox backup settings
    - Opt-in to backups for new VMs, or
    - Set default backup to use suspend method, and explicitly set which machines need full stop backup
- Using Nvidia vGPU architecture instead of hardware passthrough which should allow for suspend type backups (hardware passthrough is largely a hangover from when the machine was used for now retired workloads)
- Add check to pipeline confirming Vault is unsealed before patching deployments which rely on it
- Create alerts which get sent to a human
    - Vault being sealed
    - VM being stopped and started
    - Website being unavailable - regular health-check
- Change Vault workflow - Use of Vault could be limited to when the tunnel token changes, i.e. when Tunnel alteration is automated
- Migrate to an external hosting provider
- Add redundancy by deploying Nginx and Cloudflared container to a cloud provider

#### Low Expense to Impact Improvements
- Add check to pipeline confirming Vault is unsealed before patching deployments which rely on it. The highlighted lines were added to file `.github/workflows/build-and-deploy-website-image.yaml`
```yaml {hl_lines=["14-16"]}
Patch-Deployment-Image:  
  runs-on: arc-runner-set  
  needs: Build-and-Push  
  steps:  
    - name: Install Kubectl  
      env:  
        KUBE_VERSION: "v1.29.1"  
      run: |  
        sudo apt update  
        sudo apt install -yq openssl curl ca-certificates jq  
        sudo curl -L https://storage.googleapis.com/kubernetes-release/release/$KUBE_VERSION/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl  
        sudo chmod +x /usr/local/bin/kubectl  
  
    - name: Check Vault is unsealed  
      run: |  
        [[ $(curl -s http://vault.default.svc.cluster.local:8200/v1/sys/seal-status | jq .sealed) == 'false' ]]  
  
    - name: Update kubernetes deployment to image  
      run: |  
        kubectl patch deployment nginx-hugo-deployment -p \  
        '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-hugo","image":"localhost:5000/alexdarbyshire-site:'$IMAGE_TAG'"}]}}}}'
```
- Adjust Proxmox backup settings

The above two items were undertaken in under an hour.

#### Longer Term Improvements
Most of the brainstormed ideas sound like fun. Since this is a side project with a united executive management and dev team of one, it is likely the majority will be rubber-stamped with no thought to acceptable downtime.

### What is Acceptable Downtime?
The nature of the service will govern whether there is an acceptable level of downtime when considering the resources required to prevent it, and what that level is.

In some contexts, there is virtually no acceptable level and massive resources may be assigned. For example, consider nuclear power plant, rail and civil aviation safety. These ideas can be transferred into the tech space when we think about technology services which are responsible for supporting human life both directly and indirectly.

## Done
We have a decent list of new `TODOs` and have defined a process around post event management of unplanned service interruptions.
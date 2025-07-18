---
title: "An Ode to the Occasional Proxy: Dynamic HTTP Web Proxy Configuration in Windows, Ubuntu, and WSL"
date: 2025-07-05T09:52:00+10:00
author: "Alex Darbyshire"
slug: "http-web-proxy-some-of-the-time"
toc: true
tags:
- WSL
- Ubuntu
- Windows
- Proxy
---

*You may find yourself*... supporting developers working behind a corporate non-transparent HTTP web proxy which is implemented in some environments and not others.

*And you may ask yourself, "How do I work this?"* - with a nod to the Talking Heads, whose "Once in a Lifetime" seems strangely appropriate when dealing with proxy configurations which work sometimes but not others.

In Windows, a host of CLI tools commonly used in development don't inherit Windows proxy settings. Tools like [`curl`](https://curl.se/), [`wget`](https://www.gnu.org/software/wget/), [`npm`](https://www.npmjs.com/), [`pip`](https://pip.pypa.io/), go modules, Composer etc. Similar behaviour can be seen with most of the underlying request libraries (notably excepting Dotnet's HttpClient).

Proxy environment variables `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `FTP_PROXY` and their uncapitalised variants can help with this, but they can also introduce quirks, particularly when you use a proxy in one environment and not another on the same machine. For example, a laptop moving between office network and home network. Supporting users of varying technical knowledge using say Python occasionally can get interesting: 'Hey, have you tried this Python script that will make your job easier?'... "It doesn't install half the time, I give up."

In both Windows and Linux, the implementation of proxy environment variables and proxy configuration settings isn't as standardised as one would like. See this post from GitLab: [We need to talk: No Proxy](https://about.gitlab.com/blog/we-need-to-talk-no-proxy/) - it does a great job of giving the lay of land.

From an ops point of view, there are alternative implementations such as a transparent proxy. These notes are for the person who doesn't have the scope to implement these, and the person who is working without local admin (a prudent measure in corporate environments). Of course, get the blessing of your ops teams before messing around with network configurations, especially on other machines which they will have to support.

From a security perspective in a corporate network environment, there are good reasons for having a web proxy.

## Overall Approaches
1. Setup a local proxy which points to the corporate proxy with a failover to direct, and configure proxy settings once via environment variables. If the proxy you are working behind requires say Kerberos or NTLM auth - this is the only approach for many of the tools (some tools have specific config for these auth methods, it starts to get finicky). 

I do enjoy the touch of irony to this solution in that we add another proxy to solve proxy issues. This approach has the advantage of working across existing processes when moving between environments. It has the cons of a single point of failure and adding a another bit of software.

2. Use shell startup scripts to set and unset proxy environment variables based on environment. This only works for non-authenticated proxies. 

There are trade-offs: adding a bunch of logic to startup scripts isn't ideal, shell startup time is slowed, and if you're doing this on other users' machines, there can be complications around when they actually open shells. Also, if you're working across larger WANs, you may need to check several proxy IPs. And, key is that existing processes won't recieve the set or unset environment variables meaning restarting programs is required. A variation on this is adding service which periodically updates environment variables, though this can potentially disassociate the idea the processes have the env vars they were spawned with.

**Which approach?** I have tended towards the second option, mainly as I implement it on others machines in addition to my own. The devs and dev environment is in WSL using a use Bash start up scripts with a bit of hackery - I leave the Windows env vars alone as it limits the potential for breaking business as usual type work. I might go the first option if I was looking to solve this on my machine only, and of course there would be no other viable option if dealing with authenticated proxies.

### Local Proxy
A few of the relevant tools in this space:
- [CNTLM](https://github.com/versat/cntlm) - supports NTLM upstream, not Kerberos
- [TinyProxy](https://github.com/tinyproxy/tinyproxy) - failover config
- [Squid](https://github.com/squid-cache/squid)
- [Privoxy](https://www.privoxy.org/) - geared towards privacy/filtering
- [kpx](https://github.com/momiji/kpx) - support NTLM and Kerberos upstream
- [px](https://github.com/genotrance/px) - supports NTLM and Kerberos upstream
- [Proxifier](https://www.proxifier.com/) commercial license, requires admin to install network hook as it intercepts traffic. Notably this allows it to proxy regardless of env vars or indeed support in the program being proxied
- [Escobar](https://github.com/savely-krasovsky/escobar) - supports NTLM and Kerberos upstream
- [Fiddler](https://www.telerik.com/fiddler) - supports NTLM and Kerberos upstream. Debugging/modifying/inspecting focus
- [CharlesProxy](https://www.charlesproxy.com/) - supports NTLM and Kerberos upstream. debugging/inspecting focus

Of these, CNTLM and kpx handle failover and upstream auth based on a skim of the docs. CNTLM has been around since 2007 and is written in C but doesn't support Kerberos. 

kpx is written in Go, supports NTLM and Kerberos, and has been under active dev for about a year at time of writing.

We'll use [`kpx`](https://github.com/momiji/kpx) on Windows, WSL or pure Ubuntu. 

Note that if deployed on modern WSL:
- **WSL2**: Windows host wont be able access the proxy via [`127.0.0.1`](http://127.0.0.1) due to the virtual network interface for WSL being available at a dynamic-ish IP. Use the WSL IP address (first one found with [`hostname -I`](https://man7.org/linux/man-pages/man1/hostname.1.html)) or configure port forwarding with [`netsh`](https://docs.microsoft.com/en-us/windows-server/networking/technologies/netsh/netsh-contexts) or tools like netcat/socat (compiled for Windows and executable without elevation).

#### kpx Implementation
Download the binary for your chosen system from the [kpx releases page](https://github.com/momiji/kpx/releases). Or, pull the repo and `go run cli/main.go`

Co-locate a `kpx.yaml` config file with the binary.

```yaml
bind: 127.0.0.1
port: 7777
debug: true #This console logs all requests - for demo purposes, would turn it off for day to day

proxies:
  our_corp:
    type: anonymous
    host: 192.168.68.119 #In this example, I am running Squid in a docker container on this host
    port: 3128

rules:
  - host: "*"
    proxy: our_corp,direct #this CSV defines the failover chain, in our case try 'our_corp' first and 
```

Probably worth mentioning, in the current release (v1.11.0) the failover chain is attempted for each request. Also, there was an error related to use of 'direct' in the failover (rules.host.proxy) - I submitted a pull request to address this.

#### Proxy Environment Variables for 'Local Proxy' approach
For the local proxy approach, set your HTTP_PROXY, HTTPS_PROXY, FTP_PROXY and their uncapitalised variants to `http://127.0.0.1:7777` once in the User space for Windows (via Powershell `[SetEnvironmentVariables]` or Settings `Edit environment variables for your account`) and/or Ubuntu/WSL (via `/etc/environment`). Since we failover to direct, NO_PROXY is optional.

With NO_PROXY, be aware asterisks, wildcards and CIDR masks may or may not work depending on the underlying program (refer back to [We need to talk: No Proxy](https://about.gitlab.com/blog/we-need-to-talk-no-proxy/))

#### Docker Local Proxy Caveat
`127.0.0.1` in a Docker container won't provide access to the Linux host by design, so our local proxy won't be available in containers using this IP

There are a few work arounds at time of writing. They introduce a more environment specific quirks (ugh). See Stackoverflow [From inside of a Docker container, how do I connect to the localhost of the machine? [closed]](https://stackoverflow.com/questions/24319662/from-inside-of-a-docker-container-how-do-i-connect-to-the-localhost-of-the-mach). One could chuck another DNS server in too, along with another point of failure.

### Startup Script - PowerShell Profile
Add this to your PowerShell profile to dynamically set proxy environment variables:

```powershell
$proxyUrl = "http://your-proxy:8080"
$noProxy = "localhost,127.0.0.1,.local,.mycorporatedomain.com,*.mycorporatedomain.com"

# Define proxy variables (both cases for compatibility)
$proxyVars = @("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy")
$noProxyVars = @("NO_PROXY", "no_proxy")
$scopes = @("User", "Process")

# Test if corporate proxy is available and set accordingly
try {
    $response = Invoke-WebRequest -Uri "http://www.google.com" -Proxy $proxyUrl -TimeoutSec 1 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        # Set proxy variables (both at user level and current process level)
        foreach ($scope in $scopes) {
            foreach ($var in $proxyVars) {
                [Environment]::SetEnvironmentVariable($var, $proxyUrl, $scope)
            }
            foreach ($var in $noProxyVars) {
                [Environment]::SetEnvironmentVariable($var, $noProxy, $scope)
            }
        }
        Write-Host "Proxy environment variables set (both uppercase and lowercase)"
    }
} catch {
    # Clear all proxy variables (user level and current process level)
    foreach ($scope in $scopes) {
        foreach ($var in ($proxyVars + $noProxyVars)) {
            [Environment]::SetEnvironmentVariable($var, $null, $scope)
        }
    }
    Write-Host "No proxy detected, environment variables cleared"
}
```

Powershell's user profile startup script varies depending on version, Powershell 7+ is at `%userprofile%\Documents\PowerShell\profile.ps1`

### Startup Script - Bash via /etc/bashrc (Ubuntu and WSL)
Add this to [`/etc/bashrc`](file:///etc/bashrc) for dynamic proxy detection:

We use `/etc/bashrc` instead of `/etc/profile` as we want to set this for interactive and non-interactive shells. We use the globals startup scripts instead of user based as we want to set the env vars for all users (which for these machines tends to a single user). Can't imagine needing to apply this to a multi-user machine.

**Note** This script could be much simpler if we opted to not handle Docker Daemon or warn about sudoers env vars

```bash
#!/bin/bash
# === PROXY SETUP SCRIPT START ===
# Version: 1.0 - HTTP Proxy Auto-Configuration Script
# Generated: 2025-07-17

proxy_url="http://192.168.68.119:3128"
no_proxy="localhost,127.0.0.1,.local,.mycorporatedomain.com,*.mycorporatedomain.com"

# Function to check and and warn missing sudoers configuration for proxy environment variables
check_sudoers_proxy_config() {
    if ! grep -q "env_keep.*HTTP_PROXY" /etc/sudoers 2>/dev/null; then
        echo "Warning: Proxy environment variables may not be preserved with sudo commands, e.g. sudo apt install"
        echo "Consider adding this line to /etc/sudoers using 'sudo visudo':"
        echo "Defaults env_keep += \"HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy\""
    fi
}

# Function to handle docker daemon config and restart if required
update_docker_daemon_proxy() {
    local action="$1"  # "set" or "unset"
    local proxy_url="$2"
    local no_proxy="$3"
    
    # Only proceed if Docker is installed
    command -v docker > /dev/null || return
    
    # Ensure daemon.json exists
    if [ ! -f /etc/docker/daemon.json ]; then
        echo "Creating /etc/docker/daemon.json..."
        echo '{}' | sudo tee /etc/docker/daemon.json > /dev/null
        sudo chown root:root /etc/docker/daemon.json
        sudo chmod 644 /etc/docker/daemon.json
    fi

    local needs_update=false
    
    if [ "$action" = "set" ]; then
        local current_http_proxy=$(jq -r '.proxies["http-proxy"] // empty' /etc/docker/daemon.json)
        local current_https_proxy=$(jq -r '.proxies["https-proxy"] // empty' /etc/docker/daemon.json)
        local current_no_proxy=$(jq -r '.proxies["no-proxy"] // empty' /etc/docker/daemon.json)

        if [ "$current_http_proxy" != "$proxy_url" ] || [ "$current_https_proxy" != "$proxy_url" ] || [ "$current_no_proxy" != "$no_proxy" ]; then
            needs_update=true
        fi 

    else
        local has_proxies=$(jq -r 'has("proxies")' /etc/docker/daemon.json 2>/dev/null)
        [ "$has_proxies" = "true" ] && needs_update=true
    fi
    
    if [ "$needs_update" = "true" ]; then
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
        
        if [ "$action" = "set" ]; then
            jq ". + {\"proxies\": {\"http-proxy\": \"$proxy_url\", \"https-proxy\": \"$proxy_url\", \"no-proxy\": \"$no_proxy\"}}" /etc/docker/daemon.json > /tmp/daemon.json 2>/dev/null
        else
            jq 'del(.proxies)' /etc/docker/daemon.json > /tmp/daemon.json 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            sudo mv /tmp/daemon.json /etc/docker/daemon.json
            sudo systemctl restart docker 2>/dev/null || echo "Warning: Could not restart Docker daemon"
            echo "Docker daemon proxy configuration ${action}"
        else
            echo "Warning: Failed to update Docker daemon configuration"
            rm -f /tmp/daemon.json
        fi
    fi
}

# Function to test and set proxy
setup_proxy() {
    
    if curl -s --connect-timeout 1 --proxy "$proxy_url" http://www.google.com > /dev/null 2>&1; then
        # Set environment variables
        export HTTP_PROXY="$proxy_url"
        export HTTPS_PROXY="$proxy_url"
        export NO_PROXY="$no_proxy"
        export http_proxy="$proxy_url"
        export https_proxy="$proxy_url"
        export no_proxy="$no_proxy"
        
        update_docker_daemon_proxy "set" "$proxy_url" "$no_proxy"
        
        # Set PEAR proxy if installed
        command -v pear > /dev/null && pear config-set http_proxy "$proxy_url" 2>/dev/null
        
        echo -e "Proxy environment configured\n"
    else
        # Unset environment variables
        unset HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy
        
        update_docker_daemon_proxy "unset"
        
        # Unconfigure PEAR proxy if installed
        command -v pear > /dev/null && pear config-set http_proxy "" 2>/dev/null
        
        echo -e "No proxy detected, proxy configuration cleared\n"
    fi
}

# Run on shell startup
setup_proxy
check_sudoers_proxy_config
# === PROXY SETUP SCRIPT END ===
```

## Notes on specific usages
### Docker 
Docker run and docker build pass in the env vars automatically. 
Docker pull uses the Docker Daemon config.

An alternate approach is using ~/.docker/config.json - I feel having the system level env vars is better (unless using the local proxy approach in which case setting specific in-container proxy env vars would help work around pointing to local)

The startup script restarting the docker daemon will stop and start containers causing env vars to be propagated.

### KIND
Tear down and reinstantiate when moving between environments to allow env vars to propagate:

```bash
kind delete cluster
kind create cluster
```

### Tilt
When installed using the standard install script, the image builds are called using runc as root and don't get the env vars propagated.

Tiltfiles use starlark configuration language, one can dynamically populate a config object based on the env vars and then pass that object as build_args. This avoids the issue of missing/null value error when trying to use the env vars directly in the Tiltfile build_args.

```python
# In your Tiltfile
proxy_config = {}
proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'NO_PROXY']

for var in proxy_vars:
    value = os.getenv(var)
    if value:
        proxy_config[var] = value

docker_build('myapp', '.', build_args=proxy_config)
```

### apt Notes
apt is typically run using sudo, and for good reason env vars do not get passed to sudo.

To whitelist proxy environment variables for sudo, add this to [`/etc/sudoers`](file:///etc/sudoers) using [`visudo`](https://www.sudo.ws/man/1.8.15/visudo.man.html):

```bash
Defaults env_keep += "HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy"
```

This allows the proxy environment variables to be passed through to elevated commands.

### PEAR and PECL notes
These don't respect the proxy environment variables, need to specifically tell PEAR to use the proxy. Yes, some of us still use PECL on occasion in PHP development, haha.

Direct command to set PEAR proxy:
```bash
pear config-set http_proxy http://your-proxy:8080
```

In Dockerfiles which include PEAR/PECL installs:
```dockerfile
# Set PEAR proxy using environment variable (or default to no proxy)
ARG HTTP_PROXY="''" 
RUN pear config-set http_proxy $HTTP_PROXY
RUN pear install your-package
```

### Dotnet Windows Notes
The 'Out of the box' requests library `Httpclient` in Dotnet respects Windows proxy settings. It stops respecting these settings as soon as one of the env vars is set, so correctly setting HTTP_PROXY and missing NO_PROXY could cause issues. Keep aware of the env vars being applied for a specific process - e.g. your instance of Rider may be executing programs using Powershell which has a specific startup script.

### Dotnet no_proxy syntax
Wildcards are not `*.myexcludeddomain.com`, this can come as a surprise if you derived your exclusions from say your Windows proxy settings which does support asterisk based wildcards. Wildcard format is leading dot `.myexcludeddomain.com`

Line from relevant lib: https://github.com/dotnet/runtime/blob/main/src/libraries/System.Net.Http/src/System/Net/Http/SocketsHttpHandler/HttpEnvironmentProxy.cs#L251

### VSCode and IntelliJ Proxy Behaviour

#### VSCode
**Windows**: VSCode inherits system proxy settings from Windows Internet Options by default. Changes to system proxy settings require restarting VSCode to take effect, as the Electron framework caches network configuration at startup.

**Ubuntu**: VSCode respects standard proxy environment variables ([`HTTP_PROXY`](https://curl.se/), [`HTTPS_PROXY`](https://curl.se/), [`NO_PROXY`](https://curl.se/)). When moving between proxy and non-proxy environments, VSCode must be restarted for the new environment variables to be recognised by the underlying Electron process.

Extensions that make network calls (like language servers, Git integration, or marketplace access) inherit these same proxy settings. However, some extensions may implement their own HTTP clients that don't respect the inherited configuration.

Manual proxy configuration is available via [`File > Preferences > Settings`](vscode://settings/) → search "proxy", though environment variables typically provide better automation for dynamic environments.

#### IntelliJ (Phpstorm, Rider, Pycharm, IDEA, etc) 
**Windows**: IntelliJ detects and uses Windows system proxy settings automatically. Like VSCode, changes to system proxy configuration require an IDE restart to take effect, as the JVM caches network settings during initialisation.

**Ubuntu**: IntelliJ respects proxy environment variables when launching from a terminal that has them set. Moving between environments requires restarting the IDE to pick up new environment variable values.

Manual configuration is available via [`File > Settings > Appearance & Behavior > System Settings > HTTP Proxy`](jetbrains://idea/settings?name=Appearance+%26+Behavior--System+Settings--HTTP+Proxy). The "Auto-detect proxy settings" option works well on Windows but may be less reliable on Linux systems.

Plugin installations, version control operations, and built-in HTTP clients all inherit the configured proxy settings. However, some plugins that bundle their own HTTP libraries may require additional configuration or otherwise override. Continue.dev in IntelliJ at time of writing, I am looking at you... (it's open source so if I want fixed, I can look to a mirror)

## Debugging

### Testing Proxy Connectivity
Use [`curl`](https://curl.se/) to test proxy connectivity:

```bash
# Test direct connection
curl -I http://www.google.com

# Test via proxy
curl -I --proxy http://your-proxy:8080 http://www.google.com

# Test with authentication
curl -I --proxy-user username:password --proxy http://your-proxy:8080 http://www.google.com

# Test HTTPS via proxy
curl -I --proxy http://your-proxy:8080 https://www.google.com
```

### Setting Up a Test Environment
For testing at home, you can simulate a corporate proxy environment:

1. **Block direct internet access** (via router settings or firewall rules):
   ```bash
   # Ubuntu: Block outbound HTTP/HTTPS (WARNING: This will block ALL internet access)
   # Save current rules first for easy restoration
   sudo iptables-save > /tmp/iptables-backup.rules
   
   # Block HTTP/HTTPS but allow local traffic and SSH
   sudo iptables -A OUTPUT -o lo -j ACCEPT
   sudo iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT
   sudo iptables -A OUTPUT -p tcp --dport 80 -j DROP
   sudo iptables -A OUTPUT -p tcp --dport 443 -j DROP
   
   # To restore internet access later:
   # sudo iptables-restore < /tmp/iptables-backup.rules
   # Or flush all rules: sudo iptables -F
   ```

2. **Deploy Squid proxy using Docker**:
   ```bash
   docker run -d --name squid-proxy \
     -p 3128:3128 \
     ubuntu/squid:latest
   ```

3. **Test your proxy configuration** with the blocked environment to ensure your scripts and tools work correctly.

This approach lets you validate your proxy handling without needing access to a corporate network.

## Conclusion

Dealing with corporate proxies can be one of the 'fun ones' in work environments.

There isn't an ideal solution. Some environments need authenticated proxies, others don't. Some tools respect environment variables, others have their own configuration mechanisms. There are trade-offs whichever way we go.

Whether you choose the local proxy approach with [`kpx`](https://github.com/momiji/kpx) or go with dynamic startup scripts, the goal remains: make the proxy as close to transparent as possible to the developer experience.



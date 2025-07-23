---
title: "An Ode to the Occasional Proxy: Dynamic HTTP Forward Proxy Configuration in Windows, WSL/Ubuntu, and Docker"
date: 2025-07-18T09:52:00+10:00
author: "Alex Darbyshire"
slug: "http-forward-proxy-some-of-the-time"
toc: true
tags:
- WSL
- Ubuntu
- Windows
- Proxy
- Docker
---

*You may find yourself*... supporting developers working behind a non-transparent forward proxy which is implemented in some environments and not others.

*And you may ask yourself, "How do I work this?"* - with a nod to the Talking Heads, whose "Once in a Lifetime" seems strangely appropriate when dealing with proxy configurations which work sometimes but not others.

In Windows, a host of CLI tools commonly used in development don't inherit Windows proxy settings. Tools like [`curl`](https://curl.se/), [`wget`](https://www.gnu.org/software/wget/), [`npm`](https://www.npmjs.com/), [`pip`](https://pip.pypa.io/), [`go`](https://github.com/golang/go) modules, [`Composer`](https://github.com/composer/composer), etc. Similar behaviour can be seen with many of the underlying request libraries (notably excepting .NET's HttpClient).

Proxy environment variables `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `FTP_PROXY`, `ALL_PROXY` and their uncapitalised variants can help with this, but they can also introduce quirks, particularly when you use a proxy in one environment and not another on the same machine. 

For example, a laptop moving between office network and home network. Supporting users of varying technical knowledge using say Python occasionally can get interesting: 'Hey, have you tried this Python script that will make your job easier?'... "It doesn't install half the time, I give up."

In both Windows and Linux, the implementation of proxy environment variables and proxy configuration settings isn't as standardised as one would like. See this post from GitLab: [We need to talk: Can we standardize NO_PROXY?](https://about.gitlab.com/blog/we-need-to-talk-no-proxy/) - it does a great job giving the lay of the land.

In summary: NO_PROXY behaves differently (asterisk VS leading-dot VS maybe accepts CIDR notation), usage and precedence of capitalised and non-capitalised varies, and some programs may ignore proxy environment variables entirely opting for their own custom config.

From an ops point of view, there are alternative implementations such as a transparent proxy. That is a forward, intercepting proxy which operates without client-side configuration. This potetentially makes a juicy target for bad actors (all your HTTP traffic eggs in one basket).

These notes are for the person who doesn't have the scope to implement a transparent proxy, and the person who is working without local admin (a prudent measure in many environments). Of course, get the blessing of your ops teams before messing around with network configurations, especially on other machines which they will have to support.

From a security perspective in an operational network environment, there are good reasons for having a forward proxy. For example, install a Trusted Root Certificate on each user's machine via GPO and a proxy allows one to Man In The Middle SSL traffic for inspection, filtering and blocking by security software.

This helps immeasurably in preventing threats, and as is often the case with *great power*, brings along a host of regulatory and compliance requirements, *great responsibility*.

## Overall Approaches
**Add more proxies:**
Set up a local proxy which points to the internal proxy with a failover to direct access, and configure proxy settings once via environment variables. If the proxy you are working behind requires say Kerberos or NTLM auth - this is the only approach for many of the tools (some tools have specific config for these auth methods, it starts to get finicky). 

I do enjoy the touch of irony to this solution in that we add another proxy to solve proxy issues. This approach has the advantage of working across existing processes when moving between environments. It has the cons of a single point of failure, adding another bit of software and added complexity when trying to access from within containers (due to 127.0.0.1 being the container itself).

**Shell startup scripts:**
Use shell startup scripts to set and unset proxy environment variables based on environment. This only works for non-authenticated proxies. 

There are trade-offs: adding a bunch of logic to startup scripts isn't ideal, shell startup time is slowed, and if you're doing this on other users' machines, there can be complications around when they actually open shells. Also, if you're working across larger WANs, you may need to check several proxy IPs. And, key is that existing processes won't receive the set or unset environment variables, meaning restarting programs is required.

A variation on this is adding a service that periodically updates environment variables, though this can potentially disassociate the idea that processes have the env vars they were spawned with.

Another variation is to create a script which the user runs manually when they change environment, although this removes any semblance of dynamism.

**Which approach?** I have tended towards the second option, mainly as I implement it on others' machines in addition to my own. The devs and dev environment is in WSL/Ubuntu using Bash startup scripts with a bit of hackery - I leave the Windows env vars alone as it limits the potential for breaking business-as-usual type work. I might go the first option if I was looking to solve this on my machine only, and of course there would be no other viable option if dealing with authenticated proxies.

### Proxy Chaining a Local Forward Proxy
A few of the relevant tools in this space:
- [CNTLM](https://github.com/versat/cntlm) - supports NTLM upstream, not Kerberos
- [TinyProxy](https://github.com/tinyproxy/tinyproxy) - small footprint 
- [Squid](https://github.com/squid-cache/squid) - open-source enterprise grade, widely adopted
- [Privoxy](https://www.privoxy.org/) - geared towards privacy/filtering
- [kpx](https://github.com/momiji/kpx) - has failover, supports NTLM and Kerberos upstream
- [px](https://github.com/genotrance/px) - supports NTLM and Kerberos upstream
- [Proxifier](https://www.proxifier.com/) - commercial license, requires admin to install network hook as it intercepts traffic. Notably this allows it to proxy regardless of env vars or indeed support in the program being proxied
- [Escobar](https://github.com/savely-krasovsky/escobar) - supports NTLM and Kerberos upstream
- [Fiddler](https://www.telerik.com/fiddler) - supports NTLM and Kerberos upstream. Debugging/modifying/inspecting focus
- [Charles](https://www.charlesproxy.com/) - supports NTLM and Kerberos upstream. Debugging/inspecting focus

Of these, CNTLM and kpx handle failover and upstream auth based on a skim of the docs. CNTLM has been around since 2007 and is written in C but doesn't support Kerberos. Apparently [Microsoft is deprecating NTLM](https://techcommunity.microsoft.com/blog/windows-itpro-blog/the-evolution-of-windows-authentication/3926848).

kpx is written in Go, supports NTLM and Kerberos, and under active dev for about a year at time of writing. 

We'll use kpx in our example implementation.

Note that if deployed on Windows host and accessed from WSL: using default settings at the time of writing, the proxy won't be available at 127.0.0.1 from within WSL (as it refers to the WSL instance itself, not the Windows host). [You can grab the IP of the Windows host](https://learn.microsoft.com/en-us/windows/wsl/networking#accessing-windows-networking-apps-from-linux-host-ip).

#### kpx Implementation
Download the binary for your chosen system from the [kpx releases page](https://github.com/momiji/kpx/releases). Or, pull the repo and `go run cli/main.go`

Co-locate a `kpx.yaml` config file with the binary.

```yaml
bind: 127.0.0.1
port: 7777
debug: true # This console logs all requests - for demo purposes, would turn it off for day-to-day

proxies:
  our_work:
    type: anonymous
    host: your-proxy 
    port: 3128

rules:
  - host: "*"
    proxy: our_work,direct # this CSV defines the failover chain, in our case try 'our_work' first and then fall back to direct
```

Worth noting, in the current release (v1.11.0) the failover chain is attempted for each request. Also, there was an error related to use of 'direct' in the failover (rules[].host.proxy) - I submitted a [pull request](https://github.com/momiji/kpx/pull/6) to address this.

#### Proxy Environment Variables for 'Local Proxy' approach
For the local proxy approach, set your HTTP_PROXY, HTTPS_PROXY, FTP_PROXY and their lowercase variants to `http://127.0.0.1:7777` once in the User space for Windows (via PowerShell `[Environment]::SetEnvironmentVariable("KEY", "VALUE", "User")` or Settings `Edit environment variables for your account`) and/or Ubuntu/WSL (via `/etc/environment`). Since we failover to direct, NO_PROXY is optional.

With NO_PROXY, be aware asterisks, wildcards and CIDR masks may or may not work depending on the underlying program (refer back to [We need to talk: No Proxy](https://about.gitlab.com/blog/we-need-to-talk-no-proxy/))

#### Docker Local Proxy Caveat
`127.0.0.1` in a Docker container won't provide access to the Linux host by design, so our local proxy won't be available in containers using this IP.

There are a few workarounds at time of writing. They introduce a more environment-specific quirks (ugh). See Stackoverflow [From inside of a Docker container, how do I connect to the localhost of the machine? [closed]](https://stackoverflow.com/questions/24319662/from-inside-of-a-docker-container-how-do-i-connect-to-the-localhost-of-the-mach). 

One could say create the proxy in a container, use `macvlan` to give it its own routeable IP (a bit icky), and then use `~/.docker/config.json` to set docker specific proxy env vars using the proxy container's IP (and override the config.json env vars in the proxy container itself to avoid a loop).

### Startup Script - PowerShell Profile
Adding the below script to a PowerShell profile will dynamically set proxy environment variables to those declared in the script.

The testing logic opted for here is `Do we get an OK response from google via the proxy within 1 second?`.

We could do this some loops and less lines, opted for explicit and verbose.
```powershell
# === POWERSHELL PROXY SETUP SCRIPT START ===
# Version: 1.0 - HTTP Proxy Auto-Configuration Script
# Generated: 2025-07-17
$proxyUrl = "http://your-proxy:8080"
$noProxy = "localhost,127.0.0.1,.local,.mycorporatedomain.com,*.mycorporatedomain.com"

function Set-ProxyEnvironmentVariables {
    param($ProxyUrl, $NoProxyList)
    
    Write-Host "Setting proxy environment variables..." # both cases for compatibility
    
    # Set proxy environment variables for User
    [Environment]::SetEnvironmentVariable("HTTP_PROXY", $ProxyUrl, "User")
    [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $ProxyUrl, "User")
    [Environment]::SetEnvironmentVariable("http_proxy", $ProxyUrl, "User")
    [Environment]::SetEnvironmentVariable("https_proxy", $ProxyUrl, "User")
    [Environment]::SetEnvironmentVariable("NO_PROXY", $NoProxyList, "User")
    [Environment]::SetEnvironmentVariable("no_proxy", $NoProxyList, "User")

    # Set proxy environment variables for current process (in case someone uses the shell)
    [Environment]::SetEnvironmentVariable("HTTP_PROXY", $ProxyUrl, "Process")
    [Environment]::SetEnvironmentVariable("HTTPS_PROXY", $ProxyUrl, "Process")
    [Environment]::SetEnvironmentVariable("http_proxy", $ProxyUrl, "Process")
    [Environment]::SetEnvironmentVariable("https_proxy", $ProxyUrl, "Process")
    [Environment]::SetEnvironmentVariable("NO_PROXY", $NoProxyList, "Process")
    [Environment]::SetEnvironmentVariable("no_proxy", $NoProxyList, "Process")
    
    Write-Host "Proxy environment variables set successfully. Restart any processes reliant on them."
}

function Clear-ProxyEnvironmentVariables {
    Write-Host "Clearing proxy environment variables..."
    
    # Clear all proxy-related variables
    $variablesToClear = @("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy", "NO_PROXY", "no_proxy")
    
    foreach ($variable in $variablesToClear) {
        [Environment]::SetEnvironmentVariable($variable, $null, "User")
        [Environment]::SetEnvironmentVariable($variable, $null, "Process")
    }
    
    Write-Host "Proxy environment variables cleared. Restart any processes reliant on them."
}

function Test-ProxyConnection {
    param($ProxyUrl)
    
    try {
        Write-Host "Testing proxy connection..."
        $response = Invoke-WebRequest -Uri "https://www.google.com" -Proxy $ProxyUrl -TimeoutSec 1 -UseBasicParsing
        return $response.StatusCode -eq 200
    } catch {
        Write-Host "Proxy connection test failed: $($_.Exception.Message)"
        return $false
    }
}

# Main logic
if (Test-ProxyConnection -ProxyUrl $proxyUrl) {
    Set-ProxyEnvironmentVariables -ProxyUrl $proxyUrl -NoProxyList $noProxy
} else {
    Clear-ProxyEnvironmentVariables
}
# === POWERSHELL PROXY SETUP SCRIPT END ===
```

PowerShell's user profile startup script varies depending on version, PowerShell 7+ is at `%userprofile%\Documents\PowerShell\profile.ps1`

One could also alter the Windows proxy settings themselves in this script by altering the relevant registry keys.
```powershell
#Enable
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1 

#Disable
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0 
```

### Startup Script - Bash via /etc/bash.bashrc (Ubuntu)
Adding the below to `/etc/bash.bashrc` will dynamically set proxy env vars to those declared in the script.

We use `/etc/bash.bashrc` instead of `/etc/profile` as we want to set this for interactive and non-interactive shells. We use the global startup scripts instead of user-based ones as we want to set the env vars for all users (which for these machines tends to be a single user). Can't imagine needing to apply this to a multi-user machine. We don't use `/etc/environment` as this applies on boot.

The script uses jq for manipulating JSON, make sure it is installed `sudo apt update && sudo apt install jq`

As with the PowerShell variant, this uses the testing logic `Do we get an OK response from Google via the proxy within 1 second?`

**Note:** This script could be much simpler if we opted to not handle Docker Daemon or warn about sudoers env vars.

```bash
# === PROXY SETUP SCRIPT START ===
# Version: 1.0 - HTTP Proxy Auto-Configuration Script
# Generated: 2025-07-17

proxy_url="http://your-proxy:3128"
no_proxy="localhost,127.0.0.1,.local,.mycorporatedomain.com,*.mycorporatedomain.com"

# Function to check and warn missing sudoers configuration for proxy environment variables
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
    
    if curl -s --connect-timeout 1 --proxy "$proxy_url" https://www.google.com > /dev/null 2>&1; then
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
### Docker (modern) 
- `docker run` and `docker build` pass in proxy env vars from the process they were executed in automatically
- `docker pull` uses the Docker Daemon config in `/etc/docker/daemon.json`. This settings affects the `FROM` line when building Dockerfiles (as it is effectively a `docker pull`)
- Dockerfiles - in most cases I have been able to avoid baking in references to proxies or env vars in images (with exception of PEAR/PECL)

An alternate approach to process env vars is using `~/.docker/config.json` - I feel having the process level env vars is better (unless using the local proxy approach in which case setting specific in-container proxy env vars would help work around pointing to local).

The startup script restarting the docker daemon will stop and start containers causing env vars to be propagated.

**Note:** Older versions of Docker did not do as much automatically with proxy env vars.

**Another Note:** the proxy config settings of `daemon.json` and `config.json` differ - your go-to LLM will most likely serve you up settings structured for `config.json`.

**Third Note:** Docker Daemon technically does respect proxy environment variables, however the process is usually managed by the `init` system (`systemd` in Ubuntu's case) which requires environment variables to be specifically set within a service conf or service override conf. To have a look at the environment variables of the `dockerd` process, see `sudo cat /proc/$(pgrep dockerd)/environ | tr '\0' '\n'`

### kind 
Tear down and reinstantiate when moving between environments to allow env vars to propagate (after restarting Docker Daemon):

```bash
kind delete cluster
kind create cluster
```

### Tilt
When installed using the standard install script, the image builds are called using `runc` as `root` and don't get the env vars propagated.

Tiltfiles use Starlark configuration language, one can dynamically populate a config object based on the env vars and then pass that object as build_args. This avoids the issue of missing/null value error when trying to use the env vars directly in the Tiltfile build_args.

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

The alternative here is to script setting/unsetting proxy settings in [`/etc/apt/apt.conf`](https://manpages.ubuntu.com/manpages/xenial/man5/apt.conf.5.html).

### PEAR and PECL notes
These don't respect the proxy environment variables, need to specifically tell PEAR to use the proxy. Yes, some of us still use PECL on occasion in PHP development, haha.

Direct command to set PEAR proxy:
```bash
pear config-set http_proxy http://your-proxy:3128
```

In Dockerfiles that include PEAR/PECL installs:
```dockerfile
# Set PEAR proxy using environment variable (or default to no proxy), PECL shares these settings
ARG HTTP_PROXY="''" 
RUN pear config-set http_proxy $HTTP_PROXY
RUN pecl install your-package
```

### .NET 7.0 & 8.0 Windows Notes
The out-of-the-box requests library `HttpClient` in .NET respects Windows proxy settings. It stops respecting these settings as soon as one of the env vars is set, so correctly setting HTTP_PROXY and missing NO_PROXY could cause issues when accessing local resources. 

The default behaviour can be altered in the code.

Keep aware of the env vars being applied for a specific process - e.g. your instance of Rider may be executing programs using a specific version PowerShell which has a different startup script to the one you expect.

### .NET 7.0 & 8.0 no_proxy syntax
Wildcards are not `*.myexcludeddomain.com`, this can come as a surprise if you derived your exclusions from say your Windows proxy settings which does support asterisk based wildcards. Wildcard format is leading dot `.myexcludeddomain.com`

Line from relevant lib: https://github.com/dotnet/runtime/blob/main/src/libraries/System.Net.Http/src/System/Net/Http/SocketsHttpHandler/HttpEnvironmentProxy.cs#L251

### Framework 4.8 Notes
By default, programs compiled to Framework 4.8 respect Windows proxy settings. They do not respect proxy environment variables.

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

Plugin installations, version control operations, and built-in HTTP clients all inherit the configured proxy settings. However, some plugins that bundle their own HTTP libraries may require additional configuration or may otherwise override these settings. Continue.dev in IntelliJ at time of writing, I am looking at you... (it's open source so if I want it fixed, I can look to a mirror)

## Debugging

### Testing Proxy Connectivity
Use [`curl`](https://curl.se/) to test proxy connectivity:

```bash
# Test direct connection
curl -I https://www.google.com

# Test via proxy
curl -I --proxy http://your-proxy:8080 https://www.google.com

# Test with authentication
curl -I --proxy-user username:password --proxy http://your-proxy:8080 https://www.google.com

```

### Setting Up a Test Environment
For testing at home, simulate a proxy environment:

- **Block direct internet access on test machine** (via firewall rules or router):

- **Deploy Squid proxy using Docker on another box**:
   ```bash
   docker run -d --name squid-proxy \
     -p 3128:3128 \
     ubuntu/squid:latest
   ```
- **Test your proxy configuration** with the blocked environment.

This lets you figure it all out at your own leisure on your own gear.

## Conclusion

Dealing with non-transparent forward proxies can be one of the 'fun ones' in work environments.

I feel like it is a good one to write about as there isn't an ideal solution at the development level. There are trade-offs, complexity and a touch of cognitive load whichever approach you take. 

The aim is to improve the developer experience (while maintaining secure practices).

*Same as it ever was*



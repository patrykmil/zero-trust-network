## Unsecure

### nmap -A 74.248.135.130

Nmap scan report for 74.248.135.130
Host is up (0.033s latency).
Not shown: 993 closed tcp ports (conn-refused)
PORT STATE SERVICE VERSION
22/tcp open ssh OpenSSH 8.9p1 Ubuntu 3ubuntu0.15 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
| 256 41:53:29:1d:79:ac:b2:eb:e3:90:f2:86:f3:61:8a:cf (ECDSA)
|\_ 256 7f:8b:44:98:af:09:19:28:6a:e5:41:a0:0d:bb:46:cc (ED25519)
25/tcp filtered smtp
1037/tcp filtered ams
1999/tcp filtered tcp-id-port
3889/tcp filtered dandv-tester
8000/tcp open http Uvicorn
|\_http-server-header: uvicorn
|\_http-title: Site doesn't have a title (application/json).
14442/tcp filtered unknown
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

### curl 74.248.135.130:8000

{"message":"Secret data: ???"}

### ssh 74.248.135.130

The authenticity of host '74.248.135.130 (74.248.135.130)' can't be established.
ED25519 key fingerprint is: SHA256:QHixKVoGR4QkxlTgyyeSEAwvKX5ORnZFkmay4QQgJBo

## Zero trust

### nmap -A vm-a-zt

Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-11 19:04 +0200
Note: Host seems down. If it is really up, but blocking our ping probes, try -Pn
Nmap done: 1 IP address (0 hosts up) scanned in 3.64 seconds

### nmap -Pn -A vm-a-zt

Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-11 19:09 +0200
Nmap scan report for vm-a-zt (100.77.126.57)
Host is up (0.081s latency).
rDNS record for 100.77.126.57: vm-a-zt.tail53d718.ts.net
Not shown: 998 filtered tcp ports (no-response)
PORT STATE SERVICE VERSION
22/tcp open ssh OpenSSH 8.9p1 Ubuntu 3ubuntu0.15 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
| 256 fa:e3:ce:74:63:bd:d5:05:48:b4:bb:14:01:b2:5a:96 (ECDSA)
|\_ 256 a1:4a:ff:04:c0:b0:a9:b9:ba:dd:c2:4a:11:72:83:e3 (ED25519)
8000/tcp open http Uvicorn
|\_http-title: Site doesn't have a title (application/json).
|\_http-server-header: uvicorn
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel

### nmap -Pn -A vm-b-zt

Starting Nmap 7.99 ( https://nmap.org ) at 2026-05-11 19:09 +0200
Nmap scan report for vm-b-zt (100.71.102.63)
Host is up.
rDNS record for 100.71.102.63: vm-b-zt.tail53d718.ts.net
All 1000 scanned ports on vm-b-zt (100.71.102.63) are in ignored states.
Not shown: 1000 filtered tcp ports (no-response)

### curl vm-a-zt:8000

{"remote_time":"2026-05-12T02:05:02.481421","local_time":"2026-05-11T19:05:02.613383"}

### curl vm-a-zt:8000

curl: (28) Failed to connect to vm-b-zt port 8000 after 132779 ms: Could not connect to server

### ssh azureuser@vm-a-zt

azureuser@vm-a-zt's password:

### ssh azureuser@vm-b-zt

ssh: connect to host vm-b-zt port 22: Connection timed out

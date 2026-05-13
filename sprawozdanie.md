# Sprawozdanie - Zero Trust vs Unsecure

## 1. Czym jest Zero Trust?

Zero Trust to model bezpieczeństwa sieciowego oparty na zasadzie **"Nigdy nie ufaj, zawsze weryfikuj"**. W przeciwieństwie do otwartego podejścia, Zero Trust zakłada, że każda komunikacja - niezależnie od tego, czy pochodzi z wewnątrz, czy z zewnątrz sieci - musi być uwierzytelniona, autoryzowana i szyfrowana. Kluczowe założenia:

- Brak domyślnego zaufania do jakiegokolwiek urządzenia lub użytkownika
- Mikrosegmentacja - dostęp tylko do niezbędnych zasobów
- Ciągła weryfikacja tożsamości i stanu bezpieczeństwa
- Szyfrowanie całego ruchu (nawet wewnątrz sieci prywatnej)
- Dostęp przyznawany na zasadzie least privilege

## 2. Użyte technologie

| Technologia                      | Zastosowanie                                     |
| -------------------------------- | ------------------------------------------------ |
| **Terraform**                    | Infrastruktura jako kod (IaC)                    |
| **Azure**                        | Platforma chmurowa                               |
| **Azure Network Security Group** | Grupa zabezpieczeń sieciowej                     |
| **Tailscale**                    | VPN oparty na protokole WireGuard                |
| **Tailscale ACL**                | Reguły kontroli dostępu dla Tailscale            |
| **FastAPI / Uvicorn**            | Serwer HTTP                                      |
| **nmap**                         | Skanowanie portów - testowanie dostępności usług |
| **curl**                         | Testowanie połączeń HTTP                         |
| **ssh**                          | Testowanie dostępu do powłoki zdalnej            |

## 3. Cel zadania

Celem zadania było porównanie dwóch podejść do bezpieczeństwa sieciowego:

1. **Unsecure** - tradycyjna architektura z publicznymi adresami IP, otwartymi regułami NSG (Network Security Groups) i brakiem szyfrowania komunikacji między VM-ami.
2. **Zero Trust** - architektura z prywatnymi subnetami, bez publicznych IP, z komunikacją przez Tailscale (mesh VPN) i restrykcyjnymi regułami ACL.

Oczekiwane działanie w obu środowiskach:

| Zasób                 | Unsecure                    | Zero Trust                                      |
| --------------------- | --------------------------- | ----------------------------------------------- |
| HTTP VM-B (port 8000) | dostępny przez publiczny IP | dostępny z VM-A przez tailnet                   |
| HTTP VM-A (port 8000) | dostępny przez publiczny IP | dostępny tylko z lokalnej maszyny przez tailnet |
| SSH VM-A (port 22)    | dostępny przez publiczny IP | dostępny tylko z lokalnej maszyny przez tailnet |

## 4. Opis infrastruktur

### 4.1 Unsecure

Infrastruktura **unsecure** składa się z:

- **2 maszyn wirtualnych** (VM-A w Poland Central, VM-B w Japan East) - każda z publicznym adresem IP
- **2 sieci wirtualnych** (VNet A i VNet B) - rozdzielone geograficznie, każda z własnym subnetem
- **Network Security Groups (NSG)** z regułą **AllowAllInbound** - przepuszczającą cały ruch przychodzący z dowolnego źródła na wszystkie porty
- **Brak Tailscale** - komunikacja oparta wyłącznie na publicznych IP

Kluczowa różnica w definicji NSG w Terraform:

```hcl
# unsecure - pełna otwartość
resource "azurerm_network_security_group" "nsg_a" {
  security_rule {
    name                       = "AllowAllInbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
```

Interfejs sieciowy VM ma przypisany **publiczny adres IP**:

```hcl
# unsecure - publiczne IP na interfejsie
resource "azurerm_network_interface" "vm_a" {
  ip_configuration {
    subnet_id                     = azurerm_subnet.a.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_a.id
  }
}
```

Aplikacja na VM komunikuje się z peerem przez jego **publiczny adres IP** (przekazywany przez cloud-init):

```python
# unsecure - bezpośrednie połączenie przez publiczny IP
PEER_IP = "__PEER_IP__"
def get_remote_time():
    return get(f"http://{PEER_IP}:8000/time").text.strip('"')
```

### 4.2 Zero Trust

Infrastruktura **Zero Trust** różni się diametralnie:

- **2 maszyny wirtualne** - bez publicznych adresów IP, tylko z prywatnymi IP w Azure
- **2 sieci wirtualnych** - identyczna topologia jak w unsecure
- **Network Security Groups (NSG)** - bez żadnych reguł (domyślnie blokują cały ruch)
- **Tailscale** zainstalowany na każdej VM - tworzy mesh VPN szyfrowany WireGuard
- **cloud-init** automatyzuje instalację i autoryzację Tailscale przy pierwszym uruchomieniu

NSG są **celowo puste** - nie definiują żadnych reguł security_rule, co oznacza domyślną blokadę całego ruchu:

```hcl
# zerotrust - brak reguł (domyślnie blokada)
resource "azurerm_network_security_group" "nsg_a" {
  name                = "nsg-a-zerotrust"
  location            = var.location_a
  resource_group_name = azurerm_resource_group.main.name
}
```

Interfejs sieciowy nie ma publicznego IP:

```hcl
# zerotrust - tylko prywatne IP, brak publicznego
resource "azurerm_network_interface" "vm_a" {
  ip_configuration {
    subnet_id                     = azurerm_subnet.a.id
    private_ip_address_allocation = "Dynamic"
  }
}
```

Aplikacja na VM odnajduje peera przez **Tailscale DNS** zamiast publicznego IP:

```python
# zerotrust - komunikacja przez tailnet (mesh VPN)
PEER_HOSTNAME = "__PEER_HOSTNAME__"
def get_peer_ip():
    result = subprocess.run(["tailscale", "status"], capture_output=True, text=True)
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) >= 2 and PEER_HOSTNAME in parts[1]:
            return parts[0]
    return None
def get_remote_time():
    peer_ip = get_peer_ip()
    if peer_ip:
        return get(f"http://{peer_ip}:8000/time", timeout=5).text.strip('"')
    return "peer not found"
```

Tailscale ACL definiują precyzyjnie, kto ma dostęp do czego:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["<tailscale-ip-vm-a>"],
      "dst": ["<tailscale-ip-vm-b>:8000"]
    },
    {
      "action": "accept",
      "src": ["<tailscale-ip-local>"],
      "dst": ["<tailscale-ip-vm-a>:22", "<tailscale-ip-vm-a>:8000"]
    }
  ]
}
```

Domyślna reguła `{"src": ["*"], "dst": ["*"]}` zostaje usunięta.

### 4.3 Podsumowanie różnic w kodzie Terraform

| Aspekt                | Unsecure                                    | Zero Trust                                      |
| --------------------- | ------------------------------------------- | ----------------------------------------------- |
| Publiczne IP          | Tak - `azurerm_public_ip` przypisany do NIC | Nie                                             |
| NSG reguły            | `AllowAllInbound` - wszystko dozwolone      | Brak reguł - domyślnie blokada                  |
| Komunikacja między VM | Przez publiczne IP (jawny, nieszyfrowany)   | Przez Tailscale (WireGuard, szyfrowany)         |
| Dostęp SSH            | Przez publiczne IP z dowolnego hosta        | Tylko przez tailnet z autoryzowanego urządzenia |

## 5. Porównanie wyników testów

### Unsecure

Skan `nmap -A` na publicznym IP VM-A (74.248.135.130) wykazał:

```sh
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
```

- Możliwość SSH z dowolnego hosta:
  ```sh
  ssh azureuser@74.248.135.130  # działa
  ```
- `curl` na port 8000 zwraca dane:
  ```json
  {
    "remote_time": "2026-05-12T02:04:46.456371",
    "local_time": "2026-05-11T19:04:46.588333"
  }
  ```

### Zero Trust

Skan z lokalnej maszyny (połączonej do tailnet) na maszyny w tailnecie:

- **nmap vm-a-zt** - host wydaje się **down** przy standardowym skanie:

  ```
  Note: Host seems down.
  ```

  Dopiero z dodatkową flagą `-Pn` (pomijanie ping) zwraca:

  ```sh
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
  ```

- **nmap -Pn -A vm-b-zt**:

```
All 1000 scanned ports on vm-b-zt (100.71.102.63) are in ignored states.
```

VM-B jest całkowicie niewidoczna dla skanowania - żaden port nie odpowiada.

- **curl do VM-B** - **nie działa** (zgodnie z oczekiwaniami, ponieważ ACL nie zezwala na ten ruch):

```
curl: (28) Failed to connect to vm-b-zt port 8000
```

- **SSH do VM-B** - **nie działa** (Connection timed out):

```
ssh: connect to host vm-b-zt port 22: Connection timed out
```

- **SSH do VM-A** - działa poprawnie

**Wniosek:** Infrastruktura Zero Trust skutecznie ukrywa wszystkie usługi przed światem zewnętrznym. VM-y są widoczne tylko dla autorizowanych urządzeń, a komunikacja możliwa jest wyłącznie przez szyfrowany mesh VPN Tailscale z precyzyjnymi regułami ACL. Nawet wewnątrz tailneta dostęp jest ograniczony - VM-B jest dostępna HTTP tylko z VM-A, a do VM-A SSH ma tylko lokalna maszyna. To realizacja zasady **least privilege**: każdy ma dostęp tylko do tego, co jest mu niezbędne.

## 6. Wnioski

Model Zero Trust znacząco podnosi poziom bezpieczeństwa w stosunku do architektury tradycyjnej:

1. **Redukcja powierzchni ataku** - brak publicznych IP eliminuje całą klasę ataków polegających na skanowaniu i exploicie publicznie dostępnych usług.
2. **Segmentacja** - nawet w przypadku kompromitacji jednej VM, dostęp do pozostałych jest ograniczony przez ACL Tailscale.
3. **Szyfrowanie** - cały ruch przechodzi przez szyfrowany tunel WireGuard, co uniemożliwia podsłuchiwanie.
4. **Kontrola dostępu** - reguły ACL precyzyjnie określają, kto i do czego ma dostęp, realizując zasadę najmniejszych uprawnień.

Kosztem jest dodatkowa złożoność konfiguracji (klucz autoryzacyjny Tailscale, konfiguracja ACL) oraz zależność od dodatkowego serwisu (Tailscale) do uwierzytelniania i zarządzania tożsamościami urządzeń.

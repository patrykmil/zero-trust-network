# BCHO projekt

## Opis

Dwa środowiska:

- unsecure
- zero trust

### Docelowe działanie:

- Serwer HTTP VM-B dostępny tylko z VM-A przez tailnet
- SSH do VM-A tylko z lokalnej maszyny przez tailnet
- Serwer HTTP VM-A dostępny tylko z lokalnej maszyny przez tailnet

### Unsecure

- VM-A, VM-B z publicznym IP
- otwarte NSG
- brak Tailscale

### Zero Trust

- prywatne subnety
- brak publicznych IP
- Tailscale

Tailscale ACL:

- Dozwolone:
  - VM-A → VM-A:8000 (http)
  - local → VM-A:22 (ssh)
  - local → VM-A:8000 (http)

- Zabronione:
  - inne porty
  - komunikacja bez Tailscale

## Testy

- nmap
- curl
- ssh

Wyniki w `results.md`

## Quickstart:

1. Pobranie:

- terraform
- azure-cli
- tailscale

2. Zalogowanie do azure-cli:

```sh
az login
```

3. Git clone repozytorium:

```sh
git clone git@github.com:patrykmil/zero-trust-network.git
```

```sh
git clone https://github.com/patrykmil/zero-trust-network.git
```

### Unsecure:

W katalogu `unsecure/`:

1. Zmiana nazwy pliku `public.terraform.tfvars` na `terraform.tfvars` i uzupełnienie admin_password:

```sh
mv public.terraform.tfvars terraform.tfvars
```

2. Inicjalizacja terraform:

```sh
terraform init
```

3. Utworzenie infrastruktury:

```sh
terraform apply --auto-approve
```

4. Po zakończeniu zapisz IP dla VM-A i VM-B.

5. Dostępne usługi na obu VM:

- HTTP (port 8000)
- SSH (port 22) - user `azureuser`

### Zero Trust:

W katalogu `zero-trust/`:

1. W admin panelu tailscale **Settings → Keys → Generate auth key**
   - **Reusable** ✔
   - **Ephemeral** ✘
   - **Tags** — opcjonalnie (np. `tag:azure`)

2. Zmiana nazwy pliku `public.terraform.tfvars` na `terraform.tfvars` i uzupełnienie admin_password, tailscale_auth_key:

```sh
mv public.terraform.tfvars terraform.tfvars
```

3. Dodaj lokalną maszynę do tailneta:

4. Inicjalizacja terraform:

```sh
terraform init
```

5. Utworzenie infrastruktury:

```sh
terraform apply --auto-approve
```

6. Konfiguracja ACL w Tailscale Admin Console:

Wejście w **https://login.tailscale.com/admin/acls** → Edytuj plik ACL.

Dodać reguły (podmieniając IP):

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

Usunąć

```json
{
  {"src": ["*"], "dst": ["*"], "ip": ["*"]}
}
```

## Wyczyszczenie

1. Usunięcie infrastruktury:

```sh
terraform destroy --auto-approve
```

2. Usunięcie urządzeń z tailneta (Settings → Keys → Revoke).

3. Usunięcie maszyn z tailneta.

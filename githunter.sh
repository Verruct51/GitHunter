#!/bin/bash

# GitHunter by Ver-Ruct

# ASCII Art
clear
echo -e "\e[1;32m"
cat << "EOF"
/* __| |____________________________________________________________________________| |__ */
/* __   ____________________________________________________________________________   __ */
/*   | |                                                                            | |   */
/*   | |   ██████╗ ██╗████████╗██╗  ██╗██╗   ██╗███╗   ██╗████████╗███████╗██████╗  | |   */
/*   | |  ██╔════╝ ██║╚══██╔══╝██║  ██║██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗ | |   */
/*   | |  ██║  ███╗██║   ██║   ███████║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝ | |   */
/*   | |  ██║   ██║██║   ██║   ██╔══██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗ | |   */
/*   | |  ╚██████╔╝██║   ██║   ██║  ██║╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║ | |   */
/*   | |   ╚═════╝ ╚═╝   ╚═╝   ╚═╝  ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝     | |   */
/* __| |____________________________________________________________________________| |__ */
/* __   ____________________________________________________________________________   __ */
/*   | |                                             by: Alvin Anugerah (V€r-ṜuCT)  | |   */
EOF
echo ""
echo ""
echo -e "\e[1;33m                               Let's Find .Git Disclosure (^_^)\e[0m"
echo ""

# Input
read -p $'\e[1;34m[?] Masukkan Domain Target <domain.com> : \e[0m' DOMAIN
read -p $'\e[1;34m[?] Perulangan (Enter = 0) : \e[0m' LOOP
read -p $'\e[1;34m[?] Timeout    (Enter = 3) : \e[0m' TIMEOUT

# Defaults
LOOP=${LOOP:-0}
TIMEOUT=${TIMEOUT:-3}

# Output files
SUBDOMAINS_FILE="${DOMAIN}-Subdomain.txt"
EXPOSURE_FILE="${DOMAIN}-ListGit.txt"
EXPOSURE_CLEAN="/tmp/.githunter_exposure_clean.txt"
FOUND_FILE="${DOMAIN}-VULN.txt"

# Subdomain gathering
echo "[*] Mencari Subdomain untuk $DOMAIN dari crt.sh..."
SUBDOMAINS=$(curl -s "https://crt.sh/?q=%25${DOMAIN}&output=json" | jq -r '.[].name_value' 2>/dev/null | sort -u)

if [ -z "$SUBDOMAINS" ]; then
    echo -e "\e[1;31m[!] Tidak ada subdomain ditemukan di crt.sh. Beralih ke Subfinder...\e[0m"
    SUBDOMAINS=$(subfinder -d "$DOMAIN" -silent | sort -u)
    if [ -z "$SUBDOMAINS" ]; then
        echo -e "\e[1;31m[!] Subdomain tetap tidak ditemukan. Exit.\e[0m"
        exit 1
    fi
fi

echo -e "\e[1;32m[+] Total subdomains : $(echo "$SUBDOMAINS" | wc -l)\e[0m"
echo "$SUBDOMAINS" > "$SUBDOMAINS_FILE"

# Prepare output files
> "$EXPOSURE_FILE"
> "$EXPOSURE_CLEAN"
> "$FOUND_FILE"

# Scan loop
COUNT=0
while [ "$COUNT" -le "$LOOP" ]; do
    echo "[*] Iteration: $((COUNT+1))/$((LOOP+1))"
    echo "$SUBDOMAINS" | sed 's#$#/.git/HEAD#' | \
        httpx -silent -content-length -status-code \
        -status-code 200,301,302 -timeout "$TIMEOUT" -retries 0 \
        -ports 80,8000,443 -threads 500 | tee -a "$EXPOSURE_FILE" | \
        sed 's/\x1b\[[0-9;]*m//g' >> "$EXPOSURE_CLEAN"
    COUNT=$((COUNT + 1))
done

# Filter to FOUND
awk '$2 == "[200]" && $3 ~ /^\[[0-9]+\]$/ {
    cl = gensub(/\[|\]/, "", "g", $3);
    if (cl+0 >= 10 && cl+0 <= 99) {
        # ANSI: 32 = hijau, 35 = ungu
        gsub(/\[200\]/, "[\033[1;32m200\033[0m]", $0);     # 200 hijau
        gsub(/\['cl'\]/, "[\033[1;35m" cl "\033[0m]", $0); # content-length ungu
        gsub(/\[[0-9]+\]$/, "[\033[1;35m" cl "\033[0m]", $0);
        print $0;
    }
}' "$EXPOSURE_CLEAN" >> "$FOUND_FILE"

# Final report
echo -e "\n\e[1;32m[✓] Scan complete. Hasil tersimpan di:\e[0m"
echo " - List Subdomain   : $SUBDOMAINS_FILE"
echo " - List .Git        : $EXPOSURE_FILE"
echo " - VULNERABLE       : $FOUND_FILE"
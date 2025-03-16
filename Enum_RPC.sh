#!/bin/bash

# === Configuration ===
echo -n "Entrez votre nom d'utilisateur : "
read -r USER
echo -n "Entrez votre mot de passe : "
read -r PASSWORD
echo ""

echo -n "Entrez l'adresse IP du serveur : "
read -r SERVER_IP

RID_FILE='rid_users.txt'
USER_LIST_FILE='list_dom_users.txt'

# Vérifier la connexion RPC
echo "[*] Vérification de la connexion à $SERVER_IP..."
rpcclient --user="$USER%$PASSWORD" "$SERVER_IP" -c 'exit' &>/dev/null
if [ $? -ne 0 ]; then
    echo "[!] Échec de connexion à $SERVER_IP avec l'utilisateur $USER. Vérifiez les identifiants et l'accès."
    exit 1
fi

echo "[+] Connexion réussie à $SERVER_IP"

# Étape 1 : Récupérer la liste des groupes et leur RID
echo "[*] Récupération des groupes..."
rpcclient --user="$USER%$PASSWORD" "$SERVER_IP" -c 'enumdomgroups' > groups_list.txt

if [ ! -s groups_list.txt ]; then
    echo "[!] Impossible de récupérer les groupes. Vérifiez les permissions de l'utilisateur."
    exit 1
fi

cat groups_list.txt
echo "[*] Sélectionnez un groupe parmi la liste ci-dessus (entrez le RID) : "
read -r GROUP_RID

if [ -z "$GROUP_RID" ]; then
    echo "[!] Aucun groupe sélectionné."
    exit 1
fi

echo "[+] Groupe sélectionné avec RID: $GROUP_RID"

# Étape 2 : Extraire les RIDs des utilisateurs du groupe
echo "[*] Récupération des utilisateurs du groupe..."
rpcclient --user="$USER%$PASSWORD" "$SERVER_IP" -c "querygroupmem $GROUP_RID" | awk -F'[][]' '{print $2}' > "$RID_FILE"

echo "[+] RIDs des utilisateurs enregistrés dans $RID_FILE"

# Vérifier si le fichier contient des RIDs
if [ ! -s "$RID_FILE" ]; then
    echo "[!] Aucun utilisateur trouvé dans ce groupe."
    exit 1
fi

# Étape 3 : Récupération des noms d'utilisateurs
echo "[*] Récupération des noms d'utilisateurs..."
> "$USER_LIST_FILE"  # Réinitialisation du fichier de sortie

while IFS= read -r RID; do
    if [ -n "$RID" ]; then
        USERNAME=$(rpcclient --user="$USER%$PASSWORD" "$SERVER_IP" -c "queryuser $RID" | grep "User Name" | awk -F'[:[:space:]]+' '{print $4}')
        if [ -n "$USERNAME" ]; then
            echo "$USERNAME" >> "$USER_LIST_FILE"
        fi
    fi
done < "$RID_FILE"

echo "[+] Liste des utilisateurs enregistrée dans $USER_LIST_FILE"

# Affichage du résultat
echo "=== Utilisateurs trouvés ==="
cat "$USER_LIST_FILE"

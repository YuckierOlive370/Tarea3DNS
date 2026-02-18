#!/bin/bash

INTERFAZ="ens37"
MASCARA="255.255.255.0"

ValidarIp() { # valida formato y descarta 255.255.255.255 y 0.0.0.0
    local ip=$1
    if [[ $ip =~ ^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$ ]]; then
        [[ "$ip" != "255.255.255.255" && "$ip" != "0.0.0.0" && "$ip" != "127.0.0.1" ]]
        return $?
    fi
    return 1
}

IPaInt() {
    local IFS=.
    read -r a b c d <<< "$1"
    echo $(( (a<<24) + (b<<16) + (c<<8) + d ))
}

PedirIp() {
    local mensaje=$1
    while true; do
        read -p "$mensaje" ip
        if ValidarIp "$ip"; then
            echo "$ip"
            return
        else
            echo "IP no valida, intenta de nuevo"
        fi
    done
}

CalcularMascara() {
    local ip=$1
    local IFS=.
    read -r a b c d <<< "$ip"

    if (( a >= 1 && a <= 126 )); then
        echo "255.0.0.0"
    elif (( a >= 128 && a <= 191 )); then
        echo "255.255.0.0"
    elif (( a >= 192 && a <= 223 )); then
        echo "255.255.255.0"
    else
        echo "255.255.255.0"
    fi
}

MaskToPrefix() {
    case "$1" in
        255.0.0.0) echo 8 ;;
        255.255.0.0) echo 16 ;;
        255.255.255.0) echo 24 ;;
        255.255.255.128) echo 25 ;;
        255.255.255.192) echo 26 ;;
        255.255.255.224) echo 27 ;;
        255.255.255.240) echo 28 ;;
        255.255.255.248) echo 29 ;;
        255.255.255.252) echo 30 ;;
        255.255.255.254) echo 31 ;;
        255.255.255.255) echo 32 ;;
        *) echo 0 ;;
    esac
}

VerificarServicio() {
    if dpkg -l | grep -q bind9; then
        echo "DNS ya está instalado"
        read -p "¿Deseas reinstalarlo? (S/N): " r
        if [[ $r =~ ^[sS]$ ]]; then
            apt purge bind9 -y
            apt install bind9 dnsutils -y
        fi
    else
        echo "El servicio DNS no está instalado"
    fi
}

CalcularRedInversa() {
    local ip=$1
    local IFS=.
    read -r a b c d <<< "$ip"
    echo "$c.$b.$a"
}

PedirValor() {
    local mensaje=$1
    local defecto=$2
    local valor

    read -p "$mensaje [$defecto]: " valor
    echo "${valor:-$defecto}"
}

ValidarDominio() {
    local dominio=$1
    # Regex: letras, números, guiones, puntos; debe terminar en TLD válido (2-63 caracteres)
    if [[ $dominio =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,63}$ ]]; then
        return 0  # válido
    else
        return 1  # inválido
    fi
}

ConfigurarOpcionesBind() {
    echo "Configurando named.conf.options..."

    cat <<EOF > /etc/bind/named.conf.options
options {
    directory "/var/cache/bind";

    listen-on { any; };
    listen-on-v6 { any; };

    allow-query { any; };

    recursion yes;
    dnssec-validation auto;
};
EOF
}

Instalar() {
    if dpkg -l | grep -q bind9; then
        echo "DNS ya esta instalado si quieres volver a instalarlo vee a Verificar servicio..."
        return 1
    fi
    apt update
    apt install bind9 dnsutils -y
    systemctl enable bind9
}

Configurar() {
    echo "===== CONFIGURACIÓN DE DNS ====="

    # Datos principales

    DOMINIO=""
    until ValidarDominio "$DOMINIO"; do
        read -p "Introduce el dominio (ej: ejemplo.com): " DOMINIO
        if ! ValidarDominio "$DOMINIO"; then
            echo "Dominio inválido, intenta de nuevo."
        fi
    done

    echo "Dominio válido: $DOMINIO"

    if grep -q "zone \"$DOMINIO\"" /etc/bind/named.conf.local; then
    echo "La zona $DOMINIO ya existe"
    return
    fi

    if grep -q "static" /etc/network/interfaces.d/$INTERFAZ.cfg 2>/dev/null; then

    echo "Se asigno la IP fija"
    IP_DNS=$(grep -A 2 "iface $INTERFAZ inet static" /etc/network/interfaces.d/$INTERFAZ.cfg 2>/dev/null | grep "address" | awk '{print $2}')

    else

    echo "Asignaras la IP fija"
    IP_DNS=$(PedirIp "IP del servidor DNS: ")
    fi
    mascara=$(CalcularMascara "$IP_DNS")
    MASCARA="$mascara"

    echo "IP fija del servidor: $IP_DNS"

    rango_inicio=$(printf "%d.%d.%d.%d" \
        $(( (inicioInt >> 24) & 255 )) \
        $(( (inicioInt >> 16) & 255 )) \
        $(( (inicioInt >> 8) & 255 )) \
        $(( inicioInt & 255 ))
    )

    sudo bash -c "cat > /etc/network/interfaces.d/$INTERFAZ.cfg" <<EOF
auto $INTERFAZ
iface $INTERFAZ inet static
    address $IP_DNS
    netmask $mascara
EOF

    echo "Configuración de red escrita en /etc/network/interfaces.d/$INTERFAZ.cfg"
    echo "Recargando interfaz..."
    sudo ip addr flush dev $INTERFAZ
    prefix=$(MaskToPrefix "$mascara")
    sudo ip addr add $IP_DNS/$prefix dev $INTERFAZ
    sudo ip link set $INTERFAZ up
    RED_INV=$(CalcularRedInversa "$IP_DNS")

    ConfigurarOpcionesBind

    ZONA_DIR="/etc/bind/db.$DOMINIO"
    ZONA_INV="/etc/bind/db.$RED_INV"

    # Serial automático
    SERIAL=$(date +%Y%m%d01)

    # Valores SOA configurables
    REFRESH=$(PedirValor "Refresh (segundos)" 604800)
    RETRY=$(PedirValor "Retry (segundos)" 86400)
    EXPIRE=$(PedirValor "Expire (segundos)" 2419200)
    NEGTTL=$(PedirValor "Negative Cache TTL (segundos)" 604800)

    # Registrar zonas en BIND
    cat <<EOF >> /etc/bind/named.conf.local
zone "$DOMINIO" {
    type master;
    file "$ZONA_DIR";
};

zone "$RED_INV.in-addr.arpa" {
    type master;
    file "$ZONA_INV";
};
EOF

    # Crear zona directa
    cat <<EOF > $ZONA_DIR
\$TTL 604800
@ IN SOA ns1.$DOMINIO. admin.$DOMINIO. (
    $SERIAL     ; Serial
    $REFRESH    ; Refresh
    $RETRY      ; Retry
    $EXPIRE     ; Expire
    $NEGTTL )   ; Negative Cache TTL

@   IN NS ns1.$DOMINIO.
@   IN A  $IP_DNS
ns1 IN A  $IP_DNS
www IN A  $IP_DNS
EOF

    # Zona inversa
    ULTIMO_OCTETO=${IP_DNS##*.}

    cat <<EOF > $ZONA_INV
\$TTL 604800
@ IN SOA ns1.$DOMINIO. admin.$DOMINIO. (
    $SERIAL
    $REFRESH
    $RETRY
    $EXPIRE
    $NEGTTL )

@ IN NS ns1.$DOMINIO.
$ULTIMO_OCTETO IN PTR $DOMINIO.
EOF

    # Validaciones
    named-checkconf || return
    named-checkzone $DOMINIO $ZONA_DIR || return
    named-checkzone $RED_INV.in-addr.arpa $ZONA_INV || return

    # Reinicio del servicio
    systemctl restart bind9

    echo "DNS configurado correctamente para $DOMINIO"
}

Reconfigurar() {
    echo "===== RECONFIGURANDO DNS ====="

    # Verificar sintaxis global
    if ! named-checkconf; then
        echo "Error en la configuración global de BIND"
        return 1
    fi

    # Verificar todas las zonas registradas
    while read -r zona; do
        archivo=$(grep -A2 "zone \"$zona\"" /etc/bind/named.conf.local | awk -F\" '/file/ {print $2}')
        if [[ -f $archivo ]]; then
            named-checkzone "$zona" "$archivo" || return 1
        fi
    done < <(grep 'zone "' /etc/bind/named.conf.local | awk -F\" '{print $2}')

    # Recargar servicio
    systemctl reload bind9

    if systemctl is-active --quiet bind9; then
        echo "DNS recargado correctamente"
    else
        echo "No se pudo recargar, intentando reiniciar..."
        systemctl restart bind9
    fi
}

Monitoreo() {
    echo "++++++++ Monitoreo del servidor DNS ++++++++"

    if dpkg -l | grep -q bind9; then
        estado=$(systemctl is-active bind9)
        if [[ "$estado" == "active" ]]; then
            echo "El servidor DNS está activo"
        else
            echo "El servidor DNS no está activo"
            return
        fi
    else
        echo "Bind9 no está instalado"
        return
    fi

    echo ""
    echo "Zonas configuradas:"
    if [[ -f /etc/bind/named.conf.local ]]; then
        grep "zone" /etc/bind/named.conf.local | awk '{print $2}' | tr -d '"' || echo "No hay zonas configuradas"
    else
        echo "No se encontró el archivo de configuración de zonas"
    fi

    echo ""
    # Mostrar registros de cada zona
    for zona in $(grep "zone" /etc/bind/named.conf.local | awk '{print $2}' | tr -d '"'); do
        archivo=$(grep -A 2 "zone \"$zona\"" /etc/bind/named.conf.local | grep "file" | awk '{print $2}' | tr -d '";')
        if [[ -f "$archivo" ]]; then
            echo "Registros en la zona $zona:"
            grep -E "IN" "$archivo" | awk '{print $1, $3, $4, $5}'
        else
            echo "No se encontró archivo de zona para $zona"
        fi
        echo ""
    done
}

ABCdominios() {
    echo "===== ABC DE DOMINIOS DNS ====="
    echo "1) Alta (crear dominio)"
    echo "2) Baja (eliminar dominio)"
    echo "3) Consulta (listar dominios)"
    echo "4) Volver"
    read -p "Selecciona una opción: " op

    case $op in
        1)
            echo "Alta de dominio"
            Configurar
            ;;

        2)
            echo "Baja de dominio"

            DOMINIO=""
        until ValidarDominio "$DOM"; do
            read -p "Introduce el dominio (ej: ejemplo.com): " DOM
            if ! ValidarDominio "$DOM"; then
                echo "Dominio inválido, intenta de nuevo."
            fi
        done

            # Obtener archivo de zona directa
            ZONA_DIR=$(grep -A2 "zone \"$DOM\"" /etc/bind/named.conf.local | awk -F\" '/file/ {print $2}')

            if [[ -z $ZONA_DIR ]]; then
                echo "El dominio no existe"
                return
            fi

            # Calcular red inversa desde la IP A
            IP_DNS=$(grep "IN A" "$ZONA_DIR" | awk '{print $NF}' | head -n1)
            RED_INV=$(CalcularRedInversa "$IP_DNS")
            ZONA_INV="/etc/bind/db.$RED_INV"

            # Eliminar zonas del archivo de configuración
            sed -i "/zone \"$DOM\"/,/};/d" /etc/bind/named.conf.local
            sed -i "/zone \"$RED_INV.in-addr.arpa\"/,/};/d" /etc/bind/named.conf.local

            # Eliminar archivos de zona
            rm -f "$ZONA_DIR" "$ZONA_INV"

            # Recargar DNS
            systemctl reload bind9

            echo "Dominio $DOM eliminado correctamente"
            ;;

        3)
            echo "Dominios configurados:"
            grep 'zone "' /etc/bind/named.conf.local | awk -F\" '{print $2}'
            ;;

        4)
            return
            ;;

        *)
            echo "Opción inválida"
            ;;
    esac
}

while true; do
    echo "===== Automatización y Gestión de DNS ====="
    echo "1.- Verificar Instalacion"
    echo "2.- Instalar"
    echo "3.- Configurar"
    echo "4.- Reconfigurar"
    echo "5.- ABC Dominios"
    echo "6.- Monitoreo"
    echo "7.- Salir"
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1) VerificarServicio ;;
        2) Instalar ;;
        3) Configurar ;;
        4) Reconfigurar ;;
        5) ABCdominios ;;
        6) Monitoreo ;;
        7) echo "Saliendo..."; break ;;
        *) echo "Opción inválida" ;;
    esac
    echo ""
done
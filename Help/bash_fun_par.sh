#!/bin/bash

validateEmpty() {
   local regex='\S+'
  if ! [[ "$1" =~ $regex ]]; then
    echo "Se ha detectado un espacio vacio, saliendo del programa (variable $2)"
    exit 1
  fi  
}

validateInt() {
  local regex='^[0-9]+$'
  if ! [[ $1 =~ $regex ]]; then
    echo "No se ha detectado un numero entero sin signos, saliendo del programa (variable $2)" 
    exit 1
  fi    
}

validateIp() {
  local regex='^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$'
  if ! [[ "$1" =~ $regex ]]; then
    echo "No se ha detectado el formato IPv4, saliendo del programa (variable: $2)"
    exit 1
  fi
}

validateIpConf() {
  local regex='^(((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))\.){3}((10[0-9])|(1?[1-9]?[0-9])|(2[0-4][0-9])|(25[0-5]))$'
  if ! [[ "$1" =~ $regex ]]; then
    echo "false"
  fi
}

banIp() {
  IFS='.' read -ra octet <<< "$1"

	if [ ${octet[0]} -eq 0 ]; then
		echo -e "\nEl primero octeto no puede ser 0, saliendo del programa..."
		exit 1
	elif [ ${octet[0]} -eq 127 ]; then
		echo -e "\nEl primero octeto no puede ser 127, saliendo del programa..."
		exit 1
	elif [ ${octet[0]} -eq 255 ]; then
		echo -e "\nEl primer octeto no puede ser 255, saliendo del programa"
		exit 1
	fi 
}

usableIp() {
	if [ "$3" = "true" ] && [ "$1" = "" ]; then
		return 1
	fi
  validateIp "$1" "$2"
  banIp $1
}

getSegment() {
  IFS='.' read -ra octet <<< "$1"

	if [ ${octet[0]} -ge 1 ] && [ ${octet[0]} -le 126 ]; then
		echo "${octet[0]}.0.0.0"
	elif [ ${octet[0]} -ge 128 ] && [ ${octet[0]} -le 191 ]; then
		echo "${octet[0]}.${octet[1]}.0.0"
	elif [ ${octet[0]} -ge 192 ] && [ ${octet[0]} -le 223 ]; then
		echo "${octet[0]}.${octet[1]}.${octet[2]}.0"
	else
		echo "0.0.0.0"
	fi
}

getNetmask() {
	 IFS='.' read -ra octet <<< "$1"

	if [ ${octet[0]} -ge 1 ] && [ ${octet[0]} -le 126 ]; then
	  echo "255.0.0.0"
	elif [ ${octet[0]} -ge 128 ] && [ ${octet[0]} -le 191 ]; then
		echo "255.255.0.0"
	elif [ ${octet[0]} -ge 192 ] && [ ${octet[0]} -le 223 ]; then
		echo "255.255.255.0"
	else
		echo "255.255.255.255"
	fi
}

getIpValue() {
  IFS='.' read -ra octet <<< "$1"
	echo $((${octet[0]}*256*256*256 + ${octet[1]}*256*256 + ${octet[2]}*256 + ${octet[3]}))
}

compareIp() {
	if [ $1 -gt $2 ]; then
		echo "true"
	else
		echo "false"
	fi
}

getLocalIp() {
  echo $(ip a show red_sistemas | awk '/inet / {print $2}' | cut -d "/" -f1)
}

getPrefix() {
  echo $(ip a show red_sistemas | awk '/inet / {print $2}' | cut -d "/" -f2)
}

sumOne() {
  IFS='.' read -ra octet <<< "$1"

  octet[3]=$((octet[3]+1))

	if [ ${octet[3]} -ge 256 ]; then
		octet[3]=0
		octet[2]=$((${octet[2]} + 1))
	fi

	if [ ${octet[2]} -ge 256 ]; then
		octet[2]=0
		octet[1]=$((${octet[1]} + 1))
	fi	

	if [ ${octet[1]} -ge 256 ]; then
		octet[1]=0
		octet[0]=$((${octet[0]} + 1))
	fi	

	echo "${octet[0]}.${octet[1]}.${octet[2]}.${octet[3]}"		
}

check_service() {
	if [ "$(dpkg -l $1 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio $1"
	else
		echo -e "\nSe ha detectado el servicio $1"
	fi
}

restart_ip() {

content=""
remplace=""
found=""

while read line; do
	if [ "$found" = "true" ]; then
		content="${content}address $1\n"
		reemplace="true"
		while read line; do  # Mientras no se detecte otra configuracion entonces seguira leyendo lineas
			if [[ "$line" =~ ^[[:space:]]*(auto|iface|allow|source|\#) ]]; then
				echo "se ha leido la linea: $line"
				echo "se ha detectado nueva configuracion por lo tanto salgo del ciclo"
				break
			fi
    done
	fi

	content="$content$line\n"
	regex='[[:space:]]*iface[[:space:]]*red_sistemas[[:space:]]*'
	
	if [[ "$line" =~ $regex ]]; then
		found="true"
	else
		found="false"
	fi
done < /etc/network/interfaces

	if [ "$reemplace" = "true" ]; then
		echo -e $content > /etc/network/interfaces
	else
		content=""
		content="${content}auto red_sistemas\n"
		content="${content}iface red_sistemas inet static\n"
		content="${content}address $1\n"

		echo -e $content >> /etc/network/interfaces
	fi


  systemctl restart networking ## cambiar para no mostrar error 
}

install_service() {
	if [ "$(dpkg -l $1 2>&1 | grep 'ii')" = "" ]; then
		echo "No se ha detectado el servicio $1"

		if [ "$2" = "1" ]; then
			echo "Iniciando instalacion"
			apt-get install -y "$1" > /dev/null
			echo "Se ha terminado de instalar el servicio $1"
		elif [ "$2" = "0" ]; then
			echo "Para instalar el servicio haz uso de la bandera -i"
		else
			echo "Se ha detectado una opc. invalida"		
		fi
	else
		echo "Se ha detectado el servicio $1"
	fi	
}

restart_service() {
	if [ "$(dpkg -l $1 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio $1"
	else
		echo "Reiniciando servicio..."
		systemctl restart "$1"
	fi
}

verificar_root() {
if [ "$EUID" -ne 0 ]; then 
	echo "Please run as root"
  exit
fi
}

validateEmptyArray() {
  local array=("$@")
  local i=0
  local count=${#array[@]}

  while [ $i -lt $count ]; do
    if [ -z "${array[$i]}" ]; then
      echo "Se ha detectado un valor vacio en el vector"
      exit 1
    fi
    ((i++))
  done  
}

validateGroupNumber() {
  local array=("$@")
  local i=0
  local count=${#array[@]}

  while [ $i -lt $count ]; do
    if [ "${array[$i]}" != "1" ] && [ "${array[$i]}" != "2" ]; then
      echo "Se ha detectado que el grupo no se identifico con 1 ni con 2"
      exit 1
    fi
    ((i++))
  done  
}

validateUserExists() {
  local array=("$@")
  local i=0
  local count=${#array[@]}

  while [ $i -lt $count ]; do
    if [ -n "$(cat /etc/passwd | grep "${array[$i]}")" ]; then
      echo "Se ha detectado que uno de los usuarios ya existe"
      exit 1
    fi
    ((i++))
  done  
}

status_service_systemctl() { # VERIFICAR SI EL SERVICIO ESTA INSTALADO ANTES
	if [ "$(systemctl status $1 2>&1 | grep 'could not be found')" = "" ]; then
	  echo -e "\n=== Estado del servicio ===\n"
	  systemctl status $1 | head -n 12	
	else
		echo -e "\nNo se ha detectado el servicio $1"
    exit 1
	fi
}

uninstall_service() {
	if [ "$(dpkg -l $1 2>&1 | grep 'ii')" = "" ]; then
		echo "No se ha detectado el servicio $1"
	else
		echo "Se ha detectado el servicio $1"

		if [ "$2" = "1" ]; then
			echo "Empezando desinstalacion"
			apt-get remove -y --purge "$1" > /dev/null
			echo "Se ha terminado de desinstalar el servicio $1"
		elif [ "$2" = "0" ]; then
			echo "Para desinstalar el servicio haz uso de la bandera -c"
		else
			echo "Se ha detectado una opc. invalida"		
		fi
	fi	
}


#if [ "${1}" != "--source-only" ]; then
#  ip="150.255.255.255"
#  segment=$(getSegment "$ip")
#  netmask=$(getNetmask "$ip")
#  ip_val=$(getIpValue "$ip")
#  ip2=$(sumOne $ip)

#  echo "Tu segmento es $segment"
#  echo "Tu mascara es $netmask"
#  echo "Tu valor es $ip_val"
#  echo "Tu ip+1 es $ip2"
#fi
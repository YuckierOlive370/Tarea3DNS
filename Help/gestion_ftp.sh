#!/bin/bash

source ../Funciones/bash_fun_par.sh # Funcion parametros

verificar_root

help="--- Opciones ---\n\n"
help="${help}1) Verificar existencia del servicio FTP\n"
help="${help}2) Instalar servicio FTP\n"
help="${help}3) Crear carpetas iniciales\n"
help="${help}4) Desinstalar servicio FTP\n"
help="${help}5) Estatus servicio FTP\n"
help="${help}6) Seleccionar usuario para colocarlo en un grupo\n\n"
help="${help}--- ABC Usuarios ---\n\n"
help="${help}7) Agregar usuario\n"
help="${help}8) Eliminar usuario\n"
help="${help}9) Consultar usuario\n\n"
help="${help}--- ABC Grupos ---\n\n"
help="${help}10) Agregar grupo\n"
help="${help}11) Eliminar grupo\n"
help="${help}12) Consultar grupos existentes\n\n"
help="${help}--- Banderas ---\n\n"
help="${help}-h (mostrar este mensaje)\n"
help="${help}-o (seleccionar opcion)\n"
help="${help}-c (confirmar desinstalacion)\n"
help="${help}-i (confirmar instalacion)\n"
help="${help}-n (numero de usuarios a registrar)\n"
help="${help}-u (lista de usuarios separados por una coma)\n"
help="${help}-p (lista de contraseñas separadas por una coma)\n"
help="${help}-g (grupo al que pertenece separado por comas)\n"

base="/home"
routeftp="$base/ftp"
localuser="$routeftp/LocalUser"
option=0
install="0"
confirm="0"

no_users=""
names=""
passwords=""
groups=""

# OBTENER PARAMETROS
while getopts ":h :i :o: :n: :u: :p: :g: :c" flag; do
    case "${flag}" in
        h) 
          echo -e $help 
          exit 1
        ;; 
        o) option=$OPTARG ;;
        i) install="1" ;; 
        n) no_users=$OPTARG ;;    # FUNCION PARA VALIDAR DOMINIO
        u) names=$OPTARG ;;
        p) passwords=$OPTARG ;;
        g) groups=$OPTARG ;; 
        c) confirm="1" ;;
    esac
done

# FALTA COLOCAR WRITEABLE CHROOT ALGO ASI
configure_options() {
	if [ "$(dpkg -l "vsftpd" 2>&1 | grep 'ii')" = "" ]; then
		echo -e "\nNo se ha detectado el servicio $1"
    exit 1
	fi

  # MODIFICAR ARCHIVO VSFTPD.CONF
  if [ -f /etc/vsftpd.conf ]; then
    sed -ir 's/anonymous_enable=NO/anonymous_enable=YES/' /etc/vsftpd.conf
    sed -ir 's/#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
    sed -ir 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf

    if [ -z "$(cat /etc/vsftpd.conf | grep "user_sub_token=\$USER")" ]; then 
      echo -e "user_sub_token=\$USER" >> /etc/vsftpd.conf # baseectorio defecto para no-anonymous
    fi

    if [ -z "$(cat /etc/vsftpd.conf | grep "local_root=$base")" ]; then 
      echo -e "local_root=$localuser/\$USER" >> /etc/vsftpd.conf # baseectorio defecto para no-anonymous
    fi

    if [ -z "$(cat /etc/vsftpd.conf | grep "anon_root=$base")" ]; then 
      echo -e "anon_root=$localuser/public" >> /etc/vsftpd.conf # baseectorio defecto para anonymous
    fi

    if [ -z "$(cat /etc/vsftpd.conf | grep "local_umask=002")" ]; then 
      echo -e "local_umask=002" >> /etc/vsftpd.conf # baseectorio defecto para anonymous
    fi


  else
    echo "No se ha encontrado el archivo de configuracion /etc/vsftpd.conf"
  fi

  # Crear grupos
  #if [ -n "$(groupadd recursadores 2>&1 | grep 'already')" ]; then
  #  echo "Se ha detectado que el grupo recursadores ya ha sido creado"
  #fi

  #if [ -n "$(groupadd reprobados 2>&1 | grep 'already')" ]; then
  #  echo "Se ha detectado que el grupo reprobados ya ha sido creado"
  #fi

  if [ -d $base ]; then
    chmod 755 "$base" 
    chown "root:root" "$base"

    if ! [ -d $routeftp ]; then # CREACION /home/ftp
      mkdir $routeftp
      echo "Se ha creado el directorio /home/ftp"
    fi

    chmod 755 "$routeftp" 
    chown "root:root" "$routeftp"

    if ! [ -d $localuser ]; then # CREACION /home/ftp/localuser
      mkdir $localuser
      echo "Se ha creado el directorio $localuser"
    fi

    chmod 755 "$localuser" 
    chown "root:root" "$localuser"

    if ! [ -d "$routeftp/public" ]; then # CREACION /home/ftp/public carpeta general
      mkdir "$routeftp/public"
      echo "Se ha creado el directorio $localuser"
    fi

    chmod 2775 "$routeftp/public"
    chmod g+s "$routeftp/public"
    chown "root:users" "$routeftp/public"  
    
    if ! [ -d "$localuser/public" ]; then # CREACION /home/ftp/localuser/public usada por anonimo
      mkdir "$localuser/public"
      echo "Se ha creado el directorio $localuser"
    fi

    chmod 775 "$localuser/public"
    chmod g+s "$localuser/public"
    chown "root:root" "$localuser/public"

    local carpeta_anonymous_public="$localuser/public/public"

    if ! [ -d "$carpeta_anonymous_public" ]; then # CREACION /home/ftp/localuser/public usada por anonimo
      mkdir "$carpeta_anonymous_public" 
      echo "Se ha creado el directorio $carpeta_anonymous_public"
    fi

    chmod 775 "$carpeta_anonymous_public"
    chown "root:root" "$localuser/public"

    mount --bind "$carpeta_anonymous_public" "$routeftp/public" 
     
    # if ! [ -d "$base/public" ]; then 
    #   mkbase "$base/public"
    # fi

    # chown "root:users" "$base/public"
    # chmod 775 "$base/public"  # Permisos para la carpeta public
    # chmod g+s "$base/public"

    # if ! [ -d "$base/reprobados" ]; then 
    #   mkbase "$base/reprobados"
    # fi

    # chown "root:reprobados" "$base/reprobados"
    # chmod 770 "$base/reprobados"
    # chmod g+s "$base/reprobados"

    # if ! [ -d "$base/recursadores" ]; then 
    #   mkbase "$base/recursadores"
    # fi    

    # chown "root:recursadores" "$base/recursadores"
    # chmod 770 "$base/recursadores"
    # chmod g+s "$base/recursadores"
  else
    echo "No se ha encontrado el directorio $base, abortando..."
    exit 1
  fi

  restart_service "vsftpd"
}

change_groups() {
    # Suponiendo que $names y $groups vienen de tus flags -u y -g
    validateEmpty "$names"
    validateEmpty "$groups"

    local sufijo="$1"

    # 1. Verificar existencia del grupo destino (exacta)
    # Usamos ^ y : para que no coincida "reprobados" con "reprobadosAlumno" por error
    local found=$(getent group | grep "^$groups""Alumno:")
    
    if [ -z "$found" ]; then
        echo "Error: El grupo '$groups' no existe."
        exit 1
    fi

    # 2. Verificar si el usuario ya está en ese grupo
    if groups "$names" | grep -q "\b$groups\b"; then
        echo "El usuario $names ya es miembro de $groups."
        exit 1
    fi

    echo "Cambiando a $names al grupo $groups..."

    # 3. Limpiar pertenencia a otros grupos "Alumno" y sus montajes
    # Buscamos en qué grupos de tipo Alumno está el usuario actualmente
    local grupos_anteriores=$(getent group | grep "$sufijo" | grep "$names" | cut -d: -f1)

    for g_ant in $grupos_anteriores; do
        echo "Removiendo de grupo anterior: $g_ant"
        gpasswd -d "$names" "$g_ant" 2>/dev/null
        
        # Desmontar y limpiar carpeta del grupo anterior
        local punto_ant="$localuser/$names/${g_ant%$sufijo}"
        if mountpoint -q "$punto_ant"; then
            umount -lf "$punto_ant"
        fi
        [ -d "$punto_ant" ] && rmdir "$punto_ant"
    done

    # 4. Asignar el nuevo grupo
    usermod -aG "${groups}Alumno" "$names"

    # 5. Configurar la nueva carpeta y el nuevo montaje
    local nuevo_punto="$localuser/$names/$groups"
    local carpeta_real_grupo="/home/ftp/${groups}Alumno"

    mkdir -p "$nuevo_punto"
    
    mount --bind "$carpeta_real_grupo" "$nuevo_punto"
    
    # Asegurar permisos en el punto de montaje
    chown root:"${groups}Alumno" "$nuevo_punto"
    chmod 2775 "$nuevo_punto"

    echo -e "\e[32mCambio completado: $names ahora está en $groups\e[0m"
}

add_users2() {
  local i=0
  local localuser="/home/ftp/LocalUser"
  local carpeta_publica="/home/ftp/public"

  IFS=',' read -ra names <<< "$names" # Separar por comas
  IFS=',' read -ra passwords <<< "$passwords"

  validateEmptyArray "${names[@]}"
  validateEmptyArray "${passwords[@]}"

  # Asegurar que la carpeta pública global exista
  if [ ! -d "$carpeta_publica" ]; then
      mkdir -p "$carpeta_publica"
      chown root:users "$carpeta_publica"
      chmod 2775 "$carpeta_publica"
  fi

  while [ $i -lt "$no_users" ]; do
    local nombre_actual="${names[$i]}"
    local pass_actual="${passwords[$i]}"
    
    # Esta es la "Jaula" (Home del usuario)
    local ruta_jaula="$localuser/$nombre_actual"
    # Esta es su carpeta de trabajo real donde sí puede escribir
    local carpeta_personal="$ruta_jaula/$nombre_actual"
    # Punto de montaje para la pública
    local punto_montaje_publico="$ruta_jaula/public"

    echo "Configurando entorno para: $nombre_actual..."

    # 1. Crear el usuario con su Home en la "Jaula"
    useradd "$nombre_actual" -m -d "$ruta_jaula" -G "users" -c "Alumno" 2>/dev/null
    
    if [ $? -ne 0 ]; then
      echo "Error: No se pudo crear al usuario '$nombre_actual'."
      exit 1
    fi

    # 2. Asignar contraseña
    echo "$nombre_actual:$pass_actual" | chpasswd

    # 3. Crear estructura interna (Carpeta personal y punto de montaje)

    mkdir -p "$carpeta_personal"
    mkdir -p "$punto_montaje_publico"

    # 4. PERMISOS DE SEGURIDAD (La regla de oro del FTP)
    # La jaula debe ser de root para que funcione el chroot
    chown root:root "$ruta_jaula"
    chmod 755 "$ruta_jaula"

    # La carpeta personal interna sí es del alumno
    chown "$nombre_actual:$nombre_actual" "$carpeta_personal"
    chmod 700 "$carpeta_personal"

    mount --bind "$carpeta_publica" "$punto_montaje_publico"

    echo " -> Entorno de '$nombre_actual' listo (Home y Public montados)."
    ((i++))
  done

  echo "------------------------------------------"
  echo "Proceso finalizado: Se configuraron $no_users usuarios."  
}

deleteUser() {
    local nombre_usuario="$1"
    local etiqueta="$2" # En tu caso será "Alumno"

    validateEmpty "$nombre_usuario" "Nombre del usuario"
    validateEmpty "$etiqueta" "Etiqueta"
    
    # 1. Buscamos la línea exacta que coincida con el nombre Y la etiqueta
    # ^$nombre_usuario: asegura que la línea empiece con ese usuario exacto
    # :$etiqueta: asegura que el campo 5 sea el que buscamos
    local registro=$(getent passwd | grep "^$nombre_usuario:" | grep ":$etiqueta")

    if [ -z "$registro" ]; then
        echo -e "\e[33mNo se encontró al usuario '$nombre_usuario' con la etiqueta '$etiqueta'.\e[0m"
        return 1
    fi

    echo "Confirmado: Se eliminará a $nombre_usuario (Etiqueta: $etiqueta)"
    
    # 2. Definimos la ruta de su jaula (usando tu variable global $localUser)
    local ruta_completa="$localuser/$nombre_usuario"

    for punto_montaje in $(mount | grep "/home/ftp/LocalUser/$nombre_usuario/" | cut -d " " -f3); do
        echo " -> Desmontando con precisión: $punto_montaje"
        umount -l "$punto_montaje" 2>/dev/null
    done

    # 3. Borrado de archivos (Equivalente al Remove-Item -Recurse)
    if [ -d "$ruta_completa" ]; then
        echo "Limpiando directorio: $ruta_completa"
        rm -rf "$ruta_completa" # Cuidado extremo aquí
    fi

    # 4. Eliminación de la cuenta del sistema
    # -r borra el home registrado en /etc/passwd
    # -f fuerza la eliminación incluso si hay procesos (útil en FTP)
    userdel -f "$nombre_usuario" #2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "\e[32mUsuario '$nombre_usuario' eliminado exitosamente.\e[0m"
    else
        echo -e "\e[31mError al eliminar al usuario del sistema.\e[0m"
    fi
}

listarAlumnos() {
    local descripcion=$1
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mListado de usuarios con descripción: $descripcion\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"

    # Buscamos y le damos un formato de tablita con 'column'
    # -t: crea la tabla, -s: define el separador (los dos puntos)
    getent passwd | grep ":$descripcion:" | cut -d: -f1,3,5,6 | column -t -s ":"
    
    echo -e "\e[34m--------------------------------------------------------\e[0m"
}

add_users() {
  validateInt "$no_users" "Numero de usuarios"

  IFS=',' read -ra names <<< "$names" # Separar por comas
  IFS=',' read -ra passwords <<< "$passwords"
  IFS=',' read -ra groups <<< "$groups"

  # Verificar que los arreglos no esten vacios
  validateEmptyArray "${names[@]}"
  validateEmptyArray "${passwords[@]}"
  validateEmptyArray "${groups[@]}"

  validateUserExists "${names[@]}" # Verificar que el usuario exista
  validateGroupNumber "${groups[@]}" # Verificar que el grupo sea 1 o 2

  # Verificar que el num de usuarios ingresados coincida
  if [ "${#names[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de nombres no coincide con el numero de usuarios"
    exit 1
  fi

  if [ "${#passwords[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de contraseñas no coincide con el numero de usuarios"
    exit 1
  fi

  if [ "${#groups[@]}" != "$no_users" ]; then
    echo "Se ha detectado que el numero de grupos no coincide con el numero de usuarios"
    exit 1
  fi

  i=0; # contador

  while [ $i -lt $no_users ]; do
    if [ "${groups[$i]}" = "1" ]; then
      if [ -n "$(useradd -m ${names[$i]} -G reprobados,users 2>&1 | grep 'invalid')" ]; then #non-zero length
        echo "Se ha detectado un error al crear el nombre ${names[$1]}, saliendo del programa"
        exit 1
      fi
    elif [ "${groups[$i]}" = "2" ]; then
      if [ -n "$(useradd -m ${names[$i]} -G recursadores,users 2>&1 | grep 'invalid')" ]; then #non-zero length
        echo "Se ha detectado un error al crear el nombre ${names[$1]}, saliendo del programa"
        exit 1
      fi
    fi

    echo "${names[$i]}:${passwords[$i]}" | chpasswd

    ((i++))
  done

  echo "Se ha terminado de agregar usuarios"
}

crearGrupoAcademico() {
    local nombre_base=$1
    # Añadimos el sufijo que pensaste para identificar grupos de alumnos
    validateEmpty "$nombre_base" "Nombre del grupo"

    local nombre_grupo="${nombre_base}Alumno"
    local ruta_grupo="/home/ftp/$nombre_grupo"

    # 1. Crear el grupo en el sistema
    if ! getent group "$nombre_grupo" >/dev/null; then
        groupadd "$nombre_grupo"
        echo "Grupo '$nombre_grupo' creado con éxito."
    else
        echo "El grupo '$nombre_grupo' ya existe."
    fi

    # 2. Crear la carpeta compartida para ese grupo
    mkdir -p "$ruta_grupo"

    # 3. Permisos: root es el dueño, pero el grupo puede escribir
    # El '2' en '2775' activa el SGID (importante para carpetas grupales)
    chown root:"$nombre_grupo" "$ruta_grupo"
    chmod 2775 "$ruta_grupo"
}

deleteGroup() {
    local nombre_base=$1
    local sufijo="Alumno"
    local nombre_grupo="${nombre_base}${sufijo}"
    local ruta_grupo="/home/ftp/$nombre_grupo"

    echo "Iniciando proceso de eliminación para el grupo: $nombre_grupo"

    # 1. VALIDACIÓN DE SEGURIDAD: ¿Es un grupo de tu script?
    if [[ ! "$nombre_grupo" == *"$sufijo" ]]; then
        echo -e "\e[31mError: Solo se pueden eliminar grupos con el sufijo '$sufijo'.\e[0m"
        return 1
    fi

    # 2. VERIFICAR SI EL GRUPO EXISTE
    if ! getent group "$nombre_grupo" >/dev/null; then
        echo -e "\e[33mEl grupo '$nombre_grupo' no existe en el sistema.\e[0m"
        return 1
    fi

    # 3. LIMPIEZA DE MONTAJES (Importante en Linux)
    # Buscamos en todas las jaulas de LocalUser si alguien tiene montada esta carpeta
    echo "Desmontando accesos de usuarios..."
    for jaula in /home/ftp/LocalUser/*; do
        punto_montaje="$jaula/${nombre_grupo%$sufijo}"
        if mountpoint -q "$punto_montaje"; then
            umount -f "$punto_montaje"
            echo " -> Desmontado en: $(basename "$jaula")"
        fi
        
        # Opcional: Borrar la carpeta física que servía de punto de montaje
        [ -d "$punto_montaje" ] && rmdir "$punto_montaje"
    done

    # 4. BORRAR CARPETA COMPARTIDA REAL
    if [ -d "$ruta_grupo" ]; then
        echo "Eliminando archivos del grupo en $ruta_grupo..."
        rm -rf "$ruta_grupo"
    fi

    # 5. ELIMINAR EL GRUPO DEL SISTEMA
    groupdel "$nombre_grupo"

    if [ $? -eq 0 ]; then
        echo -e "\e[32mGrupo '$nombre_grupo' eliminado correctamente.\e[0m"
    else
        echo -e "\e[31mError al eliminar el grupo del sistema.\e[0m"
    fi
}

listarGrupos() {
    local sufijo="Alumno"
    
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mGRUPOS ACADÉMICOS REGISTRADOS (Sufijo: $sufijo)\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"
    echo -e "\e[1mNOMBRE_GRUPO\tGID\tINTEGRANTES\e[0m"
    echo -e "\e[34m--------------------------------------------------------\e[0m"

    # 1. getent group: trae la lista de grupos
    # 2. grep "$sufijo": filtra solo los que terminan en Alumno
    # 3. cut: toma el nombre (1), el GID (3) y los usuarios (4)
    # 4. column: lo alinea todo bonito
    getent group | grep "$sufijo" | cut -d: -f1,3,4 | column -t -s ":"
    
    echo -e "\e[34m--------------------------------------------------------\e[0m"
}

mostrar_menu() {
clear
echo "=========================================="
echo "        ADMINISTRACION SERVIDOR FTP"
echo "=========================================="
echo ""
echo "1) Verificar existencia del servicio FTP"
echo "2) Instalar servicio FTP"
echo "3) Crear carpetas iniciales"
echo "4) Desinstalar servicio FTP"
echo "5) Estatus servicio FTP"
echo "6) Cambiar usuario de grupo"
echo ""
echo "------ ABC Usuarios ------"
echo "7) Agregar usuario"
echo "8) Eliminar usuario"
echo "9) Consultar usuarios"
echo ""
echo "------ ABC Grupos ------"
echo "10) Agregar grupo"
echo "11) Eliminar grupo"
echo "12) Consultar grupos"
echo ""
echo "0) Salir"
echo ""
read -p "Seleccione una opcion: " option
}

while true; do

mostrar_menu

case "$option" in
  1)
    check_service "vsftpd"
    ;;

  2)
    read -p "Confirmar instalacion (1=si): " install
    install_service "vsftpd" "$install"
    configure_options
    ;;

  3)
    configure_options
    ;;

  4)
    read -p "Confirmar desinstalacion (1=si): " confirm
    uninstall_service "vsftpd" "$confirm"
    ;;

  5)
    status_service_systemctl "vsftpd"
    ;;

  6)
    read -p "Usuario: " names
    read -p "Grupo: " groups
    change_groups "Alumno"
    ;;

  7)
    read -p "Numero de usuarios: " no_users
    read -p "Usuarios (coma): " names
    read -p "Passwords (coma): " passwords
    add_users2
    ;;

  8)
    read -p "Nombre del usuario a eliminar: " names
    deleteUser "$names" "Alumno"
    ;;

  9)
    listarAlumnos "Alumno"
    ;;

  10)
    read -p "Nombre del grupo: " groups
    crearGrupoAcademico "$groups"
    ;;

  11)
    read -p "Nombre del grupo a eliminar: " groups
    deleteGroup "$groups"
    ;;

  12)
    listarGrupos
    ;;

  0)
    echo "Saliendo..."
    exit
    ;;

  *)
    echo "Opcion invalida"
    ;;
esac

echo ""
read -p "Presione ENTER para continuar..."
done

case "$option" in
  1)
  check_service "vsftpd" 
  ;; 
  2)
  install_service "vsftpd" "$install"
  configure_options
  ;;
  3)
  configure_options ;;
  4)
  uninstall_service "vsftpd" "$confirm" 
  ;;
  5)
  status_service_systemctl "vsftpd" 
  ;;
  6) change_groups "Alumno";;
  7) add_users2 ;;
  8) deleteUser "$names" "Alumno";;
  9) listarAlumnos "Alumno";;
  10) crearGrupoAcademico "$groups";;
  11) deleteGroup "$groups";;
  12) listarGrupos ;;

  *) echo "Opcion invalida" ;;
esac
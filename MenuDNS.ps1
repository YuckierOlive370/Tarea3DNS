function Validar-IP {
    param ($ip)
    if ($ip -match '^((25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)$') {
        return ($ip -ne "255.255.255.255" -and $ip -ne "0.0.0.0" -and $ip -ne "127.0.0.1")
    }
    return $false
}

function IP-a-Int {
    param ([string]$ip)
    $bytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function Pedir-IP {
    param (
        [string]$mensaje
    )

    do {
        $ip = Read-Host $mensaje
        if (-not (Validar-IP $ip)) {
            Write-Host "IP no valida, intenta de nuevo"
        }
    } until (Validar-IP $ip)

    return $ip
}

function Get-PrefixLength {
    param([string]$SubnetMask)
    $bytes = $SubnetMask.Split('.') | ForEach-Object { [Convert]::ToString([int]$_,2).PadLeft(8,'0') }
    ($bytes -join '').ToCharArray() | Where-Object { $_ -eq '1' } | Measure-Object | Select-Object -ExpandProperty Count
}

function VerificarServicio {
    if ((Get-WindowsFeature -Name DNS).Installed) {
        Write-Host "DNS ya esta instalado."
    } else {
        Write-Host "DNS no esta instalado."
        $respuesta = Read-Host "¿Deseas instalarlo ahora? (S/N)"
        if ($respuesta -match '^[sS]$') {
            Instalar
        } else {
            Write-Host "Instalacion cancelada por el usuario."
        }
    }
}

function Instalar {
    Install-WindowsFeature -Name DNS -IncludeManagementTools
}

function Configurar {
    param (
        [string]$subnetMask = "255.255.255.0"
    )

    if ((Get-WindowsFeature -Name DNS).Installed) {
    Write-Host "El rol DNS ya está instalado."
    } else {
    return
    }

    $adapter = Get-NetIPAddress -InterfaceAlias "Ethernet 1"
    if ($adapter.Dhcp -eq "Disabled"){
        Write-Host "Se cuenta con IP fija"
        $IP = (Get-NetIPAddress -InterfaceAlias "Ethernet 1" -AddressFamily IPv4).IPAddress
        Write-Host "La IP fija detectada es $IP"

    }  else {
        Write-Host "No se cuenta con IP fija"
            $IP = Pedir-IP "IP fija del servidor"
            $prefix = Get-PrefixLength -SubnetMask $subnetMask
        try {
            Remove-NetIPAddress -InterfaceIndex 11 -Confirm:$false
            $interface = Get-NetAdapter -Name "Ethernet1"
            New-NetIPAddress -InterfaceIndex $interface.InterfaceIndex `
            -IPAddress $IP `
            -PrefixLength $prefix -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Host "No se asigno la IP fija"
        }
    }

    $dominio = Read-Host "Ingresa el dominio: "
    
    Add-DnsServerPrimaryZone -Name "$dominio" -ZoneFile "$dominio.dns"
    Add-DnsServerResourceRecordA -Name "@" -ZoneName "$dominio" -IPv4Address $IP
    Add-DnsServerResourceRecordA -Name "www" -ZoneName "$dominio" -IPv4Address $IP
    Get-DnsServerZone -Name "$dominio"
    Get-DnsServerResourceRecord -ZoneName "$dominio"
}

function Reconfigurar {
    Write-Host "Bienvenido a la reconfiguracion."
    Uninstall-WindowsFeature -Name DNS
    Agregar
    Configurar
}

function Agregar{
    $dominio = Read-Host "Ingresa el dominio: "
    $IP = Read-Host "Ingresa IP dominio"
    Add-DnsServerPrimaryZone -Name "$dominio" -ZoneFile "$dominio"
    Write-Host "Dominio creado: $dominio"
    Add-DnsServerResourceRecordA -Name "@" -ZoneName "$dominio" -IPv4Address $IP
    Add-DnsServerResourceRecordA -Name "www" -ZoneName "$dominio" -IPv4Address $IP
}

function Borrar{
    $dominio = Read-Host "Ingresa el dominio: "
    Remove-DnsServerZone -Name "$dominio" -Force
    Write-Host "Dominio eliminado: $dominio"
}

function Consultar{
    $dominio = Read-Host "Ingresa el dominio: "
    $Zona = Get-DnsServerZone -Name $dominio -ErrorAction SilentlyContinue
    Get-DnsServerZone -Name "$dominio"
    Get-DnsServerResourceRecord -ZoneName "$dominio"
}

function ABC{
    Write-Host "Bienvenidio al ABC de DNS"
    Write-Host "++++++++ Menu de Opciones ++++++++"
    Write-Host "1.-Agregar"
    Write-Host "2.-Borrar"
    Write-Host "3.-Consultar"
    Write-Host "4.-Regreso al Menu"

    $op = [int](Read-Host "Selecciona: ")
    switch($op){
        1{Agregar}
        2{Borrar}
        3{Consultar}
        4{return}
        default{Write-Host "Opcion no valida"}
    }
}


$con = "S"

while ($con -match '^[sS]$') {
    Write-Host "Tarea 2: Automatizacion y Gestion del Servidor DNS"
    Write-Host "++++++++ Menu de Opciones ++++++++"
    Write-Host "1.-Verificar la presencia del servicio"
    Write-Host "2.-Instalar el servicio"
    Write-Host "3.-Configurar"
    Write-Host "4.-Reconfigurar"
    Write-Host "5.-ABC dominios"
    Write-Host "6.-Salir"
    $op = [int](Read-Host "Selecciona: ")
    switch($op){
        1{VerificarServicio}
        2{Instalar}
        3{Configurar}
        4{Reconfigurar}
        5{ABC}
        6{$con = "n"}
        default{Write-Host "Opcion no valida"}
    }
}
Write-Host "Programa terminado."

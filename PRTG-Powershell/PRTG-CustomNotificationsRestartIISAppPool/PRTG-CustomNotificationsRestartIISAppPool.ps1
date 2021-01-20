<#
.SYNOPSIS
    .SCRIPT PARA REINICIAR NOS SERVIDORES HOSTING O APPPOOL DE UM WEBSITE QUE ESTEJA FORA DO AR
.DESCRIPTION
    .
.PARAMETER NomeDoComputador
    .Digite o nome FQDN do computador (certifique-se que esse nome resolva a partir do host que executa o script) ou então o endereço IP (tenha certeza queo host que executa o script tem acesso à esse computador destino)
.PARAMETER DeviceName
    .A variável do PRTG %device corresponderá ao nome do Site / AppPool registrado nos servidores de Hosting
.PARAMETER NomeDeUsuario
    .Nome de Usuario que tem acesso administrativo no computador destino
.PARAMETER Senha
    .A Senha do usuário acima. Para manter o sigilo dessas informações usamos as variaveis do PRTG Network Monitor conforme exemplos a seguir
.EXAMPLE
    C:\PS>& '.\PRTG-CustomNotificationsRestartIISAppPool.ps1' -NomeDoComputador %host -NomeDeUsuario "%windowsdomain\%windowsuser" -Senha "%windowspassword"
    
.NOTES
    Author: Moises de Matos Gil (moises@mmgil.com.br)
    Date:   Janeiro 20, 2021

    Março 20, 2021 - Criado a Primeira Versão desse SCRIPT
#>

param(
    # PARAMETROS
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite o nome do Computador" )]
    [string[]]$NomeDoComputador,
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite o nome do WebSite / AppPool" )]
    [string]$DeviceName,
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite o Nome de Usuario" )]
    [string]$NomeDeUsuario,
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Digite a Senha" )]
    [string]$Senha
)

#######################################
function New-GenerateCredentials() {

    if ( $NomeDoComputador -is [array] ) {
        # Generate Credentials if we're not checking localhost
        if ((($env:COMPUTERNAME) -ne $NomeDoComputador[0])) {

            # Generate Credentials Object first
            $SecPasswd = ConvertTo-SecureString $Senha -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential ($NomeDeUsuario, $SecPasswd)
            return $Credentials

        }
    }
    else {
        # Generate Credentials if we're not checking localhost
        if ((($env:COMPUTERNAME) -ne $NomeDoComputador)) {

            # Generate Credentials Object first
            $SecPasswd = ConvertTo-SecureString $Senha -AsPlainText -Force
            $Credentials = New-Object System.Management.Automation.PSCredential ($NomeDeUsuario, $SecPasswd)
            return $Credentials

        }
    }

    # otherwise return false
    else { return "false" }
}  

$Credentials = (New-GenerateCredentials);

# DECLARANDO VARÍAVEIS QUE SERÃO USADAS
#$result = @()

# ABRINDO UMA SESSÃO CIMSESSION AO INVES DE PSSESSION POR QUESTOES DE PERFORMANCE
$PSSession = New-PSSession -ComputerName $NomeDoComputador -Credential $Credentials

Invoke-Command -Session $PSSession -ScriptBlock {
    Stop-WebAppPool -Name $using:DeviceName
    Stop-Website -Name $using:DeviceName
    Start-Sleep -Seconds 10
    Start-WebAppPool -Name $using:DeviceName
    Start-Website -Name $using:DeviceName
}

exit 0;
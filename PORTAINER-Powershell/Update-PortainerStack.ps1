<#
.SYNOPSIS
    .Adiciona um Stack File no ambiente de Swarm através da API do Portainer usando o Metodo String
.PARAMETER PortainerURL
    .Coloque o endereço HTTP do portainer do seu ambiente, por exemplo: https://portainer.mmgil.com.br/ ou http://DOCKERSERVER:9000
.PARAMETER StackName
    Informe o nome do Stack para visualização no Portainer.
.PARAMETER StackFile
    .Coloque o caminho do arquivo YAML.
.PARAMETER EndpointID
    .(opcional) Seleciona o Endpoint que receberá o StackFile. Se este item não for definido o script ira randomizar os Endpoints existentes
.PARAMETER SwarmID
    .(opcional) Seleciona o Swarm que receberá o StackFile.
.PARAMETER User
    .Coloque o Usuario que tem acesso à API do Portainer. (necessário o parametro Password)
.PARAMETER Password
    .Coloque a Senha do usuario que tem acesso à API do Portainer. (necessário o parametro Usuario)
.PARAMETER Credential
    .Coloque um objeto PSCredential ou informa o nome de usuario para que sozinho ele pergunte a senha durante o processo. (Nao usar os parametros Usuario e Senha)
.EXAMPLE
    C:\PS>$password = Read-Host -AsSecureString
    C:\PS>Add-PortainerStackFile.ps1 -PortainerURL http://127.0.0.1:9000 -StackName wordpress -StackFile ./stack.yaml -User admin -Password $password
    Cadastra um stack com nome wordpress usando o usuario admin e sua respectiva senha
.EXAMPLE
    C:\PS>Add-PortainerStackFile.ps1 -PortainerURL http://127.0.0.1:9000 -StackName wordpress -StackFile ./objects/stack.yaml -Credential admin
    Cadastra um stack com nome wordpress usando o usuario admin atraves do parametro Credential
.NOTES
    Author: Moises de Matos Gil
    Date:   Junho 29, 2019

    2019
#>

[CmdletBinding()]
param(
# PARAMETROS
    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 0, HelpMessage = "Informe o endereço HTTP do Portainer" )]
    [string]$PortainerURL = $( Read-Host "PortainerURL" ),

    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 1, HelpMessage = "Informe o ID do Stack, voce pode usar o Get-PortainerStack.ps1 para obter essas informações" )]
    [string]$StackID = $( Read-Host "StackID" ),

    [Parameter( Mandatory = $True, ValueFromPipeline = $True, position = 2, HelpMessage = "Informe o caminho do arquivo YAML" )]
    [string]$StackFile = $( Read-Host "StackFile" ),

    [Parameter( Mandatory = $True, position = 3, HelpMessage = "EndpointID é o ID do Endpoint cadastrado no Portainer" )]
    [string]$EndpointID,

    [Parameter( Mandatory = $false, ParameterSetName='UserAsPlanText', position = 5, HelpMessage = "Informe o usuario que tem acesso a API do Portainer" )]
    [string]$User,

    [Parameter( Mandatory = $false, ParameterSetName='UserAsPlanText', position = 6, HelpMessage = "Informe a senha do usuario que tem acesso a API do Portainer" )]
    [SecureString]$Password,

    [Parameter( Mandatory = $false, ParameterSetName='SecureCredential', position = 5, HelpMessage = "Informea senha do usuario que tem acesso a API do Portainer" )]
    [System.Management.Automation.PSCredential]$Credential

)

Begin {
    Write-Host "$(Get-Date) - [INFO]: INICIANDO ACOES (Update-PortainerStack)" -ForegroundColor Cyan
    Write-Host "$(Get-Date) - [INFO]: MOTANDO VARIAVEIS" -ForegroundColor Cyan
    [uri]$portainerApiAuth = $PortainerURL+"/api/auth"
    [uri]$stackUrl = $PortainerURL+"/api/stacks/$StackID?endpointID=$EndpointID"



    Write-Host "$(Get-Date) - [INFO]: MOTANDO CREDENCIAIS DE ACESSO A API" -ForegroundColor Cyan
    try {
        if( -not([string]::IsNullOrEmpty($Credential)) ) {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
            $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

            $jsonAuth = @{Username=$User;Password=$UnsecurePassword}
            $jsonAuth = $jsonAuth | ConvertTo-Json
            Write-Host "--> $(Get-Date) - [SUCESS]: USANDO PARAMETRO CREDENTIAL" -ForegroundColor Green
        }

        if( -not([string]::IsNullOrEmpty($User)) -and -not([string]::IsNullOrEmpty($Password)) ) {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

            $jsonAuth = @{Username=$User;Password=$UnsecurePassword}
            $jsonAuth = $jsonAuth | ConvertTo-Json
            Write-Host "--> $(Get-Date) - [SUCESS]: USANDO PARAMETROS USER E PASSWORD" -ForegroundColor Green
        } else {
            Write-Host "$(Get-Date) - [WARNING]: USER OU PASSWORD FALTANDO" -ForegroundColor Yellow
            return $LASTEXITCODE = 1
        }
    } catch {
        Write-Host "--> $(Get-Date) - [ERROR]: DEU RUIM" -ForegroundColor Red
        return $LASTEXITCODE = 1
    }



    Write-Host "$(Get-Date) - [INFO]: OBTENDO JSON WEB TOKEN" -ForegroundColor Green
    try {
        $sessionVar = (Invoke-RestMethod -Uri $portainerApiAuth.AbsoluteUri -Method Post -Body $jsonAuth -ContentType "application/json").jwt
        if( -not( [string]::IsNullOrEmpty($sessionVar) ) ) {
            Write-Host "--> $(Get-Date) - [SUCESS]: JSON WEB TOKEN OBTIDO" -ForegroundColor Green
        }
    } catch {
        Write-Host "--> $(Get-Date) - [ERROR]: DEU RUIM" -ForegroundColor Red
        return $LASTEXITCODE = 1
    }



    Write-Host "$(Get-Date) - [INFO]: OBTENDO INFORMACOES DO ARQUIVO YAML" -ForegroundColor Cyan
    try {
        $FilePath = (Get-Location).Path+$StackFile

        if( -not([string]::IsNullOrEmpty($StackFile)) -and (Test-Path $FilePath)) {
            $FileBin = [IO.File]::ReadAllBytes($FilePath)
            $FileEnc = [System.Text.Encoding]::GetEncoding('UTF-8').GetString($FileBin);
            $FileEnc = $FileEnc -replace "`r`n","\n"
            $FileEnc = $FileEnc -replace "`"", "'"
            Write-Host "$(Get-Date) - [SUCESS]: CONTEUDO DO YAML OBTIDO" -ForegroundColor Green
        } else {
            Write-Host "$(Get-Date) - [WARNING]: YAML NÃO ENCONTRADO" -ForegroundColor Yellow
            return $LASTEXITCODE = 1
        }
    } catch {
        Write-Host "--> $(Get-Date) - [ERROR]: DEU RUIM" -ForegroundColor Red
        return $LASTEXITCODE = 1
    }



    Write-Host "$(Get-Date) - [INFO]: PREPARANDO DADOS PARA ENVIAR" -ForegroundColor Cyan
    $Headers = @{
        Accept= "*/*";
        "Authorization"="Bearer $sessionVar";
        "User-Agent"="powershell/5.1";
        "Cache-Control"="no-cache";
        "accept-encoding"="gzip, deflate";
      }

      $jsonFile = @{
          Prune = $false;
          StackFileContent = "tempdata";
      }

      $jsonFile = $jsonFile | ConvertTo-Json
      $jsonFile = $jsonFile -replace "tempdata",$FileEnc


      Write-Host "$(Get-Date) - [INFO]: ENVIANDO REQUISIÇÃO PARA A API DO PORTAINER" -ForegroundColor Cyan
      try {
        $portainer = Invoke-RestMethod -Uri $stackUrl.AbsoluteUri -Method Put -ContentType "application/json" -Body $jsonFile -Headers $Headers
        $portainer
      } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Host "--> $(Get-Date) - [ERROR]: DEU RUIM -> $ErrorMessage" -ForegroundColor Red
        return $LASTEXITCODE = 1
      }

}
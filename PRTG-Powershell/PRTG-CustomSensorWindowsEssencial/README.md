# PRTG-CustomSensorWindowsEssencial

Esse script tem o objetivo de obter os dados essenciais de desempenho e disponibilidade do servidor e armazena-los no PRTG.

# Como Instalar
    
No seu servidor de PRTG, adicione esse Script no seguinte caminho:

```powershell
${env:ProgramFiles(x86)}+"\PRTG Network Monitor\Custom Sensors\EXEXML"
```

Agora, ao adicionar o sensor em algum equipamento, escolha Sensores Customizados \ EXE/Script Avançado

Defina o Nome que você desejar, escolha o script no Combo Box logo abaixo e em parâmetros adicione:

```powershell
-NomeDoComputador %host -NomeDeUsuario "%windowsdomain\%windowsuser" -Senha "%windowspassword"
```

# Exemplo de Saída do Sensor

Esta é a imagem de como será a saída desse sensor, como pode perceber somente com esse sensor economizamos em torno de 5 sensores.

![saida][]

[saida]: assets/saida.png


# Histórico

**Author:** Moises de Matos Gil (moises@mmgil.com.br)

**Date:**   Março 07, 2017

**Julho 14, 2018 -** Esse script não consegue obter as métricas de Rede do Windows Server 2008 R2.

**Julho 14, 2018 -** Alterado o metodo de conexão de PSSession para CIMSession, para melhorar a performance

**Julho 14, 2018 -** Script Adaptado para suportar Nano Server 2016.

**Março 08, 2017 -** Melhoria de desempenho, realiza a coleta através de uma única SESSION de Powershell

**Março 07, 2017 -** Criado a Primeira Versão desse SCRIPT
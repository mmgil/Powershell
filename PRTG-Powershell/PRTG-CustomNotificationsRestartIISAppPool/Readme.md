# PRTG-CustomSensorWindowsEssencial

Esse script tem o objetivo de reiniciar o AppPool e o WebSite de um ambiente de IIS caso o monitoramento do sensor HTTP esteja com status DOWN

# Como Instalar
    
No seu servidor de PRTG, adicione esse Script no seguinte caminho:

```powershell
${env:ProgramFiles(x86)}+"\PRTG Network Monitor\Notifications\EXE"
```

Agora, no seu PRTG, configure um modelo novo de notificação e marque o item Executar Programa

Defina o Nome que você desejar, escolha o script no Combo Box logo abaixo e em parâmetros adicione:

```powershell
-NomeDoComputador %host -DeviceName %device -NomeDeUsuario "%windowsdomain\%windowsuser" -Senha "%windowspassword"
```

# Histórico

**Author:** Moises de Matos Gil (moises@mmgil.com.br)

**Date:**   Março 20, 2021

**Janeiro 20, 2021 -** Criado a Primeira Versão desse SCRIPT
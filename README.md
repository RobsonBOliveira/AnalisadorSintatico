# 🧩 Analisador Sintático — Linguagem Tonto

Este projeto implementa um **analisador sintático** em **C++** usando **Bison**, projetado para processar arquivos contendo listas de tokens previamente gerados com o analisador léxico.  
O sistema percorre um diretório informado pelo usuário, identifica automaticamente todos os arquivos ***TokensList.txt,** executa o parser para cada um deles e gera relatórios de síntese ou erros.


## 🚀 Tecnologias Utilizadas

- **C++17**
- **Bison** (GNU Parser Generator)
- **GNU Make** (opcional, para automação da compilação)
- **Linux / WSL / macOS** (recomendado)



## ⚙️ Instalação e Configuração

No **Debian/Ubuntu**:

```bash
sudo apt update
sudo apt install bison make g++
``` 
## 🏗️ Compilação

Após a instalação da dependências, rode o seguinte comando:

```bash
make
```

## ▶️ Como Executar

Para rodar o analisador sobre um diretório, use:

```bash
./parser caminho_diretorio/
```


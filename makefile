# Compiladores
CC=g++
BISON=bison
ARQUIVO=parser.y

# Dependências
all: parser

parser: parser.tab.c main.cpp
	$(CC) parser.tab.c main.cpp -std=c++17 -o parser

parser.tab.c: $(ARQUIVO)
	$(BISON) -d $(ARQUIVO)

clean:
	rm parser parser.tab.c parser.tab.h

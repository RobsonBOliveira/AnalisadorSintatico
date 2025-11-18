%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Prototipos */
int yylex(void);
void yyerror(const char *s);

/* Arquivo de entrada da tabela de tokens */
FILE *tokenFile;

int lineNumber, columnNumber;
char type[50], lexeme[100];
%}

/* Declaração de tokens (iguais aos tipos do seu arquivo de tokens) */
%token ID NUM ATRIB PLUS MINUS TIMES DIVIDE PONTOVIRG EOF_TOKEN

%%

programa:
      comandos EOF_TOKEN     { printf("Análise sintática concluída com sucesso.\n"); }
    ;

comandos:
      comando
    | comandos comando
    ;

comando:
      atribuicao
    ;

atribuicao:
      ID ATRIB expr PONTOVIRG   { printf("Reconhecida atribuição.\n"); }
    ;

expr:
      NUM
    | expr PLUS expr
    | expr MINUS expr
    | expr TIMES expr
    | expr DIVIDE expr
    ;
%%

/* Função para ler tokens do arquivo */
int yylex(void) {
    if (fscanf(tokenFile, "%d %d %s %s", 
               &lineNumber, &columnNumber, type, lexeme) != 4) {
        return 0; // fim de arquivo ou linha inválida
    }


    fprintf(stdout, 
            "Linha: %d, Coluna: %d, Tipo: %s, Lexema: %s\n",
            lineNumber, columnNumber, type, lexeme);
    

    if (strcmp(type, "keyword") == 0) return ID;
    if (strcmp(type, "NUM") == 0) return NUM;
    if (strcmp(type, "ATRIB") == 0) return ATRIB;
    if (strcmp(type, "PLUS") == 0) return PLUS;
    if (strcmp(type, "MINUS") == 0) return MINUS;
    if (strcmp(type, "TIMES") == 0) return TIMES;
    if (strcmp(type, "DIVIDE") == 0) return DIVIDE;
    if (strcmp(type, "PONTOVIRG") == 0) return PONTOVIRG;
    if (strcmp(type, "EOF") == 0) return EOF_TOKEN;

    fprintf(stderr, "Token desconhecido: %s\n", type);
    exit(1);
}

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático: %s\n", s);
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Prototipos */
int yylex(void);
void yyerror(const char *s);

/* Arquivo de entrada da tabela de tokens */
FILE *tokenFile;
char tokenType[50], tokenValue[100];
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
    if (fscanf(tokenFile, "%s", tokenType) != 1)
        return 0; // fim de arquivo

    if (strcmp(tokenType, "ID") == 0) return ID;
    if (strcmp(tokenType, "NUM") == 0) return NUM;
    if (strcmp(tokenType, "ATRIB") == 0) return ATRIB;
    if (strcmp(tokenType, "PLUS") == 0) return PLUS;
    if (strcmp(tokenType, "MINUS") == 0) return MINUS;
    if (strcmp(tokenType, "TIMES") == 0) return TIMES;
    if (strcmp(tokenType, "DIVIDE") == 0) return DIVIDE;
    if (strcmp(tokenType, "PONTOVIRG") == 0) return PONTOVIRG;
    if (strcmp(tokenType, "EOF") == 0) return EOF_TOKEN;

    fprintf(stderr, "Token desconhecido: %s\n", tokenType);
    exit(1);
}

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático: %s\n", s);
}

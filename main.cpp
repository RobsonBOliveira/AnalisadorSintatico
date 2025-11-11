    #include <stdio.h>
#include <stdlib.h>

int yyparse(void);
extern FILE *tokenFile;

int main(void) {
    tokenFile = fopen("tokens.txt", "r");
    if (!tokenFile) {
        perror("Erro ao abrir tokens.txt");
        return 1;
    }

    if (yyparse() == 0)
        printf("Análise concluída sem erros!\n");

    fclose(tokenFile);
    return 0;
}

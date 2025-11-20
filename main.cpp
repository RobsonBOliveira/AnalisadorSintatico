#include <stdio.h>
#include <stdlib.h>

int yyparse(void);
extern FILE *tokenFile;
extern void init_maps();

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <arquivo_tokens>\n", argv[0]);
        return 1;
    }

    tokenFile = fopen(argv[1], "r");
    if (!tokenFile) {
        perror("Erro ao abrir arquivo");
        return 1;
    }

    init_maps(); // Carrega os mapas
    yyparse();   // Inicia a análise

    fclose(tokenFile);
    return 0;
}

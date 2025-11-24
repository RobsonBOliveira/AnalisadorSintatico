#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>

int yyparse(void);
extern FILE *tokenFile;
extern void init_maps();
struct ErrorInfo {
    int line;
    int col;
    std::string message;
    std::string suggestion;
};
extern std::vector<ErrorInfo> errorLog;
extern void printSynthesisReport();
extern void printErrorReport();

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

    init_maps();
    
    // Inicia o parser
    // O yyparse retorna 0 em caso de SUCESSO.
    if (yyparse() == 0) {
        // Sucesso total
    } else {
        // Falha no parser
    }
    
    // Gera os relatórios
    if (errorLog.empty()) {
        printSynthesisReport();
    } 
    printErrorReport();

    fclose(tokenFile);
    return 0;
}

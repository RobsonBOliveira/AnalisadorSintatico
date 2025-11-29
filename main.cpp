#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>

#include <dirent.h>

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

bool endsWith(const std::string &str, const std::string &suffix) {
    if (str.length() < suffix.length()) return false;
    return str.compare(str.length() - suffix.length(), suffix.length(), suffix) == 0;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "Uso: %s <diretorio_com_tokens>\n", argv[0]);
        return 1;
    }

    const char *directoryPath = argv[1];
    DIR *dir = opendir(directoryPath);
    if (!dir) {
        perror("Erro ao abrir diretório");
        return 1;
    }

    struct dirent *entry;

    while((entry = readdir(dir)) != NULL) {

        std::string fileName = entry->d_name;

        //Ignora . e ..
        if(fileName == ".'" || fileName == "..") continue;

        //Verifica se é arquivo TokensList.txt
        if(!endsWith(fileName, "TokensList.txt")) continue;

        //Monta caminho completo
        std::string fullPath = std::string(directoryPath) + "/" + fileName;

        printf("Processando arquivo: %s\n", fullPath.c_str());

        tokenFile = fopen(fullPath.c_str(), "r");
        if (!tokenFile) {
            perror(("Erro ao abrir arquivo: " + fullPath).c_str());
            continue; //Tenta com proximo arquivo
        }

        errorLog.clear();
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
    }
    return 0;
}

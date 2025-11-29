#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>
#include <dirent.h>

std::string currentFileName = ""; 
int yyparse(void);
FILE *tokenFile = nullptr;
extern void init_maps();
extern void printSynthesisReport();
extern void printErrorReport();

struct ErrorInfo {
    int line;
    int col;
    std::string message;
    std::string suggestion;
};

extern std::vector<ErrorInfo> errorLog;

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
    init_maps();

    while((entry = readdir(dir)) != NULL) {

        std::string fileName = entry->d_name;

        if(fileName == "." || fileName == "..") continue;
        if(!endsWith(fileName, "TokensList.txt")) continue;

        std::string fullPath = std::string(directoryPath) + "/" + fileName;
        currentFileName = fullPath;

        printf("Processando arquivo: %s\n", fullPath.c_str());

        tokenFile = fopen(fullPath.c_str(), "r");
        if (!tokenFile) {
            perror(("Erro ao abrir arquivo: " + fullPath).c_str());
            continue;
        }

        yyparse();
        fclose(tokenFile);
        
    }
    if(errorLog.empty())
        printSynthesisReport();
    else 
        printErrorReport();
    return 0;
}
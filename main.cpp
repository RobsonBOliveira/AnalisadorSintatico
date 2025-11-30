#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <vector>
#include <dirent.h>
#include <filesystem>
#include <fstream>

std::string currentFileName = ""; 
namespace fs = std::filesystem;
int yyparse(void);
FILE *tokenFile = nullptr;
extern void init_maps();
extern void printSynthesisReport(std::string dirName);
extern void printErrorReport();

struct ErrorInfo {
    int line;
    int col;
    std::string message;
    std::string suggestion;
};

void verifyAndCreateDirectory(const fs::path &path);

extern std::vector<ErrorInfo> errorLog;
extern std::ofstream reportFile;

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

    //Verifica e cria diretório "output" e subdiretório especifico para relatório
    fs::path directory = "output";
    
    fs::path dirName = std::string(directoryPath).substr(11);

    verifyAndCreateDirectory(directory);
    verifyAndCreateDirectory("output/" / dirName);    

    if(errorLog.empty())
        printSynthesisReport(dirName.string());
    else 
        printErrorReport();
    return 0;
}

void verifyAndCreateDirectory(const fs::path &path) {
    try{
        if(!fs::exists(path)) {
            fs::create_directories(path);
        }
    }catch(const fs::filesystem_error &e) {
        fprintf(stderr, "Erro ao criar diretório: %s\n", e.what());
        exit(1);
    }

}

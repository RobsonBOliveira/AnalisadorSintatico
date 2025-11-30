#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <iomanip>
#include <fstream>

using namespace std;

// Definições de Cores
#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_RESET   "\x1b[0m"

/* ========================================================================== */
/* ESTRUTURAS DE DADOS                                                        */
/* ========================================================================== */

struct InternalRelationInfo {
    string stereotype;
    string name;
    string cardinality;
    string targetClass;
};

struct RelationInfo {
    string stereotype;
    string type; 
    string details; 
};

struct ClassInfo {
    string name;
    string stereotype;
    vector<string> parents;
    vector<string> attributes;
    vector<InternalRelationInfo> internalRelations;
};

struct GensetInfo {
    string name;
    string general;
    vector<string> specifics;
};

struct PackageInfo {
    string name;
    vector<ClassInfo> classes;
    vector<GensetInfo> gensets;
};

struct DatatypeInfo {
    string name;
    string baseType; 
};

struct EnumInfo {
    string name;
    int literalCount;
};

struct ErrorInfo {
    int line;
    int col;
    string message;
    string suggestion;
};

/* ========================================================================== */
/* VARIÁVEIS GLOBAIS                                                          */
/* ========================================================================== */    
PackageInfo* currentPackage = nullptr;
ClassInfo* currentClass = nullptr;
ofstream reportFile;
int yylex(void);
void yyerror(const char *s);
void init_maps();
void printSynthesisReport();
void printErrorReport();
char typeStr[50], lexeme[100];
int lineNumber, columnNumber;
vector<PackageInfo> packages;
vector<RelationInfo> externalRelations;
vector<DatatypeInfo> datatypes;
vector<EnumInfo> enums;
vector<string> tempSpecifics;
vector<ErrorInfo> errorLog;
unordered_map<string, int> mapRelationStereotypes;
unordered_map<string, int> mapDatatypes;
unordered_map<string, int> mapReservedWords;
unordered_map<string, int> mapClassStereotypes;

extern FILE *tokenFile;
extern std::string currentFileName;
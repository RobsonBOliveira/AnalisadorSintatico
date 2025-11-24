%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <string>
#include <vector>
#include <unordered_map>
#include <iomanip> // Para formatar a tabela

using namespace std;

/* ========================================================================== */
/* ESTRUTURAS DE DADOS PARA A SÍNTESE                                         */
/* ========================================================================== */

struct RelationInfo {
    string stereotype;
    string type; // "Interna" ou "Externa"
    string details; // Ex: "Domínio -> Imagem" ou "Atributo de Classe"
};

struct ClassInfo {
    string name;
    string stereotype;
    int attributeCount;
    int internalRelationCount;
};

struct PackageInfo {
    string name;
    vector<ClassInfo> classes;
};

struct DatatypeInfo {
    string name;
    string baseType; // Se for derivado
};

struct EnumInfo {
    string name;
    int literalCount;
};

struct GensetInfo {
    string name;
    string general;
    int specificCount;
};

struct ErrorInfo {
    int line;
    int col;
    string message;
    string suggestion;
};

/* ========================================================================== */
/* VARIÁVEIS GLOBAIS DE ARMAZENAMENTO                                         */
/* ========================================================================== */

vector<PackageInfo> packages;
vector<RelationInfo> externalRelations;
vector<DatatypeInfo> datatypes;
vector<EnumInfo> enums;
vector<GensetInfo> gensets;
vector<ErrorInfo> errorLog;

// Contexto atual (para saber onde adicionar classes/relações)
PackageInfo* currentPackage = nullptr;
ClassInfo* currentClass = nullptr;

/* Declaração de funções e variáveis externas */
int yylex(void);
void yyerror(const char *s);
FILE *tokenFile;

/* Variáveis do Léxico */
int lineNumber, columnNumber;
char typeStr[50], lexeme[100];

/* Mapas */
unordered_map<string, int> mapReservedWords;
unordered_map<string, int> mapRelationStereotypes;
unordered_map<string, int> mapClassStereotypes;
unordered_map<string, int> mapDatatypes;

void init_maps();
void printSynthesisReport();
void printErrorReport();

%}

/* Define que os valores semânticos ($1, $2...) podem ser strings */
%union {
    char *sval;
}

/* ========================================================================== */
/* DECLARAÇÃO DE TOKENS                                                       */
/* ========================================================================== */

%token PACKAGE IMPORT GENSET DISJOINT COMPLETE GENERAL SPECIFICS WHERE FUNCTIONAL_COMPLEXES OF SPECIALIZES HAS
%token ENUM DATATYPE RELATION
%token ORDERED CONST DERIVED SUBSETS REDEFINES

/* Tokens com valor semântico (tipo <sval>) */
%token <sval> CLASS_STEREO REL_STEREO NATIVE_TYPE ID NUM STRING_LIT CARDINALITY

/* Símbolos */
%token LBRACE RBRACE LBRACKET RBRACKET COLON DOT COMMA 
%token ARROW_ASSOC ARROW_AGG ARROW_COMP ARROW_AGG_EXISTENTIAL 
%token EOF_TOKEN

%left ARROW_ASSOC ARROW_AGG ARROW_COMP

%%

/* ========================================================================== */
/* REGRAS DA GRAMÁTICA                                                        */
/* ========================================================================== */

programa:
    lista_imports lista_pacotes EOF_TOKEN { 
        // Apenas termina. O main chamará os relatórios.
    }
    ;
    
lista_imports:
    /* vazio */
    | lista_imports IMPORT ID
    ;

lista_pacotes:
    pacote
    | lista_pacotes pacote
    ;

/* ========================================================================== */
/* 1. PACOTES                                                                 */
/* ========================================================================== */
pacote:
    PACKAGE ID 
    {
        // Inicia novo contexto de pacote
        PackageInfo newPkg;
        newPkg.name = string($2);
        packages.push_back(newPkg);
        // Aponta currentPackage para o último elemento inserido
        currentPackage = &packages.back();
    }
    LBRACE conteudo_pacote RBRACE
    {
        currentPackage = nullptr; // Limpa contexto
    }
    | PACKAGE ID conteudo_pacote 
    {
        // Caso sem chaves (menos comum, mas suportado na gramática original)
        PackageInfo newPkg;
        newPkg.name = string($2);
        packages.push_back(newPkg);
    }
    ;

conteudo_pacote:
    /* vazio */
    | conteudo_pacote elemento
    ;

elemento:
    declaracao_classe
    | declaracao_datatype
    | declaracao_enum
    | declaracao_genset
    | declaracao_relacao_externa
    | declaracao_classe_subkind
    ;

/* ========================================================================== */
/* 2. CLASSES                                                                 */
/* ========================================================================== */
declaracao_classe:
    CLASS_STEREO ID opt_relation LBRACE 
    {
        if (currentPackage != nullptr) {
            ClassInfo newClass;
            newClass.name = string($2);
            newClass.stereotype = string($1);
            newClass.attributeCount = 0;
            newClass.internalRelationCount = 0;
            currentPackage->classes.push_back(newClass);
            currentClass = &currentPackage->classes.back();
        }
    }
    corpo_classe RBRACE
    {
        currentClass = nullptr;
    }
    | CLASS_STEREO ID opt_relation
    {
        if (currentPackage != nullptr) {
            ClassInfo newClass;
            newClass.name = string($2);
            newClass.stereotype = string($1);
            newClass.attributeCount = 0;
            newClass.internalRelationCount = 0;
            currentPackage->classes.push_back(newClass);
        }
    }
    ;

declaracao_classe_subkind:
    CLASS_STEREO ID OF FUNCTIONAL_COMPLEXES REL_STEREO ID
    {
         if (currentPackage != nullptr) {
            ClassInfo newClass;
            newClass.name = string($2);
            newClass.stereotype = string($1); // Provavelmente "subkind"
            currentPackage->classes.push_back(newClass);
        }
    }
    | CLASS_STEREO ID OF CLASS_STEREO REL_STEREO ID
    ;

opt_relation:
    /* vazio */
    | relation_list
    ;

relation_list:
    REL_STEREO ID
    | relation_list COMMA ID
    ;

corpo_classe:
    /* vazio */
    | lista_membros
    ;

lista_membros:
    membro_classe
    | lista_membros membro_classe
    ;

membro_classe:
    atributo
    | relacao_interna
    ;

atributo:
    ID COLON tipo_referencia 
    { 
        if (currentClass != nullptr) {
            currentClass->attributeCount++;
        }
    }
    ;

tipo_referencia:
    NATIVE_TYPE
    | ID
    ;

/* ========================================================================== */
/* 3. DATATYPES                                                               */
/* ========================================================================== */
declaracao_datatype:
    DATATYPE ID LBRACE lista_atributos RBRACE
    {
        DatatypeInfo dt;
        dt.name = string($2);
        dt.baseType = "Complexo (Struct)";
        datatypes.push_back(dt);
    }
    | DATATYPE ID
    | DATATYPE NATIVE_TYPE
    ;

lista_atributos:
    atributo
    | lista_atributos atributo
    ;

/* ========================================================================== */
/* 4. ENUMS                                                                   */
/* ========================================================================== */
declaracao_enum:
    ENUM ID LBRACE lista_enum RBRACE
    {
        // Contar quantos itens tem na lista_enum é difícil aqui sem uma ação no meio
        // Simplificação: apenas registrar o enum
        EnumInfo ei;
        ei.name = string($2);
        ei.literalCount = -1; // Indefinido nesta lógica simples
        enums.push_back(ei);
    }
    ;

lista_enum:
    ID
    | lista_enum COMMA ID
    ;

/* ========================================================================== */
/* 5. GENSETS                                                                 */
/* ========================================================================== */
declaracao_genset:
    meta_atributos GENSET ID WHERE GENERAL ID SPECIFICS lista_ids
    {
        GensetInfo gi;
        gi.name = string($3);
        gi.general = string($6);
        gensets.push_back(gi);
    }
    | meta_atributos GENSET ID LBRACE GENERAL ID SPECIFICS lista_ids RBRACE
    | GENERAL ID LBRACE meta_atributos SPECIFICS lista_ids RBRACE
    {
        GensetInfo gi;
        gi.name = "Unnamed";
        gi.general = string($2);
        gensets.push_back(gi);
    }
    ;

meta_atributos:
    /* vazio */
    | meta_atributos DISJOINT
    | meta_atributos COMPLETE
    ;

lista_ids:
    ID
    | lista_ids COMMA ID
    ;

/* ========================================================================== */
/* 6. RELAÇÕES                                                                */
/* ========================================================================== */

/* Interna */
relacao_interna:
    opt_rel_stereo relacao
    {
        if (currentClass != nullptr) {
            currentClass->internalRelationCount++;
        }
    }
    ;

relacao:
    operador_relacao ID operador_relacao cardinalidade_opt ID
    | CARDINALITY operador_relacao opt_has CARDINALITY ID
    ;

opt_has:
    /* vazio */
    | HAS operador_relacao
    ;
    
/* Externa */
declaracao_relacao_externa:
    RELATION REL_STEREO corpo_relacao_externa
    {
        RelationInfo ri;
        ri.stereotype = string($2);
        ri.type = "Externa";
        externalRelations.push_back(ri);
    }
    | RELATION corpo_relacao_externa
    {
        RelationInfo ri;
        ri.stereotype = "N/A";
        ri.type = "Externa";
        externalRelations.push_back(ri);
    }
    ;

corpo_relacao_externa:
    ID cardinalidade_opt operador_relacao ID cardinalidade_opt 
    | ID cardinalidade_opt operador_relacao CARDINALITY ID
    ;

operador_relacao:
    ARROW_ASSOC
    | ARROW_AGG
    | ARROW_COMP
    | ARROW_AGG_EXISTENTIAL
    ;

opt_rel_stereo:
    /* vazio */
    | REL_STEREO
    ;

cardinalidade_opt:
    /* vazio */
    | LBRACKET NUM RBRACKET
    | LBRACKET NUM ARROW_ASSOC NUM RBRACKET 
    | LBRACKET NUM DOT DOT NUM RBRACKET
    | CARDINALITY
    ;

%%

/* ========================================================================== */
/* CÓDIGO C++                                                                 */
/* ========================================================================== */

int yylex(void) {
    if (fscanf(tokenFile, "%d %d %s %s", 
               &lineNumber, &columnNumber, typeStr, lexeme) != 4) {
        return 0; 
    }

    string lex(lexeme);

    /* Símbolos Especiais */
    if (lex == "{") return LBRACE;
    if (lex == "}") return RBRACE;
    if (lex == "[") return LBRACKET;
    if (lex == "]") return RBRACKET;
    if (lex == ":") return COLON;
    if (lex == ",") return COMMA;
    if (lex == ".") return DOT;
    if (lex == "--") return ARROW_ASSOC;
    if (lex == "<>--") return ARROW_AGG;
    if (lex == "<o>--") return ARROW_AGG_EXISTENTIAL;
    
    /* Estereótipos de Classe (SALVA O NOME) */
    if (mapClassStereotypes.find(lex) != mapClassStereotypes.end()) {
        yylval.sval = strdup(lexeme); // IMPORTANTE: Copia string para uso no parser
        return CLASS_STEREO;
    }
    
    /* Estereótipos de Relação */
    string cleanLex = lex;
    if (lex == "@") return yylex(); 
    if (lex[0] == '@') cleanLex = lex.substr(1);
    
    if (mapRelationStereotypes.find(cleanLex) != mapRelationStereotypes.end()) {
        yylval.sval = strdup(cleanLex.c_str());
        return REL_STEREO;
    }

    /* Palavras Reservadas */
    if (mapReservedWords.find(lex) != mapReservedWords.end()) {
        return mapReservedWords[lex];
    }

    /* Tipos Nativos */
    if (mapDatatypes.find(lex) != mapDatatypes.end()) {
        yylval.sval = strdup(lexeme);
        return NATIVE_TYPE;
    }

    /* Genéricos */
    if (strcmp(typeStr, "NUM") == 0) {
        yylval.sval = strdup(lexeme);
        return NUM;
    }
    if (strcmp(typeStr, "Cardinality") == 0) {
        yylval.sval = strdup(lexeme);
        return CARDINALITY;
    }
    if (strcmp(typeStr, "EOF") == 0) return EOF_TOKEN;
    
    /* Identificadores (SALVA O NOME) */
    yylval.sval = strdup(lexeme);
    return ID;
}

/* Tratamento de Erro Melhorado */
void yyerror(const char *s) {
    ErrorInfo erro;
    erro.line = lineNumber;
    erro.col = columnNumber;
    erro.message = string(s) + " (Token: " + string(lexeme) + ")";
    
    // Sugestões simples baseadas no último token lido
    if (string(lexeme) == "}") erro.suggestion = "Verifique se fechou corretamente o bloco anterior ou se falta ponto e vírgula.";
    else if (string(lexeme) == "{") erro.suggestion = "Declaração mal formada antes do bloco.";
    else erro.suggestion = "Verifique a sintaxe ou palavras reservadas próximas.";

    errorLog.push_back(erro);
    
    // Opcional: imprimir stderr se quiser debug em tempo real
    // fprintf(stderr, "Erro linha %d: %s\n", lineNumber, s);
}

void printSynthesisReport() {
    cout << "\n========================================================" << endl;
    cout << "             RELATÓRIO DE SÍNTESE DA ONTOLOGIA            " << endl;
    cout << "========================================================" << endl;

    cout << "\n[1] ESTATÍSTICAS GERAIS" << endl;
    cout << "Pacotes encontrados: " << packages.size() << endl;
    cout << "Datatypes definidos: " << datatypes.size() << endl;
    cout << "Enums definidos:     " << enums.size() << endl;
    cout << "Gensets definidos:   " << gensets.size() << endl;
    cout << "Relações Externas:   " << externalRelations.size() << endl;

    cout << "\n[2] DETALHAMENTO POR PACOTE" << endl;
    if (packages.empty()) cout << "Nenhum pacote encontrado." << endl;
    
    for (const auto& pkg : packages) {
        cout << "+ Pacote '" << pkg.name << "':" << endl;
        cout << "  - Classes: " << pkg.classes.size() << endl;
        if (pkg.classes.empty()) {
            cout << "    (Nenhuma classe)" << endl;
        } else {
            cout << left << setw(20) << "    Nome" << setw(15) << "Stereotype" << setw(10) << "Atributos" << "Rels. Internas" << endl;
            cout << "    --------------------------------------------------------------" << endl;
            for (const auto& cls : pkg.classes) {
                cout << "    " << left << setw(20) << cls.name 
                     << setw(15) << cls.stereotype 
                     << setw(10) << cls.attributeCount 
                     << cls.internalRelationCount << endl;
            }
        }
        cout << endl;
    }

    if (!externalRelations.empty()) {
        cout << "[3] RELAÇÕES EXTERNAS" << endl;
        for (const auto& rel : externalRelations) {
            cout << "  - Stereotype: " << rel.stereotype << endl;
        }
    }
}

void printErrorReport() {
    cout << "\n========================================================" << endl;
    cout << "                 RELATÓRIO DE ERROS                     " << endl;
    cout << "========================================================" << endl;
    
    if (errorLog.empty()) {
        cout << "Nenhum erro sintático encontrado. A ontologia está válida!" << endl;
    } else {
        cout << "Total de erros encontrados: " << errorLog.size() << endl << endl;
        for (const auto& err : errorLog) {
            cout << "[ERRO] Linha " << err.line << ", Coluna " << err.col << endl;
            cout << "       Mensagem: " << err.message << endl;
            cout << "       Sugestão: " << err.suggestion << endl;
            cout << "--------------------------------------------------------" << endl;
        }
    }
    cout << "========================================================" << endl;
}

void init_maps() {
    // Mesma inicialização do seu código original...
    mapClassStereotypes = {
        {"relator", CLASS_STEREO}, {"event", CLASS_STEREO}, {"situation", CLASS_STEREO},
        {"process", CLASS_STEREO}, {"category", CLASS_STEREO}, {"mixin", CLASS_STEREO},
        {"phaseMixin", CLASS_STEREO}, {"roleMixin", CLASS_STEREO},
        {"historialRoleMixin", CLASS_STEREO}, {"kind", CLASS_STEREO},
        {"collective", CLASS_STEREO}, {"quantity", CLASS_STEREO},
        {"quality", CLASS_STEREO}, {"mode", CLASS_STEREO},
        {"intrisicMode", CLASS_STEREO}, {"extrinsicMode", CLASS_STEREO},
        {"subkind", CLASS_STEREO}, {"phase", CLASS_STEREO}, {"role", CLASS_STEREO},
        {"historicalRole", CLASS_STEREO}, {"material", CLASS_STEREO},
        {"intrinsic-modes", CLASS_STEREO}, {"relators", CLASS_STEREO}
    };

    mapRelationStereotypes = {
        {"material", REL_STEREO}, {"derivation", REL_STEREO}, {"comparative", REL_STEREO},
        {"mediation", REL_STEREO}, {"characterization", REL_STEREO},
        {"externalDependence", REL_STEREO}, {"componentOf", REL_STEREO},
        {"memberOf", REL_STEREO}, {"subCollectionOf", REL_STEREO},
        {"subQualityOf", REL_STEREO}, {"instantiation", REL_STEREO},
        {"termination", REL_STEREO}, {"participational", REL_STEREO},
        {"participation", REL_STEREO}, {"historicalDependence", REL_STEREO},
        {"creation", REL_STEREO}, {"manifestation", REL_STEREO},
        {"bringsAbout", REL_STEREO}, {"triggers", REL_STEREO},
        {"composition", REL_STEREO}, {"aggregation", REL_STEREO},
        {"inherence", REL_STEREO}, {"value", REL_STEREO}, {"formal", REL_STEREO},
        {"constitution", REL_STEREO}, {"specializes", REL_STEREO}
    };

    mapDatatypes = {
        {"number", NATIVE_TYPE}, {"string", NATIVE_TYPE}, {"boolean", NATIVE_TYPE},
        {"date", NATIVE_TYPE}, {"time", NATIVE_TYPE}, {"datetime", NATIVE_TYPE}
    };

    mapReservedWords = {
        {"package", PACKAGE}, {"import", IMPORT}, {"genset", GENSET},
        {"disjoint", DISJOINT}, {"complete", COMPLETE}, {"general", GENERAL},
        {"specifics", SPECIFICS}, {"where", WHERE},
        {"enum", ENUM}, {"datatype", DATATYPE}, {"relation", RELATION}, {"of", OF},
        {"specializes", SPECIALIZES}, {"functional-complexes", FUNCTIONAL_COMPLEXES},
        {"has", HAS}
    };
}
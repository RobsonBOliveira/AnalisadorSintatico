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

struct PackageInfo {
    string name;
    vector<ClassInfo> classes;
};

struct DatatypeInfo {
    string name;
    string baseType; 
};

struct EnumInfo {
    string name;
    int literalCount;
};

struct GensetInfo {
    string name;
    string general;
    vector<string> specifics;
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

PackageInfo* currentPackage = nullptr;
ClassInfo* currentClass = nullptr;

int yylex(void);
void yyerror(const char *s);
FILE *tokenFile;

int lineNumber, columnNumber;
char typeStr[50], lexeme[100];

unordered_map<string, int> mapReservedWords;
unordered_map<string, int> mapRelationStereotypes;
unordered_map<string, int> mapClassStereotypes;
unordered_map<string, int> mapDatatypes;

void init_maps();
void printSynthesisReport();
void printErrorReport();

%}

%union {
    char *sval;
}

/* ========================================================================== */
/* DECLARAÇÃO DE TOKENS                                                       */
/* ========================================================================== */

%token PACKAGE IMPORT GENSET DISJOINT COMPLETE GENERAL SPECIFICS WHERE FUNCTIONAL_COMPLEXES OF SPECIALIZES HAS
%token ENUM DATATYPE RELATION 
%token ORDERED CONST DERIVED SUBSETS REDEFINES

%token <sval> CLASS_STEREO REL_STEREO NATIVE_TYPE ID NUM STRING_LIT CARDINALITY MATERIAL

%token LBRACE RBRACE LBRACKET RBRACKET COLON DOT COMMA 
%token ARROW_ASSOC ARROW_AGG ARROW_COMP ARROW_AGG_EXISTENTIAL 

%type <sval> cardinalidade_opt opt_rel_stereo operador_relacao tipo_referencia opt_material

%nonassoc EMPTY_CARD   /* Prioridade Baixa: Prefere reduzir vazio */
%nonassoc CARDINALITY  /* Prioridade Alta:  Prefere deslocar (Shift) o token */

%left ARROW_ASSOC ARROW_AGG ARROW_COMP

%%

/* ========================================================================== */
/* REGRAS DA GRAMÁTICA                                                        */
/* ========================================================================== */

programa:
    lista_imports lista_pacotes
    ;
    
lista_imports:
    /* vazio */
    | lista_imports IMPORT ID
    ;

lista_pacotes:
    pacote
    | lista_pacotes pacote
    ;

pacote:
    PACKAGE ID 
    {
        PackageInfo newPkg;
        newPkg.name = string($2);
        packages.push_back(newPkg);
        currentPackage = &packages.back();
    }
    opt_brace_block
    {
        currentPackage = nullptr; 
    }
    ;

opt_brace_block:
    LBRACE conteudo_pacote RBRACE
    | conteudo_pacote
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
/* CLASSES                                                                    */
/* ========================================================================== */
declaracao_classe:
    CLASS_STEREO ID opt_specialization opt_relation_list_syntax opt_corpo_classe
    {
        if (currentPackage != nullptr) {
            bool exists = false;
            if (!currentPackage->classes.empty() && currentPackage->classes.back().name == string($2)) {
                currentClass = &currentPackage->classes.back();
                exists = true;
            }
            
            if (!exists) {
                ClassInfo newClass;
                newClass.name = string($2);
                newClass.stereotype = string($1);
                currentPackage->classes.push_back(newClass);
                currentClass = &currentPackage->classes.back();
            } else {
                currentClass->stereotype = string($1);
            }
        }
    }
    

opt_specialization:
    /* vazio */
    | SPECIALIZES lista_pais
    ;

lista_pais:
    ID 
    {
        if (currentPackage != nullptr && !currentPackage->classes.empty()) {
             currentPackage->classes.back().parents.push_back(string($1));
        }
    }
    | lista_pais COMMA ID
    {
        if (currentPackage != nullptr && !currentPackage->classes.empty()) {
             currentPackage->classes.back().parents.push_back(string($3));
        }
    }
    ;

opt_relation_list_syntax:
    /* vazio */
    | relation_list
    ;

relation_list:
    REL_STEREO ID
    | relation_list COMMA ID
    ;

opt_corpo_classe:
    /* vazio */
    | LBRACE corpo_classe RBRACE
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
    ID COLON tipo_referencia cardinalidade_opt
    { 
        if (currentClass != nullptr) {
            currentClass->attributes.push_back(string($1) + " : " + string($3));
        }
    }
    ;

tipo_referencia:
    NATIVE_TYPE { $$ = $1; }
    | ID { $$ = $1; }
    ;

declaracao_classe_subkind:
    CLASS_STEREO ID OF FUNCTIONAL_COMPLEXES SPECIALIZES ID
    {
         if (currentPackage != nullptr) {
            ClassInfo newClass;
            newClass.name = string($2);
            newClass.stereotype = string($1); 
            currentPackage->classes.push_back(newClass);
        }
    }
    | CLASS_STEREO ID OF CLASS_STEREO SPECIALIZES ID
    ;

declaracao_datatype:
    DATATYPE ID LBRACE lista_atributos RBRACE
    {
        DatatypeInfo dt;
        dt.name = string($2);
        dt.baseType = "Complexo";
        datatypes.push_back(dt);
    }
    | DATATYPE ID
    | DATATYPE NATIVE_TYPE
    ;

lista_atributos:
    atributo
    | lista_atributos atributo
    ;

declaracao_enum:
    ENUM ID LBRACE lista_enum RBRACE
    {
        EnumInfo ei;
        ei.name = string($2);
        enums.push_back(ei);
    }
    ;

lista_enum:
    ID
    | lista_enum COMMA ID
    ;

declaracao_genset:
    meta_atributos GENSET ID WHERE GENERAL ID SPECIFICS lista_ids
    {
        GensetInfo gi;
        gi.name = string($3);
        gi.general = string($6);
        gensets.push_back(gi);
    }
    | meta_atributos GENSET ID LBRACE GENERAL ID SPECIFICS lista_ids RBRACE
    {
        GensetInfo gi;
        gi.name = string($3);
        gi.general = string($6);
        gensets.push_back(gi);
    }
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
/* RELAÇÕES                                                                   */
/* ========================================================================== */

relacao_interna:
    opt_rel_stereo simple_relation
  | opt_rel_stereo cardinal_relation
  ;
  simple_relation:
      operador_relacao ID operador_relacao cardinalidade_opt ID
    {
        if (currentClass != nullptr) {
            InternalRelationInfo rel;
            rel.stereotype = ($<sval>1) ? string($1) : "";
            rel.name = string($2);
            rel.cardinality = ($4) ? string($4) : "";
            rel.targetClass = string($5);

            currentClass->internalRelations.push_back(rel);
        }
    }
    ;

cardinal_relation:
      CARDINALITY operador_relacao opt_id CARDINALITY ID
    {
        if(currentClass != nullptr) {
            InternalRelationInfo rel;
            rel.stereotype = "";
            rel.name = "";
            rel.cardinality = ($1) ? string($1) : "";
            rel.targetClass = string($5);
            
            currentClass->internalRelations.push_back(rel);
        }
    }
    ;

opt_id:
    /* vazio */
    |  field operador_relacao
    ;

field:
    ID
    | HAS
    | REL_STEREO
    ;
    
declaracao_relacao_externa:
    opt_material RELATION opt_rel_stereo corpo_relacao_externa
    {
        RelationInfo ri;
        ri.stereotype = $3 ? string($3) : "N/A";
        ri.type = "Externa";
        externalRelations.push_back(ri);
    }
    ;
corpo_relacao_externa:
    ID cardinalidade_opt operador_relacao ID cardinalidade_opt 
    | ID cardinalidade_opt operador_relacao CARDINALITY ID
    | ID cardinalidade_opt operador_relacao ID operador_relacao cardinalidade_opt ID
    ;

operador_relacao:
    ARROW_ASSOC { $$ = (char*)"--"; }
    | ARROW_AGG { $$ = (char*)"<>--"; }
    | ARROW_COMP { $$ = (char*)"<*>--"; }
    | ARROW_AGG_EXISTENTIAL { $$ = (char*)"<o>--"; }
    ;

opt_material:
    /* vazio */ { $$ = NULL; }
    | MATERIAL { $$ = $1; }
    ;

opt_rel_stereo:
    /* vazio */ { $$ = NULL; }
    | REL_STEREO { $$ = $1; }
    ;

cardinalidade_opt:
    /* vazio */ { $$ = NULL; } %prec EMPTY_CARD
    | LBRACKET NUM RBRACKET 
    { 
        string s = "[" + string($2) + "]";
        $$ = strdup(s.c_str()); 
    }
    | LBRACKET NUM ARROW_ASSOC NUM RBRACKET 
    { 
        string s = "[" + string($2) + ".." + string($4) + "]";
        $$ = strdup(s.c_str());
    }
    | LBRACKET NUM DOT DOT NUM RBRACKET
    { 
        string s = "[" + string($2) + ".." + string($5) + "]";
        $$ = strdup(s.c_str());
    }
    | CARDINALITY { $$ = $1; }
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
    if (lex == ":") return COLON;
    if (lex == ",") return COMMA;
    if (lex == ".") return DOT;
    if (lex == "--") return ARROW_ASSOC;
    if (lex == "<>--") return ARROW_AGG;
    if (lex == "<o>--") return ARROW_AGG_EXISTENTIAL;
    
    /* TRATAMENTO CORRIGIDO PARA BRACKETS e CARDINALIDADE */
    /* Se o token for exatamente "[", é LBRACKET */
    if (lex == "[") return LBRACKET;
    if (lex == "]") return RBRACKET;

    /* Se começar com "[", mas não for só "[", assume que é uma cardinalidade agrupada (ex: [1] ou [0..1]) */
    if (lex.length() > 1 && lex[0] == '[') {
         yylval.sval = strdup(lexeme);
         return CARDINALITY;
    }
    
    /* Estereótipos de Classe */
    if (mapClassStereotypes.find(lex) != mapClassStereotypes.end()) {
        yylval.sval = strdup(lexeme); 
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

    if (strcmp(typeStr, "NUM") == 0) {
        yylval.sval = strdup(lexeme);
        return NUM;
    }
    
    if (strcmp(typeStr, "EOF") == 0) return 0;
    
    /* Identificadores */
    yylval.sval = strdup(lexeme);
    return ID;
}

void yyerror(const char *s) {
    ErrorInfo erro;
    erro.line = lineNumber;
    erro.col = columnNumber;
    erro.message = string(s) + " (Token: " + string(lexeme) + ")";
    
    if (string(lexeme) == "}") erro.suggestion = "Verifique se fechou corretamente o bloco anterior.";
    else if (string(lexeme) == "{") erro.suggestion = "Declaração mal formada antes do bloco.";
    else if (string(lexeme) == "--") erro.suggestion = "Possível erro na declaração anterior (atributo ou relação incompleta).";
    else erro.suggestion = "Verifique a sintaxe ou palavras reservadas próximas.";

    errorLog.push_back(erro);
}

void printSynthesisReport() {
    cout << "\n========================================================" << endl;
    cout << "             RELATÓRIO DE SÍNTESE DA ONTOLOGIA            " << endl;
    cout << "========================================================" << endl;

    cout << "\n[1] ESTATÍSTICAS GERAIS" << endl;
    cout << "Pacotes:    " << packages.size() << endl;
    cout << "Datatypes:  " << datatypes.size() << endl;
    cout << "Gensets:    " << gensets.size() << endl;

    cout << "\n[2] DETALHAMENTO POR PACOTE E CLASSES" << endl;
    
    for (const auto& pkg : packages) {
        cout << "\nPACOTE: " << pkg.name << endl;
        cout << "--------------------------------------------------------" << endl;
        
        if (pkg.classes.empty()) {
            cout << "(Nenhuma classe neste pacote)" << endl;
        }

        for (const auto& cls : pkg.classes) {
            cout << "* Classe [" << cls.stereotype << "] " << cls.name;
            if (!cls.parents.empty()) {
                cout << " (Herda de: ";
                for (size_t i = 0; i < cls.parents.size(); ++i) {
                    cout << cls.parents[i] << (i < cls.parents.size() - 1 ? ", " : "");
                }
                cout << ")";
            }
            cout << endl;
            
            // Atributos
            if (!cls.attributes.empty()) {
                cout << "  - Atributos: ";
                for(auto at : cls.attributes) cout << at << ", ";
                cout << endl;
            }

            // Relações Internas
            if (!cls.internalRelations.empty()) {
                cout << "  - Relações Internas:" << endl;
                for(const auto& rel : cls.internalRelations) {
                    cout << "    > ";
                    if(!rel.stereotype.empty()) cout << "(@" << rel.stereotype << ") ";
                    cout << rel.name << " " << rel.cardinality << " --> " << rel.targetClass << endl;
                }
            }
            cout << endl;
        }
    }
    
    if (!gensets.empty()) {
        cout << "\n[3] GENSETS (GENERALIZAÇÕES)" << endl;
        for (const auto& gs : gensets) {
            cout << "* Genset '" << gs.name << "' (General: " << gs.general << ")" << endl;
        }
    }
}

void printErrorReport() {
    if (errorLog.empty()) {
        cout << "\n[SUCESSO] A ontologia está sintaticamente válida!" << endl;
        return;
    }

    cout << "\n========================================================" << endl;
    cout << "                 RELATÓRIO DE ERROS                     " << endl;
    cout << "Total de erros encontrados: " << errorLog.size() << endl;
    
    for (const auto& err : errorLog) {
        cout << "[ERRO] Linha " << err.line << ", Coluna " << err.col << endl;
        cout << "       " << err.message << endl;
        cout << "       Dica: " << err.suggestion << endl;
        cout << "--------------------------------------------------------" << endl;
    }
}

void init_maps() {
    mapClassStereotypes = {
        {"relator", CLASS_STEREO}, {"event", CLASS_STEREO}, {"situation", CLASS_STEREO},
        {"process", CLASS_STEREO}, {"category", CLASS_STEREO}, {"mixin", CLASS_STEREO},
        {"phaseMixin", CLASS_STEREO}, {"roleMixin", CLASS_STEREO},
        {"historialRoleMixin", CLASS_STEREO}, {"kind", CLASS_STEREO},
        {"collective", CLASS_STEREO}, {"quantity", CLASS_STEREO},
        {"quality", CLASS_STEREO}, {"mode", CLASS_STEREO},
        {"intrisicMode", CLASS_STEREO}, {"extrinsicMode", CLASS_STEREO},
        {"subkind", CLASS_STEREO}, {"phase", CLASS_STEREO}, {"role", CLASS_STEREO},
        {"historicalRole", CLASS_STEREO},{"intrinsic-modes", CLASS_STEREO}, 
        {"relators", CLASS_STEREO}
    };

    mapRelationStereotypes = {
        {"derivation", REL_STEREO}, {"comparative", REL_STEREO},
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
        {"constitution", REL_STEREO}, {"constitutedBy", REL_STEREO}
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
        {"has", HAS}, {"material", MATERIAL},
    };
}
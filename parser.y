%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include <string>
#include <unordered_map>

using namespace std;

/* Declaração de funções e variáveis externas */
int yylex(void);
void yyerror(const char *s);
FILE *tokenFile;

/* Variáveis globais para rastreamento */
int lineNumber, columnNumber;
char typeStr[50], lexeme[100];

/* Mapas para classificação rápida de tokens no yylex */
unordered_map<string, int> mapReservedWords;
unordered_map<string, int> mapRelationStereotypes;
unordered_map<string, int> mapClassStereotypes;
unordered_map<string, int> mapDatatypes;

/* Inicialização dos mapas (feita no main ou numa função init) */
void init_maps();
%}

/* União para valores semânticos (opcional, aqui simplificado para verificação sintática) */
%union {
    char *sval;
}

/* ========================================================================== */
/* DECLARAÇÃO DE TOKENS                            */
/* ========================================================================== */

/* Palavras reservadas estruturais */
%token PACKAGE IMPORT GENSET DISJOINT COMPLETE GENERAL SPECIFICS WHERE FUNCTIONAL-COMPLEXES
%token ENUM DATATYPE RELATION

/* Meta Atributos */
%token ORDERED CONST DERIVED SUBSETS REDEFINES

/* Estereótipos (Identificados pelos mapas) */
%token CLASS_STEREO        /* ex: kind, role, phase */
%token REL_STEREO          /* ex: material, componentOf */

/* Tipos primitivos */
%token NATIVE_TYPE         /* ex: string, int, boolean */

/* Símbolos e Literais */
%token ID
%token NUM STRING_LIT
%token LBRACE RBRACE       /* { } */
%token LBRACKET RBRACKET   /* [ ] */
%token COLON               /* : */
%token COMMA               /* , */
%token ARROW_ASSOC         /* -- */
%token ARROW_AGG           /* <>-- */
%token ARROW_COMP          /* <*>-- (exemplo hipotético para composição) */
%token EOF_TOKEN

%%

/* ========================================================================== */
/* REGRAS DA GRAMÁTICA                             */
/* ========================================================================== */

/* 1. O Programa é um conjunto de pacotes */
programa:
      lista_pacotes EOF_TOKEN { printf("Sucesso: Especificação TONTO sintaticamente correta.\n"); }
    ;

lista_pacotes:
      pacote
    | lista_pacotes pacote
    ;

/* 1. Declaração de Pacotes */
pacote:
      PACKAGE ID LBRACE conteudo_pacote RBRACE
    | PACKAGE ID conteudo_pacote 
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
    ;

/* 2. Declaração de Classes */
declaracao_classe:
      CLASS_STEREO ID opt_relation LBRACE corpo_classe RBRACE
    | CLASS_STEREO ID opt_relation
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
    | corpo_classe membro_classe
    ;

membro_classe:
      atributo
    | relacao_interna
    ;

atributo:
      ID COLON tipo_referencia { printf("  -> Atributo reconhecido.\n"); }
    ;

/* Helper para tipos: pode ser nativo ou um ID de classe/tipo criado */
tipo_referencia:
      NATIVE_TYPE
    | ID
    ;

/* 3. Declaração de Tipos de Dados (Datatypes derivados) */
declaracao_datatype:
      DATATYPE ID LBRACE lista_atributos RBRACE
    ;

lista_atributos:
      atributo
    | lista_atributos atributo
    ;

/* 4. Declaração de Classes Enumeradas */
declaracao_enum:
      ENUM ID LBRACE lista_enum RBRACE
    ;

lista_enum:
      ID
    | lista_enum COMMA ID
    ;

/* 5. Generalizações (Gensets) */
/* Cobre os dois casos: 'genset Name where...' e 'general Name { ... }' */
declaracao_genset:
      meta_atributos GENSET ID WHERE GENERAL ID SPECIFICS lista_ids
    | meta_atributos GENSET ID LBRACE GENERAL ID SPECIFICS lista_ids RBRACE
    | GENERAL ID LBRACE meta_atributos SPECIFICS lista_ids RBRACE
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

/* 6. Declaração de Relações */

/* Caso Interno: dentro de uma classe (Ex: componentOf <>-- Department) */
relacao_interna:
      REL_STEREO operador_relacao ID cardinalidade_opt
      { printf("  -> Relação interna reconhecida.\n"); }
    ;

/* Caso Externo: fora de classes (Ex: relation @mediation ... ) */
declaracao_relacao_externa:
      RELATION REL_STEREO corpo_relacao_externa
    ;

/* Define a estrutura solta vista no exemplo 6 */
corpo_relacao_externa:
    /* Pode ser nomeada ou não, o exemplo é flexível, assumindo estrutura básica:
       Dominio -- Imagem */
    ID cardinalidade_opt operador_relacao ID cardinalidade_opt
    ;

operador_relacao:
      ARROW_ASSOC
    | ARROW_AGG
    | ARROW_COMP
    ;

cardinalidade_opt:
      /* vazio */
    | LBRACKET NUM RBRACKET
    | LBRACKET NUM ARROW_ASSOC NUM RBRACKET /* Ex: [1..*] simplificado */
    ;

%%

/* ========================================================================== */
/* CÓDIGO C++                                  */
/* ========================================================================== */

int yylex(void) {
    /* Formato esperado: LINHA COLUNA TIPO LEXEMA */
    if (fscanf(tokenFile, "%d %d %s %s", 
               &lineNumber, &columnNumber, typeStr, lexeme) != 4) {
        return 0; // Fim do arquivo
    }

    // Debug opcional
    printf("Lendo: %s (%s)\n", lexeme, typeStr);

    string lex(lexeme);

    /* 1. Verifica Símbolos Especiais (mapeamento direto) */
    if (lex == "{") return LBRACE;
    if (lex == "}") return RBRACE;
    if (lex == "[") return LBRACKET;
    if (lex == "]") return RBRACKET;
    if (lex == ":") return COLON;
    if (lex == ",") return COMMA;
    if (lex == "--") return ARROW_ASSOC;
    if (lex == "<>--") return ARROW_AGG;
    
    /* 2. Verifica Estereótipos de Classe */
    if (mapClassStereotypes.find(lex) != mapClassStereotypes.end()) {
        return CLASS_STEREO;
    }
    
    /* 3. Verifica Estereótipos de Relação (com ou sem @) */
    string cleanLex = lex;
    if (lex[0] == '@') cleanLex = lex.substr(1); // Remove @ se existir
    if (mapRelationStereotypes.find(cleanLex) != mapRelationStereotypes.end()) {
        return REL_STEREO;
    }

    /* 4. Verifica Palavras Reservadas (package, genset, etc) */
    if (mapReservedWords.find(lex) != mapReservedWords.end()) {
        return mapReservedWords[lex];
    }

    /* 5. Verifica Tipos Nativos */
    if (mapDatatypes.find(lex) != mapDatatypes.end()) {
        return NATIVE_TYPE;
    }

    /* 6. Verifica Tokens Genéricos baseados no TIPO vindo do arquivo */
    if (strcmp(typeStr, "NUM") == 0) return NUM;
    if (strcmp(typeStr, "EOF") == 0) return EOF_TOKEN;
    
    /* Se não for nenhum dos acima e for um identificador */
    return ID;
}

void yyerror(const char *s) {
    fprintf(stderr, "Erro sintático na linha %d, coluna %d: %s (Token: %s)\n", 
            lineNumber, columnNumber, s, lexeme);
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
        {"historicalRole", CLASS_STEREO}, {"material", CLASS_STEREO},
        {"intrinsic-modes", CLASS_STEREO}
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
        {"enum", ENUM}, {"datatype", DATATYPE}, {"relation", RELATION}
    };
}
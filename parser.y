%{
#include "Parser.h"
%}
%define parse.error verbose
%union {
    char *sval;
}

/* ========================================================================== */
/* TOKENS                                                                     */
/* ========================================================================== */

%token PACKAGE IMPORT GENSET DISJOINT COMPLETE GENERAL SPECIFICS WHERE FUNCTIONAL_COMPLEXES OF SPECIALIZES HAS
%token ENUM DATATYPE RELATION 

%token <sval> CLASS_STEREO REL_STEREO NATIVE_TYPE ID NUM CARDINALITY MATERIAL

%token LBRACE RBRACE LBRACKET RBRACKET COLON DOT COMMA 
%token ARROW_ASSOC ARROW_AGG ARROW_COMP ARROW_AGG_EXISTENTIAL 

%type <sval> cardinalidade_opt opt_rel_stereo operador_relacao tipo_referencia opt_material pacote_header 

%nonassoc EMPTY_CARD   /* Prioridade Baixa: Prefere reduzir vazio */
%nonassoc CARDINALITY  /* Prioridade Alta:  Prefere deslocar (Shift) o token */

%left ARROW_ASSOC ARROW_AGG ARROW_COMP

%%

/* ========================================================================== */
/* GRAMÁTICA                                                                  */
/* ========================================================================== */

programa:
    lista_imports lista_pacotes
    ;

lista_imports:
    /* vazio */
    | lista_imports IMPORT ID
    /* Recuperação se erro */
    | lista_imports error ID { yyerrok; yyclearin; } 
    ;

lista_pacotes:
    pacote
    | lista_pacotes pacote
    ;

pacote:
    pacote_header
    {
        /* Ação executada APÓS resolver se o cabeçalho é válido ou erro */
        PackageInfo newPkg;
        if ($1) {
            newPkg.name = string($1);
        } else {
            /* Nome genérico para pacotes com erro de sintaxe */
            newPkg.name = "[Pacote_Sem_Nome_Linha_" + to_string(lineNumber) + "]";
        }
        packages.push_back(newPkg);
        currentPackage = &packages.back();
    }
    opt_brace_block
    {
        currentPackage = nullptr;
    }
    ;
pacote_header:
    PACKAGE ID { $$ = $2; }
    | PACKAGE error
    {
        yyerrok; 
        $$ = NULL; // Sinaliza que não houve nome
    }
    ;

opt_brace_block:
    LBRACE conteudo_pacote RBRACE
    | conteudo_pacote
    ;

conteudo_pacote:
    /* vazio */
    | conteudo_pacote elemento
    /* PONTO DE RECUPERAÇÃO: Se um elemento falhar, descarta até achar o próximo válido ou fechar bloco */
    | conteudo_pacote error
    ;

elemento:
    declaracao_classe
    | declaracao_datatype
    | declaracao_enum
    | declaracao_genset
    | declaracao_relacao_externa
    | declaracao_classe_subkind
    ;

/* CLASSES */
declaracao_classe:
    cabecalho_classe opt_specialization opt_relation_list_syntax opt_corpo_classe
    ;
cabecalho_classe:
    CLASS_STEREO ID
    {
        if (currentPackage != nullptr) {
            // Cria a nova classe e adiciona ao pacote agora
            ClassInfo newClass;
            newClass.name = string($2);
            newClass.stereotype = string($1);
            currentPackage->classes.push_back(newClass);
            
            // Atualiza o ponteiro currentClass para esta nova classe
            currentClass = &currentPackage->classes.back();
        }
    }
    ;
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
    /* PONTO DE RECUPERAÇÃO: Erro dentro da classe (atributo ou relação malformada) */
    | lista_membros error { yyerrok; }
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
    cabecalho_classe OF FUNCTIONAL_COMPLEXES SPECIALIZES ID
    {
        // Se desejar capturar a herança definida aqui também (o original ignorava):
        if (currentClass != nullptr) {
             currentClass->parents.push_back(string($5));
        }
    }
    |
    cabecalho_classe OF CLASS_STEREO SPECIALIZES ID
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
    meta_atributos GENSET ID WHERE GENERAL ID SPECIFICS 
    { tempSpecifics.clear(); } /* Limpa antes de ler a lista */
    lista_ids
    {
        if (currentPackage != nullptr) {
            GensetInfo gi;
            gi.name = string($3);
            gi.general = string($6);
            gi.specifics = tempSpecifics; // Salva a lista capturada
            
            currentPackage->gensets.push_back(gi);
        }
        tempSpecifics.clear();
    }
    | meta_atributos GENSET ID LBRACE GENERAL ID SPECIFICS 
    { tempSpecifics.clear(); } 
    lista_ids RBRACE
    {
        if (currentPackage != nullptr) {
            GensetInfo gi;
            gi.name = string($3);
            gi.general = string($6);
            gi.specifics = tempSpecifics;
            
            currentPackage->gensets.push_back(gi);
        }
        tempSpecifics.clear();
    }
    | GENERAL ID LBRACE meta_atributos SPECIFICS 
    { tempSpecifics.clear(); } 
    lista_ids RBRACE
    {
        if (currentPackage != nullptr) {
            GensetInfo gi;
            gi.name = "Unnamed_Genset"; // Nome padrão
            gi.general = string($2);
            gi.specifics = tempSpecifics;
            
            currentPackage->gensets.push_back(gi);
        }
        tempSpecifics.clear();
    }
    ;

meta_atributos:
    /* vazio */
    | meta_atributos DISJOINT
    | meta_atributos COMPLETE
    ;

lista_ids:
    ID 
    { tempSpecifics.push_back(string($1)); }
    | lista_ids COMMA ID
    { tempSpecifics.push_back(string($3)); }
    ;

/* RELAÇÕES */
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
    | field operador_relacao
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
    if (fscanf(tokenFile, "%d %d %s %s", &lineNumber, &columnNumber, typeStr, lexeme) != 4) {
        return 0; 
    }

    string lex(lexeme);

    /* Símbolos Especiais e Palavras Reservadas (Mantido igual ao original) */
    if (lex == "{") return LBRACE;
    if (lex == "}") return RBRACE;
    if (lex == ":") return COLON;
    if (lex == ",") return COMMA;
    if (lex == ".") return DOT;
    if (lex == "--") return ARROW_ASSOC;
    if (lex == "<>--") return ARROW_AGG;
    if (lex == "<o>--") return ARROW_AGG_EXISTENTIAL;
    
    if (lex == "[") return LBRACKET;
    if (lex == "]") return RBRACKET;

    if (lex.length() > 1 && lex[0] == '[') {
         yylval.sval = strdup(lexeme);
         return CARDINALITY;
    }
    
    if (mapClassStereotypes.find(lex) != mapClassStereotypes.end()) {
        yylval.sval = strdup(lexeme);
        return CLASS_STEREO;
    }
    
    string cleanLex = lex;
    if (lex == "@") return yylex(); 
    if (lex[0] == '@') cleanLex = lex.substr(1);

    if (mapRelationStereotypes.find(cleanLex) != mapRelationStereotypes.end()) {
        yylval.sval = strdup(cleanLex.c_str());
        return REL_STEREO;
    }

    if (mapReservedWords.find(lex) != mapReservedWords.end()) {
        return mapReservedWords[lex];
    }

    if (mapDatatypes.find(lex) != mapDatatypes.end()) {
        yylval.sval = strdup(lexeme);
        return NATIVE_TYPE;
    }

    if (strcmp(typeStr, "NUM") == 0) {
        yylval.sval = strdup(lexeme);
        return NUM;
    }
    
    if (strcmp(typeStr, "EOF") == 0) return 0;
    
    yylval.sval = strdup(lexeme);
    return ID;
}

void yyerror(const char *s) {
    ErrorInfo erro;
    erro.line = lineNumber;
    erro.col = columnNumber;
    erro.message = string(s);

    // Heurísticas de sugestão baseadas no token atual
    string currentToken = string(lexeme);
    if (currentToken == "}") {
        erro.suggestion = "Verifique se fechou corretamente o bloco anterior ou se há um ';' faltando.";
    } else if (currentToken == "{") {
        erro.suggestion = "Declaração anterior pode estar incompleta.";
    } else if (currentToken == "--" || currentToken == "<>--") {
        erro.suggestion = "Erro na definição de relação. Verifique a cardinalidade.";
    } else if (mapReservedWords.find(currentToken) != mapReservedWords.end()) {
        erro.suggestion = "Palavra reservada encontrada onde era esperado um identificador.";
    } else {
        erro.suggestion = "Verifique a sintaxe próxima a este token.";
    }

    errorLog.push_back(erro);

    // IMPRESSÃO FORMATADA "IDE STYLE" NO TERMINAL
    fprintf(stderr, ANSI_COLOR_RED);
    fprintf(stderr, "\n[ERROR] %s:%d:%d\n", currentFileName.c_str(), lineNumber, columnNumber);
    fprintf(stderr, "   %s\n", s); // Mensagem do Bison (ex: syntax error, unexpected X...)
    fprintf(stderr, ANSI_COLOR_YELLOW);
    fprintf(stderr, "   -> Lexema encontrado: '%s'\n", currentToken.c_str());
    fprintf(stderr, "   -> Sugestão: %s\n", erro.suggestion.c_str());
    fprintf(stderr, ANSI_COLOR_RESET);
}

void printSynthesisReport(string dirName) {

    string reportPath = "output/" + dirName + "/" + dirName +  "_Syntax_analysis.txt";
    reportFile.open(reportPath);
    reportFile << "\n========================================================" << endl;
    reportFile << "             RELATÓRIO DE SÍNTESE DA ONTOLOGIA            " << endl;
    reportFile << "========================================================" << endl;

    reportFile << "\n[1] ESTATÍSTICAS GERAIS" << endl;
    reportFile << "Pacotes:    " << packages.size() << endl;
    reportFile << "Datatypes:  " << datatypes.size() << endl;
    
    // Conta total de gensets somando de todos os pacotes
    int totalGensets = 0;
    for(const auto& pkg : packages) totalGensets += pkg.gensets.size();
    reportFile << "Gensets:    " << totalGensets << endl;

    reportFile << "\n[2] DETALHAMENTO POR PACOTE" << endl;
    
    for (const auto& pkg : packages) {
        reportFile << "\nPACOTE: " << pkg.name << endl;
        reportFile << "--------------------------------------------------------" << endl;
        
        if (pkg.classes.empty() && pkg.gensets.empty()) {
            reportFile << "(Pacote vazio)" << endl;
        }

        // --- CLASSES ---
        for (const auto& cls : pkg.classes) {
            reportFile << "* Classe [" << cls.stereotype << "] " << cls.name;
            if (!cls.parents.empty()) {
                reportFile << " (Herda de: ";
                for (size_t i = 0; i < cls.parents.size(); ++i) {
                    reportFile << cls.parents[i] << (i < cls.parents.size() - 1 ? ", " : "");
                }
                reportFile << ")";
            }
            reportFile << endl;

            // Atributos
            if (!cls.attributes.empty()) {
                reportFile << "  - Atributos: ";
                for(auto at : cls.attributes) reportFile << at << ", ";
                reportFile << endl;
            }

            // Relações Internas
            if (!cls.internalRelations.empty()) {
                reportFile << "  - Relações Internas:" << endl;
                for(const auto& rel : cls.internalRelations) {
                    reportFile << "    > ";
                    if(!rel.stereotype.empty()) reportFile << "(@" << rel.stereotype << ") ";
                    reportFile << rel.name << " " << rel.cardinality << " --> " << rel.targetClass << endl;
                }
            }
            reportFile << endl;
        }

        // --- GENSETS (Agora impressos dentro do pacote) ---
        if (!pkg.gensets.empty()) {
            reportFile << "  [Generalizações / Gensets]" << endl;
            for (const auto& gs : pkg.gensets) {
                reportFile << "  * Genset '" << gs.name << "'" << endl;
                reportFile << "    - General: " << gs.general << endl;
                reportFile << "    - Specifics: ";
                for (size_t i = 0; i < gs.specifics.size(); ++i) {
                    reportFile << gs.specifics[i] << (i < gs.specifics.size() - 1 ? ", " : "");
                }
                reportFile << endl << endl;
            }
        }
    }
    
    reportFile.close();
}

void printErrorReport() {
    if (!errorLog.empty()) {

        cout << ANSI_COLOR_RED << "\n[RESUMO] A análise finalizou com " << errorLog.size() << " erros." << ANSI_COLOR_RESET << endl;

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
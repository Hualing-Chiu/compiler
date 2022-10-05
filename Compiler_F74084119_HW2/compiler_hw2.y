/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #define YYDEBUG 1
    int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    typedef struct{
        char Name[10];
        char Type[10];
        char Func_sig[10];
        int Address;
        int Index;
        int Lineno;
        int Scope;
    }Table;

    Table table[100];
    char cur_type[10];
    char prev_type[10];
    char *func_sig;
    char returntype;
    int scope = 0;
    int addr = 0;
    int lookupFlag = 0;
    int index_num = 0;
    int index_scope = 0;
    int index_func = 0;
    int func_no_parameter = 0;
    int is_function = 0;
    int diff_type = 0;
    int conversion = 0;
    int condition_error = 0;
    int undefined_error = 0;
    int param_len;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_symbol();
    static void insert_symbol();
    static void lookup_symbol();
    static void dump_symbol();
    static void insert_function();
    char *get_type(char *target);

    /* Global variables */
    bool HAS_ERROR = false;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    char *id_name;
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token ADD SUB MUL REM INC DEC LOR LAND NOT QUO
%token GTR LSS GEQ LEQ EQL NEQ
%token ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token LPAREN RPAREN LBRACK RBARCK LBRACE RBRACE
%token SEMICOLON COMMA COLON
%token IF ELSE FOR SWITCH CASE DEFAULT
%token PRINT PRINTLN
%token TRUE FALSE
%token FUNC PACKAGE RETURN

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type Literal parameterList
%type <s_val> LBRACE_RE RBRACE_RE
%type <s_val> Expression UnaryExpr PrimaryExpr ConversionExpr
%type <s_val> Expression_mul_op Expression_cmp_op Expression_LAND Expression_add_op
%type <s_val> Operand FuncCall
%type <s_val> cmp_op add_op mul_op unary_op assign_op

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%
// insert_symbol("func",cur_type,yylineno,"()V");
Program
    : GlobalStatementList { dump_symbol(); }
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;
GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE 
;

PackageStmt
    : PACKAGE IDENT { create_symbol(); printf("package: %s\n",$2); }
;

FunctionDeclStmt
    : FuncOpen LPAREN parameterList L_R_function FuncBlock 
;

FuncOpen
    : FUNC IDENT { 
        printf("func: %s\n", $2); 
        strncpy(cur_type,$2,10); 
        is_function = 1;
        func_sig = malloc(sizeof(char));
        func_sig[0] = '(';
        param_len = 1;
        create_symbol();
    }
;

parameterList
    : IDENT Type {
        printf("param %s, type: %c\n",$1,$2[0] - 'a' + 'A');
        func_sig = realloc(func_sig, sizeof(char) * (++param_len));
        func_sig[param_len-1] = $2[0] - 'a' + 'A';
        insert_symbol($2,$1,yylineno+1,"-"); 
    }
    | parameterList COMMA IDENT Type {
        printf("param %s, type: %c\n",$3,$4[0] - 'a' + 'A');
        func_sig = realloc(func_sig, sizeof(char) * (++param_len));
        func_sig[param_len-1] = $4[0] - 'a' + 'A';
        insert_symbol($4,$3,yylineno+1,"-"); 
    }
    | { func_no_parameter = 1; }
;

L_R_function
    : RPAREN ReturnType {
        param_len += 3;
        func_sig = realloc(func_sig, sizeof(char) * param_len);
        func_sig[param_len-3] = ')';
        func_sig[param_len-2] = returntype;
        func_sig[param_len-1] = '\0';
        printf("func_signature: %s\n",func_sig);
        insert_function("func",cur_type,yylineno,func_sig); 
    }
;

ReturnType
    : Type { returntype = $1[0]-'a'+'A'; }
    | { returntype = 'V'; }
;

FuncBlock
    : LBRACE StatementList RBRACE_RE
;

LBRACE_RE
    : LBRACE NEWLINE { 
        create_symbol(); 
        index_scope = 0;
    }
;

RBRACE_RE
    : RBRACE { dump_symbol();}
;

StatementList
    : StatementList Statement
    | Statement
;

Statement
    : DeclarationStmt NEWLINE
    | SimpleStmt NEWLINE 
    | Block 
    | IfStmt
    | ForStmt
    | SwitchStmt
    | CaseStmt
    | PrintStmt NEWLINE 
    | ReturnStmt NEWLINE
    | NEWLINE { conversion = 0; }
;

SimpleStmt
    : AssignmentStmt
    | ExpressionStmt
    | IncDecStmt
;

DeclarationStmt
    : VAR IDENT Type Assign_or_not { insert_symbol($3, $2, yylineno,"-"); }
;

Assign_or_not
    : ASSIGN Expression
    | 
;

AssignmentStmt
    : Expression assign_op Expression {
        char temp[100];
        if(diff_type == 1 && conversion == 0 && undefined_error == 0){ // different type
            sprintf(temp,"invalid operation: %s (mismatched types %s and %s)", $2, prev_type, cur_type);
            yyerror(temp);
        }
        if(undefined_error == 1){
            printf("error:%d: invalid operation: %s (mismatched types ERROR and %s)\n",yylineno,$2,cur_type);
            undefined_error = 0;
        }
        printf("%s\n",$2);
    }
;

IncDecStmt
    : Expression INC { printf("INC\n"); }
    | Expression DEC { printf("DEC\n"); }
;

Block
    : LBRACE_RE StatementList RBRACE { dump_symbol(); }
;

IfStmt
    : IF Condition Block Else_or_not
;

Else_or_not
    : ELSE Block
    | ELSE IfStmt
    |
;

Condition
    : Expression {
        if(strcmp(cur_type,"bool") != 0){
            printf("error:%d: non-bool (type %s) used as for condition\n",yylineno+1,cur_type);
        }
    }
;

ForStmt
    : FOR ForClause Block
    | FOR Condition Block
;

ForClause
    : InitStmt SEMICOLON Condition SEMICOLON PostStmt
;

InitStmt
    : SimpleStmt
;

PostStmt
    : SimpleStmt
;

SwitchStmt
    : SWITCH Expression Block
;

CaseStmt
    : Case_int COLON Block
    | DEFAULT COLON Block
;

Case_int
    : CASE INT_LIT { printf("case %d\n",$2); }
;

ReturnStmt
    : RETURN Expression { printf("%creturn\n",cur_type[0]);}
    | RETURN { printf("return\n"); }
;

PrintStmt
    : PRINT LPAREN Expression RPAREN { printf("PRINT %s\n", cur_type); }
    | PRINTLN LPAREN Expression RPAREN { printf("PRINTLN %s\n", cur_type); }
;

Type
    : INT { $$ = "int32"; }
    | FLOAT { $$ = "float32"; }
    | STRING { $$ = "string"; }
    | BOOL { $$ = "bool"; }
;

ExpressionStmt
    : Expression
;

Expression
    : Expression LOR Expression_LAND { 
         char temp[100];
        if(strcmp(cur_type,"bool") != 0){
            sprintf(temp,"invalid operation: (operator LOR not defined on %s)", cur_type);
            yyerror(temp);
        }else if(diff_type == 1){
            sprintf(temp,"invalid operation: (operator LOR not defined on %s)", prev_type);
            yyerror(temp);
        }
        printf("LOR\n");
    }
    | Expression_LAND
;

Expression_LAND
    : Expression_LAND LAND Expression_cmp_op { 
        char temp[100];
        if(strcmp(cur_type,"bool") != 0){
            sprintf(temp,"invalid operation: (operator LAND not defined on %s)", cur_type);
            yyerror(temp);
        }else if(diff_type == 1){
            sprintf(temp,"invalid operation: (operator LAND not defined on %s)", prev_type);
            yyerror(temp);
        }
        printf("LAND\n");
    }
    | Expression_cmp_op
;

Expression_cmp_op
    : Expression_cmp_op cmp_op Expression_add_op {
        if(undefined_error == 1){
            printf("error:%d: invalid operation: %s (mismatched types ERROR and int32)\n",yylineno+1,$2);
            undefined_error = 0;
        }
        printf("%s\n", $<s_val>2); 
        strncpy(cur_type, "bool",10);
    }
    | Expression_add_op
;

Expression_add_op
    : Expression_add_op add_op Expression_mul_op { 
        char temp[100];
        if(diff_type == 1 && conversion == 0){ // different type
            sprintf(temp,"invalid operation: %s (mismatched types %s and %s)", $2, prev_type, cur_type);
            yyerror(temp);
        }
        printf("%s\n", $<s_val>2); 
    }
    | Expression_mul_op
;

Expression_mul_op
    :Expression_mul_op mul_op UnaryExpr { 
        char temp[100];
        if(strcmp($2, "REM") == 0){
            if(strcmp(prev_type,"float32") == 0 || strcmp(cur_type,"float32") == 0){
                printf("error:%d: invalid operation: (operator REM not defined on float32)\n",yylineno);
            }
        }

        printf("%s\n", $<s_val>2); 
    }
    | UnaryExpr
;

UnaryExpr
    : PrimaryExpr
    | unary_op UnaryExpr { printf("%s\n", $<s_val>1); }
;

PrimaryExpr
    : Operand
    | ConversionExpr
    | FuncCall
;

Operand
    : Literal
    | IDENT { lookup_symbol($<id_name>1); }
    | LPAREN Expression RPAREN { $$ = $2; }
;

ConversionExpr // 型態轉換
    : Type LPAREN Expression RPAREN {
        conversion = 1;
        if(strcmp($1, "int32") == 0){ // int32
            // strncpy(cur_type,"int32",10);
            printf("f");
        }else if(strcmp($1, "float32") == 0) // float32
            // strncpy(cur_type,"float32",10);
            printf("i");
        printf("2");
        if(strcmp(cur_type, "int32") == 0){ // 變數是int
            // strncpy(cur_type,"int32",10);
            printf("f");
        }else if(strcmp(cur_type, "float32") == 0)
            // strncpy(cur_type,"float32",10);
            printf("i");
        printf("\n");
    }
;

Literal
    : INT_LIT { 
        printf("INT_LIT %d\n", $<i_val>1); 
        if(strcmp(cur_type, "int32") == 0){
            diff_type = 0;
        }else{
            diff_type = 1;
            strncpy(prev_type,cur_type,10);
        }
        strncpy(cur_type,"int32",10); 
        $$ = "int32"; 
    }
    | FLOAT_LIT { 
        printf("FLOAT_LIT %f\n", $<f_val>1); 
        if(strcmp(cur_type, "float32") == 0){
            diff_type = 0;
        }else{
            diff_type = 1;
            strncpy(prev_type,cur_type,10);
        }
        strncpy(cur_type,"float32",10); 
        $$ = "float32"; 
    }
    | '"' STRING_LIT '"' { 
        printf("STRING_LIT %s\n", $<s_val>2); 
        if(strcmp(cur_type, "string") == 0){
            diff_type = 0;
        }else{
            diff_type = 1;
            strncpy(prev_type,cur_type,10);
        }
        strncpy(cur_type,"string",10); 
    }
    | TRUE { 
        printf("TRUE 1\n"); 
        if(strcmp(cur_type, "bool") == 0){
            diff_type = 0;
        }else{
            diff_type = 1;
            strncpy(prev_type,cur_type,10);
        }
        strncpy(cur_type,"bool",10);
    }
    | FALSE { 
        printf("FALSE 0\n");
        if(strcmp(cur_type, "bool") == 0){
            diff_type = 0;
        }else{
            diff_type = 1;
            strncpy(prev_type,cur_type,10);
        }
        strncpy(cur_type,"bool",10);
    }
;

FuncCall
    : IDENT LPAREN parameter_or_not RPAREN {
        for(int i=0;i<index_num;i++){
            if(table[i].Scope == 0 && strcmp($1,table[i].Name) == 0){
                printf("call: %s%s\n",table[i].Name,table[i].Func_sig);
                break;
            }
        }
    }
;

parameter_or_not
    : Expression COMMA parameter_or_not
    | Expression
    |
;

assign_op
    : ASSIGN { $$ = "ASSIGN";}
    | ADD_ASSIGN { $$ = "ADD"; }
    | SUB_ASSIGN { $$ = "SUB";}
    | MUL_ASSIGN { $$ = "MUL";}
    | QUO_ASSIGN { $$ = "QUO";}
    | REM_ASSIGN { $$ = "REM";}
;

cmp_op
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; }
    | LSS { $$ = "LSS"; }
    | LEQ { $$ = "LEQ"; }
    | GTR { $$ = "GTR"; }
    | GEQ { $$ = "GEQ"; }
;

add_op
    : ADD { $$ = "ADD"; }
    | SUB { $$ = "SUB"; }
;

mul_op
    : MUL { $$ = "MUL"; }
    | QUO { $$ = "QUO"; }
    | REM { $$ = "REM"; }
;

unary_op
    : ADD { $$ = "POS"; }
    | SUB { $$ = "NEG"; }
    | NOT { $$ = "NOT"; }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    strncpy(cur_type,"",10);
    strncpy(prev_type,"",10);

    yylineno = 0;
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    return 0;
}

static void create_symbol() {
    printf("> Create symbol table (scope level %d)\n", scope);
    scope++;
    // strncpy(cur_type,"",10);
    // table[index_num].Scope = scope;
    // if(func_no_parameter == 1 && is_function == 1){
    //     printf("func_signature: ()V\n");
    // }
    index_scope = 0;
}

static void insert_function(char *type,char *name,int lineno,char *f_sig){
    strcpy(table[index_num].Name, name);
    strcpy(table[index_num].Type, type);
    strcpy(table[index_num].Func_sig, f_sig);
    table[index_num].Index = index_func;
    table[index_num].Scope = 0;
    table[index_num].Lineno = lineno+1;
    table[index_num].Address = -1;
    printf("> Insert `%s` (addr: %d) to scope level %d\n", table[index_num].Name, table[index_num].Address, table[index_num].Scope);

    index_num++;
    index_func++;

}
static void insert_symbol(char *type,char *name,int lineno,char *f_sig) {
    char temp[100];
    for(int i=0;i<index_num;i++){ // check if redeclared
        if(strcmp(name,table[i].Name) == 0 && table[i].Scope == scope - 1){
            printf("error:%d: %s redeclared in this block. previous declaration at line %d\n",yylineno,name,table[i].Lineno);
        }
    }
    strcpy(table[index_num].Name, name);
    strcpy(table[index_num].Type, type);
    strcpy(table[index_num].Func_sig, f_sig);
    table[index_num].Index = index_scope;
    table[index_num].Scope = scope - 1;
    table[index_num].Lineno = lineno;
    table[index_num].Address = addr;
    printf("> Insert `%s` (addr: %d) to scope level %d\n", table[index_num].Name, table[index_num].Address, table[index_num].Scope);

    addr++;
    index_num++;
    index_scope++;
    is_function = 0;
}

static void lookup_symbol(char *name) {
    char temp[100];
    int s = scope;
    // printf("index_num = %d\n",index_num);
    while(s >= 0){
        if(lookupFlag == 1){
            break;
        }else{
            for(int i=0;i<index_num;i++){
                if(strcmp(table[i].Name, name) == 0 && table[i].Scope == s){
                    lookupFlag = 1;
                    printf("IDENT (name=%s, address=%d)\n",table[i].Name, table[i].Address);
                    if(strcmp(table[i].Type,cur_type) == 0){
                        diff_type = 0;
                        strncpy(prev_type,cur_type,10);
                    }else{
                        diff_type = 1;
                        strncpy(prev_type,cur_type,10);
                    }
                    strncpy(cur_type,table[i].Type,10);
                }
            }
        }
        s--;
    }
    if(lookupFlag == 0){
            printf("error:%d: undefined: %s\n",yylineno+1,name);
            undefined_error = 1;
        }
    lookupFlag = 0;
}

static void dump_symbol() {
    scope--;
    printf("\n> Dump symbol table (scope level: %d)\n", scope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
    for(int i=0;i<index_num;i++){
        if(table[i].Scope == scope){
             printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
            table[i].Index, table[i].Name, table[i].Type, table[i].Address, table[i].Lineno, table[i].Func_sig);
            table[i].Scope = -1;
        }
    }
    printf("\n");
}
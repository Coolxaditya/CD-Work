%{
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>
#include <string>
#include <utility>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include "SymbolTable.cpp"

using namespace std;

int yyparse(void);
int yylex(void);

FILE *fp;
ofstream errors("error.txt");
ofstream logs("logs.txt");
int line_count = 1;
int error_count = 0;
int labelCount = 0;
int tempCount = 0;
extern FILE *yyin;

SymbolTable* symbolTable = new SymbolTable(logs.rdbuf(), 10);
string tempType;
vector<string> tempParameterList;
vector<string> tempParameterTypeList;
vector<string> ASM_varlist;
vector<pair<string, string>> ASM_arrlist;
vector<pair<string, string>> tempDeclareList;
vector<SymbolInfo*> tempArgList;
string tempCode = "";
string tempFuncName;
bool isPrintln = false;

const string printlnCode =
const string printlnCode =
    "PRINT_FUNC PROC\n"
    "    PUSH AX\n"
    "    PUSH BX\n"
    "    PUSH CX\n"
    "    PUSH DX\n"
    "    CMP AX,0\n"
    "    JGE BEGIN\n"
    "    PUSH AX\n"
    "    MOV DL,'-'\n"
    "    MOV AH,2\n"
    "    INT 21H\n"
    "    POP AX\n"
    "    NEG AX\n"
    "BEGIN:\n"
    "    XOR CX,CX\n"
    "    MOV BX,10\n"
    "REPEAT:\n"
    "    XOR DX,DX\n"
    "    DIV BX\n"
    "    PUSH DX\n"
    "    INC CX\n"
    "    OR AX,AX\n"
    "    JNE REPEAT\n"
    "    MOV AH,2\n"
    "PRINT_LOOP:\n"
    "    POP DX\n"
    "    ADD DL,30H\n"
    "    INT 21H\n"
    "    LOOP PRINT_LOOP\n"
    "    MOV AH,2\n"
    "    MOV DL,10\n"
    "    INT 21H\n"
    "    MOV DL,13\n"
    "    INT 21H\n"
    "    POP DX\n"
    "    POP CX\n"
    "    POP BX\n"
    "    POP AX\n"
    "    ret\n"
    "PRINT_FUNC ENDP\n";

string newLabel() {
    return "Label" + to_string(labelCount++);
}

string newTemp() {
    return "T" + to_string(tempCount++);
}

void reportError(const string& msg) {
    error_count++;
    errors << "Line no " << line_count << " : " << msg << endl;
}

string refactor(string str) {
    int ii = 0;
    for (int i = 0; i < str.length(); i++) {
        if (str[i] == ',') str[i] = ' ';
        if (str[i] != '\t' && str[i] != '\n' && str[i] != '\0')
            str[ii++] = str[i];
    }
    str.resize(ii);
    return str;
}

bool compare_line(const string& lhs, const string& rhs) {
    string one = refactor(lhs);
    string two = refactor(rhs);
    vector<string> tokens1, tokens2;
    stringstream check1(one), check2(two);
    string intermediate;
    while (getline(check1, intermediate, ' ')) tokens1.push_back(intermediate);
    while (getline(check2, intermediate, ' ')) tokens2.push_back(intermediate);
    if (tokens1.size() == 3 && tokens2.size() == 3) {
        if (tokens1[0] == "MOV" && tokens2[0] == "MOV") {
            return tokens1[1] == tokens2[2] && tokens2[1] == tokens1[2];
        }
    }
    return false;
}

void yyerror(const char *s) {
    reportError(s);
}
%}

%token PREPROCESSOR ARROW SCOPE DOT STRING_LITERAL IF ELSE FOR WHILE DO BREAK STRING ID PRINTLN INT FLOAT CHAR DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE CONST_INT CONST_FLOAT CONST_CHAR ADDOP MULOP INCOP RELOP ASSIGNOP LOGICOP BITOP NOT DECOP LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON

%left RELOP LOGICOP BITOP
%left ADDOP
%left MULOP

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%union {
    SymbolInfo* s;
}

%type <s> start

%%

start : program
{
    ofstream fout("code.asm");
    ofstream ffout("optimized_code.asm");
    string outputCODE;
    outputCODE += ".MODEL SMALL \n.STACK 100H \n.DATA \n";
    for (const auto& v : ASM_varlist)
        outputCODE += v + " DW ? \n";
    for (const auto& arr : ASM_arrlist)
        outputCODE += arr.first + " dw " + arr.second + " dup(?)\n";
    outputCODE += ".CODE\n";
    outputCODE += $<s>1->getASMcode();
    if (isPrintln) outputCODE += printlnCode;
    outputCODE += "END MAIN\n";
    fout << outputCODE << endl;
    outputCODE.clear();

    // Optimization
    vector<string> code_lines;
    ifstream input("code.asm");
    for (string line; getline(input, line);)
        code_lines.push_back(line);
    int total_lines = code_lines.size();
    vector<bool> isOpt(total_lines, true);
    for (int i = 0; i < total_lines - 1; i++)
        if (compare_line(code_lines[i], code_lines[i + 1]))
            isOpt[i + 1] = false;
    for (int i = 0; i < total_lines; i++)
        if (isOpt[i]) outputCODE += code_lines[i] + "\n";
    ffout << outputCODE;
}
;

program : program unit
{
    $<s>$ = new SymbolInfo();
    logs << "Line at " << line_count << " : program->program unit\n\n";
    logs << $<s>1->getName() << " " << $<s>2->getName() << "\n\n";
    $<s>$->setName($<s>1->getName() + $<s>2->getName());
    $<s>$->setASMcode($<s>1->getASMcode() + $<s>2->getASMcode());
    delete $<s>1; delete $<s>2;
}
| unit
{
    $<s>$ = new SymbolInfo();
    logs << "Line at " << line_count << " : program->unit\n\n";
    logs << $<s>1->getName() << "\n\n";
    $<s>$->setName($<s>1->getName());
    $<s>$->setASMcode($<s>1->getASMcode());
    delete $<s>1;
}
;

// ...existing rules...
// (Paste your rules here, updating as above: use std::string, clear temp vectors after use, use reportError, delete SymbolInfo* objects after use, etc.)

%%

int main(int argc, char *argv[]) {
    if ((fp = fopen(argv[1], "r")) == NULL) {
        cout << "Cannot Open Input File." << endl;
        exit(1);
    }
    yyin = fp;
    yyparse();
    fclose(fp);
    logs << "Total Line : " << line_count << " \nTotal errors : " << error_count << "  \n\n";
    errors << "Total Line : " << line_count << " \nTotal errors : " << error_count << "  \n\n";
    errors.close();
    logs.close();
    // Clean up SymbolInfo* objects in tempArgList, tempDeclareList, etc. if needed
    return 0;
}
%option noyywrap

%{
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <unordered_map>
#include "SymbolTable.cpp"
#include "y.tab.h"

using namespace std;

extern int error_count;
extern int line_count;
extern FILE *errors;

inline void IncLine() { ++line_count; }
inline void IncError() { ++error_count; }

inline int make_token(const char* text, const char* type, int token_type) {
    yylval.s = new SymbolInfo(text, type);
    return token_type;
}

// Use static const unordered_map for thread-safety and efficiency
static const unordered_map<string, int> keywords = {
    {"if", IF}, {"else", ELSE}, {"for", FOR}, {"while", WHILE}, {"do", DO},
    {"break", BREAK}, {"continue", CONTINUE}, {"int", INT}, {"char", CHAR},
    {"float", FLOAT}, {"double", DOUBLE}, {"void", VOID}, {"return", RETURN},
    {"switch", SWITCH}, {"case", CASE}, {"default", DEFAULT}, {"println", PRINTLN}
};
%}

Letter          [a-zA-Z]
Digit           [0-9]
HexDigit        [0-9a-fA-F]
Newline         \n
WhiteSpace      [ \t\f\r\v]

%%

"#".*                       { return PREPROCESSOR; }
{WhiteSpace}+               { /* skip whitespace */ }
{Newline}                   { IncLine(); }

"//".*                      { IncLine(); /* skip single-line comment */ }

// Improved multi-line comment handling
"/*"([^*]|\*+[^*/])*\*+"/"  {
    for (int i = 0; i < yyleng; ++i)
        if (yytext[i] == '\n') IncLine();
}

"++"                        { return INCOP; }
"--"                        { return DECOP; }

"=="|"!="|"<="|">="|"<"|">" { return make_token(yytext, "RELOP", RELOP); }
"="                         { return ASSIGNOP; }
"&&"|"||"                   { return make_token(yytext, "LOGICOP", LOGICOP); }
"!"                         { return NOT; }
"("                         { return LPAREN; }
")"                         { return RPAREN; }
"{"                         { return LCURL; }
"}"                         { return RCURL; }
"["                         { return LTHIRD; }
"]"                         { return RTHIRD; }
","                         { return COMMA; }
";"                         { return SEMICOLON; }
"->"                        { return ARROW; }
"::"                        { return SCOPE; }
"."                         { return DOT; }
"+"|"-"                     { return make_token(yytext, "ADDOP", ADDOP); }
"*"|"/"|"%"                 { return make_token(yytext, "MULOP", MULOP); }
"0[xX]{HexDigit}+"          { return make_token(yytext, "CONST_HEX", CONST_INT); }
"0[0-7]*"                   { return make_token(yytext, "CONST_OCT", CONST_INT); }
{Digit}+                    { return make_token(yytext, "CONST_INT", CONST_INT); }
({Digit}+(\.{Digit}*)?|\.{Digit}+)([eE][-+]?{Digit}+)? { return make_token(yytext, "CONST_FLOAT", CONST_FLOAT); }
"'"([^'\\]|\\[abfnrtv0'\"\\])"'" { return make_token(yytext, "CONST_CHAR", CONST_CHAR); }
\"([^\\\"\n]|\\.)*\"        { return make_token(yytext, "STRING_LITERAL", STRING_LITERAL); }

// Optimized identifier/keyword handling
({Letter}|_)({Letter}|{Digit}|_)* {
    auto it = keywords.find(yytext);
    if (it != keywords.end()) {
        yylval.s = new SymbolInfo(yytext, "KEYWORD");
        return it->second;
    } else {
        yylval.s = new SymbolInfo(yytext, "ID");
        return ID;
    }
}

. {
    fprintf(errors, "Unrecognized token: %s at line %d\n", yytext, line_count);
    IncError();
}
%%
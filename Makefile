# Makefile for CPP Compiler using Flex and Bison

# File names
LEX_FILE = tokenizers.l
YACC_FILE = compiler.y
OUTPUT = a.out
INPUT = input.cpp

# Generated files
LEX_C = lex.yy.c
YACC_C = y.tab.c
YACC_H = y.tab.h
YACC_O = y.o
LEX_O = l.o

# Compiler and flags
CXX = g++
CXXFLAGS = -w
FALLBACK_FLAGS = -fpermissive -w
LIBS = -lfl

# Default target
.PHONY: all clean build run
all: run

# Build only
build: $(OUTPUT)

# Final executable
$(OUTPUT): $(YACC_O) $(LEX_O)
	$(CXX) -o $@ $^ $(LIBS)

# Object files
$(YACC_O): $(YACC_C)
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(LEX_O): $(LEX_C)
	@$(CXX) $(CXXFLAGS) -c -o $@ $< || \
	$(CXX) $(FALLBACK_FLAGS) -c -o $@ $<

# Generated C files
$(YACC_C) $(YACC_H): $(YACC_FILE)
	bison -d -y -v $<

$(LEX_C): $(LEX_FILE)
	flex $<

# Run the output
run: build
	./$(OUTPUT) $(INPUT)

# Cleanup
clean:
	rm -f $(OUTPUT) $(LEX_C) $(YACC_C) $(YACC_H) $(YACC_O) $(LEX_O) y.output error.txt logs.txt

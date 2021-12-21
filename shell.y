
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>
#include <string.h>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT LESS PIPE AMP GREATGREAT GREATAMP GREATGREATAMP TWOGREAT NEWLINE

%{
//#define yylex yylex
#define MAXFILENAME 1024
#include <cstdio>
#include "shell.hh"
#include <regex.h>
#include <dirent.h>
void expandWildcardsIfNecessary(char *arg);
void expandWildcard(char *prefix, char *suffix);
void yyerror(const char * s);
int yylex();

bool multipleOut = 0;
%}

%%

goal:
  commands
  ;

commands:
  command
  | commands command
  ;

command: simple_command
       ;

simple_command:	
  pipe_list iomodifier_list background_opt NEWLINE {
    //printf("   Yacc: Execute command\n");
    if (multipleOut == 0) {
      Shell::_currentCommand.execute();
    } else {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
      Shell::prompt();
    }
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

pipe_list:
  pipe_list PIPE command_and_args
  | command_and_args
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    expandWildcardsIfNecessary((char*)$1->c_str());
    //Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_list:
  iomodifier_list iomodifier_opt
  |
  ;

iomodifier_opt:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile == 0) {
      Shell::_currentCommand._outFile = $2;
    } else {
      multipleOut = 1;
    }
  }
  | LESS WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | GREATGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile == 0) {
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._append = 1;
    } else {
      multipleOut = 1;
    }
  }
  | TWOGREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._errFile == 0) {
      Shell::_currentCommand._errFile = $2;
    } else {
      multipleOut = 1;
    }
  }
  | GREATAMP WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile == 0 && Shell::_currentCommand._outFile == 0) {
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = new std::string(*$2);
    } else {
      multipleOut = 1;
    }
  }
  | GREATGREATAMP WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile == 0 && Shell::_currentCommand._outFile == 0) {
      Shell::_currentCommand._outFile = $2;
      Shell::_currentCommand._errFile = new std::string(*$2);
      Shell::_currentCommand._append = 1;
    } else {
      multipleOut = 1;
    }
  } /* can be empty */ 
  ;

background_opt:
  AMP {
    Shell::_currentCommand._background = 1;
  }
  |
  ;

%%

int maxEntries;
int nEntries;
char ** array;


void expandWildcardsIfNecessary(char *arg) {
  if (!strchr(arg, '*') && !strchr(arg, '?')) {
    Command::_currentSimpleCommand->insertArgument(new std::string(arg));
    return;
  } else if (!strchr(arg, '/')) {
    char * reg = (char*)malloc(2*strlen(arg)+10);
    char * a = arg;
    char * r = reg;
    *r = '^';
    r++;
    while (*a) {
      if (*a == '*') { *r='.'; r++; *r='*'; r++; }
      else if (*a == '?') { *r='.'; r++;}
      else if (*a == '.') { *r='\\'; r++; *r='.'; r++;}
      else { *r=*a; r++;}
      a++;
    }
    *r='$';
    r++;
    *r=0;
 
    regex_t re;
    int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
    //if (!expbuf) {
    //perror("compile");
    //return;
    //}

    DIR * dir = opendir(".");
    if (dir == NULL) {
      perror("opendir");
      return;
    }
  
    regmatch_t match;
    struct dirent * ent;
    maxEntries = 20;
    nEntries = 0;
    array = (char**) malloc(maxEntries*sizeof(char*));

    while ( (ent = readdir(dir))!= NULL) {
      if (regexec(&re, ent->d_name, 1, &match, 0) ==0 ) {
        if (nEntries == maxEntries) {
          maxEntries *=2;
          array = (char**) realloc(array, maxEntries*sizeof(char*));
        }
        if (ent->d_name[0] == '.') {
          if (arg[0] == '.') {
            array[nEntries] = strdup(ent->d_name);
            nEntries++;
          }
        } else {
          array[nEntries]= strdup(ent->d_name);
          nEntries++;
        }
      }
    }
    closedir(dir);
    regfree(&re);
    free(reg);

  } else {
    maxEntries = 20;
    nEntries = 0;
    array = (char**) malloc(maxEntries*sizeof(char*));
    expandWildcard("", arg);
    if (array[0] == NULL) {
      Command::_currentSimpleCommand->insertArgument(new std::string(arg));
      return;
    }
  }


  qsort(array, nEntries, sizeof(char *),[] (const void *a, const void *b){
         return strcmp(*(const char **)a, *(const char **)b); 
        });
  for (int i = 0; i < nEntries; i++) {
    Command::_currentSimpleCommand->insertArgument(new std::string(array[i]));
    free(array[i]);
  }
  free(array);
}




void expandWildcard(char * prefix, char * suffix) {
  if (suffix[0] == 0) {
    if (nEntries == maxEntries) {
      maxEntries *= 2;
      array = (char**) realloc(array, maxEntries*sizeof(char*));
    }
    prefix++;
    array[nEntries] = strdup(prefix);
    nEntries++;
    return;
  }
  int shift = 0;
  if (suffix[0] == '/') {
    shift = sizeof(char);
  }
  char * s = strchr(suffix, '/');
  char component[MAXFILENAME];
  if (s != NULL){
    strncpy(component + shift, suffix, s-suffix);
    suffix = s + 1;
  }
  else {
    strcpy(component, suffix);
    suffix = suffix + strlen(suffix);
  }

  char newPrefix[MAXFILENAME];
  if (!strchr(component, '*') && !strchr(component, '?')) {
    sprintf(newPrefix,"%s/%s", prefix, component);
    expandWildcard(newPrefix, suffix);
    return;
  }

  char * reg = (char*)malloc(2*strlen(component)+10);
  char * a = component;
  char * r = reg;
  *r = '^';
  r++;
  while (*a) {
    if (*a == '*') { *r='.'; r++; *r='*'; r++; }
    else if (*a == '?') { *r='.'; r++;}
    else if (*a == '.') { *r='\\'; r++; *r='.'; r++;}
    else { *r=*a; r++;}
    a++;
  }
  *r='$';
  r++;
  *r=0;

  regex_t re;
  int expbuf = regcomp(&re, reg, REG_EXTENDED|REG_NOSUB);
  char * dir;
  if (prefix==NULL) {
    dir ="."; 
  } else {
    dir=prefix;
  }

  DIR * d = opendir(dir);
  if (d==NULL) {
    return;
  }


  struct dirent * ent;
  regmatch_t match;
  while ((ent = readdir(d)) != NULL) {
    if (regexec(&re, ent->d_name, 1, &match, 0) == 0) {
      if (ent->d_name[0] != '.') {
        sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
        expandWildcard(newPrefix,suffix);
      }
    }
  }
  regfree(&re);
  free(reg);
  closedir(d);
}


void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}



#if 0
main()
{
  yyparse();
}
#endif

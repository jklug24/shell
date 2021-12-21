
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include "shell.hh"
#include <cstring>
#include "y.tab.hh"
#include <regex>
#include <iostream>
#include <sys/wait.h>
#include <unistd.h>

////////////  Start added code ///////////

/*
extern "C" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)
*/

/////////// End added code ///////////

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

"|" {return PIPE;}
">" {return GREAT;}
"<" {return LESS;}
"2>" {return TWOGREAT;}
">>" {return GREATGREAT;}
">&" {return GREATAMP;}
">>&" {return GREATGREATAMP;}
"&" {return AMP;}


~[^ \n\t|><&]* {
  std::string home = yytext;
  if (home[1] != '\0' && home[1] != '/') {
    home = "/homes/" + home.substr(1, home.size()-1);
    yylval.cpp_string = new std::string(home);
    return WORD;
  } else {
    std::string fullpath = "/homes/";
    fullpath = fullpath.append(getenv("USER"));
    fullpath = fullpath.append(home.substr(1, home.size()-1));
    yylval.cpp_string = new std::string(fullpath);
    return WORD;
  }
}

[\$][\(][^\n\}]*[\)] {
  std::string command = yytext;
  //fprintf(stderr, "%s\n", command.c_str());
  command = command.substr(2, command.size()-3);
  
  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2);

  int pin[2];
  int pout[2];

  pipe(pin);
  pipe(pout);

  /*
  dup2(pin[0], 0);
  close(pin[0]);
  dup2(pout[1], 1);
  close(pout[1]);
  dup2(pout[1], 2);
  close(pout[1]);
  */
  
  write(pin[1], command.c_str(), strlen(command.c_str()));
  write(pin[1], "\n", 1);
  write(pin[1], "exit", 4);
  write(pin[1], "\n", 1);

  close(pin[1]);

  int ret = fork();
  if (ret == 0) {

    dup2(pin[0], 0);
    close(pin[0]);
    dup2(pout[1], 1);
    close(pout[1]);

    char* proc = "/proc/self/exe";
    char* a[] = {proc, NULL};
    execvp(proc, a);
  } else if (ret < 0) {
    perror("fork");
    exit(1);
  }

  char ch;
  char * buffer = (char *) malloc (4096);
  read(pout[0], buffer, 4096);
  for (int i = strlen(buffer)-1; i >= 0; i--) {
    if (buffer[i] == '\n') {
      myunputc(' ');
    } else {
      myunputc(buffer[i]);
    }
  }

  //waitpid(ret, NULL, 0);

  /*
  dup2(tmpin, 0);
  close(tmpin);
  dup2(tmpout, 1);
  close(tmpout);
  dup2(tmperr, 2);
  close(tmperr);
  */

  free(buffer);  
}

[/$][/{][^ \n\t|><&\}]*[\}] {
  std::string rep = yytext;
  int f = rep.find('{') + 1;
  int l = rep.find('}');
  std::string expand = rep.substr(f, l-f);

  if (!strcmp(expand.c_str(), "$")) {
    yylval.cpp_string = new std::string(std::to_string(getpid()));
  } else if (!strcmp(expand.c_str(), "!")) {
    yylval.cpp_string = new std::string(std::to_string(lastPid));
  } else if (!strcmp(expand.c_str(), "?")) {
    yylval.cpp_string = new std::string(std::to_string(lastReturn));
  } else if (!strcmp(expand.c_str(), "_")) {
    yylval.cpp_string = new std::string(lastCommand);
  } else if (!strcmp(expand.c_str(), "SHELL")) {
    yylval.cpp_string = new std::string(realpath(path, NULL));
  } else {
    if (getenv(expand.c_str())) {
      yylval.cpp_string = new std::string(getenv(expand.c_str()));
    } else {
      yylval.cpp_string = new std::string(expand);
    }
  }
  return WORD;
}

[\"][^\n\t\"][^\n\t\"]*[\"] {
  yylval.cpp_string = new std::string(yytext);
  yylval.cpp_string = new std::string(yylval.cpp_string->substr(1, yylval.cpp_string->size()-2));
  return WORD;
}

[^ \n\t|><&]*\\[^ \t\n][^ \t\n|><&]* {
  //yylval.cpp_string = new std::string(std::regex_replace(std::string(yytext), std::regex("\\([^/])"), "$1"));
  
  // using string/c-string (3) version:
  int i = 0;
    char * escape = (char *)malloc(200);
    char * temp = yytext;

    while(*temp){
        if (*temp == '\\'){
            if(*(temp+1) == '\\'){
                temp = temp + 2;
                escape[i++] = '\\';
            } else {
                escape[i++] = *(++temp);
            } 
        } else {
            escape[i++] = *temp;
        }
        temp++;
    }

    escape[i] = '\0';
    yylval.cpp_string = new std::string(strdup(escape));
  //yylval.cpp_string = &s;//new std::string(std::regex_replace(s,std::regex("[\\\\]([^\n])"),"$1"));
  return WORD;
}

[^ \t\n|><&][^ \t\n|><&]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}


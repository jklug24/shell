#include <cstdio>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

#include "shell.hh"

int yyparse(void);
char *path;

extern "C" void ctrlc(int sig) {
  printf("\n");
  Shell::prompt();
}

extern "C" void zombie(int sig) {
  while(waitpid(-1, 0, WNOHANG) > 0);
}

void Shell::prompt() {
  if (isatty(0)) {
    printf("myshell>");
    fflush(stdout);
  }
}

int main(int argc, char **argv) { 
  path = argv[0];

  struct sigaction sa1;
  sa1.sa_handler = ctrlc;
  sigemptyset(&sa1.sa_mask);
  sa1.sa_flags = SA_RESTART;

  if(sigaction(SIGINT, &sa1, NULL)){
    perror("sigaction");
    exit(-1);
  }

  struct sigaction sa2;
  sa2.sa_handler = zombie;
  sigemptyset(&sa2.sa_mask);
  sa2.sa_flags = SA_RESTART;

  if(sigaction(SIGCHLD, &sa2, NULL)){
    perror("sigaction");
    exit(-1);
  }

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;

#ifndef shell_hh
#define shell_hh

#include "command.hh"

extern char *path;
extern char *lastCommand;
extern int lastPid;
extern int lastReturn;

struct Shell {

  static void prompt();

  static Command _currentCommand;
};

#endif

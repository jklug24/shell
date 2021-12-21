/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>

#include <iostream>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <cstring>

#include "command.hh"
#include "shell.hh"

extern char **environ;
char *lastCommand;
int lastReturn;
int lastPid;

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile ) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf("\n\n" );
    printf("  Output       Input        Error        Background\n" );
    printf("  ------------ ------------ ------------ ------------\n" );
    printf("  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf("\n\n" );
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }

    // Print contents of Command data structure
    //if (isatty(0)) {
        //print();
    //}


    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec

    // Set up tmp and fd vars
    int tmpin = dup(0);
    //close(0);
    int tmpout = dup(1);
    //close(1);
    int tmperr = dup(2);
    //close(2);

    int fdin;
    int fdout;
    int fderr;

    // if there is an infile open it else use stdin
    if (_inFile) {
        fdin = open(_inFile->c_str(), O_RDONLY);
    } else {
        fdin = dup(tmpin);
    }


    // iterate through each command
    int ret;
    int numCommands = _simpleCommands.size();
    for (int i = 0; i < numCommands; i++) {
        dup2(fdin, 0);
        close(fdin);

        // if the command is the last one set fdout and fderr appropriately
        if (i == numCommands-1) {
            if (_outFile) {
                if (_append) {
                    fdout = open(_outFile->c_str(), O_WRONLY|O_CREAT|O_APPEND, 0666);
                } else {
                    fdout = open(_outFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0666);
                }
            } else {
                fdout = dup(tmpout);
            }
            if (_errFile) {
                if (_append) {
                    fderr = open(_errFile->c_str(), O_WRONLY|O_CREAT|O_APPEND, 0666);
                } else {
                    fderr = open(_errFile->c_str(), O_WRONLY|O_CREAT|O_TRUNC, 0666);
                }
            } else {
                fderr = dup(tmperr);
            }
            dup2(fderr, 2);
            close(fderr);
        //if the command is not the last one set up the pipe
        } else {
            int fdpipe[2];
            pipe(fdpipe);
            fdout = fdpipe[1];
            fdin = fdpipe[0];
        }

        // set out and error correctly
        dup2(fdout, 1);
        close(fdout);
        dup2(fderr, 2);
        close(fderr);
        // fork new process
        if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "exit")) {
            printf("Good bye!!\n");
            _exit(1);
        
        }  else if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "setenv")) {
            setenv(_simpleCommands[i]->_arguments[1]->c_str(),
                            _simpleCommands[i]->_arguments[2]->c_str(), 1);
            clear();
            Shell::prompt();
            return;
        
        } else if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "unsetenv")) {
            unsetenv(_simpleCommands[i]->_arguments[1]->c_str());
            clear();
            Shell::prompt();
            return;
        
        } else if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "cd")) {
            int err;
            if (_simpleCommands[i]->_arguments.size() == 1) {
                err = chdir(getenv("HOME"));
            } else {
                err = chdir(_simpleCommands[i]->_arguments[1]->c_str());
            }
            if (err < 0) {
                perror("cd: can't cd to notfound");
            }
            clear();
            Shell::prompt();
            return;
        } else {
            ret = fork();
            if (ret == 0) {
                // if printenv, iterate through and print environ
                if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")) {
                    char **p = environ;
                    while (*p) {
                        printf("%s\n", *p);
                        p++;
                    }
                    exit(0);
                }

                // create arglist to fit execvp input standard
                int argLen = _simpleCommands[i]->_arguments.size();
                char** const argList = new char* [argLen+1];
                for (int j = 0; j < argLen; j++) {
                    argList[j] = const_cast<char*>(_simpleCommands[i]->_arguments[j]->c_str());
                }
                argList[argLen] = nullptr;
    
                // execvp command in child process and exit
                execvp(_simpleCommands[i]->_arguments[0]->c_str(), argList);
                perror("execvp");
                exit(1);
            }
        }
    }

    int numArgs = _simpleCommands[numCommands-1]->_arguments.size();
    lastCommand = strdup(_simpleCommands[numCommands-1]->_arguments[numArgs-1]->c_str());

    // reset in, out and error
    dup2(tmpin, 0);
    dup2(tmpout, 1);
    dup2(tmperr, 2);
    close(tmpin);
    close(tmpout);
    close(tmperr);

    // wait for process to execute if not background process
    if (!_background) {
        int status;
        waitpid(ret, &status, 0);
        lastReturn = WEXITSTATUS(status);
    } else {
        lastPid = ret;
    }

    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}

SimpleCommand * Command::_currentSimpleCommand;

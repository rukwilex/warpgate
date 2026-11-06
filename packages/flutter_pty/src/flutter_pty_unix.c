
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <pthread.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/wait.h>

#include "forkpty.h"
#include "flutter_pty.h"

#include "include/dart_api.h"
#include "include/dart_api_dl.h"
#include "include/dart_native_api.h"

typedef struct PtyHandle
{
    int ptm;

    int pid;

    pthread_mutex_t mutex;

    pthread_cond_t ready;

    int credits;

    int closing;

    bool ackRead;

    int refs;

} PtyHandle;

static void pty_release(PtyHandle *handle)
{
    if (__atomic_sub_fetch(&handle->refs, 1, __ATOMIC_SEQ_CST) == 0)
    {
        close(handle->ptm);
        pthread_cond_destroy(&handle->ready);
        pthread_mutex_destroy(&handle->mutex);
        free(handle);
    }
}

typedef struct ReadLoopOptions
{
    PtyHandle *handle;

    Dart_Port port;

} ReadLoopOptions;

char *error_message = NULL;

static void *read_loop(void *arg)
{
    ReadLoopOptions *options = (ReadLoopOptions *)arg;
    PtyHandle *handle = options->handle;

    char buffer[16384];

    while (1)
    {
        if (handle->ackRead)
        {
            pthread_mutex_lock(&handle->mutex);
            while (handle->credits == 0 && !handle->closing)
            {
                pthread_cond_wait(&handle->ready, &handle->mutex);
            }
            if (handle->credits > 0)
            {
                handle->credits--;
            }
            pthread_mutex_unlock(&handle->mutex);
        }
        ssize_t n = read(handle->ptm, buffer, sizeof(buffer));

        if (n <= 0)
        {
            break;
        }

        Dart_CObject result;
        result.type = Dart_CObject_kTypedData;
        result.value.as_typed_data.type = Dart_TypedData_kUint8;
        result.value.as_typed_data.length = n;
        result.value.as_typed_data.values = (uint8_t *)buffer;

        Dart_PostCObject_DL(options->port, &result);
    }

    free(options);
    pty_release(handle);
    return NULL;
}

static void start_read_thread(PtyHandle *handle, Dart_Port port)
{
    ReadLoopOptions *options = malloc(sizeof(ReadLoopOptions));

    options->handle = handle;

    options->port = port;

    pthread_t _thread;

    if (pthread_create(&_thread, NULL, &read_loop, options) == 0)
    {
        pthread_detach(_thread);
    }
    else
    {
        free(options);
        pty_release(handle);
    }
}

typedef struct WaitExitOptions
{
    int pid;

    Dart_Port port;

} WaitExitOptions;

static void *wait_exit_thread(void *arg)
{
    WaitExitOptions *options = (WaitExitOptions *)arg;

    int status;

    waitpid(options->pid, &status, 0);

    if (WIFEXITED(status))
    {
        Dart_PostInteger_DL(options->port, WEXITSTATUS(status));
    }
    else if (WIFSIGNALED(status))
    {
        Dart_PostInteger_DL(options->port, -WTERMSIG(status));
    }

    free(options);
    return NULL;
}

static void start_wait_exit_thread(int pid, Dart_Port port)
{
    WaitExitOptions *options = malloc(sizeof(WaitExitOptions));

    options->pid = pid;

    options->port = port;

    pthread_t _thread;

    if (pthread_create(&_thread, NULL, &wait_exit_thread, options) == 0)
    {
        pthread_detach(_thread);
    }
    else
    {
        free(options);
    }
}

static void set_environment(char **environment)
{
    if (environment == NULL)
    {
        return;
    }

    while (*environment != NULL)
    {
        putenv(*environment);
        environment++;
    }
}

FFI_PLUGIN_EXPORT PtyHandle *pty_create(PtyOptions *options)
{
    struct winsize ws;

    ws.ws_row = options->rows;
    ws.ws_col = options->cols;

    int ptm;

    int pid = pty_forkpty(&ptm, NULL, NULL, &ws);

    if (pid < 0)
    {
        error_message = "pty_forkpty failed";
        perror("pty_forkpty");
        return NULL;
    }

    if (pid == 0)
    {
        set_environment(options->environment);

        if (options->working_directory != NULL && strlen(options->working_directory) > 0)
        {
            chdir(options->working_directory);
        }

        int ok = execvp(options->executable, options->arguments);

        if (ok < 0)
        {
            perror("execvp");
        }
    }

    PtyHandle *handle = (PtyHandle *)malloc(sizeof(PtyHandle));

    handle->ptm = ptm;
    handle->pid = pid;
    pthread_mutex_init(&handle->mutex, NULL);
    pthread_cond_init(&handle->ready, NULL);
    handle->credits = 1;
    handle->closing = 0;
    handle->ackRead = options->ackRead;
    handle->refs = 2;

    start_read_thread(handle, options->stdout_port);

    start_wait_exit_thread(pid, options->exit_port);

    return handle;
}

FFI_PLUGIN_EXPORT void pty_write(PtyHandle *handle, char *buffer, int length)
{
    write(handle->ptm, buffer, length);
}

FFI_PLUGIN_EXPORT void pty_ack_read(PtyHandle *handle)
{
    if (handle->ackRead)
    {
        pthread_mutex_lock(&handle->mutex);
        if (handle->credits < 1)
        {
            handle->credits++;
        }
        pthread_cond_signal(&handle->ready);
        pthread_mutex_unlock(&handle->mutex);
    }
}

FFI_PLUGIN_EXPORT int pty_resize(PtyHandle *handle, int rows, int cols)
{
    struct winsize ws;

    ws.ws_row = rows;
    ws.ws_col = cols;

    return ioctl(handle->ptm, TIOCSWINSZ, &ws);
}

FFI_PLUGIN_EXPORT int pty_getpid(PtyHandle *handle)
{
    return handle->pid;
}

FFI_PLUGIN_EXPORT void pty_close(PtyHandle *handle)
{
    pthread_mutex_lock(&handle->mutex);
    handle->closing = 1;
    pthread_cond_broadcast(&handle->ready);
    pthread_mutex_unlock(&handle->mutex);
    pty_release(handle);
}

FFI_PLUGIN_EXPORT char *pty_error(void)
{
    return NULL;
}

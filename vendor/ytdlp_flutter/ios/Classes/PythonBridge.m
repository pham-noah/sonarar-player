#import "PythonBridge.h"

#include <Python/Python.h>

static BOOL sRunning = NO;

@implementation PythonBridge

+ (BOOL)isRunning {
    return sRunning;
}

+ (BOOL)startWorkerWithStdlibPath:(NSString *)stdlibPath
                       scriptPath:(NSString *)scriptPath
                        workerDir:(NSString *)workerDir
                          pyzPath:(NSString *)pyzPath
                         certPath:(NSString *)certPath {
    if (sRunning) {
        return YES;
    }
    sRunning = YES;

    // The worker reads its configuration from the environment; set it
    // before the interpreter thread starts.
    setenv("YTDLP_WORKER_DIR", workerDir.UTF8String, 1);
    setenv("YTDLP_PYZ", pyzPath.UTF8String, 1);
    if (certPath != nil) {
        setenv("SSL_CERT_FILE", certPath.UTF8String, 1);
    }
    // Keep CPython from probing for a home installation that doesn't exist.
    setenv("PYTHONHOME", stdlibPath.stringByDeletingLastPathComponent.UTF8String, 1);

    [NSThread detachNewThreadWithBlock:^{
        PyStatus status;
        PyConfig config;
        PyConfig_InitIsolatedConfig(&config);
        config.write_bytecode = 0;      // the bundle is read-only
        config.buffered_stdio = 0;
        config.install_signal_handlers = 0;  // don't fight the app runtime

        status = PyConfig_SetBytesString(&config, &config.program_name,
                                         "ytdlp_worker");
        if (PyStatus_Exception(status)) {
            NSLog(@"[ytdlp_flutter] program_name failed: %s", status.err_msg);
            PyConfig_Clear(&config);
            sRunning = NO;
            return;
        }

        // Explicit module search paths: the bundled stdlib, its binary
        // modules, and the yt-dlp zipapp.
        config.module_search_paths_set = 1;
        NSArray<NSString *> *paths = @[
            stdlibPath,
            [stdlibPath stringByAppendingPathComponent:@"lib-dynload"],
            pyzPath,
        ];
        for (NSString *path in paths) {
            wchar_t *wide = Py_DecodeLocale(path.UTF8String, NULL);
            status = PyWideStringList_Append(&config.module_search_paths, wide);
            PyMem_RawFree(wide);
            if (PyStatus_Exception(status)) {
                NSLog(@"[ytdlp_flutter] search path failed: %s", status.err_msg);
                PyConfig_Clear(&config);
                sRunning = NO;
                return;
            }
        }

        status = Py_InitializeFromConfig(&config);
        PyConfig_Clear(&config);
        if (PyStatus_Exception(status)) {
            NSLog(@"[ytdlp_flutter] Py_InitializeFromConfig failed: %s",
                  status.err_msg);
            sRunning = NO;
            return;
        }

        FILE *fp = fopen(scriptPath.UTF8String, "r");
        if (fp == NULL) {
            NSLog(@"[ytdlp_flutter] cannot open worker script %@", scriptPath);
            sRunning = NO;
            return;
        }
        // Runs the worker loop; only returns if the loop dies.
        int rc = PyRun_SimpleFileEx(fp, "worker.py", 1);
        NSLog(@"[ytdlp_flutter] worker script exited (rc=%d)", rc);
        sRunning = NO;
    }];
    return YES;
}

@end

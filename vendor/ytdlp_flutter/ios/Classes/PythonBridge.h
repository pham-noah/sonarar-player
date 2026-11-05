#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Boots an embedded CPython on a dedicated thread and runs the ytdlp
/// worker script. The interpreter runs for the app's lifetime; CPython
/// cannot be safely re-initialized, so this may only be called once.
@interface PythonBridge : NSObject

/// Returns NO (with an error message via NSLog) if the interpreter could
/// not be configured. YES means the worker thread was launched.
+ (BOOL)startWorkerWithStdlibPath:(NSString *)stdlibPath
                       scriptPath:(NSString *)scriptPath
                        workerDir:(NSString *)workerDir
                          pyzPath:(NSString *)pyzPath
                         certPath:(nullable NSString *)certPath;

+ (BOOL)isRunning;

@end

NS_ASSUME_NONNULL_END

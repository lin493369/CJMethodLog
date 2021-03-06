//
//  CJLogger.m
//  CJMethodLog
//
//  Created by ChiJinLian on 2018/2/9.
//  Copyright © 2018年 ChiJinLian. All rights reserved.
//

#import "CJLogger.h"
#import "CJMethodLog+CJMessage.h"
#import <sys/mman.h>

static size_t normal_size = 5*1024;
malloc_zone_t *global_memory_zone;

class CJHighSpeedLogger {
public:
    ~CJHighSpeedLogger();
    CJHighSpeedLogger(malloc_zone_t *zone, NSString *path, size_t mmap_size);
    BOOL sprintfLogger(size_t grain_size,const char *format, ...);
    void cleanLogger();
    void syncLogger();
    bool isValid();
private:
    char *mmap_ptr;
    size_t mmap_size;
    size_t current_len;
    malloc_zone_t *memory_zone;
    FILE *mmap_fp;
    bool isFailed;
};

@interface CJLogger () {
    CJHighSpeedLogger *_stacklogger;
    NSString *_writeLogFilePath;
    NSRecursiveLock *_flushLock;
    NSString *_logFileWriteDir;
    NSString *_logFileReadDir;
}

@end

@implementation CJLogger

+ (CJLogger *)instance {
    static CJLogger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[CJLogger alloc] init];
    });
    return manager;
}

- (id)init {
    if(self = [super init]){
        _flushLock = [NSRecursiveLock new];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *LibDirectory = [paths objectAtIndex:0];
        _logFileWriteDir = [LibDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@",kCJLogDetector,kCJLogWriteDetector]];
//        CJLNSLog(@"log日志路径 = %@",_logFileWriteDir);
        _logFileReadDir = [LibDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@",kCJLogDetector,kCJLogReadDetector]];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:_logFileWriteDir]) {
            [fileManager createDirectoryAtPath:_logFileWriteDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        if (![fileManager fileExistsAtPath:_logFileReadDir]) {
            [fileManager createDirectoryAtPath:_logFileReadDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        [self moveWriteDataToReadFilePathFromStartSyncLog:NO];
        
        if(global_memory_zone == nil){
            global_memory_zone = malloc_create_zone(0, 0);
            malloc_set_zone_name(global_memory_zone, "CJLogDetector");
        }
        
        if(_stacklogger == NULL){
            _stacklogger = new CJHighSpeedLogger(global_memory_zone, _writeLogFilePath, normal_size);
            [self flushCustomLog:@"Create a new log file after the application launching"];
        }
    }
    return self;
}

- (void)moveWriteDataToReadFilePathFromStartSyncLog:(BOOL)startSyncLog {
    NSArray *tempArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_logFileWriteDir error:nil];
    for (NSString *file in tempArray) {
        if ([[file pathExtension] isEqualToString:kFileExtension]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] moveItemAtPath:[_logFileWriteDir stringByAppendingPathComponent:file] toPath:[_logFileReadDir stringByAppendingPathComponent:file] error:&error];
            if (error) {
                CJLNSLog(@"CJMethodLog: Failed to move log file，error = %@",error);
            }
        }
    }
    NSString *logFileName = [NSString stringWithFormat:@"%f.%@",CFAbsoluteTimeGetCurrent(),kFileExtension];
    _writeLogFilePath = [_logFileWriteDir stringByAppendingPathComponent:logFileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_writeLogFilePath]) {
        [[NSFileManager defaultManager] createFileAtPath:_writeLogFilePath contents:nil attributes:nil];
        if (startSyncLog) {
            _stacklogger = new CJHighSpeedLogger(global_memory_zone, _writeLogFilePath, normal_size);
            
//            [self flushCustomLog:@"Create a new log file after sync log data"];
//            [self flushAllocationStack:@"\n"];
        }
    }
}

- (void)flushCustomLog:(NSString *)log {
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc]init];
    dateFormat.dateFormat = @"yyyy/MM/dd/ HH:mm:ss";
    NSString *startDateStr = [dateFormat stringFromDate:[NSDate date]];
    [self flushAllocationStack:[NSString stringWithFormat:@"+++++++++++++++++++++ %@ %@ +++++++++++++++++++++\n",startDateStr,log]];
}

/**
 开始内存堆栈映射
 */
- (void)flushAllocationStack:(NSString *)log {
    if (_stacklogger != NULL && _stacklogger->isValid()) {
        [_flushLock lock];
        _stacklogger->sprintfLogger(normal_size,"%s",[log UTF8String]);
        [_flushLock unlock];
    }
}

- (void)stopFlush {
    _stacklogger->cleanLogger();
    _stacklogger->syncLogger();
}

- (void)syncLogData:(void(^)(NSData *logData))finishBlock {
    
    //新建一个空的文件，用来保存需要同步的所有的日志信息
    NSString *allLogFileName = [NSString stringWithFormat:@"%f.%@",CFAbsoluteTimeGetCurrent(),kFileExtension];
    NSString *allLogFilePath = [_logFileReadDir stringByAppendingPathComponent:allLogFileName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:allLogFilePath]) {
        [[NSFileManager defaultManager] createFileAtPath:allLogFilePath contents:nil attributes:nil];
    }
    
    [_flushLock lock];
    _stacklogger->syncLogger();
    [self flushCustomLog:@"Start sync log data"];
    [self flushAllocationStack:@"\n"];
    [self moveWriteDataToReadFilePathFromStartSyncLog:YES];
    [_flushLock unlock];
    
    NSArray *readArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_logFileReadDir error:nil];
    NSMutableData *allData = [[NSMutableData alloc] init];
    for (NSString *file in readArray) {
        if (![file isEqualToString:allLogFileName] && [[file pathExtension] isEqualToString:kFileExtension]) {
            NSString *filePath = [_logFileReadDir stringByAppendingPathComponent:file];
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            [allData appendData:data];
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }
    }
    
    if (![allData writeToFile:allLogFilePath atomically:YES]) {
        CJLNSLog(@"CJMethodLog: After sync log data, failed to write log data");
    }
    
    if (finishBlock) {
        finishBlock([allData copy]);
    }
}

- (void)clearLogData {
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_logFileReadDir error:NULL];
    NSEnumerator *enumerator = [contents objectEnumerator];
    NSString *filename;
    while ((filename = [enumerator nextObject])) {
        if ([[filename pathExtension] isEqualToString:kFileExtension]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] removeItemAtPath:[_logFileReadDir stringByAppendingPathComponent:filename] error:NULL];
            if (error) {
                CJLNSLog(@"CJMethodLog: Failed to delete log data, error = %@",error);
            }
        }
    }
}

@end

CJHighSpeedLogger::~CJHighSpeedLogger() {
    if(mmap_ptr != NULL){
        //取消参数start所指的映射内存起始地址，参数length则是欲取消的内存大小
        munmap(mmap_ptr , mmap_size);
    }
}

CJHighSpeedLogger::CJHighSpeedLogger(malloc_zone_t *zone, NSString *path, size_t size) {
    current_len = 0;
    mmap_size = size;
    memory_zone = zone;
    FILE *fp = fopen ( [path fileSystemRepresentation] , "wb+" ) ;
    if(fp != NULL){
        int ret = ftruncate(fileno(fp), size);
        if(ret == -1){
            isFailed = true;
        }
        else {
            //函数设置文件指针stream的位置
            fseek(fp, 0, SEEK_SET);
            char *ptr = (char *)mmap(0, size, PROT_WRITE | PROT_READ, (MAP_FILE|MAP_SHARED), fileno(fp), 0);
            memset(ptr, '\0', size);
            if(ptr != NULL){
                mmap_ptr = ptr;
                mmap_fp = fp;
            }
            else {
                isFailed = true;
            }
        }
    }
    else {
        isFailed = true;
    }
}

BOOL CJHighSpeedLogger::sprintfLogger(size_t grain_size,const char *format, ...) {
    va_list args;
    va_start(args, format);
    BOOL result = NO;
    size_t maxSize = 10240;
    char *tmp = (char *)memory_zone->malloc(memory_zone, maxSize);
    size_t length = vsnprintf(tmp, maxSize, format, args);
    if(length >= maxSize) {
        memory_zone->free(memory_zone,tmp);
        return NO;
    }

    if(length + current_len < mmap_size - 1){
        current_len += snprintf(mmap_ptr + current_len, (mmap_size - 1 - current_len), "%s", (const char*)tmp);
        result = YES;
    }
    else {
        char *copy = (char *)memory_zone->malloc(memory_zone, mmap_size);
        memcpy(copy, mmap_ptr, mmap_size);
        munmap(mmap_ptr ,mmap_size);
        size_t copy_size = mmap_size;
        mmap_size += grain_size;
        int ret = ftruncate(fileno(mmap_fp), mmap_size);
        if(ret == -1){
            memory_zone->free(memory_zone,copy);
            result = NO;
        }
        else {
            fseek(mmap_fp, 0, SEEK_SET);
            mmap_ptr = (char *)mmap(0, mmap_size, PROT_WRITE | PROT_READ, (MAP_FILE|MAP_SHARED), fileno(mmap_fp), 0);
            memset(mmap_ptr, '\0', mmap_size);
            if(!mmap_ptr){
                memory_zone->free(memory_zone,copy);
                result = NO;
            }
            else {
                result = YES;
                memcpy(mmap_ptr, copy, copy_size);
                current_len += snprintf(mmap_ptr + current_len, (mmap_size - 1 - current_len), "%s", (const char*)tmp);
            }
        }
        memory_zone->free(memory_zone,copy);
    }
    va_end(args);
    memory_zone->free(memory_zone,tmp);
    return result;
}

void CJHighSpeedLogger::cleanLogger() {
    current_len = 0;
    memset(mmap_ptr, '\0', mmap_size);
}

void CJHighSpeedLogger::syncLogger() {
    msync(mmap_ptr, mmap_size, MS_ASYNC);
}

bool CJHighSpeedLogger::isValid() {
    return !isFailed;
}


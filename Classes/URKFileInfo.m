//
//  URKFileInfo.m
//  UnrarKit
//

#import "URKFileInfo.h"

@implementation URKFileInfo

- (id)initWithFileHeader:(struct RARHeaderDataEx *)fileHeader {
    self = [super init];
    if (self) {
        _fileName = [NSString stringWithCString:fileHeader->FileName encoding:NSASCIIStringEncoding];
        _archiveName = [NSString stringWithCString:fileHeader->ArcName encoding:NSASCIIStringEncoding];
        _unpackedSize = (long long) fileHeader->UnpSizeHigh << 32 | fileHeader->UnpSize;
        _packedSize = (long long) fileHeader->PackSizeHigh << 32 | fileHeader->PackSize;
        _packingMethod = fileHeader->Method;
        _hostOS = fileHeader->HostOS;
        _fileTime = [self parseDOSDate:fileHeader->FileTime];
        _fileCRC = fileHeader->FileCRC;
        _flags = fileHeader->Flags;
        _fileDictionary = fileHeader->DictSize;
    }
    return self;
}

- (NSDate *)parseDOSDate:(NSUInteger)dosTime {
    if (dosTime == 0) return nil;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    // MSDOS Date Format Parsing specified
    // here: http://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
    
    int year = ((dosTime>>25)&127) + 1980;  // 7 bits
    int month = (dosTime>>21)&15;  // 4 bits
    int day = (dosTime>>16)&31; // 5 bits
    int hour = (dosTime>>11)&31; // 5 bits
    int minute = (dosTime>>5)&63;	// 6 bits
    int second = (dosTime&31) * 2;  // 5 bits
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    [components setYear:year];
    [components setMonth:month];
    [components setDay:day];
    [components setHour:hour];
    [components setMinute:minute];
    [components setSecond:second];
    
    NSDate *date = [calendar dateFromComponents:components];
    
    return date;
}

@end

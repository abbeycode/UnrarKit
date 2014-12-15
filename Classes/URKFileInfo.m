//
//  URKFileInfo.m
//  UnrarKit
//

#import "URKFileInfo.h"

@implementation URKFileInfo

- (instancetype)initWithFileHeader:(struct RARHeaderDataEx *)fileHeader
{
    if ((self = [super init])) {
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

- (NSDate *)parseDOSDate:(NSUInteger)dosTime
{
    if (dosTime == 0) {
        return nil;
    }
    
    // MSDOS Date Format Parsing specified at this URL:
    // http://www.cocoanetics.com/2012/02/decompressing-files-into-memory/
    
    int year = ((dosTime>>25) & 127) + 1980; // 7 bits
    int month = (dosTime>>21) & 15;          // 4 bits
    int day = (dosTime>>16) & 31;            // 5 bits
    int hour = (dosTime>>11) & 31;           // 5 bits
    int minute = (dosTime>>5) & 63;          // 6 bits
    int second = (dosTime & 31) * 2;         // 5 bits
    
    NSDateComponents *components = [[NSDateComponents alloc] init];
    components.year = year;
    components.month = month;
    components.day = day;
    components.hour = hour;
    components.minute = minute;
    components.second = second;
    
    return [[NSCalendar currentCalendar] dateFromComponents:components];
}

@end

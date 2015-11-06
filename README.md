[![Build Status](https://travis-ci.org/abbeycode/UnrarKit.svg?branch=master)](https://travis-ci.org/abbeycode/UnrarKit)

# About

UnrarKit is here to enable Mac and iOS apps to easily work with RAR files for read-only operations. It is currently based on version 5.2.1 of the [UnRAR library](http://www.rarlab.com/rar/unrarsrc-5.2.1.tar.gz).

There is a main project, with unit tests, and a basic iOS example project, which demonstrates how to use the library.

I'm always open to improvements, so please submit your pull requests, or [create issues](https://github.com/abbeycode/UnrarKit/issues) for someone else to implement.


# Example Usage

```Objective-C
NSError *archiveError = nil;
URKArchive *archive = [[URKArchive alloc] initWithPath:@"An Archive.rar" error:&archiveError];
NSError *error = nil;
```

## Listing the file names in an archive
```Objective-C
NSArray<String*> *filesInArchive = [archive listFilenames:&error];
for (NSString *name in filesInArchive) {
    NSLog(@"Archived file: %@", name);
}
```

## Listing the file details in an archive
```Objective-C
NSArray<URKFileInfo*> *fileInfosInArchive = [archive listFileInfo:&error];
for (URKFileInfo *info in fileInfosInArchive) {
    NSLog(@"Archive name: %@ | File name: %@ | Size: %lld", info.archiveName, info.filename, info.uncompressedSize);
}
```

## Working with passwords
```Objective-C
NSArray<URKFileInfo*> *fileInfosInArchive = [archive listFileInfo:&error];
if (archive.isPasswordProtected) {
    NSString *givenPassword = // prompt user
    archive.password = givenPassword
}

// You can now extract the files
```

## Extracting files to a directory
```Objective-C
BOOL extractFilesSuccessful = [archive extractFilesTo:@"some/directory"
                                            overWrite:NO
                                             progress:
    ^(URKFileInfo *currentFile, CGFloat percentArchiveDecompressed) {
        NSLog(@"Extracting %@: %f%% complete", currentFile.filename, percentArchiveDecompressed);
    }
                                                error:&error];
```

## Extracting a file into memory
```Objective-C
NSData *extractedData = [archive extractDataFromFile:@"a file in the archive.jpg"
                                            progress:^(CGFloat percentDecompressed) {
                                                         NSLog(@"Extracting, %f%% complete", percentDecompressed);
                                            }
                                               error:&error];
```

## Streaming a file

For large files, you may not want the whole contents in memory at once. You can handle it one "chunk" at a time, like so:

```Objective-C
BOOL success = [archive extractBufferedDataFromFile:@"a file in the archive.jpg"
                                              error:&error
                                             action:
                ^(NSData *dataChunk, CGFloat percentDecompressed) {
                    NSLog(@"Decompressed: %f%%", percentDecompressed);
                    // Do something with the NSData chunk
                }];
```

# Installation

UnrarKit is a CocoaPods project, which is the recommended way to install it. If you're not familiar with [CocoaPods](http://cocoapods.org), you can start with their [Getting Started guide](http://guides.cocoapods.org/using/getting-started.html).

I've included a sample [`podfile`](Example/Podfile) in the Example directory along with the sample project. Everything should install with the single command:

    pod install


# Notes

To open in Xcode, use the [UnrarKit.xcworkspace](UnrarKit.xcworkspace) file, which includes the other projects.

## Documentation

Full documentation for the project is available on [CocoaDocs](http://cocoadocs.org/docsets/UnrarKit).

# Credits

* Dov Frankel (dov@abbey-code.com)
* Rogerio Pereira Araujo (rogerio.araujo@gmail.com)
* Vicent Scott (vkan388@gmail.com)

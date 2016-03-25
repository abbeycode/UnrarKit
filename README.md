[![Build Status](https://travis-ci.org/abbeycode/UnrarKit.svg?branch=master)](https://travis-ci.org/abbeycode/UnrarKit)
[![Documentation Coverage](https://img.shields.io/cocoapods/metrics/doc-percent/UnrarKit.svg)](http://cocoadocs.org/docsets/UnrarKit)

# About

UnrarKit is here to enable Mac and iOS apps to easily work with RAR files for read-only operations. It is currently based on version 5.2.1 of the [UnRAR library](http://www.rarlab.com/rar/unrarsrc-5.2.1.tar.gz).

There is a main project, with unit tests, and a basic iOS example project, which demonstrates how to use the library. To see all of these, open the main workspace file.

I'm always open to improvements, so please submit your pull requests, or [create issues](https://github.com/abbeycode/UnrarKit/issues) for someone else to implement.


# Installation

UnrarKit supports both [CocoaPods](https://cocoapods.org/) and [Carthage](https://github.com/Carthage/Carthage). CocoaPods does not support dynamic framework targets (as of v0.39.0), so in that case, please use Carthage.

Cartfile:

    github "abbeycode/UnrarKit"

Podfile:

    pod "UnrarKit"

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

# Notes

To open in Xcode, use the [UnrarKit.xcworkspace](UnrarKit.xcworkspace) file, which includes the other projects.

## Documentation

Full documentation for the project is available on [CocoaDocs](http://cocoadocs.org/docsets/UnrarKit).

# Pushing a new CocoaPods version

New tagged builds (in any branch) get pushed to CocoaPods automatically, provided they meet the following criteria:

1. All builds and tests succeed
2. The library builds successfully for CocoaPods and for Carthage
3. The build is tagged with something resembling a version number (`#.#.#(-beta#)`, e.g. **2.9** or **2.9-beta5**)
4. `pod spec lint` passes, making sure the CocoaPod is 100% valid

Before pushing a build, you must:

1. Add the release notes to the [CHANGELOG.md](CHANGELOG.md), and commit
2. Run [set-version](Scripts/set-version.sh), like so:
     
    `./Scripts/set-version.sh <version number>`
    
    This does the following:
    
    1. Updates the [UnrarKit-Info.plist](Resources/UnrarKit-Info.plist) file to indicate the new version number, and commits it

    2. Makes an annotated tag whose message contains the release notes entered in Step 1

Once that's done, you can call `git push --follow-tags` [<sup id=a1>1</sup>](#f1), and let [Travis CI](https://travis-ci.org/abbeycode/UnrarKit/builds) take care of the rest. 

# Credits

* Dov Frankel (dov@abbey-code.com)
* Rogerio Pereira Araujo (rogerio.araujo@gmail.com)
* Vicent Scott (vkan388@gmail.com)



<hr>

<span id="f1">1</span>: Or set `followTags = true` in your git config to always get this behavior:

    git config --global push.followTags true

[↩](#a1)
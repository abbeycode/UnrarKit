# UnrarKit CHANGELOG

## 2.7.1

* Pushing tagged builds to CocoaPods from Travis
* Adding release notes to GitHub

## 2.7

Updated to the latest version of the UnRAR library (v5.3.11)


## 2.6

* Added full support for Carthage (Issue #22)
* Added annotations for nullability, improving compatibility with Xcode 7 and Swift


## 2.5.3

Fixed Podspec bug causing build errors when building as a framework with CocoaPods (Issue #28)


## 2.5.2

Moved off of deprecated `xcconfig` attribute in podspec (Issue #25)


## 2.5.1

Improved performance of the `-isPasswordProtected` method (Issue #24)


## 2.5

Fixed bug in -extractFilesTo:overwrite:progress:error: that would sometimes cause garbage characters in the extracted files' names (Issue #20)


## 2.4.3

Tweaked isPasswordProtected so it doesn't log an error message when an archive has a header password (Issue #21)


## 2.4.2

Fixed bug causing validatePassword to return NO for valid passwords in RAR5 archives (Issue #19)


## 2.4.1

Decreased size of library, by removing large sample archives (Issue #18), and added more information to the readme file


## 2.4

Added methods to detect whether a file is a RAR archive (Issue #17)


## 2.3

* Full Unicode support (Issue #11)
* Better support for moving files during a decompression into memory by adding a new block-based method that streams the file (Issue #4)
* Added pervasive use of new [URKFileInfo](Classes/URKFileInfo.h) class, which exposes several metadata fields of each file, rather than relying on passing filenames around (Issue #7 - Thanks, @mmcdole!)
* Added methods to test whether an archive is password-protected, and to test a given password (Issue #10 - Thanks, @scinfu!)
* Added progress reporting callbacks to most methods (Issue #6)
* Added several block-based methods that allow a guarantee of completing successfully, even if a file moves or gets deleted (Issue #5)
* Now fully thread-safe, even accessing the same archive object on different threads (it will block, instead of crashing)


## 2.2.4

Added -lc++ to CocoaPods linker flags, so that a .mm file is no longer required for a successful build


## 2.2.2

Added documentation, full Travis CI integration


## 2.2

Upgraded to unrar library 5.2.1


## 2.1

Fixed bug in NSErrors generated


## 2.0.7

Fixed major leak of file descriptors, causing clients to run out of file descriptors


## 2.0.6

Added requires_arc flag to podspec


## 2.0.5

Fixed an Xcode 6 compilation bug


## 2.0.2

First release in CocoaPods spec repo


## 2.0.0

Initial release
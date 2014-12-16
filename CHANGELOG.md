# UnrarKit CHANGELOG

## 2.3

* Full Unicode support (Issue #11)
* Better support for moving files during a decompression into memory by adding a new block-based method that streams the file (Issue #4)
* Added pervasive use of new [URKFileInfo](Classes/URKFileInfo.h) class, which exposes several metadata fields of each file, rather than relying on passing filenames around (Issue #7 - Thanks, @mmcdole!)
* Added methods to test whether an archive is password-protected, and to test a given password (Issue #10 - Thanks, @scinfu!)


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
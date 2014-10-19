[![Build Status](https://travis-ci.org/abbeycode/UnrarKit.svg?branch=master)](https://travis-ci.org/abbeycode/UnrarKit)

# About

UnrarKit is here to enable Mac and iOS apps to easily work with RAR files for read-only operations. It is currently based on version 5.2.1 of the [UnRAR library](http://www.rarlab.com/rar/unrarsrc-5.2.1.tar.gz).

There is a main project, with unit tests, and a basic iOS example project, which demonstrates how to use the library.

I'm always open to improvements, so please submit your pull requests, or [create issues](https://github.com/abbeycode/UnrarKit/issues) for someone else to implement.


# Installation

UnrarKit is a CocoaPods project, which is the recommended way to install it. If you're not familiar with [CocoaPods](http://cocoapods.org), you can start with their [Getting Started guide](http://guides.cocoapods.org/using/getting-started.html).

I've included a sample [`podfile`](Example/Podfile) in the Example directory along with the sample project. Everything should install with the single command:

    pod install


# Notes

Since UnrarKit uses C++ libraries, you will need to change the extension of classes that use UnrarKit to `.mm`. This will include `libstdc++` in the linking stage. If you would like to keep your extension `.m` (though I'm not sure what the advantage would be), you will need to add `libstdc++` to the linker flags in your application.

To open in Xcode, use the [UnrarKit.xcworkspace](UnrarKit.xcworkspace) file, which includes the other projects.

# Credits

* Dov Frankel (dov@abbey-code.com)
* Rogerio Pereira Araujo (rogerio.araujo@gmail.com)
* Vicent Scott (vkan388@gmail.com)

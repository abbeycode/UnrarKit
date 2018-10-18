//
//  SwiftTests.swift
//  UnrarKit Tests
//
//  Created by Dov Frankel on 10/18/18.
//

import Foundation

enum SignPostCode: UInt32 {   // some custom constants that I'll reference in Instruments
    case createTextFile = 0
    case archiveData = 1
    case extractData = 2
}

enum SignPostColor: UInt {    // standard color scheme for signposts in Instruments
    case blue = 0
    case green = 1
    case purple = 2
    case orange = 3
    case red = 4
}

#if !TARGET_OS_IPHONE
class SwiftTests: URKArchiveTestCase {
    
    func testExtractBufferedData_LargeSingleFile() {
        guard #available(macOS 10.12, *) else { return }
        NSLog("Running...")
        
        let largeArchiveName = "Large Single File Archive.rar";
        let archivedFileName = "AF429D3F-E1AE-4A67-B0F0-475B9D1AB713-87062-0000ACEB6B04D0A8.txt";

        let archiveURL = self.url(ofTestFile: largeArchiveName)!
        XCTAssertNotNil(archiveURL, "No URL found for archived large text file")
        
        do {
            let archiveExists = try archiveURL.checkResourceIsReachable()
            XCTAssertTrue(archiveExists, """
                Could not find large single file. This file is not part of the repo - please add
                it to the `Tests/Test Data` directory and update the largeArchiveName and
                archivedFileName variables above.
                
                largeArchiveName: \(largeArchiveName)
                archivedFileName: \(archivedFileName)
                """
            )
        } catch let err {
            XCTFail("Failed to check whether archive exists: \(err)")
            return
        }
        
        let deflatedFileURL = self.tempDirectory.appendingPathComponent("DeflatedTextFile.txt")
        let createSuccess = FileManager.default.createFile(atPath: deflatedFileURL.path, contents: nil, attributes: nil)
        XCTAssertTrue(createSuccess, "Failed to create empty deflate file")
        
        let handle = try! FileHandle(forWritingTo: deflatedFileURL)
        let archive = try! URKArchive(url: archiveURL)
        
        kdebug_signpost_start(SignPostCode.extractData.rawValue, 0, 0, 0, SignPostColor.purple.rawValue)
        
        try! archive.extractBufferedData(fromFile: archivedFileName) { (dataChunk, percentDecompressed) in
            NSLog("Decompressed: %f%%", percentDecompressed)
            handle.write(dataChunk)
        }
        
        kdebug_signpost_end(SignPostCode.extractData.rawValue, 0, 0, 0, SignPostColor.purple.rawValue)
    }
    
}
#endif

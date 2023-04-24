import Foundation
import ArgumentParser
import Automerge

extension AMInspector {
    struct Dump: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "dump",
            abstract: "Inspects and prints general metrics about Automerge files."
        )
        
        @OptionGroup var options: AMInspector.Options
        
        mutating func run() throws {
            let data: Data
            let doc: Document
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: options.inputFile))
            } catch {
                print("Unable to open file at \(options.inputFile).")
                AMInspector.exit(withError: error)
            }
            
            do {
                doc = try Document(data)
            } catch {
                print("\(options.inputFile) is not an Automerge document.")
                AMInspector.exit(withError: error)
            }
            do {
                try walk(doc)
            } catch {
                print("Error while walking document.")
                AMInspector.exit(withError: error)
            }
            
        }
    
        func walk(_ doc: Document) throws {
            print("{".white.bold)
            try walk(doc, from: ObjId.ROOT)
            print("}".white.bold)
        }

        func walk(_ doc: Document, from objId: ObjId, indent: Int = 1) throws {
            let indentString = String(repeating: " ", count: indent * 2)
            let whitequote = "\"".white.bold
            switch doc.objectType(obj: objId) {
            case .Map:
                for (key, value) in try doc.mapEntries(obj: objId) {
                    if case let Value.Scalar(scalarValue) = value {
                        print("\(indentString)\(whitequote)\("\(key)".lightBlue)\(whitequote) :\("\(scalarValue)".green)")
                    }
                    if case let Value.Object(childObjId, _) = value {
                        print("\(indentString)\(whitequote)\("\(key)".lightBlue)\(whitequote) : \("{".white.bold)")
                        try walk(doc, from: childObjId, indent: indent + 1)
                        print("\(indentString)}".white.bold)
                    }
                }
            case .List:
                if doc.length(obj: objId) == 0 {
                    print("\(indentString)[]".white.bold)
                } else {
                    print("\(indentString)[".white.bold)
                    for value in try doc.values(obj: objId) {
                        if case let Value.Scalar(scalarValue) = value {
                            print("\(indentString)  \("\(scalarValue)".white.bold)")
                        } else {
                            if case let Value.Object(childObjId, _) = value {
                                try walk(doc, from: childObjId, indent: indent + 1)
                            }
                        }
                    }
                    print("\(indentString)]".white.bold)
                }
            case .Text:
                let stringValue = try doc.text(obj: objId)
                print("\(indentString)\("Text[".green)\(whitequote)\(stringValue)\(whitequote)\("]".green)")
            }
        }
    }
}

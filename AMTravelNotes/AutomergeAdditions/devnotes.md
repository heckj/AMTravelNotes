# Developer Notes

The core of this started out with a few property wrappers that Alex Good created that revolved around a few key ideas:

1. Get something together that provides a top-level reference object that is Observable to work with SwiftUI.
2. An instance of this has two key properties:
  - `doc` - a reference to an Automerge document
  - `objId` - a reference to an objectId within an Automerge document
  These are enshrined with the protocols `HasDoc` and `HasObj`
3. Property wrappers that act as a proxy between properties that a developer drops into their own model class, provides a type for the local instance. 
The wrappers can also (like @Published) return a `Binding` to that type, with the storage details abstracted.
The form of property wrapper that Alex used was the mechanism that not only wraps the property, but has a reference ot the enclosing type as well. 
This is how it gets access to a document and objectId from which to read and write through the lower-level Automerge API. 

The basic setup lets you craft individual classes with properties that read and write from an existing Automerge document. As an example:

```swift
class SimpleModel: ObservableObject, HasDoc, HasObj, Identifiable {
    @AmScalarProp("id") var id: UUID
    @AmScalarProp("title") var title: String
    @AmText("summary") var notes: String

    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
        super.init(doc: doc, obj: obj)
    }
}
```

With this basic setup you load an Automerge Document and then create an instance of this model.
You can then pass that to SwiftUI views, and the code within the property wrappers triggers updates using the  observable object pattern as any bindings are updated.
The property wrappers dealt with converting the developer-provided types to and from scalar properties using the protocol `ScalarValueRepresentable`.
This does the work to transfer a limited set of types that aren't "composed" as containers from local Swift representations to the Automerge library's `Value` type, but only for the scalar values. 

Some of the limitations, for local App usage:

There isn't any direct way to create an Automerge schema from the developer-provided model. 
At the moment, I'm extending the initializer for the model with code that uses the low-level Automerge pieces to create a schema:
```swift
// TODO: check to see if it exists, and create if not
do {
    guard let obj = obj else {
        fatalError("initialized model not linked to an Automerge objectId.")
    }
    let _ = try! doc.putObject(obj: obj, key: "summary", ty: .Text)
    try doc.put(obj: obj, key: "id", value: .String(UUID().uuidString))
    let _ = try! doc.putObject(obj: obj, key: "images", ty: .List)
} catch {
    fatalError("Error establishing model schema: \(error)")
}
```

There's no direct support for lists - or anything that is "list like" (for example, that conforms to a Collection).

## Expose the Dynamic Types

Not ideal, but one fairly quick and immediate option was to expose the dynamic nature right on through.
This provides classes that "act like a ..." (List, Object, or Map) to bind to an ObjectId and access the values directly.
The types created were `DynamicAutomergeList`, `DynamicAutomergeMap`, and `DynamicAutomergeObject`.
All of which returned an instance of `AutomergeType` which is a single, combined enumeration that captures all the variations that you can find within an Automerge `Value`.
To cover all the variations of the lower-layer API underneath Automerge `Value`, you need to potentially walk through two nested enumerations - Value and ScalarValue - both of which are enumerations with associated values.

While this provided code that worked, it still suffered from being read-only.

## Path - getting a lookup to ObjectId

Everything set up so far builds from an ObjectId - but these are a bit hard to find. 
Specifically, you have to "walk" an Automerge document to get to a valid Id and the Id themselves are opaque - so you can't easily construct them.
I wanted to potentially return a class instance that was bound to an object within a List, which got me thinking about schema. 
I wanted to have an easier way to describe where in an Automerge document you were trying to access.
There's parts of this in the low-level Automerge API - a path being an array of `PathElement`.
The Automerge API provides this as a return value that is a struct of `Prop` and `ObjId`, which provides the Automerge-specific identifier to get to the next layer down a tree, but isn't amenable to constructing from a human readable string.
The path concept I added `lookupPath` takes a page from `jq` syntax of JSON documents (which shares some notable structural similarities with Automerge documents). 
It provides a means of parsing a string into an ObjectId by breaking up that string as steps into the schema,
walking the path, and reading back the relevant ObjectId, key to binding these classes.
Since that was a somewhat expensive operation, I also knocked together a simple memoization (cache) that
stores the ObjectIds along with their path as the various requests are walked. 
That cache, however, should be treated as ephemeral and reset with each document sync - as any document sync can dramatically alter the schema and remove and add ObjectIds.
I also made a `stringPath` method that was specific to an array of `PathElement` so that I could retrieve a path from an Automerge returned `[PathElement]` array.

I stepped back and added alternative initializers to the various objects that accepted a path as an alternative to providing a specific ObjectId as well:

```swift
init?(doc: Document, path: String) throws {
    self.doc = doc
    if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .List {
        self.obj = objId
    } else {
        return nil
    }
}
```


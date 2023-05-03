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

April 6, 2023

Not ideal, but one fairly quick and immediate option was to expose the dynamic nature right on through.
This provides classes that "act like a ..." (List, Object, or Map) to bind to an ObjectId and access the values directly.
The types created were `DynamicAutomergeList`, `DynamicAutomergeMap`, and `DynamicAutomergeObject`.
All of which returned an instance of `AutomergeType` which is a single, combined enumeration that captures all the variations that you can find within an Automerge `Value`.
To cover all the variations of the lower-layer API underneath Automerge `Value`, you need to potentially walk through two nested enumerations - Value and ScalarValue - both of which are enumerations with associated values.

While this provided code that worked, it still suffered from being read-only.

## Using a string based path to lookup an ObjectId

March 24, 2023

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

April 25, 2023

My earliest Path distinguished indexing into maps with a string, and lists with a integer, separated by a `.` character.
That seemed awkward to me as I read them, so I switched to taking a page from the CLI tool `jq`:

- Use `.` to denote shifting from one schema collection type to another.
- Use `[]` to represent indexing into a list - and the integer within the brackets represents the specific index location.
- Use arbitrary strings to represent the key to a value within a map.
- Default pathing strings always start from the root (which in general is a Map type object), but can represent arbitrary paths down from an interior schema location.
- Leaf nodes in the schema (the end values that aren't also containers) don't have a location representation.

Examples:

`.notes.[3]`: indicates that the root object has the key 'notes', that it is a list with at least 4 elements long, and this location points to the fourth element of that list.

My vague idea behind picking the `jq` structure for this is that it's filter "language" has a well-established structure that maps very closely.
In addition, the string path structure could be readily advanced to a filtering/query sort of mechanism.

## Using developer-provided classes to create schema in Automerge

April 10, 2023

I started to develop generic types that can take a developer-provided class structure and use that to return something that acts like a list, returning instances of the type the developer indicated, bound to Automerge.
I looked through Swift's capabilities to have "self knowledge" of stored properties on a type, and realized it was nearly non-existant. 
There's some functionality there through reflection (`Mirror`), but that the most common pattern - `Codable` - used compiler-synthesized code to get the same "automatic" iteration.

There's also an order of operations limitation with the Automerge API that needs to be considered.
When we want to add an object in Automerge, we need to know it's explicit parent ObjectId in order to get back a new ObjectId that represents the core of what will be a map or a list.
There's no concept of making a "free floating" object that gets placed somewhere within an Automerge document later.
Swift, on the other hand, tends to use the pattern of "create an instance in isolation" and then apply it to a location, effectively the inverse of what Automerge expects.
Because of this, to encode add an instance to a list - which in Automerge terms is adding a map into a list, and then populating the map. 
This implies that we need to hold the various instance values together without having an ObjectId, at least for a short period of time.

Because of this challenge, I started by tweaking `HasObj` protocol to be an optional ObjectId, thinking that it could represent a concept of the instance being "bound" to Automerge or not (free-floating).
The idea being that this is a valid state for an instance within Swift - being created before being added to a list - but that the instance wouldn't be "preserved" or written into Automerge until it **was** added to the list. 
Then it's various properties in term added to the map that represents the object.

The closest Swift idiomatic mechanism that I know of to this pattern is encoding as per the Codable protocol pair.
It achieves this sort of pattern, exposing an `init(from:)` method, with either a developer-provided implementation, or a compiler-synthesized version if all of the underlying stored properties conform to  `Codable`.
There _might_ be an interesting path forward here, outside of compiler synthesis, with Swift 5.9 feature being added now - Macros.

Thinking through how a developer provides this schema, my ideal preference would be structs for their simplicity - and the fact that they're easily, directly usable with SwiftUI. 
However, a struct doesn't offer much of a mechanism for observing changes to it and doesn't fit well with representing a "reference" to an instance in another data structure.
It does seem like it would be possible to completely encode and decode structs from Automerge, but then every change would have to go through that encode/decode process.
And part of what I'd like to have is any changes from a SwiftUI interface, which works through `Binding` to a type, to be reflected in the underlying data store directly.
If most updates are small and frequent, this seems like a pretty big mismatch. 

So it seems like a reference type (class) makes a lot more sense, leveraging some of the pattern that Alex initially set up. 
Those wrap instance properties with PropertyWrappers that can provide the `Binding<Thing>` that SwiftUI controls like to have, for example `Binding<String>` or `Binding<Int>`.
Because of the pattern of assignment - appending a new instance into a list - I need to have those objects support the idea of _not_ having an ObjectId for some (short!) period of time.
After the code adds the relevant type (list or map) in Automerge, it can provide the ObjectId to that instance. 
After which we need to iterate through the values of the instance and write those into Automerge, potentially recursively going down whatever structure exists within the stored properties.
When this is complete, any of the property wrappers should be able to read (and write, through a Binding) to the Automerge document for any value updates.

With a list iterator, I'll want to decode an object of some type from Automerge into a 'bound' instance (as in, it has a valid ObjectId) where any updates can be immediately written back.
I might be able to achieve this binding by leveraging Codable - or perhaps making a rough clone of the Codable protocols that don't need to be fully type erased - that support this iterative reading and writing of containers and values within them.
It turns out that Codable does a large amount of type erasure with it's structure, which in turn makes it a complex thing to understand.
I have this vague idea that I might replicate what Alex did with AutoSurgeon with an "AutomergeEncoder" that leverages the Codable protocol to explicitly write into, and read out from, and Automerge document.
If I can "decode" into one of these developer-provided classes that leverage the Property Wrappers for providing bindings from Swift types back to Automerge updates, that might work quite smoothly.

The same process, reversed (that is - `Encoding`) would then potentially create the schema that I'd like to exist even within a blank Automerge document.

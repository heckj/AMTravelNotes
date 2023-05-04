/// A type the represents a location within an un-keyed container.
struct ArrayKey: CodingKey, Equatable {
    init(index: Int) {
        intValue = index
    }

    init?(stringValue _: String) {
        preconditionFailure("Did not expect to be initialized with a string")
    }

    init?(intValue: Int) {
        self.intValue = intValue
    }

    var intValue: Int?

    var stringValue: String {
        "Index \(intValue!)"
    }
}

func == (lhs: ArrayKey, rhs: ArrayKey) -> Bool {
    precondition(lhs.intValue != nil)
    precondition(rhs.intValue != nil)
    return lhs.intValue == rhs.intValue
}

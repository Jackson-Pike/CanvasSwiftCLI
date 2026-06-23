// To run, use "swift scripts/classes_example.swift"

class C1 {
    // ----- Example 3 ------
    var x: Int = 0
    var y: Int = 0

    func setx1(_ v: Int) { x = v }
    func sety1(_ v: Int) { y = v }
    func getx1() -> Int { x }
    func gety1() -> Int { y }

    // ----- Example 5 ------
    func m1() {
        self.m2()
    }

    func m2() {
        print(13)
    }
}

class C2: C1 {
    // ----- Example 3 ------
    var y2: Int = 0

    func sety2(_ v: Int) { y2 = v }
    func getx2() -> Int { x }
    func gety2() -> Int { y2 }

    // ----- Example 5 ------
    override func m1() {
        print(22)
    }
    override func m2() {
        print(23)
    }
    func m3() {
        super.m1()
    }
}

let o2 = C2()
o2.setx1(101)
o2.sety1(102)
o2.sety2(999)

let someInts: [Int] = [
    o2.getx1(), // 101
    o2.gety1(), // 102
    o2.getx2(), // 101
    o2.gety2()  // 999
]

print(someInts)


class C3: C2 {
    override func m1() {
        print(32)
    }

    override func m2() { print(33) }
}

let o3 = C3()
o3.m3()



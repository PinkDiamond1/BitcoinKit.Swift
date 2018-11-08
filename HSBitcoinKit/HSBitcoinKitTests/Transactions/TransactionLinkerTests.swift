import XCTest
import Cuckoo
import RealmSwift
@testable import HSBitcoinKit

class TransactionLinkerTests: XCTestCase {

    private var linker: TransactionLinker!

    private var realm: Realm!
    private var previousTransaction: Transaction!
    private var pubKey: PublicKey!
    private var pubKeys: Results<PublicKey>!
    private var pubKeyHash = Data(hex: "1ec865abcb88cec71c484d4dadec3d7dc0271a7b")!

    override func setUp() {
        super.setUp()

        realm = try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "TestRealm"))
        try! realm.write { realm.deleteAll() }

        linker = TransactionLinker()
        previousTransaction = TestData.p2pkhTransaction
        pubKey = TestData.pubKey(pubKeyHash: pubKeyHash)

        try! realm.write {
            realm.add(pubKey, update: true)
            realm.add(previousTransaction)
        }

        pubKeys = realm.objects(PublicKey.self)
    }

    override func tearDown() {
        linker = nil
        realm = nil

        super.tearDown()
    }

    func testHandle_HasPreviousOutput() {
        let input = TransactionInput()
        input.previousOutputTxReversedHex = previousTransaction.reversedHashHex
        input.previousOutputIndex = previousTransaction.outputs.first!.index
        input.sequence = 100

        let transaction = Transaction()
        transaction.reversedHashHex = "0000000000000000000111111111111122222222222222333333333333333000"
        transaction.inputs.append(input)

        try! realm.write {
            realm.add(previousTransaction, update: true)
            realm.add(transaction, update: true)
        }

        XCTAssertEqual(transaction.isMine, false)
        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
        XCTAssertEqual(transaction.inputs.first!.address, nil)
        XCTAssertEqual(transaction.inputs.first!.keyHash, nil)
        try? realm.write {
            linker.handle(transaction: transaction, realm: realm)
        }
        XCTAssertEqual(transaction.isMine, true)
        assertOutputEqual(out1: transaction.inputs.first!.previousOutput!, out2: previousTransaction.outputs.first!)
        XCTAssertEqual(transaction.inputs.first!.address, previousTransaction.outputs.first!.address)
        XCTAssertEqual(transaction.inputs.first!.keyHash, previousTransaction.outputs.first!.keyHash)
    }

    func testHandle_HasNotPreviousOutput() {
        let input = TransactionInput()
        input.previousOutputTxReversedHex = TestData.p2pkTransaction.reversedHashHex
        input.previousOutputIndex = TestData.p2pkTransaction.outputs.first!.index
        input.sequence = 100

        let transaction = Transaction()
        transaction.reversedHashHex = "0000000000000000000111111111111122222222222222333333333333333000"
        transaction.inputs.append(input)

        try! realm.write {
            realm.add(previousTransaction, update: true)
            realm.add(transaction, update: true)
        }

        XCTAssertEqual(transaction.isMine, false)
        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
        try? realm.write {
            linker.handle(transaction: transaction, realm: realm)
        }
        XCTAssertEqual(transaction.isMine, false)
        XCTAssertEqual(transaction.inputs.first!.previousOutput, nil)
    }

    private func assertOutputEqual(out1: TransactionOutput, out2: TransactionOutput) {
        XCTAssertEqual(out1.value, out2.value)
        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
        XCTAssertEqual(out1.index, out2.index)
    }

}
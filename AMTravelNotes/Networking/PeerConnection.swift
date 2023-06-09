/*
 Copyright © 2022 Apple Inc.

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 WWDC Video references aligned with this code:
 - https://developer.apple.com/videos/play/wwdc2019/713/
 - https://developer.apple.com/videos/play/wwdc2020/10110/
 - https://developer.apple.com/videos/play/wwdc2022/110339/
 */

import Foundation
import Network

// Create parameters for use in PeerConnection and PeerListener with app services.
func applicationServiceParameters() -> NWParameters {
    let parameters = NWParameters.applicationService

    // Add your custom protocol to support messages.
    let syncOptions = NWProtocolFramer.Options(definition: AutomergeSyncProtocol.definition)
    parameters.defaultProtocolStack.applicationProtocols.insert(syncOptions, at: 0)

    return parameters
}

var sharedConnection: PeerConnection?

protocol PeerConnectionDelegate: AnyObject {
    func connectionReady()
    func connectionFailed()
    func receivedMessage(content: Data?, message: NWProtocolFramer.Message)
    func displayAdvertiseError(_ error: NWError)
}

class PeerConnection {
    weak var delegate: PeerConnectionDelegate?
    var connection: NWConnection?
    let endpoint: NWEndpoint?
    let initiatedConnection: Bool

    // Create an outbound connection when the user initiates a game.
    init(endpoint: NWEndpoint, interface _: NWInterface?, passcode: String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.endpoint = nil
        initiatedConnection = true

        let connection = NWConnection(to: endpoint, using: NWParameters(passcode: passcode))
        self.connection = connection

        startConnection()
    }

    // Create an outbound connection when the user initiates a game via DeviceDiscoveryUI.
    init(endpoint: NWEndpoint, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.endpoint = endpoint
        initiatedConnection = true

        // Create the NWConnection to the supplied endpoint.
        let connection = NWConnection(to: endpoint, using: applicationServiceParameters())
        self.connection = connection

        startConnection()
    }

    // Handle an inbound connection when the user receives a game request.
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        endpoint = nil
        self.connection = connection
        initiatedConnection = false

        startConnection()
    }

    // Handle the user exiting the game.
    func cancel() {
        if let connection = connection {
            connection.cancel()
            self.connection = nil
        }
    }

    // Handle starting the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        guard let connection = connection else {
            return
        }

        connection.stateUpdateHandler = { [weak self] newState in
            switch newState {
            case .ready:
                print("\(connection) established")

                // When the connection is ready, start receiving messages.
                self?.receiveNextMessage()

                // Notify the delegate that the connection is ready.
                if let delegate = self?.delegate {
                    delegate.connectionReady()
                }
            case let .failed(error):
                print("\(connection) failed with \(error)")

                // Cancel the connection upon a failure.
                connection.cancel()

                if let endpoint = self?.endpoint, let initiated = self?.initiatedConnection,
                   initiated, error == NWError.posix(.ECONNABORTED)
                {
                    // Reconnect if the user suspends the app on the nearby device.
                    let connection = NWConnection(to: endpoint, using: applicationServiceParameters())
                    self?.connection = connection
                    self?.startConnection()
                } else if let delegate = self?.delegate {
                    // Notify the delegate when the connection fails.
                    delegate.connectionFailed()
                }
            default:
                break
            }
        }

        // Start the connection establishment.
        connection.start(queue: .main)
    }

    // Handle sending a "document ID" message.
    func sendDocumentId(_ documentId: String) {
        // corresponds to SyncMessageType.id
        guard let connection = connection else {
            return
        }

        // Create a message object to hold the command type.
        let message = NWProtocolFramer.Message(syncMessageType: .id)
        let context = NWConnection.ContentContext(
            identifier: "DocumentId",
            metadata: [message]
        )

        // Send the app content along with the message.
        connection.send(
            content: documentId.data(using: .unicode),
            contentContext: context,
            isComplete: true,
            completion: .idempotent
        )
    }

    // Handle sending a "sync" message.
    func sendSyncMsg(_ syncMsg: Data) {
        guard let connection = connection else {
            return
        }

        // Create a message object to hold the command type.
        let message = NWProtocolFramer.Message(syncMessageType: .sync)
        let context = NWConnection.ContentContext(
            identifier: "Sync",
            metadata: [message]
        )

        // Send the app content along with the message.
        connection.send(
            content: syncMsg,
            contentContext: context,
            isComplete: true,
            completion: .idempotent
        )
    }

    // Receive a message, deliver it to your delegate, and continue receiving more messages.
    func receiveNextMessage() {
        guard let connection = connection else {
            return
        }

        connection.receiveMessage { content, context, _, error in
            // Extract your message type from the received context.
            if let gameMessage = context?
                .protocolMetadata(definition: AutomergeSyncProtocol.definition) as? NWProtocolFramer.Message
            {
                self.delegate?.receivedMessage(content: content, message: gameMessage)
            }
            if error == nil {
                // Continue to receive more messages until you receive an error.
                self.receiveNextMessage()
            }
        }
    }
}

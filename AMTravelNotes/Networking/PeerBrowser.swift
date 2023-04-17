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

import Network

var sharedBrowser: PeerBrowser?

// Update the UI when you receive new browser results.
protocol PeerBrowserDelegate: AnyObject {
	func refreshResults(results: Set<NWBrowser.Result>)
	func displayBrowseError(_ error: NWError)
}

class PeerBrowser {

	weak var delegate: PeerBrowserDelegate?
	var browser: NWBrowser?

	// Create a browsing object with a delegate.
	init(delegate: PeerBrowserDelegate) {
		self.delegate = delegate
		startBrowsing()
	}

	// Start browsing for services.
	func startBrowsing() {
		// Create parameters, and allow browsing over a peer-to-peer link.
		let parameters = NWParameters()
		parameters.includePeerToPeer = true

		// Browse for the Automerge sync bonjour service type.
        let browser = NWBrowser(for: .bonjour(type: AutomergeSyncProtocol.bonjourType, domain: nil),
                                using: parameters)
		self.browser = browser
		browser.stateUpdateHandler = { newState in
			switch newState {
			case .failed(let error):
				// Restart the browser if it loses its connection.
				if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
					print("Browser failed with \(error), restarting")
					browser.cancel()
					self.startBrowsing()
				} else {
					print("Browser failed with \(error), stopping")
					self.delegate?.displayBrowseError(error)
					browser.cancel()
				}
			case .ready:
				// Post initial results.
				self.delegate?.refreshResults(results: browser.browseResults)
			case .cancelled:
				sharedBrowser = nil
				self.delegate?.refreshResults(results: Set())
			default:
				break
			}
		}

		// When the list of discovered endpoints changes, refresh the delegate.
		browser.browseResultsChangedHandler = { results, changes in
			self.delegate?.refreshResults(results: results)
		}

		// Start browsing and ask for updates on the main queue.
		browser.start(queue: .main)
	}
}

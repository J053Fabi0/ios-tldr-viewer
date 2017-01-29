//
//  TLDRResponse.swift
//  tldr-viewer
//
//  Created by Matthew Flint on 31/12/2015.
//  Copyright © 2015 Green Light. All rights reserved.
//

import Foundation

struct TLDRResponse {
    let data: Data!
    let response: URLResponse!
    var error: Error?
}
